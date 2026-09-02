import os
import secrets
import logging
from typing import Optional
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from dotenv import load_dotenv

from app.database.repository import Repository
from app.database.connection import engine, db_session
from app.database.models import Base
from app.utils.security import hash_password, verify_password
from app.services.email import send_welcome_email


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
    allow_origins=allowed_origins if allowed_origins != ["*"] else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class AuthRequest(BaseModel):
    action: str = "register"  # "register", "login", or "google_signin"
    email: str
    password: Optional[str] = None


@app.get("/health")
def health_check():
    """Unauthenticated health check endpoint for Render and uptime monitoring."""
    return {"status": "ok", "service": "AI News Aggregator API"}


@app.post("/api/auth")
def authenticate(payload: AuthRequest):
    """Handles subscriber registration, login, and Google verification."""
    email = payload.email.strip().lower()
    if not email or "@" not in email or "." not in email:
        raise HTTPException(status_code=400, detail="A valid email address is required.")

    repo = Repository()

    try:
        if payload.action == "google_signin":
            user = repo.get_subscriber_by_email(email)
            if not user:
                pwd_hash = hash_password(secrets.token_urlsafe(32))
                user = repo.create_subscriber(email=email, password_hash=pwd_hash)
                send_welcome_email(email)


            return {
                "success": True,
                "message": "Authenticated with Google! You are active for AI news digests.",
                "subscriber": {"id": user.id, "email": user.email},
            }

        password = payload.password or ""
        if not password or len(password) < 6:
            raise HTTPException(status_code=400, detail="Password must be at least 6 characters.")

        if payload.action == "register":
            existing = repo.get_subscriber_by_email(email)
            if existing:
                if verify_password(password, existing.password_hash):
                    return {
                        "success": True,
                        "message": "Welcome back! You are subscribed to AI news digests.",
                        "subscriber": {"id": existing.id, "email": existing.email},
                    }
                else:
                    raise HTTPException(
                        status_code=400,
                        detail="An account with this email already exists with a different password.",
                    )

            pwd_hash = hash_password(password)
            sub = repo.create_subscriber(email=email, password_hash=pwd_hash)
            send_welcome_email(email)
            return {

                "success": True,
                "message": "Successfully registered! You will now receive daily AI news digests.",
                "subscriber": {"id": sub.id, "email": sub.email},
            }

        elif payload.action == "login":
            user = repo.get_subscriber_by_email(email)
            if not user or not verify_password(password, user.password_hash):
                raise HTTPException(status_code=401, detail="Invalid email or password.")

            return {
                "success": True,
                "message": "Login successful! You are actively receiving AI news digests.",
                "subscriber": {"id": user.id, "email": user.email},
            }

        elif payload.action in ("delete", "unsubscribe"):
            deleted = repo.delete_subscriber(email)
            if deleted:
                logger.info(f"Subscriber {email} unsubscribed and deleted.")
                return {
                    "success": True,
                    "message": "Subscription cancelled and account removed successfully. You will no longer receive daily digests.",
                }
            else:
                # Still return success so the client state clears gracefully
                return {
                    "success": True,
                    "message": "Subscription was already inactive.",
                }

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
