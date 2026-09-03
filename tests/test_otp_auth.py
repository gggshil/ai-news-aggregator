import unittest
import json
import time
from datetime import datetime, timedelta

from app.database.connection import engine, SessionLocal
from app.database.models import Base, Subscriber, RefreshToken, EmailOtp
from app.database.repository import Repository
from app.utils.tokens import (
    create_access_token,
    create_refresh_token,
    decode_and_verify_token,
    hash_token,
)
from api.auth import handler as AuthHandler
import io


def call_api(action: str = None, email: str = None, otp: str = None, password: str = None, refresh_token: str = None, headers: dict = None) -> tuple[int, dict]:
    """Helper to invoke the auth handler directly and return (status_code, json_dict)."""
    payload = {}
    if action:
        payload["action"] = action
    if email is not None:
        payload["email"] = email
    if otp is not None:
        payload["otp"] = otp
    if password is not None:
        payload["password"] = password
    if refresh_token is not None:
        payload["refresh_token"] = refresh_token

    body_bytes = json.dumps(payload).encode("utf-8")
    req_headers = {
        "Content-Type": "application/json",
        "Content-Length": str(len(body_bytes)),
    }
    if headers:
        req_headers.update(headers)

    raw_req = "POST /api/auth HTTP/1.1\r\n"
    for k, v in req_headers.items():
        raw_req += f"{k}: {v}\r\n"
    raw_req += "\r\n"

    rfile = io.BytesIO(raw_req.encode("utf-8") + body_bytes)
    wfile = io.BytesIO()

    class MockHandler(AuthHandler):
        def __init__(self, r, w):
            self.rfile = r
            self.wfile = w
            self.requestline = "POST /api/auth HTTP/1.1"
            self.command = "POST"
            self.path = "/api/auth"
            self.request_version = "HTTP/1.1"
            self.protocol_version = "HTTP/1.1"
            self.headers = self.parse_headers(r)
            self.client_address = ("127.0.0.1", 54321)
            self.server = None
            self.close_connection = True

        def log_message(self, format, *args):
            pass

        def parse_headers(self, r):
            from http.client import parse_headers
            r.readline()
            return parse_headers(r)

    inst = MockHandler(rfile, wfile)
    inst.do_POST()

    wfile.seek(0)
    raw_resp = wfile.getvalue().decode("utf-8")
    parts = raw_resp.split("\r\n\r\n", 1)
    status_line = parts[0].split("\r\n")[0]
    code = int(status_line.split(" ")[1])
    try:
        data = json.loads(parts[1]) if len(parts) > 1 and parts[1] else {}
    except Exception:
        data = {"raw": parts[1]}
    return code, data


