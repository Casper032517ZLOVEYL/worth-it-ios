#!/usr/bin/env python3
"""Check a built .app before distribution; never bypass review or invent credentials."""
import argparse
import json
from pathlib import Path
import plistlib
import re
from urllib.parse import urlparse

parser = argparse.ArgumentParser()
parser.add_argument('--app', required=True, help='Path to built .app')
args = parser.parse_args()
app = Path(args.app)
errors, notes = [], []
info = plistlib.loads((app / 'Info.plist').read_bytes())

def required(key):
    value = info.get(key, '')
    if not isinstance(value, str) or not value.strip() or '$(' in value:
        errors.append(key + ': missing real release value')
        return ''
    return value

for key in ('AppOwnerName', 'PrivacyPolicyURL', 'SupportURL', 'SupportEmail'):
    value = required(key)
    if value and key.endswith('URL'):
        url = urlparse(value)
        if url.scheme != 'https' or not url.netloc or 'your-domain' in url.netloc:
            errors.append(key + ': real HTTPS URL required')
if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', info.get('SupportEmail', '')):
    errors.append('SupportEmail: valid monitored support address required')
manifest = app / 'PrivacyInfo.xcprivacy'
if not manifest.exists():
    errors.append('Privacy manifest missing')
else:
    privacy = plistlib.loads(manifest.read_bytes())
    if privacy.get('NSPrivacyTracking'):
        errors.append('Tracking declaration does not match this build')
translations = app / 'InterfaceTranslations.json'
if not translations.exists():
    errors.append('Localization resource missing from app bundle')
else:
    table = json.loads(translations.read_text())
    expected = set(info.get('CFBundleLocalizations', [])) - {'zh-Hans', 'zh-Hant'}
    for key in ['设置', '语言设置', '下一问', '完全符合']:
        if not expected.issubset(table.get(key, {})):
            errors.append('Incomplete primary interface translation: ' + key)
wechat = info.get('WeChatAppID', '')
if re.fullmatch(r'wx[a-zA-Z0-9]{16}', wechat):
    for key in ('WeChatUniversalLink', 'AuthBaseURL'):
        value = info.get(key) or info.get('WeChatAuthBaseURL', '')
        if urlparse(value).scheme != 'https':
            errors.append(key + ': HTTPS configuration required')
    errors.append('WeChat enabled: implement and verify an equivalent login option under Apple guideline 4.8 before App Store submission; the Apple binding placeholder is not Sign in with Apple')
else:
    notes.append('WeChat not configured; no WeChat authorization entry will be offered')
notes.extend([
    'Confirm real URLs are reachable, privacy policy owner matches registrations, and backend is live.',
    'Confirm platform category, screenshots, age rating, copyright/source records and actual capabilities match.',
    'Do not advertise fortune, health outcomes or actual success-probability prediction.',
    'Contact-free local profile is available; verify it remains accessible without phone or email.',
    'Release cannot claim full long-form localization; document the exact primary-interface/question coverage.'
])
for error in errors: print('BLOCKER:', error)
for note in notes: print('CHECK:', note)
print('Release preflight:', 'NOT READY' if errors else 'LOCAL CHECKS PASSED; external review checks still required')
raise SystemExit(1 if errors else 0)
