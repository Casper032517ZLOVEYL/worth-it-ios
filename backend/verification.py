"""Server-only SMS/email delivery and single-use verification challenges."""
from hashlib import sha256
import hmac
import json
import os
import re
import secrets
import smtplib
import ssl
import time
from email.message import EmailMessage


class DeliveryUnavailable(Exception):
    pass


class TencentSMS:
    def __init__(self):
        self.values = {key: os.getenv(key, '') for key in (
            'TENCENT_SECRET_ID', 'TENCENT_SECRET_KEY', 'SMS_SDK_APP_ID', 'SMS_SIGN_NAME', 'SMS_TEMPLATE_ID')}

    def send(self, phone, code):
        if not all(self.values.values()):
            raise DeliveryUnavailable('短信服务尚未配置，暂时无法发送验证码。')
        try:
            from tencentcloud.common import credential
            from tencentcloud.sms.v20210111 import sms_client, models
            client = sms_client.SmsClient(credential.Credential(self.values['TENCENT_SECRET_ID'], self.values['TENCENT_SECRET_KEY']),
                                          os.getenv('SMS_REGION', 'ap-guangzhou'))
            req = models.SendSmsRequest()
            params = [code, '5'] if os.getenv('SMS_TEMPLATE_WITH_MINUTES') == '1' else [code]
            req.from_json_string(json.dumps(dict(PhoneNumberSet=['+86' + phone], SmsSdkAppId=self.values['SMS_SDK_APP_ID'],
                                                TemplateId=self.values['SMS_TEMPLATE_ID'], SignName=self.values['SMS_SIGN_NAME'],
                                                TemplateParamSet=params)))
            response = client.SendSms(req)
            if len(response.SendStatusSet) != 1 or response.SendStatusSet[0].Code != 'Ok':
                raise DeliveryUnavailable('短信未发送成功，请稍后重试。')
        except DeliveryUnavailable:
            raise
        except Exception:
            # SDK exceptions may contain request data. Never expose/log them.
            raise DeliveryUnavailable('短信通道暂时不可用，请稍后重试。') from None


class SMTPDelivery:
    def send(self, email, code):
        host, username, password, sender = [os.getenv(key, '') for key in ('SMTP_HOST', 'SMTP_USER', 'SMTP_PASSWORD', 'SMTP_FROM')]
        if not all((host, username, password, sender)):
            raise DeliveryUnavailable('邮件验证服务尚未配置。')
        message = EmailMessage()
        message['Subject'], message['From'], message['To'] = '值得吗？邮箱验证', sender, email
        message.set_content('你的邮箱验证码为：' + code + '。5 分钟内有效，如非本人操作请忽略。')
        try:
            with smtplib.SMTP_SSL(host, int(os.getenv('SMTP_PORT', '465')), timeout=15, context=ssl.create_default_context()) as smtp:
                smtp.login(username, password)
                smtp.send_message(message)
        except Exception:
            raise DeliveryUnavailable('验证邮件未发送成功，请稍后重试。') from None


