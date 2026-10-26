import os
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from server import AuthStore, AuthApplication, AuthError
from verification import Verification, DeliveryUnavailable, TencentSMS


class CaptureDelivery:
    # Dependency injection exists only in tests; production always uses provider delivery.
    def __init__(self):
        self.messages = []

    def send(self, target, code):
        self.messages.append((target, code))


class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.store = AuthStore(os.path.join(self.directory.name, 'auth.sqlite3'))
        self.sender = CaptureDelivery()
        self.verification = Verification(self.store, 's' * 48, sms=self.sender, email=self.sender)
        self.app = AuthApplication(self.store, verification=self.verification)
        self.phone = '13800138000'

    def tearDown(self):
        self.directory.cleanup()

    def send(self, **kwargs):
        return self.verification.send(self.phone, 'sms', 'login', '', 'client', **kwargs)

    def test_phone_session_requires_delivered_single_use_code(self):
        challenge = self.send()
        code = self.sender.messages[-1][1]
        self.assertEqual(set(challenge), {'challengeID', 'expiresAt', 'resendAfter'})
        self.assertNotIn('code', challenge)
        body = dict(target=self.phone, challengeID=challenge['challengeID'], code=code)
        result = self.app.verify_login(body)
        self.assertEqual(result['user']['phone'], self.phone)
        self.assertEqual(self.store.user(result['sessionToken']), result['user'])
        with self.assertRaises(AuthError):
            self.app.verify_login(body)
        with self.store.db() as db:
            row = db.execute('SELECT code_hash FROM verification').fetchone()
            self.assertNotEqual(row['code_hash'], code)
            self.assertEqual(len(row['code_hash']), 64)

    def test_attempt_limit_persists_and_expiry_is_enforced(self):
        challenge = self.send(now=1000)
        code = self.sender.messages[-1][1]
        wrong = '000001' if code == '000000' else '000000'
        for _ in range(5):
            with self.assertRaises(AuthError):
                self.verification.consume(challenge['challengeID'], self.phone, 'sms', 'login', '', wrong, now=1001)
        with self.assertRaises(AuthError):
            self.verification.consume(challenge['challengeID'], self.phone, 'sms', 'login', '', code, now=1002)
        second = self.send(now=1100)
        with self.assertRaises(AuthError):
            self.verification.consume(second['challengeID'], self.phone, 'sms', 'login', '', self.sender.messages[-1][1], now=1400)

    def test_cooldown_and_hourly_limits(self):
        self.send(now=1000)
        with self.assertRaises(AuthError) as failure:
            self.send(now=1059)
        self.assertEqual(failure.exception.status, 429)
        for i in range(1, 5):
            self.send(now=1000 + i * 60)
        with self.assertRaises(AuthError):
            self.send(now=1300)
        self.assertEqual(len(self.sender.messages), 5)

    def test_new_code_invalidates_old_code(self):
        first = self.send(now=1000)
        first_code = self.sender.messages[-1][1]
        second = self.send(now=1060)
        with self.assertRaises(AuthError):
            self.verification.consume(first['challengeID'], self.phone, 'sms', 'login', '', first_code, now=1061)
        self.verification.consume(second['challengeID'], self.phone, 'sms', 'login', '', self.sender.messages[-1][1], now=1061)

    def test_parallel_replay_only_succeeds_once(self):
        challenge = self.send()
        code = self.sender.messages[-1][1]
        def consume(_):
            try:
                self.app.verify_login(dict(target=self.phone, challengeID=challenge['challengeID'], code=code))
                return True
            except AuthError:
                return False
        with ThreadPoolExecutor(max_workers=6) as pool:
            self.assertEqual(sum(pool.map(consume, range(6))), 1)

    def test_owner_and_purpose_cannot_be_substituted(self):
        challenge = self.verification.send(self.phone, 'sms', 'phone', 'owner-a', 'client')
        code = self.sender.messages[-1][1]
        for purpose, owner in [('login', ''), ('phone', 'owner-b')]:
            with self.assertRaises(AuthError):
                self.verification.consume(challenge['challengeID'], self.phone, 'sms', purpose, owner, code)
        self.verification.consume(challenge['challengeID'], self.phone, 'sms', 'phone', 'owner-a', code)

    def test_provider_failure_never_returns_challenge_or_authenticates(self):
        class FailingDelivery:
            def send(self, *_):
                raise DeliveryUnavailable('unavailable')
        service = Verification(self.store, 's' * 48, sms=FailingDelivery())
        with self.assertRaises(AuthError) as failure:
            service.send(self.phone, 'sms', 'login', '', 'client')
        self.assertEqual(failure.exception.status, 503)
        with self.store.db() as db:
            self.assertEqual(db.execute('SELECT status FROM verification').fetchone()[0], 'failed')
            self.assertEqual(db.execute('SELECT COUNT(*) FROM sessions').fetchone()[0], 0)

    def test_bind_and_password_verified_then_revokes_other_sessions(self):
        first = self.store.issue('wx-app', 'openid')
        other = self.store.issue('wx-app', 'openid')
        token = first['sessionToken']
        body = dict(target=self.phone, purpose='phone')
        challenge = self.app.verification_request(body, 'client', token)
        user = self.app.update_account(token, {**body, 'challengeID': challenge['challengeID'], 'code': self.sender.messages[-1][1]}, 'phone')
        self.assertEqual(user['phone'], self.phone)
        with self.assertRaises(AuthError):
            self.store.user(other['sessionToken'])
        self.assertEqual(self.store.issue_identity('phone', self.phone)['user']['id'], user['id'])
        # Separate recipient avoids the intentional per-target cooldown.
        email = self.verification.send('person@example.com', 'email', 'email', user['id'], 'client')
        self.app.update_account(token, dict(target='person@example.com', challengeID=email['challengeID'], code=self.sender.messages[-1][1]), 'email')
        self.store.set_password(user['id'], 'strong-password')
        self.assertTrue(self.store.user(token)['hasPassword'])
        with self.store.db() as db:
            self.assertNotIn('strong-password', str(dict(db.execute('SELECT * FROM passwords').fetchone())))

    def test_cannot_bind_another_accounts_phone(self):
        owner = self.store.issue_identity('phone', self.phone)['user']['id']
        other = self.store.issue('wx-app', 'other')['user']['id']
        with self.assertRaises(AuthError) as failure:
            self.store.bind(other, 'phone', self.phone)
        self.assertEqual(failure.exception.status, 409)
        self.assertEqual(self.store.issue_identity('phone', self.phone)['user']['id'], owner)

    def test_delete_is_account_scoped_and_invalidates_session(self):
        first = self.store.issue_identity('phone', self.phone)
        other = self.store.issue('app', 'other')
        self.store.delete(first['sessionToken'])
        with self.assertRaises(AuthError):
            self.store.user(first['sessionToken'])
        self.assertEqual(self.store.user(other['sessionToken']), other['user'])
        expired = self.store.issue('app', 'old', now=1000)
        with self.assertRaises(AuthError):
            self.store.delete(expired['sessionToken'])

    def test_missing_config_does_not_send(self):
        service = Verification(self.store, '', sms=self.sender)
        with self.assertRaises(AuthError) as failure:
            service.send(self.phone, 'sms', 'login', '', 'client')
        self.assertEqual(failure.exception.status, 503)
        self.assertFalse(self.sender.messages)


if __name__ == '__main__':
    unittest.main()
