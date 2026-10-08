# End-to-end test strategy

## Layers and environments

| Layer | Runs where | Cases | Release evidence |
|---|---|---|---|
| Domain values and source selection | Swift package, macOS CI | Invalid/decoded SoC, stale/future samples, wrong vehicle, demo isolation, freshest preferred source | Passing package tests; boundary cases |
| Energy/planning | Swift package and deterministic fixtures | Units, usable capacity, impossible arrival, reserve, unavailable stops, uncertainty, charge taper, overflow | Golden scenario outputs and invariant tests |
| Framing/decoders | Swift package/replay CI | Every chunk split, multiple frames, truncated/malformed messages, bounded buffer, timeout/cancellation, error text, reset after reconnect | Provenance-tagged corpus and parser tests |
| BLE/session state machine | Mock transport plus benign hardware peripheral | Authorization/power changes, selection, late callbacks, loss/retry, MTU/write type, duplicate notification, explicit stop | State transition tests; real adapter report |
| App UX | iOS simulator XCTest UI tests | Empty/manual/demo states, stale/disconnected states, permission guidance, trip/charger flows, backend failure, Dynamic Type and accessibility | `.xcresult`, screenshots, accessibility review |
| Providers/backend | Contract tests and recorded/sandbox responses | Token refresh/revocation, coverage mismatch, 429/backoff, missing timestamps, charger price/access nuances, offline/cache/version changes | Fixture version, sandbox checks, secret redaction |
| AI assistant | Fixed eval corpus and fake tools; controlled live evaluation later | Unsupported vehicle, stale SoC, impossible trip, unknown prices, malicious descriptions, tool schema errors, loops/timeouts | Eval report with tool traces and bounded budget |
| Physical lifecycle | iPhone + adapter + EV, private test lab | SoC accuracy, locked/background delivery, reconnect, sleep/12V, charging, trip observations, OS upgrades | Exact tuple report and measured limitations |
| Distribution | Signed archive and TestFlight on devices | Install/upgrade, onboarding, permissions, account deletion/revocation, crash recovery | Archive provenance, beta report, release checklist |

The bootstrap includes only the domain/framing tests and two manual/demo UI flows. It does not include completed provider contracts, BLE state machine tests, model evals, or hardware reports.

## Deterministic replay

Build a transport interface with timestamped chunks, state events, expected requests, and injected clock/scheduler. Record legitimate hardware captures privately, remove VINs/IDs/locations and identifying adapter names, and commit only consented sanitized fixtures with model/firmware/profile provenance. Synthetic fixtures must be labeled synthetic.

Replay tests should verify the expected read-only request sequence, exact bytes at every chunk split, no requests after stop, one in-flight request, response limit, timeout cleanup, and connection-generation isolation. Fuzz parsers offline with bounded generated inputs; never use a vehicle as a fuzz target.

## CI and evidence

The provided `ci.yml` installs a pinned Nix release, evaluates the locked flake for both Mac architectures, and runs repository structural validation, Swift package tests, XcodeGen and simulator UI tests inside `nix develop --no-update-lock-file`. It checks that supporting tools come from Nix and Apple build tools still come from the host. Xcode results and an unsigned toolchain attestation are stored on a macOS runner. It grants only `contents: read`; there are no signing/provider/model secrets. Uploads are diagnostic artifacts, not signed releases.