class Verification:
    def __init__(self, store, key, sms=None, email=None, daily_limit=100):
        self.store, self.key = store, key
        self.sms, self.email = sms or TencentSMS(), email or SMTPDelivery()
        self.daily_limit = daily_limit
        with store.db() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS verification (
                    id TEXT PRIMARY KEY, target TEXT NOT NULL, channel TEXT NOT NULL,
                    purpose TEXT NOT NULL, owner TEXT NOT NULL, code_hash TEXT NOT NULL,
                    expires INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0,
                    status TEXT NOT NULL DEFAULT 'pending');
                CREATE TABLE IF NOT EXISTS delivery_log (
                    target_hash TEXT NOT NULL, client_hash TEXT NOT NULL, created INTEGER NOT NULL);
            ''')

    def hashed_code(self, challenge_id, target, purpose, owner, code):
        message = '|'.join([challenge_id, target, purpose, owner, code]).encode()
        return hmac.new(self.key.encode(), message, sha256).hexdigest()

    def send(self, target, channel, purpose, owner, client, now=None):
        from server import AuthError, iso
        if len(self.key) < 32:
            raise AuthError(503, '验证服务尚未配置。')
        valid = re.fullmatch(r'1[3-9][0-9]{9}', target) if channel == 'sms' else re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', target)
        if not valid or len(target) > 254:
            raise AuthError(400, '请输入有效的手机号或邮箱。')
        now = int(time.time() if now is None else now)
        challenge_id, code = secrets.token_urlsafe(24), f'{secrets.randbelow(1000000):06d}'
        target_hash, client_hash = sha256(target.encode()).hexdigest(), sha256(client.encode()).hexdigest()
        with self.store.db() as db:
            db.execute('BEGIN IMMEDIATE')
            db.execute('DELETE FROM delivery_log WHERE created<?', (now - 86400,))
            db.execute('DELETE FROM verification WHERE expires<?', (now - 86400,))
            last = db.execute('SELECT MAX(created) FROM delivery_log WHERE target_hash=?', (target_hash,)).fetchone()[0]
            per_target = db.execute('SELECT COUNT(*) FROM delivery_log WHERE target_hash=? AND created>?', (target_hash, now-3600)).fetchone()[0]
            per_client = db.execute('SELECT COUNT(*) FROM delivery_log WHERE client_hash=? AND created>?', (client_hash, now-3600)).fetchone()[0]
            daily = db.execute('SELECT COUNT(*) FROM delivery_log').fetchone()[0]
            if (last is not None and now-last < 60) or per_target >= 5 or per_client >= 10 or daily >= self.daily_limit:
                raise AuthError(429, '发送过于频繁，请稍后再试。')
            db.execute('INSERT INTO delivery_log VALUES(?,?,?)', (target_hash, client_hash, now))
            db.execute('INSERT INTO verification(id,target,channel,purpose,owner,code_hash,expires) VALUES(?,?,?,?,?,?,?)',
                       (challenge_id, target, channel, purpose, owner, self.hashed_code(challenge_id, target, purpose, owner, code), now+300))
        try:
            (self.sms if channel == 'sms' else self.email).send(target, code)
        except Exception as error:
            with self.store.db() as db:
                db.execute("UPDATE verification SET status='failed' WHERE id=?", (challenge_id,))
            raise AuthError(503, str(error) if isinstance(error, DeliveryUnavailable) else '验证码未发送成功。') from None
        with self.store.db() as db:
            # New successful delivery invalidates any older code for the same purpose.
            db.execute("UPDATE verification SET status='used' WHERE target=? AND purpose=? AND owner=? AND status='sent'", (target, purpose, owner))
            db.execute("UPDATE verification SET status='sent' WHERE id=?", (challenge_id,))
        return dict(challengeID=challenge_id, expiresAt=iso(now+300), resendAfter=60)

    def consume(self, challenge_id, target, channel, purpose, owner, code, now=None):
        from server import AuthError
        now = int(time.time() if now is None else now)
        if not isinstance(code, str) or not re.fullmatch(r'\d{6}', code):
            raise AuthError(400, '请输入六位验证码。')
        failure = False
        with self.store.db() as db:
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT * FROM verification WHERE id=?', (challenge_id,)).fetchone()
            if row is None or row['status'] != 'sent' or row['expires'] <= now or row['attempts'] >= 5:
                failure = True
            elif (row['target'], row['channel'], row['purpose'], row['owner']) != (target, channel, purpose, owner):
                db.execute('UPDATE verification SET attempts=attempts+1 WHERE id=?', (challenge_id,))
                failure = True
            elif not hmac.compare_digest(row['code_hash'], self.hashed_code(challenge_id, target, purpose, owner, code)):
                db.execute('UPDATE verification SET attempts=attempts+1 WHERE id=?', (challenge_id,))
                failure = True
            else:
                db.execute("UPDATE verification SET status='used' WHERE id=?", (challenge_id,))
        if failure:
            raise AuthError(401, '验证码错误、过期或已使用，请重新获取。')
