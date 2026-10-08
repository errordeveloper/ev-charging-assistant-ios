# Linux test discovery index-store correction (2026-10-08)

A fresh Nix build reproduced the Linux CI failure: SwiftPM 6.0 test discovery still opens an index store when `--disable-index-store` is supplied. `--disable-xctest` did not prevent that build step. Earlier local validation reused an index store and did not expose this clean-build failure.

The Linux workflow now determines the expected path using `swift build --show-bin-path`, then passes `-Xswiftc -index-store-path -Xswiftc "$index_store_path"` to `swift test --disable-index-store`. This creates real Swift index records for discovery while leaving C indexing disabled for the upstream Nix Clang wrapper. Both test frameworks remain enabled.

A fresh build in `.build/indexfix-native` with the official Swift 6.0.3 Linux toolchain passed all 27 Swift Testing tests using this command. This follow-up was validated with the unpacked toolchain, not a completed Nix-shell run; remote Linux CI must verify the Nix integration. Whitespace checks passed. Application and macOS commands are unchanged.

---

# In-process Linux hashing follow-up (2026-10-08)

Linux repository tooling now uses pinned Swift Crypto 4.3.1 through the `Crypto` module; macOS continues using system CryptoKit. Both paths call `SHA256.hash` directly. No hash subprocess is launched, and EVCore has no crypto dependency. `Package.resolved` pins Swift Crypto and its transitive Swift ASN.1 dependency.

All 27 unit tests passed in the Linux Nix shell with Swift 6.0.3 and `swift test --disable-index-store --jobs 4`, including known SHA-256 vectors, unusual filenames, missing-file handling and checksum rejection. Linux SwiftPM commands disable optional index-store generation because upstream Nix Clang does not support Swift's C indexing flag. macOS validation is left to CI.

---

# Linux cloud validation (2026-10-06)

The x86_64 Linux flake shell was executed on Debian 13 using Nix 2.20.6 from checksum-pinned nix-portable v012 and the checksum-pinned official Swift 6.0.3 release. Nix mapped its store through bubblewrap; user namespaces required execution outside the command sandbox. CI continues to install Nix 2.31.2.

- `nix flake check --no-update-lock-file --all-systems --no-build`: passed for x86_64 Linux and both Darwin architectures. Darwin outputs were evaluated, not built or tested on this host.
- `nix develop --no-update-lock-file --command swift test --jobs 4`: clean build passed all 26 Swift Testing tests (10 EVCore and 16 repository-tooling tests). The XCTest compatibility runner's zero-test line is separate from the completed Swift Testing suite.
- `swift run repo-tools check-toolchain` inside the Nix shell: passed Linux Nix provenance and minimum Swift checks.
- `swift run repo-tools validate` inside the Nix shell: passed repository contracts and links.
- `actionlint .github/workflows/ci.yml` from the locked Nixpkgs commit: passed. The added Linux CI job has not been executed remotely.
- Shell syntax and `git diff --check`: passed.

SwiftPM commands used `--scratch-path .build/nix-linux --cache-path .build/swiftpm-cache --config-path .build/swiftpm-config --security-path .build/swiftpm-security` on this read-only-home cloud host. The Nix shell supplies compiler cache paths under `.build/`, portable Darwin/Glibc imports, GNU SHA-256 hashing on Linux at that revision (subsequently replaced with in-process Swift Crypto), and Nix's Clang linker wrapper so generated binaries use the same libc/loader as the Swift runtime. The original bundled Clang produced a crashing manifest executable by mixing the host loader with Nix libraries; the wrapper correction was verified by the clean package build and tests.

The lockfile and macOS package/shell derivations are unchanged. Linux ARM64, LLDB, iOS cross-compilation, app/UI execution, hardware and Apple-toolchain attestation remain outside this Linux workflow. Xcode and Apple SDKs are still required on macOS. No claim of a macOS build or hardware validation is made by these results.

---

# Bootstrap validation

## EV-001 follow-up: Swift repository tooling (2026-10-06)

This report covers the current Swift tooling migration on branch `refactor/swift-repo-tools`, based on `91c277c`. Earlier bootstrap and installation reports remain in Git history at that commit. The migration was recorded in `bb51919`; final review added the PATH lookup regression fix and this refreshed evidence.

Acceptance criteria: move repository validation, toolchain checks, unsigned in-toto collection, backlog import, XcodeGen installation and simulator selection into the `repo-tools` SwiftPM executable; run CI through the locked Nix shell; preserve checksum verification, bundled presets, preview-only import defaults and failure reporting; retain kebab-case script names and CLI subcommands.

Non-goals: change app or telemetry behavior, install Xcode or simulator runtimes through Nix, sign attestations, create backlog issues, establish vehicle compatibility, or claim the full iOS build is hermetic. EV-001 still needs a green CI run and validated Xcode/runtime pins.

