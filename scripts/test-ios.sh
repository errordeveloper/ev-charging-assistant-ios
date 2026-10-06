#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname -- "$script_dir")"
cd "$repo_dir"

command -v xcodebuild >/dev/null
command -v xcodegen >/dev/null
command -v python3 >/dev/null
xcodegen generate
mkdir -p artifacts
xcrun simctl list devices available --json > artifacts/simulators.json

simulator_id="${IOS_SIMULATOR_UDID:-}"
if [[ -z "$simulator_id" ]]; then
  simulator_id="$(python3 - <<'PY'
import json
import re
from pathlib import Path

devices = json.loads(Path('artifacts/simulators.json').read_text())['devices']
def version(runtime):
    return tuple(int(v) for v in re.findall(r'\d+', runtime))
for runtime in sorted(devices, key=version, reverse=True):
    if '.iOS-' not in runtime:
        continue
    for device in devices[runtime]:
        if device.get('isAvailable') and device['name'].startswith('iPhone'):
            print(device['udid'])
            raise SystemExit(0)
raise SystemExit('No available iPhone simulator; install an iOS runtime in Xcode.')
PY
  )"
fi

xcrun simctl bootstatus "$simulator_id" -b
bundle_path="artifacts/UI-$(date -u +%Y%m%dT%H%M%SZ).xcresult"
xcodebuild \
  -project EVChargingAssistant.xcodeproj \
  -scheme EVChargingAssistant \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -parallel-testing-enabled NO \
  -resultBundlePath "$bundle_path" \
  CODE_SIGNING_ALLOWED=NO \
  test
