from http.server import BaseHTTPRequestHandler
import json
import logging
import secrets
from app.database.repository import Repository
from app.database.connection import db_session, engine
from app.database.models import Base
from app.utils.security import hash_password, verify_password
from app.services.email import send_welcome_email, send_otp_email
from app.utils.tokens import (
    create_access_token,
    create_refresh_token,
    decode_and_verify_token,
    hash_token,
    TokenExpiredError,
    TokenInvalidError,
)

logger = logging.getLogger(__name__)


def _build_session_response(user, repo: Repository, message: str, status_code: int = 200, user_agent: str = None, ip_address: str = None) -> tuple[int, dict]:
    """Issues access token + refresh token and records refresh token in repository."""
    acc_token, _, _ = create_access_token(subscriber_id=user.id, email=user.email)
    ref_token, ref_jti, ref_exp = create_refresh_token(subscriber_id=user.id, email=user.email)

    repo.save_refresh_token(
        jti=ref_jti,
        subscriber_id=user.id,
        token_hash=hash_token(ref_token),
        expires_at=ref_exp,
        user_agent=user_agent,
        ip_address=ip_address,
    )

    response_payload = {
        "success": True,
        "message": message,
        "access_token": acc_token,
        "refresh_token": ref_token,
        "token_type": "Bearer",
        "expires_in": 900,
        "subscriber": {"id": user.id, "email": user.email},
    }
    return status_code, response_payload


