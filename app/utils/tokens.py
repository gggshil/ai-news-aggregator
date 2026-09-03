import base64
import hashlib
import hmac
import json
import logging
import os
import secrets
import time
import uuid
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

# JWT configuration
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY") or os.getenv("SECRET_KEY")
if not JWT_SECRET_KEY:
    # Stable fallback based on environment or machine-generated secret
    JWT_SECRET_KEY = os.getenv("APP_PASSWORD", "ai-news-aggregator-production-secret-key-salt")

JWT_ALGORITHM = "HS256"
JWT_ISSUER = "ai-news-aggregator"
DEFAULT_ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15"))
DEFAULT_REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))


class TokenError(Exception):
    """Base exception for token issues."""
    pass


class TokenExpiredError(TokenError):
    """Raised when token is expired."""
    pass


class TokenInvalidError(TokenError):
    """Raised when token signature or payload is invalid."""
    pass


def _b64url_encode(data: bytes) -> str:
    """Encodes bytes to base64url without padding."""
    return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")


def _b64url_decode(segment: str) -> bytes:
    """Decodes base64url string with auto padding."""
    rem = len(segment) % 4
    if rem > 0:
        segment += "=" * (4 - rem)
    return base64.urlsafe_b64decode(segment.encode("utf-8"))


def hash_token(raw_token: str) -> str:
    """Produces SHA-256 hash of a raw token for secure database storage."""
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


def create_token(
    payload: dict,
    expires_in_seconds: int,
    token_type: str = "access",
) -> tuple[str, str, datetime]:
    """
    Creates an RFC 7519 compliant HS256 JWT.
    Returns: (raw_jwt_string, jti, expiry_datetime)
    """
    now = int(time.time())
    exp = now + expires_in_seconds
    jti = str(uuid.uuid4())

    header = {
        "alg": JWT_ALGORITHM,
        "typ": "JWT"
    }

    claims = {
        "iss": JWT_ISSUER,
        "iat": now,
        "exp": exp,
        "jti": jti,
        "type": token_type,
    }
    claims.update(payload)

    header_bytes = json.dumps(header, separators=(",", ":")).encode("utf-8")
    payload_bytes = json.dumps(claims, separators=(",", ":")).encode("utf-8")

    encoded_header = _b64url_encode(header_bytes)
    encoded_payload = _b64url_encode(payload_bytes)

    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    signature = hmac.new(
        JWT_SECRET_KEY.encode("utf-8"),
        signing_input,
        hashlib.sha256
    ).digest()
    encoded_signature = _b64url_encode(signature)

    raw_jwt = f"{encoded_header}.{encoded_payload}.{encoded_signature}"
    expiry_dt = datetime.fromtimestamp(exp, tz=timezone.utc).replace(tzinfo=None)
    return raw_jwt, jti, expiry_dt


def create_access_token(
    subscriber_id: str,
    email: str,
    expires_in_minutes: int = DEFAULT_ACCESS_TOKEN_EXPIRE_MINUTES,
    custom_claims: dict = None,
) -> tuple[str, str, datetime]:
    """
    Generates a short-lived access token (default: 15 minutes).
    Returns (raw_jwt, jti, expiry_datetime).
    """
    payload = {
        "sub": subscriber_id,
        "email": email.strip().lower(),
    }
    if custom_claims:
        payload.update(custom_claims)

    return create_token(
        payload=payload,
        expires_in_seconds=expires_in_minutes * 60,
        token_type="access"
    )


def create_refresh_token(
    subscriber_id: str,
    email: str,
    expires_in_days: int = DEFAULT_REFRESH_TOKEN_EXPIRE_DAYS,
) -> tuple[str, str, datetime]:
    """
    Generates a long-lived refresh token (default: 30 days).
    Returns (raw_jwt, jti, expiry_datetime).
    """
    payload = {
        "sub": subscriber_id,
        "email": email.strip().lower(),
    }
    return create_token(
        payload=payload,
        expires_in_seconds=expires_in_days * 86400,
        token_type="refresh"
    )


def decode_and_verify_token(token: str, expected_type: str = "access") -> dict:
    """
    Decodes and rigorously validates an HS256 JWT:
    - Format (3 parts)
    - Algorithm (HS256)
    - Signature via constant-time comparison
    - Expiration (exp claim)
    - Issuer (iss claim)
    - Token type (type claim: 'access' or 'refresh')
    """
    if not token or not isinstance(token, str):
        raise TokenInvalidError("Missing or invalid token format.")

    token = token.strip()
    if token.startswith("Bearer "):
        token = token[7:].strip()

    parts = token.split(".")
    if len(parts) != 3:
        raise TokenInvalidError("Malformed JWT structure.")

    encoded_header, encoded_payload, encoded_signature = parts

    try:
        header_bytes = _b64url_decode(encoded_header)
        header = json.loads(header_bytes.decode("utf-8"))
    except Exception as e:
        raise TokenInvalidError(f"Invalid token header: {e}")

    if header.get("alg") != JWT_ALGORITHM:
        raise TokenInvalidError(f"Unsupported algorithm: {header.get('alg')}")

    # Validate HMAC signature
    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    expected_sig = hmac.new(
        JWT_SECRET_KEY.encode("utf-8"),
        signing_input,
        hashlib.sha256
    ).digest()
    expected_encoded_sig = _b64url_encode(expected_sig)

    if not hmac.compare_digest(expected_encoded_sig, encoded_signature):
        raise TokenInvalidError("Invalid token signature.")

    try:
        payload_bytes = _b64url_decode(encoded_payload)
        payload = json.loads(payload_bytes.decode("utf-8"))
    except Exception as e:
        raise TokenInvalidError(f"Invalid token payload: {e}")

    # Verify issuer
    if payload.get("iss") != JWT_ISSUER:
        raise TokenInvalidError("Invalid token issuer.")

    # Verify token type
    if expected_type and payload.get("type") != expected_type:
        raise TokenInvalidError(f"Invalid token type. Expected '{expected_type}', got '{payload.get('type')}'.")

    # Verify expiration
    exp = payload.get("exp")
    if not exp or not isinstance(exp, (int, float)):
        raise TokenInvalidError("Token missing expiration claim.")

    now = int(time.time())
    if now > exp:
        raise TokenExpiredError("Token has expired.")

    return payload


def create_password_reset_token(
    subscriber_id: str,
    email: str,
    expires_in_minutes: int = 60,
) -> tuple[str, str, datetime]:
    """Generates a secure password reset token (valid for 60 minutes)."""
    payload = {
        "sub": subscriber_id,
        "email": email.strip().lower(),
    }
    return create_token(
        payload=payload,
        expires_in_seconds=expires_in_minutes * 60,
        token_type="reset",
    )

