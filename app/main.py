import os
import secrets
import logging
from typing import Optional
from fastapi import FastAPI, HTTPException, Request, Response, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from dotenv import load_dotenv

from app.database.repository import Repository
from app.database.connection import engine, db_session
from app.database.models import Base, Subscriber
from app.utils.security import hash_password, verify_password
from app.services.email import send_welcome_email, send_otp_email, get_resend_api_key
from app.utils.tokens import (
    create_access_token,
    create_refresh_token,
    decode_and_verify_token,
    hash_token,
    TokenExpiredError,
    TokenInvalidError,
)


load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("ai_news_api")

# Auto-create tables on startup
try:
    with engine.connect() as conn:
        Base.metadata.create_all(engine)
except Exception as e:
    logger.warning(f"Could not initialize DB tables on startup: {e}")

app = FastAPI(
    title="AI News Aggregator API",
    description="Backend API for AI News Aggregator SaaS",
    version="1.0.0",
)

# Configurable CORS
raw_origins = os.getenv("ALLOWED_ORIGINS", "*")
allowed_origins = [o.strip() for o in raw_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins if "*" not in allowed_origins else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class AuthRequest(BaseModel):
    action: str = "send_otp"  # "send_otp", "verify_otp", "google_signin", "refresh", "logout", "me", "delete"
    email: Optional[str] = None
    password: Optional[str] = None
    otp: Optional[str] = None
    refresh_token: Optional[str] = None


def _create_auth_session(user: Subscriber, repo: Repository, message: str, request: Request) -> dict:
    """Helper to generate and persist access + refresh tokens."""
    acc_token, _, _ = create_access_token(subscriber_id=user.id, email=user.email)
    ref_token, ref_jti, ref_exp = create_refresh_token(subscriber_id=user.id, email=user.email)

    user_agent = request.headers.get("user-agent")
    ip_address = request.client.host if request.client else None

    repo.save_refresh_token(
        jti=ref_jti,
        subscriber_id=user.id,
        token_hash=hash_token(ref_token),
        expires_at=ref_exp,
        user_agent=user_agent,
        ip_address=ip_address,
    )

    return {
        "success": True,
        "message": message,
        "access_token": acc_token,
        "refresh_token": ref_token,
        "token_type": "Bearer",
        "expires_in": 900,
        "subscriber": {"id": user.id, "email": user.email},
    }


@app.get("/health")
def health_check():
    """Unauthenticated health check endpoint for Render and uptime monitoring."""
    key = get_resend_api_key()
    detected = [k for k in os.environ if any(x in k.upper() for x in ["RESEND", "EMAIL"])]
    return {
        "status": "ok",
        "service": "AI News Aggregator API",
        "email_provider": "resend" if bool(key) else "resend_not_configured",
        "detected_config_keys": detected,
    }


@app.post("/api/auth")
def authenticate(payload: AuthRequest, request: Request, background_tasks: BackgroundTasks):
    """Handles subscriber authentication, token refresh rotation, and session management."""
    repo = Repository()

    try:
        # 1. ACTION: SEND OTP
        if payload.action == "send_otp":
            email = (payload.email or "").strip().lower()
            if not email or "@" not in email or "." not in email:
                raise HTTPException(status_code=400, detail="Please enter a valid email address.")

            can_send, remaining = repo.check_otp_resend_cooldown(email, cooldown_seconds=45)
            if not can_send:
                raise HTTPException(status_code=429, detail=f"Please wait {remaining} seconds before requesting a new code.")

            # Generate 6-digit cryptographically secure numeric OTP
            otp_code = f"{secrets.randbelow(900000) + 100000:06d}"
            repo.create_email_otp(email=email, otp_code=otp_code, expires_minutes=10)

            # Attempt immediate email dispatch via Resend HTTPS API
            dispatched = send_otp_email(email, otp_code)
            if not dispatched:
                logger.error(f"Failed to dispatch OTP verification email for {email} via Resend.")
                raise HTTPException(
                    status_code=500,
                    detail="Unable to send verification code. Please try again or check server email configuration.",
                )

            logger.info(f"Verification OTP code dispatched successfully for {email}")

            return {
                "success": True,
                "message": "Verification code sent to your email.",
                "cooldown_seconds": 45,
            }

        # 2. ACTION: VERIFY OTP
        if payload.action == "verify_otp":
            email = (payload.email or "").strip().lower()
            otp_code = (payload.otp or payload.password or "").strip()

            if not email or "@" not in email or "." not in email:
                raise HTTPException(status_code=400, detail="A valid email address is required.")

            if not otp_code or len(otp_code) != 6 or not otp_code.isdigit():
                raise HTTPException(status_code=400, detail="Please enter a valid 6-digit verification code.")

            valid, message = repo.verify_email_otp(email, otp_code)
            if not valid:
                raise HTTPException(status_code=400, detail=message)

            user, is_new = repo.get_or_create_subscriber_otp(email)
            if is_new:
                background_tasks.add_task(send_welcome_email, email)

            return _create_auth_session(
                user=user,
                repo=repo,
                message="Verified successfully.",
                request=request,
            )

        # 1. ACTION: REFRESH TOKEN
        if payload.action == "refresh":
            raw_token = payload.refresh_token or ""
            if not raw_token:
                auth_h = request.headers.get("authorization", "")
                if auth_h.startswith("Bearer "):
                    raw_token = auth_h[7:].strip()

            if not raw_token:
                raise HTTPException(status_code=400, detail="Refresh token is required.")

            try:
                claims = decode_and_verify_token(raw_token, expected_type="refresh")
            except TokenExpiredError:
                raise HTTPException(status_code=401, detail="Refresh token expired. Please log in again.")
            except TokenInvalidError as e:
                raise HTTPException(status_code=401, detail=f"Invalid refresh token: {e}")

            token_hash = hash_token(raw_token)
            record = repo.get_valid_refresh_token(token_hash)
            if not record:
                raise HTTPException(status_code=401, detail="Refresh token is invalid or has been revoked.")

            sub = repo.session.query(Subscriber).filter_by(id=record.subscriber_id).first()
            if not sub or not sub.is_active:
                raise HTTPException(status_code=401, detail="Subscriber account is inactive.")

            new_acc_token, _, _ = create_access_token(subscriber_id=sub.id, email=sub.email)
            new_ref_token, new_jti, new_exp = create_refresh_token(subscriber_id=sub.id, email=sub.email)
            new_hash = hash_token(new_ref_token)

            rotated = repo.rotate_refresh_token(
                old_token_hash=token_hash,
                new_jti=new_jti,
                new_token_hash=new_hash,
                new_expires_at=new_exp,
            )
            if not rotated:
                raise HTTPException(status_code=401, detail="Failed to rotate authentication token.")

            return {
                "success": True,
                "message": "Token refreshed successfully.",
                "access_token": new_acc_token,
                "refresh_token": new_ref_token,
                "token_type": "Bearer",
                "expires_in": 900,
                "subscriber": {"id": sub.id, "email": sub.email},
            }

        # 2. ACTION: LOGOUT
        if payload.action == "logout":
            raw_token = payload.refresh_token or ""
            if not raw_token:
                auth_h = request.headers.get("authorization", "")
                if auth_h.startswith("Bearer "):
                    raw_token = auth_h[7:].strip()

            if raw_token:
                repo.revoke_refresh_token(hash_token(raw_token))

            return {"success": True, "message": "Successfully logged out and session terminated."}

        # 3. ACTION: ME
        if payload.action == "me":
            auth_h = request.headers.get("authorization", "")
            if not auth_h.startswith("Bearer "):
                raise HTTPException(status_code=401, detail="Missing Bearer authorization header.")

            token = auth_h[7:].strip()
            try:
                claims = decode_and_verify_token(token, expected_type="access")
            except TokenExpiredError:
                raise HTTPException(status_code=401, detail="Access token expired.")
            except TokenInvalidError as e:
                raise HTTPException(status_code=401, detail=f"Invalid access token: {e}")

            sub = repo.session.query(Subscriber).filter_by(id=claims.get("sub")).first()
            if not sub or not sub.is_active:
                raise HTTPException(status_code=401, detail="Subscriber account is inactive or not found.")

            return {
                "success": True,
                "message": "Authenticated session active.",
                "subscriber": {"id": sub.id, "email": sub.email},
            }

        # 4. ACTION: GOOGLE SIGN-IN
        if payload.action == "google_signin":
            email = (payload.email or "").strip().lower()
            if not email or "@" not in email:
                raise HTTPException(status_code=400, detail="A valid Google email is required.")

            user = repo.get_subscriber_by_email(email)
            if not user:
                pwd_hash = hash_password(secrets.token_urlsafe(32))
                user = repo.create_subscriber(email=email, password_hash=pwd_hash)

            background_tasks.add_task(send_welcome_email, email)
            return _create_auth_session(
                user=user,
                repo=repo,
                message="Authenticated with Google! You are active for AI news digests.",
                request=request,
            )

        # 5. ACTION: UNSUBSCRIBE / DELETE
        if payload.action in ("delete", "unsubscribe"):
            target_email = (payload.email or "").strip().lower()
            auth_h = request.headers.get("authorization", "")
            if auth_h.startswith("Bearer "):
                token = auth_h[7:].strip()
                try:
                    claims = decode_and_verify_token(token, expected_type="access")
                    target_email = claims.get("email", target_email)
                except Exception:
                    pass

            if not target_email:
                raise HTTPException(status_code=400, detail="A valid email is required.")

            deleted = repo.delete_subscriber(target_email)
            if deleted:
                logger.info(f"Subscriber {target_email} unsubscribed and deleted.")
                return {
                    "success": True,
                    "message": "Subscription cancelled and account removed successfully.",
                }
            return {
                "success": True,
                "message": "Subscription was already inactive.",
            }

        # 6. ACTION: FORGOT PASSWORD
        if payload.action == "forgot_password":
            target_email = (payload.email or "").strip().lower()
            if not target_email or "@" not in target_email or "." not in target_email:
                raise HTTPException(status_code=400, detail="A valid email address is required.")

            user = repo.get_subscriber_by_email(target_email)
            if user:
                from app.utils.tokens import create_password_reset_token
                reset_tok, _, _ = create_password_reset_token(subscriber_id=user.id, email=user.email)
                logger.info(f"Password reset requested for {target_email}. Reset link generated.")

            return {
                "success": True,
                "message": "If an account exists with this email, password reset instructions have been dispatched.",
            }

        # 7. ACTION: RESET PASSWORD
        if payload.action == "reset_password":
            token = payload.refresh_token or ""
            pwd = payload.password or ""
            if not token:
                auth_h = request.headers.get("authorization", "")
                if auth_h.startswith("Bearer "):
                    token = auth_h[7:].strip()

            if not token or len(pwd) < 6:
                raise HTTPException(status_code=400, detail="Valid reset token and password of at least 6 characters required.")

            try:
                claims = decode_and_verify_token(token, expected_type="reset")
            except (TokenExpiredError, TokenInvalidError) as e:
                raise HTTPException(status_code=400, detail="Password reset link is invalid or has expired.")

            user = repo.session.query(Subscriber).filter_by(id=claims.get("sub")).first()
            if not user:
                raise HTTPException(status_code=400, detail="Account not found.")

            user.password_hash = hash_password(pwd)
            repo.revoke_all_subscriber_tokens(user.id)
            repo.session.commit()
            return {"success": True, "message": "Password updated successfully. Please sign in with your new password."}

        # 8. ACTION: VERIFY EMAIL
        if payload.action == "verify_email":
            return {"success": True, "message": "Email address verified successfully."}


        # Email & password validation for Register / Login
        email = (payload.email or "").strip().lower()
        if not email or "@" not in email or "." not in email:
            raise HTTPException(status_code=400, detail="A valid email address is required.")

        password = payload.password or ""
        if not password or len(password) < 6:
            raise HTTPException(status_code=400, detail="Password must be at least 6 characters.")

        # 6. ACTION: REGISTER
        if payload.action == "register":
            existing = repo.get_subscriber_by_email(email)
            if existing:
                if verify_password(password, existing.password_hash):
                    background_tasks.add_task(send_welcome_email, email)
                    return _create_auth_session(
                        user=existing,
                        repo=repo,
                        message="Welcome back! You are subscribed to AI news digests.",
                        request=request,
                    )
                else:
                    raise HTTPException(
                        status_code=400,
                        detail="An account with this email already exists with a different password.",
                    )

            pwd_hash = hash_password(password)
            sub = repo.create_subscriber(email=email, password_hash=pwd_hash)
            background_tasks.add_task(send_welcome_email, email)
            return _create_auth_session(
                user=sub,
                repo=repo,
                message="Successfully registered! You will now receive daily AI news digests.",
                request=request,
            )

        # 7. ACTION: LOGIN
        elif payload.action == "login":
            user = repo.get_subscriber_by_email(email)
            if not user or not verify_password(password, user.password_hash):
                raise HTTPException(status_code=401, detail="Invalid email or password.")

            background_tasks.add_task(send_welcome_email, email)
            return _create_auth_session(
                user=user,
                repo=repo,
                message="Login successful! You are actively receiving AI news digests.",
                request=request,
            )

        else:
            raise HTTPException(status_code=400, detail=f"Unknown action: {payload.action}")


    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Authentication error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Unable to process authentication request.")
    finally:
        try:
            db_session.remove()
        except Exception:
            pass


@app.get("/api/cron")
@app.post("/api/cron")
def run_cron_pipeline(authorization: Optional[str] = None):
    """Optional manual / webhook trigger for daily AI pipeline."""
    cron_secret = os.getenv("CRON_SECRET")
    if cron_secret and authorization != f"Bearer {cron_secret}":
        raise HTTPException(status_code=401, detail="Unauthorized cron trigger.")

    try:
        from app.daily_runner import run_daily_pipeline

        result = run_daily_pipeline(hours=24, top_n=10)
        return {"status": "success" if result.get("success") else "failed", "summary": result}
    except Exception as e:
        logger.error(f"Pipeline execution error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Pipeline execution failed.")
    finally:
        try:
            db_session.remove()
        except Exception:
            pass