`runs-on: macos-15` selects a GitHub-hosted Darwin/macOS machine. GitHub also documents explicit Intel labels such as `macos-15-intel` and newer macOS labels. The host runs Xcode/Swift and the iOS Simulator; it is not a physical iPhone or a vehicle Bluetooth lab. Keep software CI hosted and use a separate self-hosted Mac plus attached iPhone/adapter/EV for physical acceptance tests. Runner details: [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) and [macOS image inventory](https://github.com/actions/runner-images/tree/main/images/macos).

The generator archive/checksum and Actions commits are pinned. After the first green run, pin the exact verified Xcode/runtime, add dependency-update checks, and configure required branch checks. Avoid `pull_request_target` for untrusted code with secrets. A provider test with real credentials is a separate trusted job, never a condition for routine replay tests.

Future agent jobs must attach the issue/commit SHA and evidence manifest. Hardware jobs are manually triggered on a private, supervised lab runner. Capture originals remain private. Failures update the issue/PR status; a repair loop cannot waive a missing physical gate.

### Toolchain attestation v1

`swift run repo-tools record-toolchain` writes `artifacts/toolchain.intoto.json`, a single unsigned JSON [in-toto Statement v1](https://github.com/in-toto/attestation/blob/main/spec/v1/statement.md). It uses the custom predicate type URI `https://github.com/errordeveloper/ev-charging-assistant-ios/attestations/toolchain/v1`, defined here. It has no signing envelope or signatures.

The subjects are the SHA-256 digests of the actual bytes of `flake.nix`, `flake.lock`, `nix/xcodegen.nix`, `config/toolchain.json`, `.github/workflows/ci.yml`, `Package.swift`, `Tools/RepoTools/main.swift`, `Tools/RepoToolsSupport/Attestation.swift` and `Tools/RepoToolsSupport/Command.swift`. The predicate describes the observed environment associated with those configuration inputs, not the provenance or test status of a built app.

- `recordedAt`: UTC collection timestamp.
- `host`: operating system, CPU architecture and kernel release.
- `environment`: only the allowlisted Xcode selection and GitHub run metadata; credentials and the rest of the environment are excluded.
- `observations`: fixed tool/version, selected Swift path, simulator SDK/runtime inventory and Git revision/status probes. Each records the command, resolved executable, exit code, stdout and stderr.
- `collectionSucceeded`: whether every probe completed successfully. An empty runtime inventory can still be collected successfully; this field does not mean UI tests passed or a simulator is installed.

Each command has a 60-second timeout. Missing commands, timeouts and nonzero exits are recorded as failures; the collector writes the incomplete statement, prints each failed probe's name, command, exit code and diagnostic to stderr, and exits nonzero so CI can upload the evidence without treating collection as successful. Missing subject files fail collection because their digests cannot be supplied. This statement replaces the previous plain-text toolchain reports. Test logs and `.xcresult` bundles remain diagnostic artifacts.

## AI evaluation acceptance

Start with at least 40 hand-reviewed cases across healthy, degraded, unknown, adversarial, and infeasible conditions. Version prompts, schemas, model settings, fixtures, and expected invariants. Assess tool choice/arguments, correct scope and freshness, reserve math sourced from code, factual explanation, refusal to invent data, cancellation, and call/spend budget.

Require zero vehicle-command attempts, zero use of other-vehicle/demo data as live data, and zero fabricated battery/price/availability facts in the release evaluation set. Report rate/denominator for other quality measures and retain failures. Passing a finite set is release evidence, not a guarantee; add cases from beta failures and rerun affected evaluations after prompt/tool/model changes.

## Hardware matrix and practical pilot

Cover the minimum supported iOS and latest supported iOS, at least two phone generations if available, the chosen adapter firmware, and the exact pilot vehicle software. Test foreground, locked, background, range loss, Bluetooth toggles, interrupted charging, explicit stop, vehicle sleep, and app relaunch. Add new firmware/model combinations only with evidence.

Begin parked. For road observations, a passenger/tester operates the app and records readings while the driver drives; agents analyze sanitized logs afterward. Measure sample age, reconnect duration, error rates, discrepancies, and whether app behavior prevents vehicle/adapter sleep. If measurement equipment is missing, report the energy/sleep gate as incomplete.

## Release gates

1. Green domain, replay, backend contract, UI, and eval checks applicable to shipped features.
2. Hardware evidence for every advertised tuple/condition; untested cases clearly excluded from coverage.
3. Source/age/unknown and manual fallback behave correctly when Bluetooth/backend data fails.
4. No fabricated tariff/availability or hidden account/vehicle commands.
5. Reviewed privacy disclosures, consent flows, token revocation, deletion behavior, redacted diagnostics, and access controls.
6. Accessibility and small/large text/device layout checks; beta install/upgrade and recovery tests.
7. Signed archive/build provenance, release notes, support matrix, and user-authorized distribution.

## Commands

```bash
nix develop
swift run repo-tools check-toolchain
swift run repo-tools check-xcodegen
swift run repo-tools record-toolchain
swift run repo-tools validate
swift test
xcodegen generate
bash scripts/test-ios.sh
git diff --check
```

Tests must not be labeled passed when a runtime or device is absent. Use `docs/BOOTSTRAP_VALIDATION.md` to distinguish the scaffold's source checks from executed Swift/Xcode/hardware tests.
