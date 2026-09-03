import os
import unittest
from unittest.mock import patch, MagicMock
import urllib.request
import urllib.error
import io

from app.services.email import (
    send_otp_email,
    send_email,
    _send_via_resend,
    DEFAULT_EMAIL_FROM,
)


class TestResendEmail(unittest.TestCase):
    def setUp(self):
        self.test_email = "tester@example.com"
        self.test_otp = "849201"

    # =========================================================================
    # 1. ENVIRONMENT CONFIGURATION & VALIDATION
    # =========================================================================
    def test_missing_api_key_fails_safely(self):
        """Verifies that missing RESEND_API_KEY fails cleanly without throwing unhandled exceptions."""
        with patch.dict(os.environ, {"RESEND_API_KEY": ""}, clear=True):
            success = send_otp_email(self.test_email, self.test_otp)
            self.assertFalse(success, "send_otp_email must return False when RESEND_API_KEY is missing")

        with patch.dict(os.environ, {"RESEND_API_KEY": ""}, clear=True):
            with self.assertRaises(ValueError):
                send_email("Subject", "Body", recipients=[self.test_email])

    def test_invalid_recipient_format(self):
        """Verifies that invalid recipient addresses fail validation safely."""
        with patch.dict(os.environ, {"RESEND_API_KEY": "re_test_key_123"}):
            self.assertFalse(send_otp_email("", self.test_otp))
            self.assertFalse(send_otp_email("notanemail", self.test_otp))

    # =========================================================================
    # 2. RESEND HTTPS PAYLOAD & PORT 443 VERIFICATION
    # =========================================================================
    @patch("urllib.request.urlopen")
    def test_successful_resend_https_dispatch(self, mock_urlopen):
        """Verifies that email dispatch sends correct HTTPS payload to Resend endpoint."""
        mock_response = MagicMock()
        mock_response.status = 200
        mock_response.__enter__.return_value = mock_response
        mock_urlopen.return_value = mock_response

        with patch.dict(os.environ, {
            "RESEND_API_KEY": "re_valid_secret_key",
            "EMAIL_FROM": "AI News Aggregator <onboarding@resend.dev>",
        }):
            result = send_otp_email(self.test_email, self.test_otp)
            self.assertTrue(result, "send_otp_email must return True on 200 response")

            # Check urlopen was invoked
            self.assertTrue(mock_urlopen.called)
            req = mock_urlopen.call_args[0][0]

            # Verify request attributes
            self.assertEqual(req.full_url, "https://api.resend.com/emails")
            self.assertEqual(req.get_method(), "POST")
            self.assertEqual(req.headers.get("Authorization"), "Bearer re_valid_secret_key")
            self.assertEqual(req.headers.get("Content-type"), "application/json")

            # Verify payload
            import json
            payload = json.loads(req.data.decode("utf-8"))
            self.assertEqual(payload["from"], "AI News Aggregator <onboarding@resend.dev>")
            self.assertIn(self.test_email, payload["to"])
            self.assertIn(self.test_otp, payload["text"])
            self.assertIn(self.test_otp, payload["html"])
            self.assertIn("AI News Aggregator", payload["subject"])

    # =========================================================================
    # 3. RESEND ERROR HANDLING & LOG SANITIZATION
    # =========================================================================
    @patch("urllib.request.urlopen")
    def test_resend_http_401_unauthorized(self, mock_urlopen):
        """Verifies that invalid Resend API key (HTTP 401) is handled gracefully without leaking secrets."""
        err = urllib.error.HTTPError(
            url="https://api.resend.com/emails",
            code=401,
            msg="Unauthorized",
            hdrs={},
            fp=io.BytesIO(b'{"message": "Invalid API key"}')
        )
        mock_urlopen.side_effect = err

        with patch.dict(os.environ, {"RESEND_API_KEY": "re_invalid_key"}):
            with self.assertLogs("ai_news_api", level="ERROR") as log_cm:
                result = send_otp_email(self.test_email, self.test_otp)
                self.assertFalse(result, "Must return False on HTTP 401")

                # Verify secrets are NOT present in log
                joined_logs = " ".join(log_cm.output)
                self.assertNotIn("re_invalid_key", joined_logs, "API Key must NEVER be logged")
                self.assertNotIn(self.test_otp, joined_logs, "OTP code must NEVER be logged")

    @patch("urllib.request.urlopen")
    def test_resend_http_422_domain_error(self, mock_urlopen):
        """Verifies unverified domain or unprocessable entity (HTTP 422) is caught cleanly."""
        err = urllib.error.HTTPError(
            url="https://api.resend.com/emails",
            code=422,
            msg="Unprocessable Entity",
            hdrs={},
            fp=io.BytesIO(b'{"message": "domain not verified"}')
        )
        mock_urlopen.side_effect = err

        with patch.dict(os.environ, {"RESEND_API_KEY": "re_test_key"}):
            result = send_otp_email(self.test_email, self.test_otp)
            self.assertFalse(result, "Must return False on HTTP 422")

    @patch("urllib.request.urlopen")
    def test_resend_network_timeout(self, mock_urlopen):
        """Verifies network connection failure or timeout is caught safely."""
        mock_urlopen.side_effect = urllib.error.URLError("Connection timed out")

        with patch.dict(os.environ, {"RESEND_API_KEY": "re_test_key"}):
            result = send_otp_email(self.test_email, self.test_otp)
            self.assertFalse(result, "Must return False on network timeout")

    # =========================================================================
    # 4. ZERO SMTP AUDIT
    # =========================================================================
    def test_no_smtplib_usage(self):
        """Confirms that smtplib is not imported or used in the email service."""
        import sys
        import app.services.email as email_module

        self.assertFalse(
            hasattr(email_module, "smtplib"),
            "smtplib must NOT exist as an attribute in app.services.email"
        )
        self.assertFalse(
            hasattr(email_module, "SMTP"),
            "SMTP must NOT exist in app.services.email"
        )
        self.assertFalse(
            hasattr(email_module, "SMTP_SSL"),
            "SMTP_SSL must NOT exist in app.services.email"
        )


if __name__ == "__main__":
    unittest.main()
