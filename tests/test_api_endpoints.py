import unittest
import json
import time
from app.database.connection import engine, SessionLocal
from app.database.models import Base
from app.database.repository import Repository
from app.utils.security import hash_password
from app.utils.tokens import hash_token
from api.auth import handler as AuthHandler
import io


class DummySocket:
    def __init__(self):
        self._wfile = io.BytesIO()

    def makefile(self, mode, *args, **kwargs):
        if "b" in mode:
            return self._wfile
        return io.StringIO()

    def sendall(self, data):
        self._wfile.write(data)

    def close(self):
        pass


def call_handler(method: str, path: str, body: dict = None, headers: dict = None) -> tuple[int, dict]:
    """Simulates an HTTP request to the BaseHTTPRequestHandler without opening an actual socket."""
    body_bytes = json.dumps(body).encode("utf-8") if body else b""
    req_headers = {
        "Content-Type": "application/json",
        "Content-Length": str(len(body_bytes)),
    }
    if headers:
        req_headers.update(headers)

    raw_request = f"{method} {path} HTTP/1.1\r\n"
    for k, v in req_headers.items():
        raw_request += f"{k}: {v}\r\n"
    raw_request += "\r\n"

    rfile = io.BytesIO(raw_request.encode("utf-8") + body_bytes)
    wfile = io.BytesIO()

    # Create handler instance
    class CustomAuthHandler(AuthHandler):
        def __init__(self, rfile, wfile):
            self.rfile = rfile
            self.wfile = wfile
            self.requestline = f"{method} {path} HTTP/1.1"
            self.command = method
            self.path = path
            self.request_version = "HTTP/1.1"
            self.protocol_version = "HTTP/1.1"
            self.headers = self.parse_headers(rfile)
            self.client_address = ("127.0.0.1", 12345)
            self.server = None
            self.close_connection = True

        def log_message(self, format, *args):
            pass

        def parse_headers(self, rfile):
            from http.client import parse_headers
            # skip request line
            rfile.readline()
            return parse_headers(rfile)

    inst = CustomAuthHandler(rfile, wfile)
    if method == "POST":
        inst.do_POST()
    elif method == "GET":
        inst.do_GET()

    # Parse wfile output
    wfile.seek(0)
    response_lines = wfile.getvalue().decode("utf-8")
    parts = response_lines.split("\r\n\r\n", 1)
    header_part = parts[0]
    body_part = parts[1] if len(parts) > 1 else ""

    status_line = header_part.split("\r\n")[0]
    status_code = int(status_line.split(" ")[1])
    try:
        response_data = json.loads(body_part) if body_part else {}
    except Exception:
        response_data = {"raw": body_part}

    return status_code, response_data


class TestApiAuthEndpoints(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.create_all(engine)

    def setUp(self):
        self.session = SessionLocal()
        self.repo = Repository(session=self.session)
        self.test_email = "api_tester@deepmind.com"
        self.test_pwd = "SecretPassword123"
        self.repo.delete_subscriber(self.test_email)

    def tearDown(self):
        try:
            self.repo.delete_subscriber(self.test_email)
            self.session.close()
        except Exception:
            pass

    def test_01_register_and_receive_tokens(self):
        code, data = call_handler("POST", "/api/auth", {
            "action": "register",
            "email": self.test_email,
            "password": self.test_pwd,
        })
        self.assertEqual(code, 201)
        self.assertTrue(data.get("success"))
        self.assertIn("access_token", data)
        self.assertIn("refresh_token", data)
        self.assertEqual(data.get("token_type"), "Bearer")

    def test_02_login_and_receive_tokens(self):
        # Register first
        call_handler("POST", "/api/auth", {
            "action": "register",
            "email": self.test_email,
            "password": self.test_pwd,
        })

        # Login
        code, data = call_handler("POST", "/api/auth", {
            "action": "login",
            "email": self.test_email,
            "password": self.test_pwd,
        })
        self.assertEqual(code, 200)
        self.assertTrue(data.get("success"))
        self.assertIn("access_token", data)
        self.assertIn("refresh_token", data)

    def test_03_refresh_token_rotation_endpoint(self):
        # Register
        _, reg_data = call_handler("POST", "/api/auth", {
            "action": "register",
            "email": self.test_email,
            "password": self.test_pwd,
        })
        initial_refresh_token = reg_data["refresh_token"]

        # Refresh
        code, ref_data = call_handler("POST", "/api/auth", {
            "action": "refresh",
            "refresh_token": initial_refresh_token,
        })
        self.assertEqual(code, 200)
        self.assertTrue(ref_data.get("success"))
        new_refresh_token = ref_data["refresh_token"]
        self.assertNotEqual(initial_refresh_token, new_refresh_token)

        # Using old rotated token should now fail with 401
        code_reuse, reuse_data = call_handler("POST", "/api/auth", {
            "action": "refresh",
            "refresh_token": initial_refresh_token,
        })
        self.assertEqual(code_reuse, 401)

    def test_04_me_endpoint_with_valid_and_invalid_tokens(self):
        _, reg_data = call_handler("POST", "/api/auth", {
            "action": "register",
            "email": self.test_email,
            "password": self.test_pwd,
        })
        access_token = reg_data["access_token"]

        # Call me with valid access token
        code, me_data = call_handler("POST", "/api/auth", {
            "action": "me"
        }, headers={"Authorization": f"Bearer {access_token}"})
        self.assertEqual(code, 200)
        self.assertEqual(me_data["subscriber"]["email"], self.test_email)

        # Call me with invalid access token
        code_bad, _ = call_handler("POST", "/api/auth", {
            "action": "me"
        }, headers={"Authorization": "Bearer bad_token.tampered.signature"})
        self.assertEqual(code_bad, 401)

    def test_05_logout_revokes_token(self):
        _, reg_data = call_handler("POST", "/api/auth", {
            "action": "register",
            "email": self.test_email,
            "password": self.test_pwd,
        })
        refresh_token = reg_data["refresh_token"]

        # Logout
        code, logout_data = call_handler("POST", "/api/auth", {
            "action": "logout",
            "refresh_token": refresh_token,
        })
        self.assertEqual(code, 200)

        # Attempting refresh after logout must fail
        code_after, _ = call_handler("POST", "/api/auth", {
            "action": "refresh",
            "refresh_token": refresh_token,
        })
        self.assertEqual(code_after, 401)


if __name__ == "__main__":
    unittest.main()
