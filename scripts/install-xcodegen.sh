#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'XcodeGen installer requires macOS.' >&2
  exit 1
fi
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname -- "$script_dir")"
cd "$repo_dir"
mkdir -p .tools/xcodegen/bin
archive="$repo_dir/.tools/xcodegen/xcodegen.zip"
download_url="$(python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path('config/toolchain.json').read_text())['xcodegen']['url'])
PY
)"
curl --fail --location --retry 3 --output "$archive" "$download_url"
python3 - <<'PY'
import hashlib
import json
from pathlib import Path
config = json.loads(Path('config/toolchain.json').read_text())['xcodegen']
archive = Path('.tools/xcodegen/xcodegen.zip')
actual = hashlib.sha256(archive.read_bytes()).hexdigest()
if actual != config['sha256']:
    raise SystemExit('XcodeGen checksum mismatch; refusing to execute download.')
print('Verified XcodeGen archive SHA-256.')
PY
unzip -q -o "$archive" -d .tools/xcodegen/unpacked
binary_path="$(python3 - <<'PY'
from pathlib import Path
candidates = [p for p in Path('.tools/xcodegen/unpacked').rglob('xcodegen') if p.is_file()]
if len(candidates) != 1:
    raise SystemExit('Expected exactly one XcodeGen executable in the verified archive.')
print(candidates[0])
PY
)"
# XcodeGen loads build-setting presets relative to its installed executable.
# Keep the archive's bin/ and share/ layout; the binary alone is incomplete.
presets_path="$(dirname -- "$(dirname -- "$binary_path")")/share/xcodegen/SettingPresets"
mkdir -p .tools/xcodegen/share/xcodegen
cp -R "$presets_path" .tools/xcodegen/share/xcodegen/
install -m 755 "$binary_path" .tools/xcodegen/bin/xcodegen
.tools/xcodegen/bin/xcodegen --version
