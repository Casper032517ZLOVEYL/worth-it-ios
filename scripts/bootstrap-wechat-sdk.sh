#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
destination='Vendor/WechatOpenSDK-NoPay.xcframework'
if [[ -f "$destination/Info.plist" ]]; then
  echo 'WeChat SDK already exists. Remove the downloaded directory first if you need a fresh copy.'
  exit 0
fi
scratch_dir=$(mktemp -d /tmp/worthit-wechat.XXXXXX)
trap 'rm -rf "$scratch_dir"' EXIT
archive="$scratch_dir/OpenSDK2.0.9_NoPay.zip"
curl --fail --location --proto '=https' --tlsv1.2 --retry 2 \
  'https://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.9_NoPay.zip' \
  --output "$archive"
expected='ae8c7e847d83997f38891e27ad6bed98dd50d638a00ef2ec0890d4e9ac748f83'
actual=$(shasum -a 256 "$archive" | awk '{print $1}')
if [[ "$actual" != "$expected" ]]; then
  echo 'SDK checksum mismatch; nothing installed.' >&2
  exit 1
fi
ditto -x -k "$archive" "$scratch_dir/unpacked"
framework=$(find "$scratch_dir/unpacked" -type d -name 'WechatOpenSDK-NoPay.xcframework' -print -quit)
if [[ -z "$framework" || ! -f "$framework/Info.plist" ]]; then
  echo 'Expected XCFramework missing from official archive.' >&2
  exit 1
fi
mkdir -p Vendor
cp -R "$framework" "$destination"
# Correct the upstream module autolink declaration for a static framework.
python3 - "$destination" <<'PY'
from pathlib import Path
import sys
for modulemap in Path(sys.argv[1]).rglob('module.modulemap'):
    source = modulemap.read_text()
    modulemap.write_text(source.replace('link "WechatOpenSDK"', 'link framework "WechatOpenSDK"'))
PY
echo 'Official WeChat OpenSDK 2.0.9 NoPay downloaded, verified and prepared.'