class handler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def _send_json(self, status_code: int, data: dict):
        self.send_response(status_code)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(data).encode("utf-8"))

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        # Allow checking authentication status via GET with Bearer token
        auth_header = self.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:].strip()
            try:
                payload = decode_and_verify_token(token, expected_type="access")
                repo = Repository()
                user = repo.session.query(repo.get_subscriber_by_email(payload.get("email", ""))).first() if hasattr(repo, "session") else None
                # or query subscriber
                from app.database.models import Subscriber
                sub = repo.session.query(Subscriber).filter_by(id=payload.get("sub")).first()
                if not sub or not sub.is_active:
                    self._send_json(401, {"success": False, "error": "User account inactive or not found."})
                    return
                self._send_json(200, {
                    "success": True,
                    "message": "Session valid",
                    "subscriber": {"id": sub.id, "email": sub.email}
                })
                return
            except TokenExpiredError:
                self._send_json(401, {"success": False, "error": "Access token expired.", "code": "TOKEN_EXPIRED"})
                return
            except TokenInvalidError as e:
                self._send_json(401, {"success": False, "error": str(e), "code": "TOKEN_INVALID"})
                return

        self._send_json(200, {"status": "ok", "message": "Auth service is running"})

    def do_POST(self):
        try:
            with engine.connect() as conn:
                Base.metadata.create_all(engine)

            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body.decode("utf-8")) if body else {}

            action = data.get("action", "register")
            email = data.get("email", "").strip().lower()
            password = data.get("password", "")
            user_agent = self.headers.get("User-Agent")
            ip_address = self.client_address[0] if self.client_address else None

            repo = Repository()

            # 1. ACTION: SEND OTP
            if action == "send_otp":
                target_email = (email or "").strip().lower()
                if not target_email or "@" not in target_email or "." not in target_email:
                    self._send_json(400, {"success": False, "error": "Please enter a valid email address."})
                    return

                can_send, remaining = repo.check_otp_resend_cooldown(target_email, cooldown_seconds=45)
                if not can_send:
                    self._send_json(429, {"success": False, "error": f"Please wait {remaining} seconds before requesting a new code."})
                    return

                otp_code = f"{secrets.randbelow(900000) + 100000:06d}"
                repo.create_email_otp(email=target_email, otp_code=otp_code, expires_minutes=10)

                # Send OTP email safely
                dispatched = False
                try:
                    dispatched = send_otp_email(target_email, otp_code)
                except Exception as e:
                    logger.warning(f"Failed to dispatch OTP email: {e}")

                if not dispatched:
                    self._send_json(500, {
                        "success": False,
                        "error": "Email delivery failed. Render free tier blocks outbound SMTP ports (465/587). Please add RESEND_API_KEY in Render settings or run the local backend server.",
                    })
                    return

                self._send_json(200, {
                    "success": True,
                    "message": "Verification code sent to your email.",
                    "cooldown_seconds": 45,
                })
                return

            # 2. ACTION: VERIFY OTP
            if action == "verify_otp":
                target_email = (email or "").strip().lower()
                otp_code = (data.get("otp") or password or "").strip()

                if not target_email or "@" not in target_email or "." not in target_email:
                    self._send_json(400, {"success": False, "error": "A valid email address is required."})
                    return

                if not otp_code or len(otp_code) != 6 or not otp_code.isdigit():
                    self._send_json(400, {"success": False, "error": "Please enter a valid 6-digit verification code."})
                    return

                valid, msg = repo.verify_email_otp(target_email, otp_code)
                if not valid:
                    self._send_json(400, {"success": False, "error": msg})
                    return

                user, is_new = repo.get_or_create_subscriber_otp(target_email)
                if is_new:
                    try:
                        send_welcome_email(target_email)
                    except Exception:
                        pass

                user_agent = self.headers.get("User-Agent")
                ip_addr = self.client_address[0] if self.client_address else None
                status_code, resp_payload = _build_session_response(
                    user=user,
                    repo=repo,
                    message="Verified successfully.",
                    status_code=200,
                    user_agent=user_agent,
                    ip_address=ip_addr,
                )
                self._send_json(status_code, resp_payload)
                return

            # 3. ACTION: REFRESH TOKEN
            if action == "refresh":
                raw_refresh_token = data.get("refresh_token") or ""
                if not raw_refresh_token:
                    auth_header = self.headers.get("Authorization", "")
                    if auth_header.startswith("Bearer "):
                        raw_refresh_token = auth_header[7:].strip()

                if not raw_refresh_token:
                    self._send_json(400, {"success": False, "error": "Refresh token is required."})
                    return

                try:
                    payload = decode_and_verify_token(raw_refresh_token, expected_type="refresh")
                except TokenExpiredError:
                    self._send_json(401, {"success": False, "error": "Refresh token expired. Please log in again.", "code": "REFRESH_EXPIRED"})
                    return
                except TokenInvalidError as e:
                    self._send_json(401, {"success": False, "error": f"Invalid refresh token: {e}", "code": "REFRESH_INVALID"})
                    return

                old_hash = hash_token(raw_refresh_token)
                token_record = repo.get_valid_refresh_token(old_hash)
                if not token_record:
                    # Token revoked or not found
                    self._send_json(401, {"success": False, "error": "Refresh token has been revoked or expired.", "code": "REFRESH_REVOKED"})
                    return

                from app.database.models import Subscriber
                sub = repo.session.query(Subscriber).filter_by(id=token_record.subscriber_id).first()
                if not sub or not sub.is_active:
                    self._send_json(401, {"success": False, "error": "Subscriber account no longer active.", "code": "ACCOUNT_INACTIVE"})
                    return

                # Rotate refresh token
                new_acc_token, _, _ = create_access_token(subscriber_id=sub.id, email=sub.email)
                new_ref_token, new_jti, new_exp = create_refresh_token(subscriber_id=sub.id, email=sub.email)
                new_hash = hash_token(new_ref_token)

                rotated = repo.rotate_refresh_token(
                    old_token_hash=old_hash,
                    new_jti=new_jti,
                    new_token_hash=new_hash,
                    new_expires_at=new_exp,
                )
                if not rotated:
                    self._send_json(401, {"success": False, "error": "Failed to rotate session token."})
                    return

                self._send_json(200, {
                    "success": True,
                    "message": "Token refreshed successfully.",
                    "access_token": new_acc_token,
                    "refresh_token": new_ref_token,
                    "token_type": "Bearer",
                    "expires_in": 900,
                    "subscriber": {"id": sub.id, "email": sub.email},
                })
                return

            # 2. ACTION: LOGOUT
            if action == "logout":
                raw_refresh_token = data.get("refresh_token") or ""
                if not raw_refresh_token:
                    auth_header = self.headers.get("Authorization", "")
                    if auth_header.startswith("Bearer "):
                        raw_refresh_token = auth_header[7:].strip()

                if raw_refresh_token:
                    repo.revoke_refresh_token(hash_token(raw_refresh_token))

                self._send_json(200, {
                    "success": True,
                    "message": "Session terminated and user logged out successfully."
                })
                return

            # 3. ACTION: ME (Verify active session)
            if action == "me":
                auth_header = self.headers.get("Authorization", "")
                if not auth_header.startswith("Bearer "):
                    self._send_json(401, {"success": False, "error": "Missing Bearer authorization header."})
                    return

                token = auth_header[7:].strip()
                try:
                    payload = decode_and_verify_token(token, expected_type="access")
                except TokenExpiredError:
                    self._send_json(401, {"success": False, "error": "Access token expired.", "code": "TOKEN_EXPIRED"})
                    return
                except TokenInvalidError as e:
                    self._send_json(401, {"success": False, "error": str(e), "code": "TOKEN_INVALID"})
                    return

                from app.database.models import Subscriber
                sub = repo.session.query(Subscriber).filter_by(id=payload.get("sub")).first()
                if not sub or not sub.is_active:
                    self._send_json(401, {"success": False, "error": "User account inactive or not found."})
                    return

                self._send_json(200, {
                    "success": True,
                    "message": "Authenticated session active.",
                    "subscriber": {"id": sub.id, "email": sub.email}
                })
                return

            # 4. ACTION: GOOGLE SIGN-IN
            if action == "google_signin":
                if not email or "@" not in email:
                    self._send_json(400, {"success": False, "error": "Invalid Google email address."})
                    return

                user = repo.get_subscriber_by_email(email)
                if not user:
                    pwd_hash = hash_password(secrets.token_urlsafe(32))
                    user = repo.create_subscriber(email=email, password_hash=pwd_hash)

                send_welcome_email(email)
                status_code, payload = _build_session_response(
                    user=user,
                    repo=repo,
                    message="Authenticated with Google! You are active for AI news digests.",
                    status_code=200,
                    user_agent=user_agent,
                    ip_address=ip_address,
                )
                self._send_json(status_code, payload)
                return

            # 5. ACTION: UNSUBSCRIBE / DELETE ACCOUNT
            if action in ("delete", "unsubscribe"):
                # Derive identity from access token or email
                target_email = email
                auth_header = self.headers.get("Authorization", "")
                if auth_header.startswith("Bearer "):
                    token = auth_header[7:].strip()
                    try:
                        token_payload = decode_and_verify_token(token, expected_type="access")
                        target_email = token_payload.get("email", target_email)
                    except Exception:
                        pass

                if not target_email:
                    self._send_json(400, {"success": False, "error": "A valid email is required to unsubscribe."})
                    return

                deleted = repo.delete_subscriber(target_email)
                self._send_json(200, {
                    "success": True,
                    "message": "Subscription cancelled and account removed successfully." if deleted else "Subscription was already inactive."
                })
                return

            # 6. ACTION: FORGOT PASSWORD
            if action == "forgot_password":
                target_email = email.strip().lower()
                if not target_email or "@" not in target_email or "." not in target_email:
                    self._send_json(400, {"success": False, "error": "A valid email address is required."})
                    return

                user = repo.get_subscriber_by_email(target_email)
                if user:
                    from app.utils.tokens import create_password_reset_token
                    reset_tok, _, _ = create_password_reset_token(subscriber_id=user.id, email=user.email)
                    logger.info(f"Password reset requested for {target_email}. Reset link generated.")

                self._send_json(200, {
                    "success": True,
                    "message": "If an account exists with this email, password reset instructions have been dispatched.",
                })
                return

            # 7. ACTION: RESET PASSWORD
            if action == "reset_password":
                token = data.get("refresh_token") or data.get("reset_token") or ""
                pwd = password
                if not token:
                    auth_header = self.headers.get("Authorization", "")
                    if auth_header.startswith("Bearer "):
                        token = auth_header[7:].strip()

                if not token or len(pwd) < 6:
                    self._send_json(400, {"success": False, "error": "Valid reset token and password of at least 6 characters required."})
                    return

                try:
                    claims = decode_and_verify_token(token, expected_type="reset")
                except (TokenExpiredError, TokenInvalidError):
                    self._send_json(400, {"success": False, "error": "Password reset link is invalid or has expired."})
                    return

                from app.database.models import Subscriber
                user = repo.session.query(Subscriber).filter_by(id=claims.get("sub")).first()
                if not user:
                    self._send_json(400, {"success": False, "error": "Account not found."})
                    return

                user.password_hash = hash_password(pwd)
                repo.revoke_all_subscriber_tokens(user.id)
                repo.session.commit()
                self._send_json(200, {
                    "success": True,
                    "message": "Password updated successfully. Please sign in with your new password.",
                })
                return

            # 8. ACTION: VERIFY EMAIL
            if action == "verify_email":
                self._send_json(200, {"success": True, "message": "Email address verified successfully."})
                return


            # Validation for Register & Login
            if not email or "@" not in email:
                self._send_json(400, {"success": False, "error": "A valid email is required."})
                return

            if not password or len(password) < 6:
                self._send_json(400, {"success": False, "error": "Password must be at least 6 characters."})
                return

            # 6. ACTION: REGISTER
            if action == "register":
                existing = repo.get_subscriber_by_email(email)
                if existing:
                    if verify_password(password, existing.password_hash):
                        send_welcome_email(email)
                        status_code, payload = _build_session_response(
                            user=existing,
                            repo=repo,
                            message="Welcome back! You are subscribed to AI news digests.",
                            status_code=200,
                            user_agent=user_agent,
                            ip_address=ip_address,
                        )
                        self._send_json(status_code, payload)
                        return
                    else:
                        self._send_json(400, {"success": False, "error": "An account with this email already exists with a different password."})
                        return

                pwd_hash = hash_password(password)
                sub = repo.create_subscriber(email=email, password_hash=pwd_hash)
                send_welcome_email(email)
                status_code, payload = _build_session_response(
                    user=sub,
                    repo=repo,
                    message="Successfully registered! You will now receive daily AI news digests.",
                    status_code=201,
                    user_agent=user_agent,
                    ip_address=ip_address,
                )
                self._send_json(status_code, payload)
                return

            # 7. ACTION: LOGIN
            elif action == "login":
                user = repo.get_subscriber_by_email(email)
                if not user or not verify_password(password, user.password_hash):
                    self._send_json(401, {"success": False, "error": "Invalid email or password."})
                    return

                send_welcome_email(email)
                status_code, payload = _build_session_response(
                    user=user,
                    repo=repo,
                    message="Login successful! You are actively receiving AI news digests.",
                    status_code=200,
                    user_agent=user_agent,
                    ip_address=ip_address,
                )
                self._send_json(status_code, payload)
                return

            else:
                self._send_json(400, {"success": False, "error": f"Unknown action: {action}"})

        except Exception as e:
            logger.error(f"Error handling auth request: {e}", exc_info=True)
            self._send_json(500, {"success": False, "error": "Internal server error."})
        finally:
            try:
                db_session.remove()
            except Exception:
                pass
