import unittest
import time
import json
import io
from datetime import datetime, timedelta

from app.utils.tokens import (
    create_access_token,
    create_refresh_token,
    decode_and_verify_token,
    hash_token,
    TokenExpiredError,
    TokenInvalidError,
)
from app.database.connection import engine, SessionLocal
from app.database.models import Base, Subscriber, RefreshToken
from app.database.repository import Repository
from api.auth import handler as AuthHandler


class MockWfile(io.BytesIO):
    pass


class MockRfile(io.BytesIO):
    pass


class TestTokenLifecycle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.create_all(engine)

    def setUp(self):
        self.session = SessionLocal()
        self.repo = Repository(session=self.session)
        # Clean test user if present
        self.test_email = "token_tester@deepmind.com"
        self.repo.delete_subscriber(self.test_email)
        self.test_user = self.repo.create_subscriber(email=self.test_email, password_hash="dummy_hash")

    def tearDown(self):
        try:
            self.repo.delete_subscriber(self.test_email)
            self.session.close()
        except Exception:
            pass

    # TEST 1: Login -> Access token received -> Authenticated API works
    def test_01_access_token_creation_and_verification(self):
        token, jti, expiry = create_access_token(self.test_user.id, self.test_user.email, expires_in_minutes=15)
        self.assertTrue(token)
        self.assertTrue(jti)
        self.assertGreater(expiry, datetime.utcnow())

        # Verify claims
        claims = decode_and_verify_token(token, expected_type="access")
        self.assertEqual(claims["sub"], self.test_user.id)
        self.assertEqual(claims["email"], self.test_user.email)
        self.assertEqual(claims["type"], "access")
        self.assertEqual(claims["iss"], "ai-news-aggregator")

    # TEST 2: Access token expired -> detection
    def test_02_access_token_expiration(self):
        # Create token with 0 seconds lifetime
        token, _, _ = create_access_token(self.test_user.id, self.test_user.email, expires_in_minutes=-1)
        with self.assertRaises(TokenExpiredError):
            decode_and_verify_token(token, expected_type="access")

    # TEST 3: Invalid token signature or tampering
    def test_03_tampered_token_rejection(self):
        token, _, _ = create_access_token(self.test_user.id, self.test_user.email, expires_in_minutes=15)
        # Tamper payload
        parts = token.split(".")
        tampered = f"{parts[0]}.eyJuYW1lIjoiaGFja2VyIn0.{parts[2]}"
        with self.assertRaises(TokenInvalidError):
            decode_and_verify_token(tampered, expected_type="access")

    # TEST 4: Token type mismatch (e.g. passing refresh token where access token expected)
    def test_04_token_type_mismatch(self):
        ref_token, _, _ = create_refresh_token(self.test_user.id, self.test_user.email, expires_in_days=30)
        with self.assertRaises(TokenInvalidError):
            decode_and_verify_token(ref_token, expected_type="access")

    # TEST 5: Refresh token rotation in database
    def test_05_refresh_token_rotation(self):
        ref_token, jti, exp = create_refresh_token(self.test_user.id, self.test_user.email, expires_in_days=30)
        ref_hash = hash_token(ref_token)

        # Store in DB
        record = self.repo.save_refresh_token(
            jti=jti,
            subscriber_id=self.test_user.id,
            token_hash=ref_hash,
            expires_at=exp,
        )
        self.assertIsNotNone(record)
        self.assertFalse(record.revoked)

        # Rotate token
        new_ref_token, new_jti, new_exp = create_refresh_token(self.test_user.id, self.test_user.email, expires_in_days=30)
        new_hash = hash_token(new_ref_token)

        rotated = self.repo.rotate_refresh_token(
            old_token_hash=ref_hash,
            new_jti=new_jti,
            new_token_hash=new_hash,
            new_expires_at=new_exp,
        )
        self.assertIsNotNone(rotated)
        self.assertEqual(rotated.id, new_jti)

        # Verify old token is now revoked
        old_valid = self.repo.get_valid_refresh_token(ref_hash)
        self.assertIsNone(old_valid, "Old rotated token must no longer be valid")

        # Verify new token is valid
        new_valid = self.repo.get_valid_refresh_token(new_hash)
        self.assertIsNotNone(new_valid, "New rotated token must be active")

    # TEST 6: Refresh token revocation
    def test_06_token_revocation(self):
        ref_token, jti, exp = create_refresh_token(self.test_user.id, self.test_user.email, expires_in_days=30)
        ref_hash = hash_token(ref_token)

        self.repo.save_refresh_token(
            jti=jti,
            subscriber_id=self.test_user.id,
            token_hash=ref_hash,
            expires_at=exp,
        )

        # Revoke
        revoked = self.repo.revoke_refresh_token(ref_hash)
        self.assertTrue(revoked)

        # Lookup must return None
        lookup = self.repo.get_valid_refresh_token(ref_hash)
        self.assertIsNone(lookup)

    # TEST 7: Revoke all subscriber tokens on account deletion or global logout
    def test_07_revoke_all_subscriber_tokens(self):
        t1, j1, exp1 = create_refresh_token(self.test_user.id, self.test_user.email, expires_in_days=30)
        t2, j2, exp2 = create_refresh_token(self.test_user.id, self.test_user.email, expires_in_days=30)

        self.repo.save_refresh_token(jti=j1, subscriber_id=self.test_user.id, token_hash=hash_token(t1), expires_at=exp1)
        self.repo.save_refresh_token(jti=j2, subscriber_id=self.test_user.id, token_hash=hash_token(t2), expires_at=exp2)

        revoked_count = self.repo.revoke_all_subscriber_tokens(self.test_user.id)
        self.assertGreaterEqual(revoked_count, 2)

        self.assertIsNone(self.repo.get_valid_refresh_token(hash_token(t1)))
        self.assertIsNone(self.repo.get_valid_refresh_token(hash_token(t2)))


if __name__ == "__main__":
    unittest.main()
