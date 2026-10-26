"""WeChat code exchange service. Run behind HTTPS; secrets are server environment only."""
from contextlib import contextmanager
from datetime import datetime, timezone
from hashlib import sha256
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import hashlib
import ipaddress
import os
import re
import secrets
import sqlite3
import threading
import time
from urllib.parse import urlencode
from urllib.request import urlopen
import uuid
from tree_hole import TreeHole, ChatError


def iso(timestamp):
    return datetime.fromtimestamp(timestamp, timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def digest(value):
    return sha256(value.encode()).hexdigest()


class AuthError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


class AuthStore:
    def __init__(self, path):
        self.path = path
        with self.db() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS challenges (
                    id TEXT PRIMARY KEY, state_hash TEXT NOT NULL,
                    expires INTEGER NOT NULL, used INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE IF NOT EXISTS users (
                    id TEXT PRIMARY KEY, app_id TEXT NOT NULL, openid TEXT NOT NULL,
                    UNIQUE(app_id, openid));
                CREATE TABLE IF NOT EXISTS identities (
                    provider TEXT NOT NULL, subject TEXT NOT NULL, user_id TEXT NOT NULL,
                    UNIQUE(provider, subject));
                CREATE TABLE IF NOT EXISTS passwords (user_id TEXT PRIMARY KEY, salt TEXT NOT NULL, hash TEXT NOT NULL);
                INSERT OR IGNORE INTO identities SELECT 'wechat:' || app_id, openid, id FROM users WHERE app_id NOT IN ('phone', 'email') AND app_id NOT LIKE 'wechat:%';
                CREATE TABLE IF NOT EXISTS sessions (
                    token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL,
                    expires INTEGER NOT NULL);
            ''')
        os.chmod(path, 0o600)

    @contextmanager
    def db(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        try:
            yield db
            db.commit()
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()

    def challenge(self, now=None):
        now = int(time.time() if now is None else now)
        challenge_id, state = secrets.token_urlsafe(24), secrets.token_urlsafe(32)
        expires = now + 300
        with self.db() as db:
            db.execute('DELETE FROM challenges WHERE expires <= ?', (now,))
            db.execute('DELETE FROM sessions WHERE expires <= ?', (now,))
            db.execute('INSERT INTO challenges(id,state_hash,expires) VALUES(?,?,?)',
                       (challenge_id, digest(state), expires))
        return dict(challengeID=challenge_id, state=state, expiresAt=iso(expires))

    def consume(self, challenge_id, state, now=None):
        now = int(time.time() if now is None else now)
        with self.db() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT * FROM challenges WHERE id=?', (challenge_id,)).fetchone()
            if row is None or row['used'] or row['expires'] <= now or not secrets.compare_digest(row['state_hash'], digest(state)):
                raise AuthError(401, 'Invalid, expired or consumed authorization state')
            db.execute('UPDATE challenges SET used=1 WHERE id=?', (challenge_id,))

    def issue(self, app_id, openid, now=None):
        return self.issue_identity('wechat:' + app_id, openid, now)

    def issue_identity(self, provider, subject, now=None):
        with self.db() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT user_id FROM identities WHERE provider=? AND subject=?', (provider, subject)).fetchone()
            user_id = row['user_id'] if row else str(uuid.uuid4())
            if row is None:
                db.execute('INSERT INTO users VALUES(?,?,?)', (user_id, provider[7:] if provider.startswith('wechat:') else provider, subject))
                db.execute('INSERT INTO identities VALUES(?,?,?)', (provider, subject, user_id))
        return self.new_session(user_id, now)

    def new_session(self, user_id, now=None):
        now = int(time.time() if now is None else now)
        token, expires = secrets.token_urlsafe(48), now + 7 * 24 * 3600
        with self.db() as db:
            db.execute('INSERT INTO sessions VALUES(?,?,?)', (digest(token), user_id, expires))
        return dict(sessionToken=token, expiresAt=iso(expires), user=self.account(user_id))

    def account(self, user_id):
        with self.db() as db:
            identities = db.execute('SELECT provider,subject FROM identities WHERE user_id=?', (user_id,)).fetchall()
            password = db.execute('SELECT 1 FROM passwords WHERE user_id=?', (user_id,)).fetchone()
        providers = [r['provider'].split(':')[0] for r in identities]
        result = dict(id=user_id, nickname='星光旅人', providers=providers, hasPassword=password is not None)
        for row in identities:
            if row['provider'] in ('phone', 'email'):
                result[row['provider']] = row['subject']
        return result

    def user(self, token, now=None):
        now = int(time.time() if now is None else now)
        with self.db() as db:
            row = db.execute('SELECT user_id FROM sessions WHERE token_hash=? AND expires>?', (digest(token), now)).fetchone()
        if row is None:
            raise AuthError(401, 'Session expired or invalid')
        return self.account(row['user_id'])

    def bind(self, user_id, provider, subject):
        with self.db() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT user_id FROM identities WHERE provider=? AND subject=?', (provider, subject)).fetchone()
            if row and row['user_id'] != user_id:
                raise AuthError(409, 'This identity already belongs to another account')
            db.execute('DELETE FROM identities WHERE provider=? AND user_id=?', (provider, user_id))
            db.execute('INSERT OR IGNORE INTO identities VALUES(?,?,?)', (provider, subject, user_id))
            # Updating identity invalidates other devices, retaining this app session is handled by caller.
        return self.account(user_id)

    def revoke(self, token):
        user = self.user(token)
        with self.db() as db:
            db.execute('DELETE FROM sessions WHERE token_hash=?', (digest(token),))
        return user

    def revoke_others(self, token):
        user = self.user(token)
        with self.db() as db:
            db.execute('DELETE FROM sessions WHERE user_id=? AND token_hash<>?', (user['id'], digest(token)))
        return user

    def delete(self, token):
        user = self.user(token)
        # A fresh login is required for this irreversible server action.
        with self.db() as db:
            row = db.execute('SELECT expires FROM sessions WHERE token_hash=?', (digest(token),)).fetchone()
            if row['expires'] - 7 * 24 * 3600 < time.time() - 600:
                raise AuthError(401, 'Please sign in again before deleting your account')
            for table in ('identities', 'passwords', 'sessions'):
                db.execute('DELETE FROM ' + table + ' WHERE user_id=?', (user['id'],))
            db.execute('DELETE FROM users WHERE id=?', (user['id'],))
            db.execute('DELETE FROM verification WHERE owner=?', (user['id'],))
        return user

    def set_password(self, user_id, password):
        if not isinstance(password, str) or not 8 <= len(password) <= 128:
            raise AuthError(400, 'Password must contain 8 to 128 characters')
        salt = secrets.token_hex(16)
        hashed = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 600000).hex()
        with self.db() as db:
            db.execute('INSERT OR REPLACE INTO passwords VALUES(?,?,?)', (user_id, salt, hashed))
        return self.account(user_id)


def exchange_with_wechat(app_id, app_secret, code):
    params = urlencode(dict(appid=app_id, secret=app_secret, code=code, grant_type='authorization_code'))
    # Do not log this URL: the secret must never enter access logs.
    try:
        with urlopen('https://api.weixin.qq.com/sns/oauth2/access_token?' + params, timeout=15) as response:
            result = json.loads(response.read(65536))
    except Exception:
        raise AuthError(502, 'WeChat is temporarily unavailable') from None
    if result.get('errcode') or not result.get('access_token') or not result.get('openid'):
        raise AuthError(401, 'WeChat authorization code is invalid or expired')
    if 'snsapi_userinfo' not in result.get('scope', '').split(','):
        raise AuthError(401, 'Required WeChat authorization scope missing')
    # Only login is needed. Do not fetch unnecessary user info or return WeChat tokens.
    return result['openid']


class AuthApplication:
    def __init__(self, store, app_id="", secret="", exchanger=exchange_with_wechat, verification=None):
        self.store, self.app_id, self.secret, self.exchanger = store, app_id, secret, exchanger
        if verification is None:
            from verification import Verification
            verification = Verification(store, os.getenv('VERIFICATION_HMAC_KEY', ''))
        self.verification = verification
        self.lock = threading.Lock()
        self.requests = {}
        self.chat = TreeHole()

    def rate_limit(self, client):
        now = time.monotonic()
        with self.lock:
            self.requests = {key: values for key, values in self.requests.items() if values[-1] > now - 60}
            recent = [t for t in self.requests.get(client, []) if t > now - 60]
            if len(recent) >= 30:
                raise AuthError(429, 'Too many requests; retry later')
            self.requests[client] = recent + [now]

    def verification_request(self, body, client, token=None):
        purpose = body.get('purpose', 'login')
        if purpose not in ('login', 'phone', 'email', 'password'):
            raise AuthError(400, 'Invalid purpose')
        owner = ''
        target = body.get('target', '')
        if not isinstance(target, str):
            raise AuthError(400, 'Invalid contact')
        channel = body.get('channel', 'sms')
        if purpose != 'login':
            user = self.store.user(token or '')
            owner = user['id']
            if purpose == 'password':
                target = user.get('phone') or user.get('email') or ''
                channel = 'sms' if user.get('phone') else 'email'
            elif purpose == 'phone':
                channel = 'sms'
            else:
                channel = 'email'
        if channel not in ('sms', 'email'):
            raise AuthError(400, 'Invalid channel')
        if purpose == 'email':
            target = target.strip().lower()
        if purpose == 'login' and channel != 'sms':
            raise AuthError(400, 'SMS login required')
        return self.verification.send(target, channel, purpose, owner, client)

    def verify_login(self, body):
        target = body.get('target', '')
        self.verification.consume(body.get('challengeID', ''), target, 'sms', 'login', '', body.get('code', ''))
        return self.store.issue_identity('phone', target)

    def update_account(self, token, body, purpose):
        user = self.store.user(token)
        target = body.get('target', '')
        if purpose == 'password':
            target = user.get('phone') or user.get('email') or ''
        elif purpose == 'email' and isinstance(target, str):
            target = target.strip().lower()
        self.verification.consume(body.get('challengeID', ''), target, 'sms' if (purpose == 'phone' or (purpose == 'password' and user.get('phone'))) else 'email', purpose, user['id'], body.get('code', ''))
        if purpose == 'password':
            result = self.store.set_password(user['id'], body.get('password'))
        else:
            result = self.store.bind(user['id'], purpose, target)
        self.store.revoke_others(token)
        return result

    def exchange(self, body):
        values = [body.get(key) for key in ('challengeID', 'state', 'code')]
        if not all(isinstance(value, str) and 0 < len(value) <= 1024 for value in values):
            raise AuthError(400, 'Invalid authorization request')
        self.store.consume(body['challengeID'], body['state'])
        openid = self.exchanger(self.app_id, self.secret, body['code'])
        return self.store.issue(self.app_id, openid)


def handler_for(application):
    class Handler(BaseHTTPRequestHandler):
        server_version = 'WorthItAuth'

        def log_message(self, format, *args):
            # No request URL, credential, authorization code or headers in default logs.
            pass

        def send_json(self, status, payload):
            data = json.dumps(payload, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(data)))
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            self.dispatch()

        def do_POST(self):
            self.dispatch()

        def dispatch(self):
            try:
                client = self.client_address[0]
                if os.getenv('AUTH_TRUST_LOCAL_PROXY') == '1' and ipaddress.ip_address(client).is_loopback:
                    forwarded = self.headers.get('X-Real-IP', '')
                    if forwarded:
                        try:
                            client = str(ipaddress.ip_address(forwarded))
                        except ValueError:
                            raise AuthError(400, 'Invalid proxy client address')
                application.rate_limit(client)
                if self.command == 'GET' and self.path == '/tree-hole/status':
                    return self.send_json(200, application.chat.status())
                if self.command == 'GET' and self.path == '/auth/session':
                    return self.send_json(200, application.store.user(self.bearer()))
                if self.command != 'POST':
                    raise AuthError(404, 'Not found')
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= (65536 if self.path.startswith('/tree-hole/') else 4096):
                    raise AuthError(400, 'Invalid body size')
                if self.headers.get_content_type() != 'application/json':
                    raise AuthError(415, 'JSON required')
                body = json.loads(self.rfile.read(size))
                if not isinstance(body, dict):
                    raise AuthError(400, 'JSON object required')
                if self.path == '/tree-hole/session':
                    result = application.chat.session(client)
                elif self.path == '/tree-hole/messages':
                    result = application.chat.reply(body, self.bearer(), client)
                elif self.path == '/auth/verification/send':
                    token = self.bearer() if body.get('purpose', 'login') != 'login' else None
                    result = application.verification_request(body, client, token)
                elif self.path == '/auth/phone/verify':
                    result = application.verify_login(body)
                elif self.path in ('/account/phone', '/account/email', '/account/password'):
                    result = application.update_account(self.bearer(), body, self.path.rsplit('/', 1)[1])
                elif self.path == '/account/delete':
                    result = application.store.delete(self.bearer())
                elif self.path == '/account/revoke-others':
                    result = application.store.revoke_others(self.bearer())
                elif self.path == '/account/bind/wechat':
                    user = application.store.user(self.bearer())
                    application.store.consume(body.get('challengeID', ''), body.get('state', ''))
                    openid = application.exchanger(application.app_id, application.secret, body.get('code', ''))
                    result = application.store.bind(user['id'], 'wechat:' + application.app_id, openid)
                elif self.path == '/auth/wechat/challenge':
                    result = application.store.challenge()
                elif self.path == '/auth/wechat/exchange':
                    result = application.exchange(body)
                elif self.path == '/auth/logout':
                    result = application.store.revoke(self.bearer())
                else:
                    raise AuthError(404, 'Not found')
                self.send_json(200, result)
            except (AuthError, ChatError) as error:
                self.send_json(error.status, dict(error=error.message))
            except (ValueError, UnicodeError):
                self.send_json(400, dict(error='Invalid JSON request'))
            except Exception:
                self.send_json(500, dict(error='Internal error'))

        def bearer(self):
            header = self.headers.get('Authorization', '')
            if not header.startswith('Bearer ') or not 20 <= len(header[7:]) <= 512:
                raise AuthError(401, 'Bearer session required')
            return header[7:]

    return Handler


if __name__ == '__main__':
    app_id, secret = os.getenv('WECHAT_APP_ID', ''), os.getenv('WECHAT_APP_SECRET', '')
    if len(os.getenv('VERIFICATION_HMAC_KEY', '')) < 32:
        raise SystemExit('Set VERIFICATION_HMAC_KEY to a random server-only value of at least 32 characters.')
    store = AuthStore(os.getenv('AUTH_DATABASE', 'worthit-auth.sqlite3'))
    application = AuthApplication(store, app_id, secret)
    port = int(os.getenv('PORT', '8080'))
    print(f'Auth reference service on 127.0.0.1:{port}; expose only through your HTTPS reverse proxy.')
    server = ThreadingHTTPServer(('127.0.0.1', port), handler_for(application))
    server.serve_forever()
