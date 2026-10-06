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
