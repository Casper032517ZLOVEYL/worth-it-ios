import os
import tempfile
import unittest
from server import AuthStore, AuthApplication, AuthError


class AuthTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.store = AuthStore(os.path.join(self.directory.name, 'auth.sqlite3'))

    def tearDown(self):
        self.directory.cleanup()

    def test_state_is_required_and_cannot_replay(self):
        challenge = self.store.challenge()
        with self.assertRaises(AuthError):
            self.store.consume(challenge['challengeID'], 'incorrect')
        self.store.consume(challenge['challengeID'], challenge['state'])
        with self.assertRaises(AuthError):
            self.store.consume(challenge['challengeID'], challenge['state'])

    def test_expired_challenge_fails(self):
        challenge = self.store.challenge(now=100)
        with self.assertRaises(AuthError):
            self.store.consume(challenge['challengeID'], challenge['state'], now=400)

    def test_verified_exchange_returns_only_app_session(self):
        calls = []
        def exchanger(app_id, secret, code):
            calls.append((app_id, code))
            return 'real-provider-openid-from-stub'
        app = AuthApplication(self.store, 'wx-server-appid', 'server-only-secret', exchanger)
        challenge = self.store.challenge()
        result = app.exchange({**challenge, 'code': 'test-code'})
        self.assertEqual(calls, [('wx-server-appid', 'test-code')])
        self.assertEqual(set(result), {'sessionToken', 'expiresAt', 'user'})
        self.assertNotIn('openid', str(result))
        self.assertEqual(self.store.user(result['sessionToken']), result['user'])
        with self.assertRaises(AuthError):
            app.exchange({**challenge, 'code': 'test-code'})
        self.assertEqual(len(calls), 1)

    def test_identity_is_stable_and_app_scoped(self):
        first = self.store.issue('app-a', 'openid')
        second = self.store.issue('app-a', 'openid')
        other = self.store.issue('app-b', 'openid')
        self.assertEqual(first['user'], second['user'])
        self.assertNotEqual(first['user']['id'], other['user']['id'])
        self.assertNotEqual(first['sessionToken'], second['sessionToken'])
        with self.store.db() as db:
            self.assertIsNone(db.execute('SELECT * FROM sessions WHERE token_hash=?', (first['sessionToken'],)).fetchone())

    def test_logout_and_expiry(self):
        result = self.store.issue('app', 'user')
        self.store.revoke(result['sessionToken'])
        with self.assertRaises(AuthError):
            self.store.user(result['sessionToken'])
        expired = self.store.issue('app', 'user', now=0)
        with self.assertRaises(AuthError):
            self.store.user(expired['sessionToken'], now=7*24*3600)

    def test_bad_request_never_calls_wechat(self):
        app = AuthApplication(self.store, 'app', 'secret', lambda *_: self.fail('Must not exchange'))
        for body in ({}, {'code': 2}, {'challengeID': 'missing', 'state': 'x', 'code': 'x'}):
            with self.assertRaises(AuthError):
                app.exchange(body)


if __name__ == '__main__':
    unittest.main()
