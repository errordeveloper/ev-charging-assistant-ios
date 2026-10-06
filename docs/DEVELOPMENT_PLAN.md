# End-to-end agentic development plan

## Product outcome and initial choices

Help a UK EV owner answer: “What is my battery state now, where should I charge, and can I reach the next stop with my chosen reserve?” Explain recommendation tradeoffs using measured data, timestamps, explicit assumptions, and a deterministic planner.

Initial decisions: native SwiftUI, iOS 18+ as the proposed baseline, Swift 6, pure Swift domain package, Core Bluetooth adapter transport, one read-only vehicle profile, UK-first charger data, and optional cloud telemetry. A small backend will broker provider OAuth and assistant tools; no backend is implemented in the bootstrap. Revisit the minimum iOS version after testing demand and background behavior.

Do not promise direct-car Bluetooth SoC access, broad EV coverage, continuous background polling, charger availability, or tariff equality across apps. Each is a separately verified capability.

First pilot: the user's Enyaq if available. Confirm the exact model year, trim, software, and chosen adapter before writing the vehicle profile. Do not infer battery capacity or diagnostic scaling from its marketing name.

## Milestones and exit gates

| Milestone | Work | Exit evidence | Dependencies |
|---|---|---|---|
| M0 — Reproducible foundation | Generate Xcode project; compile Swift 6; run domain/UI tests; choose and pin Xcode/XcodeGen; create branch rules and issue backlog | First green macOS CI run, simulator screenshots, tool versions and reproducible local commands | GitHub repo; macOS/Xcode runner |
| M1 — Hardware feasibility | Select a documented BLE OBD adapter; confirm third-party protocol access; test iPhone discovery/GATT/transport; obtain legitimate vehicle read requests | Sanitized GATT/transport evidence and a recorded SoC vs dashboard comparison for one exact tuple | Physical iPhone, adapter, stationary EV, protocol documentation |
| M2 — Reliable telemetry slice | Connection state machine; profile allowlist; framing/decoder; bounded polling; freshness; reconnect; manual fallback | Replay suite plus parked-car session, correct SoC, failure behavior and explicit stop | M1 |
| M3 — Charger discovery | Contract and licensed UK feed; map/search; connectors/accessibility; tariff provenance and timestamp; outage/staleness UI | Provider contract tests, recorded fixtures, live UK spot checks; no invented rates/availability | Provider access and data-use terms |
| M4 — Route and charging planner | Route distance/elevation inputs; consumption uncertainty; usable capacity; charge curves; stops/reserve/preferences; replan triggers | Golden scenarios, infeasible-route cases, uncertainty ranges, compared with measured pilot trips | M2, M3, routing provider |
| M5 — Cloud telemetry | Select aggregator through coverage/terms spike; backend OAuth; freshness and quotas; reconcile local/cloud/manual | Sandbox contracts, exact-model coverage evidence, expiry/revocation/rate-limit tests | Provider account/contract; backend |
| M6 — AI assistant | Typed tools and schemas; read-only recommendations; cited data; bounded tool loop; evals; streaming/cancel | Golden eval set, adversarial tests, budgets, safe failure on unknown/stale telemetry | M3/M4; hosted model/backend choice |
| M7 — Physical lifecycle validation | Locked/background operation; app termination/restoration; Bluetooth off; vehicle sleep; energy measurement; passenger-observed trip | Completed hardware matrix with recorded limits; no permanent-polling claim | M2; hardware lab/tester |
| M8 — Beta and release | Accessibility, privacy, crash reporting policy, signing/TestFlight, pilot feedback, archive and release checklist | Signed archive, beta install/test report, completed release gates and privacy disclosures | M0–M7; Apple developer access |

M3 can start once the app/provider contracts are stable. M5 is optional for an initial local/manual beta; M6 can be prototyped against fixtures but cannot ship with fabricated live data. M7 feasibility experiments start in M1 rather than waiting for the end. Each milestone is a gate, not a calendar promise.

