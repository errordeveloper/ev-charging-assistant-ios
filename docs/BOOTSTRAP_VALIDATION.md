# Bootstrap validation

Prepared 2026-10-01 in a Linux workspace without Swift, Xcode, a signed-in GitHub CLI, or a physical iPhone/adapter/vehicle.

## Executed checks

- `python3 scripts/validate_repo.py`: PASS. Required files and Markdown links are consistent; the compatibility candidate is unverified; 12 backlog items have no dependency cycles; Actions are SHA-pinned; the scanner is foreground-only and sends no commands.
- Python AST syntax and all JSON/YAML parsing: PASS.
- `bash -n scripts/test-ios.sh` and `bash -n scripts/install-xcodegen.sh`: PASS.
- `python3 scripts/import-backlog.py` preview: PASS; no remote issue writes occur in preview.
- `git diff --check`: PASS for the staged bootstrap.
- Primary GitHub release/tag metadata checked: checkout v7.0.1 and upload-artifact v7.0.1 resolve to the pinned commits; XcodeGen 2.46.0 archive digest is recorded. Download/execution of the generator still requires a Mac/CI run.

These are source/package consistency checks, not Swift compiler or hardware evidence.

## Not executed

- `swift test`: Swift is not installed in this workspace.
- XcodeGen/Xcode app compilation and simulator UI tests: require macOS/Xcode.
- Bluetooth transport, decoder and background tests: not implemented beyond discovery; no test hardware is available.
- Cloud/provider contracts and AI evaluations: future milestones, not implemented.
- GitHub Actions: no remote repository exists yet, so the workflow has not run.
- GitHub issues: 12 specifications are prepared, but no remote issues exist yet.

## Next verification gate

On the first macOS runner, run the commands in README, fix any build/UI failures, record the exact toolchain and commit SHA, and pin the validated setup. A code scaffold with unexecuted Swift tests is not a green build. Use a completed physical report before advertising vehicle support.

## EV-001 follow-up: XcodeGen installation (2026-10-06)

Scope: repair the installer that copied the generator executable without its bundled setting presets, leaving generated product names empty and preventing the UI test build.

Acceptance criteria: install the presets from the checksum-verified archive in the generator's supported relative location; verify generated product names, Debug/Release, iOS, app and UI-test defaults from an isolated directory; run the available repository, Swift and simulator checks and record their results.

Non-goals: change app behavior, validate Bluetooth hardware, configure branch rules, or pin a new Xcode/runtime before CI evidence is available. This repair is one part of EV-001, not completion of the milestone.

Local validation used the working tree based on `fdaea32`, Xcode 27.0 (27A266a), Apple Swift 6.4 and the iOS Simulator 27.0 SDK. XcodeGen remains pinned to 2.46.0 with the existing archive checksum.

| Command | Result |
|---|---|
| `bash scripts/install-xcodegen.sh` | PASS: archive checksum verified; executable and bundled presets installed. |
| `python3 scripts/test-xcodegen.py` (installed generator on `PATH`) | Failed before the fix with missing product names and Debug settings; PASS after the fix. CI now runs this regression check before simulator startup. |
| `python3 scripts/validate_repo.py` | PASS. |
| `bash -n scripts/install-xcodegen.sh scripts/test-ios.sh` | PASS. |
| `swift test` | PASS: 10 tests. |
| `bash scripts/test-ios.sh` (installed generator on `PATH`) | Project generation passed without missing-preset warnings; UI tests did not run because no iPhone simulator was installed. |
| `xcodebuild -project EVChargingAssistant.xcodeproj -scheme EVChargingAssistant -destination 'generic/platform=iOS Simulator' -derivedDataPath artifacts/DerivedData CODE_SIGNING_ALLOWED=NO build-for-testing` | PASS: app and UI test targets compiled for arm64 and x86_64; `TEST BUILD SUCCEEDED`. This is compilation evidence, not a UI test pass. |
| `git diff --check` | PASS. |

Swift and Xcode checks required access outside the execution sandbox to compiler caches and simulator services. Local logs are in the ignored `artifacts/swift-test.log`, `artifacts/ios-test.log` and `artifacts/ios-build-for-testing.log`. The only build warnings were skipped App Intents metadata extraction for targets without an AppIntents dependency. UI screenshots and hardware tests were not run; app UI and telemetry code were unchanged. A green CI run and runtime/toolchain pinning remain outstanding.
