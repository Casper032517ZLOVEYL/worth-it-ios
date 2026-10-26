#!/usr/bin/env python3
"""Validate real primary-interface and question coverage, not just a language menu."""
import json
from pathlib import Path
import re
import plistlib
root = Path(__file__).resolve().parent.parent
app = root / '值得吗？'
table = json.loads((app / 'Resources/InterfaceTranslations.json').read_text())
locales = plistlib.loads((root / 'Configuration/AppInfo.plist').read_bytes())['CFBundleLocalizations']
foreign = set(locales) - {'zh-Hans', 'zh-Hant'}
assert len(locales) == 28 and len(foreign) == 26
questions = re.findall(r'\.init\(id: \d+, dimension: \.\w+, title: ("(?:[^"\\]|\\.)*"), note:', (app / 'Models/Decision.swift').read_text())
assert len(questions) == 20
keys = [json.loads(q) for q in questions] + ['树洞', '设置', '语言设置', '显示设置', '账号安全', '下一问', '完全不符合', '不太符合', '比较符合', '完全符合']
for key in keys:
    assert foreign.issubset(table[key]), (key, foreign - set(table.get(key, {})))
    for language in foreign:
        value = table[key][language]
        assert value.strip() and (language == 'ja' or not re.search('[\u4e00-\u9fff]', value)), (key, language, value)
for key, variants in table.items():
    source = sorted(re.findall(r'%(?:\d+\$)?[@df]', key))
    for language, value in variants.items():
        assert sorted(re.findall(r'%(?:\d+\$)?[@df]', value)) == source, (key, language, 'format mismatch')
print('PASS: 28 declared languages; 26 foreign languages have 20 questions, four answer levels and primary navigation. Format placeholders match.')
print('Long-form poems and commentary retain original text when not translated; this is disclosed in the language picker.')
