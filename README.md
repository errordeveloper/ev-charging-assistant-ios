# EV Charging Assistant for iOS

An iOS charging and route-planning assistant with local Bluetooth telemetry as a first-class input. Start with one measured vehicle/adapter combination, then expand coverage through explicit compatibility profiles and optional cloud providers.

## Repository status

This is a development bootstrap, not a finished charging app. It includes:

- SwiftUI battery dashboard with explicitly labeled manual and demo inputs.
- Bounded, foreground Core Bluetooth discovery. No connection or vehicle commands yet.
- A dependency-free EVCore library for validated telemetry, freshness/source selection, a constant-consumption energy estimator, and bounded ASCII response framing.
- Domain tests, two simulator UI tests, macOS CI, project generation, and an agent implementation contract.
- An end-to-end roadmap and a hardware evidence template.

**No vehicle, adapter, battery decoder, cloud provider, charger feed, or AI service is validated or integrated yet.** Demo data never counts as evidence of hardware support. The energy experiment is not turn-by-turn routing or a charger-stop optimizer.

## Run package tests on Linux

On x86_64 Linux, install Nix with the `nix-command` and `flakes` features enabled, then run:

```bash
nix develop --no-update-lock-file --command swift run --disable-index-store repo-tools check-toolchain
nix develop --no-update-lock-file --command swift test --disable-index-store --jobs 4
nix develop --no-update-lock-file --command swift run --disable-index-store repo-tools validate
```

The Linux shell supplies a checksum-pinned official Swift 6.0.3 toolchain, Git, Clang and GNU coreutils. The locked Nixpkgs Swift compiler is 5.10.1, below this package's Swift 6 requirement. Repository-tool hashing uses Apple’s Swift Crypto 4.3.1 (`Crypto`) on Linux and system CryptoKit on macOS, with the same in-process `SHA256` API. Swift Crypto is pinned to the latest release supporting this Swift 6.0 toolchain; newer releases require Swift 6.1 or 6.2. EVCore remains dependency-free, and the crypto dependency is only linked into Linux repository tooling. Linux ARM64 is not currently exposed by the flake. The Linux package omits the upstream LLDB debugger, whose Ubuntu-specific dependencies are outside this compiler/test workflow.

Linux test commands disable SwiftPM’s optional index store because the Nix Clang wrapper does not support the Swift-specific C indexing flag. Compilation and test assertions still run normally.

The shell defaults compiler caches to the ignored `.build/` directory. If your cloud machine's home directory is read-only, append `--cache-path .build/swiftpm-cache --config-path .build/swiftpm-config --security-path .build/swiftpm-security` to SwiftPM commands.

Linux can compile EVCore and repository tools and execute their unit tests. SwiftUI, Core Bluetooth, Xcode project generation, simulator UI tests and the Apple-toolchain attestation remain macOS workflows. This shell does not supply Apple SDKs or an iOS cross-compilation environment; building the iOS app still requires Xcode on a Mac. No API credentials or services are needed for package tests.

## Run on a Mac

Install Xcode with Swift 6 and an iOS 18+ SDK/runtime, plus [Nix](https://nixos.org/download/) with the `nix-command` and `flakes` features enabled. Nix 2.31.2 is used in CI. The flake supports Apple Silicon and Intel Macs and supplies Git and [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46.0. `flake.lock` pins Nixpkgs; `config/toolchain.json` pins the generator archive/checksum and CI installer/Actions versions.

```bash
nix develop
swift run repo-tools check-toolchain
swift run repo-tools check-xcodegen
swift test
swift run repo-tools validate
xcodegen generate
open EVChargingAssistant.xcodeproj
```

CI uses the same shell without allowing lock-file updates. Run individual commands without entering an interactive shell:

```bash
nix develop --no-update-lock-file --command swift test
nix develop --no-update-lock-file --command bash scripts/test-ios.sh
nix develop --no-update-lock-file --command swift run repo-tools record-toolchain
```

Xcode, Swift, Apple SDKs and simulator runtimes remain host prerequisites. The shell uses `mkShellNoCC` to keep Nix's compiler/SDK configuration out of the app build. Select Xcode using `xcode-select` or set `DEVELOPER_DIR` before `nix develop`; the shell preserves that selection. `swift run repo-tools check-toolchain` checks tool provenance and the minimum Swift and simulator SDK versions. An SDK alone does not provide a simulator runtime. Exact Xcode/runtime pinning remains pending a green CI run.

To update the supporting packages, run `nix flake update nixpkgs`, review `flake.lock`, and rerun the shell, generator, Swift and UI checks. The XcodeGen package reads the existing version, URL and checksum directly from `config/toolchain.json`, so upgrading Nixpkgs does not silently upgrade the generator.

CI records toolchain evidence as an unsigned in-toto Statement at `artifacts/toolchain.intoto.json`. It includes configuration file digests, observed tool versions and simulator runtimes. See the [attestation format](docs/TEST_STRATEGY.md#toolchain-attestation-v1) for its scope and failure behavior.

Choose your Apple development team in Xcode for a physical iPhone. Simulator runs need no signing. Run `bash scripts/test-ios.sh` for simulator UI tests. Bluetooth discovery requires a physical iPhone for the hardware acceptance gate; simulator tests use manual/demo inputs and disable discovery through `-uitesting`.

No API credentials are needed for this scaffold. Generated Xcode project files and raw private lab evidence stay out of version control.

The Nix XcodeGen package preserves both the executable and its bundled setting presets. `swift run repo-tools check-xcodegen` generates an isolated sample project and checks its build defaults before CI starts a simulator; it does not compile the app or run UI tests. The standalone `scripts/install-xcodegen.sh` remains available for setups without Nix; add `.tools/xcodegen/bin` to `PATH` after running it. It uses the same Swift helper and requires Xcode with Swift 6.

Repository automation lives in the `repo-tools` SwiftPM executable, using Foundation and in-process SHA-256 (system CryptoKit on Apple platforms; Swift Crypto on Linux). `swift run repo-tools --help` lists its commands; SwiftPM compiles it on first use and reuses the build. `swift test` covers both EVCore and the tooling. The tooling targets are separate from the EVCore library used by the app.

## Development documents

| Document | Purpose |
|---|---|
| [Development plan](docs/DEVELOPMENT_PLAN.md) | Ordered milestones, acceptance gates, and agent execution loop |
| [Architecture](docs/ARCHITECTURE.md) | Data ownership, typed tools, app/backend boundaries |
| [Bluetooth](docs/BLUETOOTH.md) | Adapter/protocol experiments, background constraints, compatibility evidence |
| [Test strategy](docs/TEST_STRATEGY.md) | Replay, simulator, cloud, hardware, AI evaluations, release gates |
| [Security and privacy](docs/SECURITY_AND_PRIVACY.md) | Credential handling, telemetry minimization, trust boundaries |
| [Backlog](docs/BACKLOG.md) | Ready-to-file issues with dependencies and completion evidence |
| [Agent instructions](AGENTS.md) | Commands, scope discipline, and evidence rules |

The first product milestone is **a validated, read-only battery reading from one EV via one documented BLE adapter**. The user's Enyaq is a proposed first pilot if available; its exact model/year/software and protocol support must be recorded rather than inferred.

## Validation of this bootstrap

See [bootstrap validation](docs/BOOTSTRAP_VALIDATION.md). Swift/Xcode tests must run on the first Mac or GitHub macOS runner before treating the scaffold as build-verified.

Repository working name: `errordeveloper/ev-charging-assistant-ios`. Intended initial visibility: private. No open-source license has been chosen.
