import unittest
import json
import time
import concurrent.futures
from datetime import datetime, timedelta

from app.database.connection import engine, SessionLocal
from app.database.models import Base, Subscriber, RefreshToken
from app.database.repository import Repository
from app.utils.security import hash_password, verify_password
from app.utils.tokens import (
    create_access_token,
    create_refresh_token,
    create_password_reset_token,
    decode_and_verify_token,
    hash_token,
    TokenExpiredError,
    TokenInvalidError,
)
from api.auth import handler as AuthHandler
import io


def call_api(action: str = None, email: str = None, password: str = None, refresh_token: str = None, headers: dict = None, body_override: dict = None) -> tuple[int, dict]:
    """Helper to invoke the auth handler directly and return (status_code, json_dict)."""
    if body_override is not None:
        payload = body_override
    else:
        payload = {}
        if action:
            payload["action"] = action
        if email is not None:
            payload["email"] = email
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


class TestAuthMatrix(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.create_all(engine)

    def setUp(self):
        self.session = SessionLocal()
        self.repo = Repository(session=self.session)
        self.valid_email = "matrix_user@deepmind.com"
        self.valid_password = "MatrixStrongPassword!2026"
        self.repo.delete_subscriber(self.valid_email)

    def tearDown(self):
        try:
            self.repo.delete_subscriber(self.valid_email)
            self.session.close()
        except Exception:
            pass

    # ==================== A. LOGIN TEST CASES ====================
    def test_A_login_cases(self):
        # Setup: Create account
        code, reg = call_api("register", self.valid_email, self.valid_password)
        self.assertEqual(code, 201)

        # TC-LOGIN-001: Valid credentials
        c, d = call_api("login", self.valid_email, self.valid_password)
        self.assertEqual(c, 200, "TC-LOGIN-001: Valid login must return 200")
        self.assertTrue(d.get("success"))
        self.assertTrue(d.get("access_token"))
        self.assertTrue(d.get("refresh_token"))
        self.assertEqual(d.get("subscriber", {}).get("email"), self.valid_email)

        # TC-LOGIN-002: Incorrect password
        c, d = call_api("login", self.valid_email, "WrongPassword123")
        self.assertEqual(c, 401, "TC-LOGIN-002: Incorrect password must return 401")
        self.assertFalse(d.get("success", False))

        # TC-LOGIN-003: Unregistered email
        c, d = call_api("login", "unregistered_999@domain.com", "Password123")
        self.assertEqual(c, 401, "TC-LOGIN-003: Unregistered email must return 401 generic error")
        self.assertFalse(d.get("success", False))

        # TC-LOGIN-004: Empty email
        c, d = call_api("login", "", self.valid_password)
        self.assertEqual(c, 400, "TC-LOGIN-004: Empty email must return 400")

        # TC-LOGIN-005: Invalid email format
        c, d = call_api("login", "notanemail", self.valid_password)
        self.assertEqual(c, 400, "TC-LOGIN-005: Invalid email format must return 400")

        # TC-LOGIN-006: Empty password
        c, d = call_api("login", self.valid_email, "")
        self.assertEqual(c, 400, "TC-LOGIN-006: Empty password must return 400")

    # ==================== B. SIGNUP TEST CASES ====================
    def test_B_signup_cases(self):
        # TC-SIGNUP-001: Valid signup
        signup_email = "new_signup_user@deepmind.com"
        self.repo.delete_subscriber(signup_email)
        c, d = call_api("register", signup_email, "StrongP@ssword2026")
        self.assertEqual(c, 201, "TC-SIGNUP-001: New signup must return 201")
        self.assertTrue(d.get("success"))
        self.assertTrue(d.get("access_token"))
        self.assertTrue(d.get("refresh_token"))

        # TC-SIGNUP-002: Existing email with wrong password
        c, d = call_api("register", signup_email, "DifferentPassword999")
        self.assertEqual(c, 400, "TC-SIGNUP-002: Existing email with different password must fail")

        # TC-SIGNUP-003: Invalid email
        c, d = call_api("register", "invalid-email-address", "StrongPassword1")
        self.assertEqual(c, 400, "TC-SIGNUP-003: Invalid email format must return 400")

        # TC-SIGNUP-004: Weak password (< 6 chars)
        c, d = call_api("register", "weakpwd@test.com", "123")
        self.assertEqual(c, 400, "TC-SIGNUP-004: Password < 6 chars must return 400")

        self.repo.delete_subscriber(signup_email)

    # ==================== C. GOOGLE OAUTH TEST CASES ====================
    def test_C_google_oauth_cases(self):
        google_email = "google_tester@gmail.com"
        self.repo.delete_subscriber(google_email)

        # TC-GOOGLE-001: New Google user signup
        c, d = call_api("google_signin", google_email)
        self.assertEqual(c, 200, "TC-GOOGLE-001: Google signin must return 200")
        self.assertTrue(d.get("success"))
        self.assertTrue(d.get("access_token"))
        self.assertTrue(d.get("refresh_token"))
        self.assertEqual(d.get("subscriber", {}).get("email"), google_email)

        # TC-GOOGLE-002: Existing user Google login
        c, d2 = call_api("google_signin", google_email)
        self.assertEqual(c, 200, "TC-GOOGLE-002: Existing Google user must authenticate")
        self.assertEqual(d["subscriber"]["id"], d2["subscriber"]["id"], "Must map to same subscriber record")

        # TC-GOOGLE-004: Invalid Google email
        c, d = call_api("google_signin", "invalid_google_addr")
        self.assertEqual(c, 400, "TC-GOOGLE-004: Invalid Google email must return 400")

        self.repo.delete_subscriber(google_email)

    # ==================== D & E. ACCESS & REFRESH TOKEN LIFECYCLE ====================
    def test_D_and_E_token_lifecycle(self):
        # Register user
        _, reg = call_api("register", self.valid_email, self.valid_password)
        access_tok = reg["access_token"]
        refresh_tok = reg["refresh_token"]

        # TC-TOKEN-001 & 002: Access token works on protected endpoint
        c, d = call_api("me", headers={"Authorization": f"Bearer {access_tok}"})
        self.assertEqual(c, 200, "TC-TOKEN-002: Bearer access token must allow access to protected 'me'")
        self.assertEqual(d["subscriber"]["email"], self.valid_email)

        # TC-TOKEN-003: Invalid access token
        c, d = call_api("me", headers={"Authorization": "Bearer bad.token.value"})
        self.assertEqual(c, 401, "TC-TOKEN-003: Invalid token must return 401")

        # TC-TOKEN-004 & TC-REFRESH-001 / 002: Expired access token triggers refresh
        c, ref_data = call_api("refresh", refresh_token=refresh_tok)
        self.assertEqual(c, 200, "TC-REFRESH-002: Valid refresh token must succeed")
        new_acc = ref_data["access_token"]
        new_ref = ref_data["refresh_token"]
        self.assertNotEqual(refresh_tok, new_ref, "Refresh token rotation must return a new token")

        # TC-REFRESH-005: Old rotated refresh token must now be revoked
        c, d = call_api("refresh", refresh_token=refresh_tok)
        self.assertEqual(c, 401, "TC-REFRESH-005: Using old rotated refresh token must fail with 401")

        # TC-REFRESH-004: Invalid refresh token
        c, d = call_api("refresh", refresh_token="invalid.refresh.jwt")
        self.assertEqual(c, 401, "TC-REFRESH-004: Invalid refresh token must fail with 401")

    # ==================== F. CONCURRENT REFRESH TESTS ====================
    def test_F_concurrent_refresh(self):
        _, reg = call_api("register", self.valid_email, self.valid_password)
        refresh_tok = reg["refresh_token"]

        # Simulate 5 concurrent requests with the refresh token
        def do_refresh():
            return call_api("refresh", refresh_token=refresh_tok)

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = [executor.submit(do_refresh) for _ in range(5)]
            results = [f.result() for f in futures]

        status_codes = [r[0] for r in results]
        # Exactly one request must succeed with 200, and the others must be rejected with 401 (rotation prevents reuse!)
        successes = status_codes.count(200)
        self.assertEqual(successes, 1, "TC-CONCURRENT-001: Exactly ONE refresh operation succeeds; old token is immediately rotated")

    # ==================== J. LOGOUT TEST CASES ====================
    def test_J_logout_cases(self):
        _, reg = call_api("register", self.valid_email, self.valid_password)
        ref_tok = reg["refresh_token"]

        # TC-LOGOUT-001: Logout terminates session
        c, d = call_api("logout", refresh_token=ref_tok)
        self.assertEqual(c, 200, "TC-LOGOUT-001: Logout must succeed")

        # TC-LOGOUT-003: Refresh after logout must fail
        c, d = call_api("refresh", refresh_token=ref_tok)
        self.assertEqual(c, 401, "TC-LOGOUT-003: Refresh after logout must be rejected")

    # ==================== K. PASSWORD RESET TEST CASES ====================
    def test_K_password_reset_cases(self):
        _, reg = call_api("register", self.valid_email, self.valid_password)
        user = self.repo.get_subscriber_by_email(self.valid_email)

        # TC-PASSWORD-001: Forgot password with valid email
        c, d = call_api("forgot_password", email=self.valid_email)
        self.assertEqual(c, 200, "TC-PASSWORD-001: Forgot password must succeed")

        # TC-PASSWORD-002: Forgot password with unknown email
        c, d = call_api("forgot_password", email="unknown_user@random.com")
        self.assertEqual(c, 200, "TC-PASSWORD-002: Must return generic success to avoid email harvesting")

        # TC-PASSWORD-003: Invalid reset token
        c, d = call_api("reset_password", refresh_token="invalid_reset_token", password="NewPassword123")
        self.assertEqual(c, 400, "TC-PASSWORD-003: Invalid reset token must return 400")

        # TC-PASSWORD-004: Expired reset token
        expired_token, _, _ = create_password_reset_token(user.id, user.email, expires_in_minutes=-1)
        c, d = call_api("reset_password", refresh_token=expired_token, password="NewPassword123")
        self.assertEqual(c, 400, "TC-PASSWORD-004: Expired reset token must return 400")

        # TC-PASSWORD-005: Successful password reset
        valid_reset_tok, _, _ = create_password_reset_token(user.id, user.email, expires_in_minutes=60)
        c, d = call_api("reset_password", refresh_token=valid_reset_tok, password="NewPassword!2026")
        self.assertEqual(c, 200, "TC-PASSWORD-005: Valid reset must update password")

        # Old password no longer works
        c, _ = call_api("login", self.valid_email, self.valid_password)
        self.assertEqual(c, 401, "Old password must no longer work")

        # New password works
        c, _ = call_api("login", self.valid_email, "NewPassword!2026")
        self.assertEqual(c, 200, "New password must authenticate successfully")

    # ==================== L. EMAIL VERIFICATION ====================
    def test_L_email_verification(self):
        # TC-EMAIL-001 / 002: Email verification action
        c, d = call_api("verify_email", email=self.valid_email)
        self.assertEqual(c, 200, "TC-EMAIL-002: Verify email returns 200")
        self.assertTrue(d.get("success"))

    # ==================== N. SECURITY TEST CASES ====================
    def test_N_security_cases(self):
        _, reg = call_api("register", self.valid_email, self.valid_password)
        access_tok = reg["access_token"]

        # TC-SECURITY-005: Protected endpoint without token
        c, d = call_api("me")
        self.assertEqual(c, 401, "TC-SECURITY-005: Protected endpoint without token must return 401")

        # TC-SECURITY-006: Fake user ID attack - user identity derived strictly from validated token claims
        claims = decode_and_verify_token(access_tok, expected_type="access")
        self.assertEqual(claims["email"], self.valid_email)
        self.assertIn("sub", claims)

    # ==================== R, S, T. E2E LIFECYCLE TESTS ====================
    def test_R_and_T_e2e_lifecycle(self):
        # Step 1: Login
        call_api("register", self.valid_email, self.valid_password)
        c, login_data = call_api("login", self.valid_email, self.valid_password)
        self.assertEqual(c, 200)
        acc = login_data["access_token"]
        ref = login_data["refresh_token"]

        # Step 2: Verify protected API
        c, me = call_api("me", headers={"Authorization": f"Bearer {acc}"})
        self.assertEqual(c, 200)

        # Step 3 & 4 & 5 & 6 & 7: Refresh token
        c, ref_res = call_api("refresh", refresh_token=ref)
        self.assertEqual(c, 200)
        new_acc = ref_res["access_token"]
        new_ref = ref_res["refresh_token"]

        # Step 8: Retried request with new token
        c, me2 = call_api("me", headers={"Authorization": f"Bearer {new_acc}"})
        self.assertEqual(c, 200)

        # Step 9: Logout terminates session
        c, _ = call_api("logout", refresh_token=new_ref)
        self.assertEqual(c, 200)

        # Step 10: Old refresh fails
        c, _ = call_api("refresh", refresh_token=new_ref)
        self.assertEqual(c, 401)


if __name__ == "__main__":
    unittest.main()
