#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname -- "$script_dir")"
cd "$repo_dir"

command -v xcodebuild >/dev/null
command -v xcodegen >/dev/null
command -v swift >/dev/null
xcodegen generate
mkdir -p artifacts
xcrun simctl list devices available --json > artifacts/simulators.json

simulator_id="${IOS_SIMULATOR_UDID:-}"
if [[ -z "$simulator_id" ]]; then
  simulator_id="$(swift run repo-tools select-simulator)"
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