The original UI build failure came from installing the XcodeGen binary without its bundled setting presets, leaving generated product names empty. The Swift installer preserves the repaired binary/preset layout. Both the Nix package and standalone installation passed an isolated generation check for product names, Debug/Release settings, iOS defaults and app/UI-test presets.

## Executed checks

Local execution used an Apple Silicon Mac, Nix 2.31.2 (Determinate Nix 3.11.3), Xcode 27.0 (27A266a), Apple Swift 6.4, the iOS Simulator 27.0 SDK, Git 2.54.0 and XcodeGen 2.46.0. These are local results, not evidence of a GitHub Actions run.

Except the flake check, workflow lint and shell/diff checks, the commands below ran inside `nix develop --no-update-lock-file --command`.

| Command | Result |
|---|---|
| `nix flake check --no-update-lock-file --all-systems --no-build` | PASS: both Darwin architectures evaluate. Only Apple Silicon was executed locally. |
| `swift test` | PASS: 25 tests, comprising 10 EVCore and 15 repository-tooling tests. |
| `swift run repo-tools validate` | PASS: required files, Markdown links, compatibility policy, acyclic backlog, pinned Actions/lock inputs and script naming. |
| `swift run repo-tools check-toolchain` | PASS: Nix Git/XcodeGen, host Apple tools and minimum compiler/SDK versions. |
| `swift run repo-tools check-xcodegen` | PASS: required presets generated from an isolated directory using the Nix package. |
| `swift run repo-tools record-toolchain` | PASS: unsigned Statement v1 with 9 file subjects and all 10 probes successful. |
| `swift run repo-tools import-backlog` | PASS: preview of 12 prepared issues; no remote writes. |
| `bash scripts/install-xcodegen.sh` | PASS: configured archive downloaded, SHA-256 verified before extraction, executable/presets/license installed. |
| `PATH="$PWD/.tools/xcodegen/bin:$PATH" swift run repo-tools check-xcodegen` | PASS: the standalone installation also supplies the required presets. |
| `xcodegen generate` | PASS: project generation with the installed presets. |
| `xcodebuild -project EVChargingAssistant.xcodeproj -scheme EVChargingAssistant -destination 'generic/platform=iOS Simulator' -derivedDataPath artifacts/NixDerivedData CODE_SIGNING_ALLOWED=NO build-for-testing` | PASS: app and UI test targets compiled; `TEST BUILD SUCCEEDED`. The tooling targets remain outside the app dependency graph. |
| `bash scripts/test-ios.sh` | Project generation passed; launcher exited 1 because no iPhone simulator runtime/device was installed. UI tests did not run. |
| `nix shell --inputs-from . nixpkgs#actionlint --command actionlint .github/workflows/ci.yml` | PASS: workflow syntax and expressions. |
| `bash -n scripts/install-xcodegen.sh scripts/test-ios.sh` | PASS. |
| `git diff 91c277c --check` | PASS. |

The simulator selection test first failed against the unimplemented selector, then passed after implementation. It covers numeric runtime ordering, availability, phone type and platform filtering. Review also exposed incorrect lookup with relative/empty PATH entries; a failing regression test now passes. Other tooling tests cover actual subprocess timeout/missing-command behavior, large literal input, nonzero diagnostics, SHA-256 known vectors, incomplete attestations, environment allowlisting, missing subject files, archive checksum rejection, required installation resources and backlog dependency boundaries.

Logs are retained locally under ignored `artifacts/`: `swift-tools-red.log`, `swift-tools-path-red.log`, `swift-tools-final.log`, `swift-tools-checks.log`, `swift-tools-integration.log`, `swift-tools-flake.log`, `swift-tools-actionlint.log`, `swift-tools-ios-build.log` and `swift-tools-ui.log`. The refreshed unsigned environment statement is `artifacts/toolchain.intoto.json`; it reports collection success, not a UI test pass. Compiler caches, the Nix store, downloads and Apple simulator services required access outside the execution sandbox.

## Outstanding gates

- Simulator UI execution and screenshots require an installed iOS runtime. The SDK-only build does not satisfy that gate.
- Intel host execution and a green GitHub Actions run remain unverified. Pin the validated Xcode/runtime after CI succeeds.
- Physical iPhone/adapter/vehicle evidence remains absent. Bluetooth discovery does not establish vehicle or state-of-charge support.
- Provider contracts, diagnostic transport, background behavior and AI evaluations remain future milestones.
- GitHub access requires reauthentication, so a draft PR could not be opened from this session.

App UI and telemetry code were unchanged. Use the current commands in README and a completed physical report before advertising vehicle support.
