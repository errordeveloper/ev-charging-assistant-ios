# Agent contract

## Goal and current state

Build an iOS EV charging and route-planning assistant with measured Bluetooth telemetry support. Read `README.md`, `docs/DEVELOPMENT_PLAN.md`, and the issue's acceptance criteria before changing code. The bootstrap discovers BLE peripherals; it does not read a car battery. Do not describe a planned feature as shipped.

## Commands

```bash
swift run repo-tools validate
swift test
xcodegen generate
bash scripts/test-ios.sh
git diff --check
```

Swift tests require Swift 6. Use `nix develop --no-update-lock-file --command` on macOS or x86_64 Linux for package tests and repository validation. The Linux shell supplies Swift; macOS uses host Xcode. App and UI tests require macOS/Xcode. If a tool is unavailable, report the check as not run; never manufacture logs or substitute source inspection for a passed build.

Use kebab-case for script filenames, for example `install-xcodegen.sh`. Use kebab-case for repository CLI subcommands too.

## Implementation loop

1. Pick one issue whose dependencies and inputs are resolved. Record its acceptance criteria and non-goals.
2. Work in an isolated branch/worktree. Keep the change reviewable and scoped to that issue.
3. Establish a failing behavioral test for a meaningful bug or new boundary; use protocol fixtures instead of physical hardware for routine iteration.
4. Implement, run relevant tests, inspect UI screenshots where UI changed, and fix failures.
5. Review the diff against acceptance criteria and privacy/protocol invariants. A reviewer agent can inspect the change if the execution environment and user authorize parallel agents; otherwise do a separate review pass.
6. Open a draft PR with exact commands, results, evidence links, unresolved assumptions, and required hardware gates. Mark ready when its software gates pass.
7. Merge according to repository rules and the user's authorization. Signing, distribution, paid provider onboarding, and vehicle tests need their own execution inputs and scope; planning them is not evidence they happened.

## Architecture rules

- Keep EVCore free of UI, networking, platform Bluetooth, model SDKs, and secrets. Inject time and external effects into tests.
- Telemetry always has a vehicle identifier, original observation time, source, units, and an explicit validity/freshness policy. Do not reset a cached cloud sample's age on fetch. Unknown/stale is not 0%.
- Demo fixtures remain labeled and isolated. Do not silently combine them with a real vehicle or claim simulator success proves BLE support.
- Discovering a peripheral or connecting to a dongle does not prove vehicle/SoC support.
- No guessed service UUID, manufacturer PID/DID, ECU header, scaling formula, or universal Bluetooth-car-battery API. Record provenance and verified traces before implementing a profile.
- Diagnostic traffic is read-only at the vehicle level, with an explicit reviewed request allowlist. Adapter setup writes are distinct from vehicle reads. No DTC clearing, coding, flashing, unlocking, charging commands, arbitrary CAN injection, or model-generated diagnostic bytes.
- One in-flight diagnostic request at a time; bounded buffer/timeouts; cancellation; explicit stop; profile-specific poll limits; no idle wake polling by default.
- LLMs call typed, allowlisted tools. Deterministic code computes energy, stop feasibility, constraints, and tariffs. Untrusted provider text cannot change policy.
- Provider and model secrets belong behind a backend; user tokens use Keychain. Do not commit secrets, VINs, exact routes, Bluetooth identifiers, or raw captures from a real user.
- Use primary documentation for platform/protocol claims; timestamp capability evidence. Respect source-code/data licenses.

## Tests and evidence

Test behaviors and failure boundaries, not private implementation structure. For parsers, exercise chunk boundaries, limits, malformed data, and reconnect reset. For planning, test infeasible inputs, reserve constraints, freshness, and unit conversions. Add evaluations when changing assistant tools/prompts. Update the compatibility matrix only from a completed hardware report.

A physical-device gate cannot be waived by an agent that only has a simulator. A hardware report must identify the tested tuple and distinguish measured result from target. Keep private originals outside git and commit sanitized fixtures with consent and provenance.

## Pull request completion

Software-complete means applicable tests pass and limitations are stated. Product-complete also needs the issue's physical-device/provider/release evidence. Do not silently skip a gate, disable failing tests, expand privileges, or claim a missing check passed. Update docs when behavior changes.