## Executable agent workflow

The default workflow is issue-driven and bounded. Roles can run sequentially in one agent session. Parallel agents are optional and require explicit execution authorization and isolated ownership; this plan does not launch persistent workers.

1. **Intake/planning:** select a ready issue, read existing evidence, identify inputs, and write precise acceptance criteria. If a physical test or paid provider is needed, prepare the experiment/contract first and label the dependency.
2. **Implementation:** branch from current main, add meaningful behavioral tests, implement one vertical slice, and run the smallest appropriate checks. Use replay fixtures for repeatable protocol work.
3. **Verification:** run domain/contract/UI/eval checks appropriate to the slice, inspect screenshots, collect logs and `.xcresult`, and identify unavailable gates honestly.
4. **Review:** inspect the diff and test evidence against requirements, privacy rules, and architectural boundaries. Review agent output is evidence, not an automatic waiver for hardware or merge rules.
5. **PR:** provide trigger/problem, resulting behavior, validation results, remaining gates, and source/protocol provenance. No unconditional “all tests passed” summary if some checks did not run.
6. **Reconciliation:** respond to CI/review failures with a new scoped change and rerun affected checks. Do not retry a deterministic failure repeatedly. After two ineffective repair attempts, state the failure, attempted remedies, and required input; continue other independent ready work.
7. **Completion:** merge under configured repository rules, update the backlog/compatibility evidence, and advance dependent issues. Release distribution is a distinct milestone.

## Agent execution infrastructure to add after M0

The bootstrap CI runs tests; it does **not** run an implementation agent or scheduled development loop. Choose a supported GitHub/Codex executor or another explicitly configured runner in a separate issue. Do not embed a model API key into an iOS app or allow untrusted fork code access to it.

- Trigger from an explicit issue/PR assignment or approved job request, not every incoming comment or repository text.
- Give each run its own branch/worktree, bounded time/token/spend budgets, restricted repo permissions, and an immutable input commit SHA.
- Serialize changes to shared architecture/contracts; parallelize only independent issues after their interfaces are stable.
- Report `blocked_input`, `blocked_hardware`, `software_checks_failed`, or `ready_for_review` as explicit outcomes.
- Keep an evidence bundle: input SHA, task spec, resulting SHA, tool versions, commands/statuses, test reports, screenshots, provider-fixture version, and review findings.
- Permit retries for transient network failures with backoff; distinguish them from parser/build/assertion failures. Never auto-relax a constraint to make a test green.
- A physical Mac/iPhone lab runner should use a private, manually triggered workflow, not a runner that executes arbitrary external PRs. Store original captures privately; sanitize before use as fixtures.
- Agent output uses draft PRs by default. Auto-merge is a later explicit repository policy decision once required checks and review gates are in place.

## First three development tasks

1. Run this bootstrap on a Mac, fix any compile/project-generation/UI issues, record the first green CI SHA, and pin the verified toolchain.
2. Confirm one adapter's developer protocol and one vehicle's read-only SoC request/response. Record adapter firmware, advertised services, characteristic properties, vehicle software, units/scaling, display-vs-BMS distinction, sample timing, and sleep behavior.
3. Implement that profile behind a replay-tested transport and decoder; demonstrate fresh SoC, disconnect-to-stale behavior, explicit stop, and manual fallback on a physical iPhone.

If M1 fails for the first tuple, stop that compatibility claim and evaluate another documented adapter/profile while continuing charger/planner work with labeled manual inputs. Cloud telemetry is an independent fallback, not proof that local Bluetooth works.

## Decisions still needing evidence

Adapter choice, exact initial vehicle, validated PID/DID mapping and licensing, charger/routing provider, cloud provider and model-specific read scope, backend/model provider, bundle ID and signing team, minimum supported iOS, background product promises, data retention, monetization, and public/open-source licensing.

These do not block preparing the architecture and tests. They do block claiming the corresponding integration or distributing a production app.
