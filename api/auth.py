from http.server import BaseHTTPRequestHandler
import json
import logging
from app.database.repository import Repository
from app.database.connection import db_session, engine
from app.database.models import Base
from app.utils.security import hash_password, verify_password
from app.services.email import send_welcome_email


logger = logging.getLogger(__name__)


class handler(BaseHTTPRequestHandler):
    def _send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self):
        self.send_response(200)
        self._send_cors_headers()
        self.end_headers()

    def do_GET(self):
        self.send_response(200)
        self._send_cors_headers()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(
            json.dumps({"status": "ok", "message": "Auth service is running"}).encode(
                "utf-8"
            )
        )

    def do_POST(self):
        try:
            # Ensure DB tables exist
            with engine.connect() as conn:
                Base.metadata.create_all(engine)

            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            data = json.loads(body.decode("utf-8")) if body else {}

            action = data.get("action", "register")
            email = data.get("email", "").strip().lower()
            password = data.get("password", "")

            if action == "google_signin":
                if not email or "@" not in email:
                    self.send_response(400)
                    self._send_cors_headers()
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(
                        json.dumps({"success": False, "error": "Invalid Google email address."}).encode("utf-8")
                    )
                    return

                repo = Repository()
                user = repo.get_subscriber_by_email(email)
                if not user:
                    import secrets
                    pwd_hash = hash_password(secrets.token_urlsafe(32))
                    user = repo.create_subscriber(email=email, password_hash=pwd_hash)

                send_welcome_email(email)



                self.send_response(200)
                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps({
                        "success": True,
                        "message": "Authenticated with Google! You are active for AI news digests.",
                        "subscriber": {"id": user.id, "email": user.email},
                    }).encode("utf-8")
                )
                return

            if not email or "@" not in email:
                self.send_response(400)
                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps({"success": False, "error": "A valid email is required."}).encode("utf-8")
                )
                return

            if not password or len(password) < 6:
                self.send_response(400)
                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps({
                        "success": False,
                        "error": "Password must be at least 6 characters.",
                    }).encode("utf-8")
                )
                return

            repo = Repository()


            if action == "register":
                existing = repo.get_subscriber_by_email(email)
                if existing:
                    # If already exists, check password or inform user
                    if verify_password(password, existing.password_hash):
                        send_welcome_email(email)
                        self.send_response(200)

                        self._send_cors_headers()
                        self.send_header("Content-Type", "application/json")
                        self.end_headers()
                        self.wfile.write(
                            json.dumps({
                                "success": True,
                                "message": "Welcome back! You are subscribed to AI news digests.",
                                "subscriber": {"id": existing.id, "email": existing.email},
                            }).encode("utf-8")
                        )
                        return
                    else:
                        self.send_response(400)
                        self._send_cors_headers()
                        self.send_header("Content-Type", "application/json")
                        self.end_headers()
                        self.wfile.write(
                            json.dumps({
                                "success": False,
                                "error": "An account with this email already exists with a different password.",
                            }).encode("utf-8")
                        )
                        return

                pwd_hash = hash_password(password)
                sub = repo.create_subscriber(email=email, password_hash=pwd_hash)
                send_welcome_email(email)


                self.send_response(201)
                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps({
                        "success": True,
                        "message": "Successfully registered! You will now receive daily AI news digests.",
                        "subscriber": {"id": sub.id, "email": sub.email},
                    }).encode("utf-8")
                )

            elif action == "login":
                user = repo.get_subscriber_by_email(email)
                if not user or not verify_password(password, user.password_hash):
                    self.send_response(401)
                    self._send_cors_headers()
                    self.send_header("Content-Type", "application/json")
                    self.end_headers()
                    self.wfile.write(
                        json.dumps({
                            "success": False,
                            "error": "Invalid email or password.",
                        }).encode("utf-8")
                    )
                    return

                send_welcome_email(email)
                self.send_response(200)

                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps({
                        "success": True,
                        "message": "Login successful! You are actively receiving AI news digests.",
                        "subscriber": {"id": user.id, "email": user.email},
                    }).encode("utf-8")
                )
            elif action in ("delete", "unsubscribe"):
                deleted = repo.delete_subscriber(email)
                self.send_response(200)
                self._send_cors_headers()
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps({
                        "success": True,
                        "message": "Subscription cancelled and account removed successfully. You will no longer receive daily digests.",
                    }).encode("utf-8")
                )
            else:
                self.send_response(400)
                self._send_cors_headers()

                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(
                    json.dumps({"success": False, "error": f"Unknown action: {action}"}).encode("utf-8")
                )

        except Exception as e:
            logger.error(f"Error handling auth request: {e}", exc_info=True)
            self.send_response(500)
            self._send_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(
                json.dumps({"success": False, "error": f"Internal server error: {str(e)}"}).encode("utf-8")
            )
        finally:
            try:
                db_session.remove()
            except Exception:
                pass