class TestOtpAuth(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.create_all(engine)

    def setUp(self):
        self.session = SessionLocal()
        self.repo = Repository(session=self.session)
        self.email = "otp_tester@deepmind.com"
        self._cleanup()

    def tearDown(self):
        self._cleanup()
        self.session.close()

    def _cleanup(self):
        try:
            self.repo.delete_subscriber(self.email)
            self.session.query(EmailOtp).filter_by(email=self.email).delete()
            self.session.commit()
        except Exception:
            pass

    # ==================== 1. OTP TESTS ====================
    def test_TC_OTP_001_and_002_request_otp(self):
        # TC-OTP-002: Invalid email requests OTP -> validation error
        code, d = call_api("send_otp", "invalid_email_format")
        self.assertEqual(code, 400, "TC-OTP-002: Invalid email format must return 400")

        # TC-OTP-001: Valid email requests OTP -> 200, success message, cooldown
        code, d = call_api("send_otp", self.email)
        self.assertEqual(code, 200, "TC-OTP-001: Valid email must return 200")
        self.assertTrue(d.get("success"))
        self.assertIn("Verification code sent", d.get("message"))
        self.assertGreaterEqual(d.get("cooldown_seconds", 0), 40)

        # Verify DB has active record
        active_otp = self.repo.get_active_email_otp(self.email)
        self.assertIsNotNone(active_otp)
        self.assertFalse(active_otp.verified)

    def test_TC_OTP_004_005_verify_otp(self):
        # Create a known OTP code in repository
        otp_code = "654321"
        self.repo.create_email_otp(self.email, otp_code, expires_minutes=10)

        # TC-OTP-005: Incorrect OTP
        code, d = call_api("verify_otp", self.email, otp="111111")
        self.assertEqual(code, 400, "TC-OTP-005: Incorrect OTP must return 400")
        self.assertIn("incorrect", d.get("error", "").lower())

        # TC-OTP-004: Correct OTP
        code, d = call_api("verify_otp", self.email, otp=otp_code)
        self.assertEqual(code, 200, "TC-OTP-004: Correct OTP must return 200")
        self.assertTrue(d.get("success"))
        self.assertTrue(d.get("access_token"))
        self.assertTrue(d.get("refresh_token"))

        # TC-OTP-007: OTP reused after successful verification -> rejected
        code, d = call_api("verify_otp", self.email, otp=otp_code)
        self.assertEqual(code, 400, "TC-OTP-007: Reused OTP must be rejected")

    def test_TC_OTP_006_expired_otp(self):
        # Create expired OTP
        otp_code = "999888"
        rec = self.repo.create_email_otp(self.email, otp_code, expires_minutes=-1)

        code, d = call_api("verify_otp", self.email, otp=otp_code)
        self.assertEqual(code, 400, "TC-OTP-006: Expired OTP must return 400")
        self.assertIn("expired", d.get("error", "").lower())

    def test_TC_OTP_009_rapid_resend_cooldown(self):
        # First send
        call_api("send_otp", self.email)

        # Immediate second send within cooldown -> 429
        code, d = call_api("send_otp", self.email)
        self.assertEqual(code, 429, "TC-OTP-009: Rapid resend attempts within cooldown must return 429")

    def test_TC_OTP_010_max_incorrect_attempts(self):
        otp_code = "123456"
        self.repo.create_email_otp(self.email, otp_code, expires_minutes=10)

        # Attempt 5 wrong tries
        for i in range(5):
            call_api("verify_otp", self.email, otp=f"00000{i}")

        # 6th attempt should be blocked due to attempt limit
        code, d = call_api("verify_otp", self.email, otp=otp_code)
        self.assertEqual(code, 400, "TC-OTP-010: Exceeding attempts must lock OTP")
        self.assertIn("too many", d.get("error", "").lower())

    # ==================== 2. ACCOUNT & GOOGLE TESTS ====================
    def test_TC_ACCOUNT_and_GOOGLE(self):
        # TC-ACCOUNT-001: New email verifies successfully -> new account created
        otp_code = "789123"
        self.repo.create_email_otp(self.email, otp_code, expires_minutes=10)
        code, d = call_api("verify_otp", self.email, otp=otp_code)
        self.assertEqual(code, 200)

        user = self.repo.get_subscriber_by_email(self.email)
        self.assertIsNotNone(user, "TC-ACCOUNT-001: User record must exist in DB")

        # TC-ACCOUNT-002: Existing email verifies successfully -> logs in to same account
        new_otp = "456789"
        # reset cooldown in DB for test
        self.session.query(EmailOtp).filter_by(email=self.email).delete()
        self.session.commit()
        self.repo.create_email_otp(self.email, new_otp, expires_minutes=10)

        code, d2 = call_api("verify_otp", self.email, otp=new_otp)
        self.assertEqual(code, 200)
        self.assertEqual(d2["subscriber"]["id"], user.id, "TC-ACCOUNT-003: Must not duplicate user account")

        # TC-ACCOUNT-004: Google account has same email as OTP account -> links cleanly
        code, g_data = call_api("google_signin", self.email)
        self.assertEqual(code, 200)
        self.assertEqual(g_data["subscriber"]["id"], user.id, "TC-ACCOUNT-004: Google user maps to same subscriber")

    # ==================== 3. TOKEN & SESSION TESTS ====================
    def test_TC_TOKEN_and_SESSION(self):
        otp_code = "333444"
        self.repo.create_email_otp(self.email, otp_code, expires_minutes=10)
        code, d = call_api("verify_otp", self.email, otp=otp_code)
        self.assertEqual(code, 200)

        acc_token = d["access_token"]
        ref_token = d["refresh_token"]

        # TC-TOKEN-002: Authenticated API receives correct authentication
        code, me_data = call_api("me", headers={"Authorization": f"Bearer {acc_token}"})
        self.assertEqual(code, 200, "TC-TOKEN-002: Bearer access token accepted")

        # TC-SEC-006: Protected API without authentication
        code, _ = call_api("me")
        self.assertEqual(code, 401, "TC-SEC-006: Missing token rejected with 401")

        # TC-TOKEN-004: Refresh succeeds
        code, ref_res = call_api("refresh", refresh_token=ref_token)
        self.assertEqual(code, 200, "TC-TOKEN-004: Valid refresh token produces new tokens")
        new_acc = ref_res["access_token"]
        new_ref = ref_res["refresh_token"]

        # TC-SESSION-004: Logout terminates session
        code, _ = call_api("logout", refresh_token=new_ref)
        self.assertEqual(code, 200, "TC-SESSION-004: Logout succeeds")

        # Refresh with revoked token fails
        code, _ = call_api("refresh", refresh_token=new_ref)
        self.assertEqual(code, 401, "Refresh after logout fails with 401")


if __name__ == "__main__":
    unittest.main()
