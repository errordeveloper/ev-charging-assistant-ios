# Ready-to-file development backlog

These are prepared issue specifications. They have not yet been created as GitHub issues. Dependencies use stable local IDs until issue numbers exist.

| ID | Task | Depends on |
|---|---|---|
| EV-001 | Compile and pin the iOS foundation | None |
| EV-002 | Validate one BLE adapter and vehicle protocol | EV-001 |
| EV-003 | Implement a replay-tested Bluetooth diagnostic session | EV-002 |
| EV-004 | Ship the first read-only SoC vertical slice | EV-003 |
| EV-005 | Characterize background, restoration and vehicle sleep | EV-004 |
| EV-006 | Integrate a licensed UK charger data feed | EV-001 |
| EV-007 | Implement deterministic route and charging-stop planning | EV-004, EV-006 |
| EV-008 | Build the provider and assistant backend contracts | EV-001 |
| EV-009 | Add optional cloud vehicle telemetry | EV-008, EV-004 |
| EV-010 | Implement the AI charging assistant with evaluated tools | EV-007, EV-008 |
| EV-011 | Configure bounded issue-to-PR agent execution | EV-001 |
| EV-012 | Deliver a physically validated TestFlight beta | EV-005, EV-006, EV-007, EV-010 |

## [EV-001] Compile and pin the iOS foundation

Run the scaffold on macOS, correct any generator/compiler/UI issues, pin a verified Xcode and XcodeGen setup, and configure required checks.

Completion evidence:

- Swift package and simulator UI tests pass for a recorded commit SHA.
- Record actual compiler, SDK, runtime and generator versions; pin the validated Xcode/runtime while retaining the checked generator archive/checksum.
- Review simulator screenshots and accessibility labels; configure branch rules if supported by the repository plan.

## [EV-002] Validate one BLE adapter and vehicle protocol

Complete the hardware feasibility experiment for one exact iPhone/adapter/EV tuple. The Enyaq and OBDLink CX are candidates only.

Completion evidence:

- Obtain documented third-party GATT/transport access and legitimate read-only SoC request/decoder provenance.
- Record stationary GATT/session evidence, metric meaning and synchronized dashboard comparisons.
- Complete a hardware report with failures and unknowns; do not mark unsupported or untested tuples verified.

## [EV-003] Implement a replay-tested Bluetooth diagnostic session

Separate Core Bluetooth effects, adapter transport and serialized diagnostic session. Preserve explicit user start/stop and bounded resource use.

Completion evidence:

- Handle permission/power/reset, connect failure, selection, notification fragmentation, timeout and cancellation.
- One request in flight; allowlisted requests only; bounded buffers, retries and poll rate.
- Late callbacks and reconnect buffers cannot update the wrong session; no traffic after stop.
- Replay checks pass and a physical adapter session matches its documented transport.

## [EV-004] Ship the first read-only SoC vertical slice

Implement the verified vehicle profile, normalize SoC and timestamps, and show live/manual/stale states without hiding source provenance.

Completion evidence:

- Decoder preserves dashboard-vs-BMS semantics and validates range/units/profile version.
- Replay fixtures cover success, malformed/unsupported response, wrong vehicle and invalid scaling.
- Physical SoC comparison, foreground freshness and reconnect targets are measured and reported.
- Unknown/stale states and explicit manual fallback work; compatibility record references a completed report.

## [EV-005] Characterize background, restoration and vehicle sleep

Test supported lifecycle behavior before advertising background battery telemetry. Implement only capabilities justified by physical evidence.

Completion evidence:

- Report locked/background, range loss, Bluetooth toggle, system termination, user force-quit and relaunch results.
- Evaluate current iOS background APIs and the iOS 26 Live Activity option separately from minimum-OS behavior.
- Measure vehicle/adapter sleep and 12V impact, including explicit stop; no unsupported permanent-polling claim.
- Advertised conditions and compatibility records match measured results.

## [EV-006] Integrate a licensed UK charger data feed

Select a provider through data coverage/licensing tests and add charger map/search with provenance-aware tariff and availability states.

Completion evidence:

- Record coverage, data rights, auth, quotas, caching and freshness terms.
- Normalize connectors, power, access, price/payment method, VAT/session/idle fees and timestamps.
- Contract fixtures cover outages, unknown/stale availability, missing prices and rate limits.
- Map/search UX and representative live UK data checks pass without invented values.

## [EV-007] Implement deterministic route and charging-stop planning

Extend the energy experiment into a planner with real routes, usable capacity, consumption uncertainty, charger constraints and charge curves.

Completion evidence:

- Golden scenarios cover reserve, impossible legs, unavailable stops, unit conversion and charging taper.
- Return assumptions, feasible alternatives and time/cost/arrival ranges; do not ask the model to do reserve math.
- Replan on meaningful source/route changes with cancellation and debounce.
- Compare predictions to measured pilot trips and document limitations.

## [EV-008] Build the provider and assistant backend contracts

Add a small backend with versioned schemas, scoped user sessions, secure secret storage and typed read-only tool endpoints.

Completion evidence:

- Provider/model credentials stay server-side; iOS session credentials use Keychain.
- OpenAPI/JSON Schema contracts validate units, timestamps, identity and bounded inputs.
- Contract tests exercise auth, revocation, quota/backoff, errors, redaction and deletion.
- Routine PR CI uses fixtures without production credentials.

## [EV-009] Add optional cloud vehicle telemetry

Choose an aggregator through exact-model coverage and terms evidence, implement OAuth linking, and reconcile local/cloud/manual telemetry.

Completion evidence:

- Demonstrate SoC read scope for the exact model and region using provider evidence; broader coverage remains qualified.
- Keep original observation time; reject wrong-vehicle, future and age-unknown readings for live use.
- Test refresh/revocation, offline/cache, stale cloud, 429 and source changes.
- Unlink/delete removes credentials and linked data as documented.

## [EV-010] Implement the AI charging assistant with evaluated tools

Implement bounded model interaction around typed deterministic tools and user-visible, sourced recommendations.

Completion evidence:

- Tools are scoped and recommendation-only; no arbitrary diagnostics, purchases or vehicle controls.
- At least 40 versioned evaluation cases cover degraded, unknown, malicious and infeasible inputs.
- Release set has zero fabricated battery/price/availability facts or vehicle-command attempts.
- Streaming, cancellation, time/tool/spend budgets and safe unknown-state UX pass.

## [EV-011] Configure bounded issue-to-PR agent execution

Select a supported executor and implement explicitly triggered, isolated runs with evidence-backed repair/review and a private hardware gate.

Completion evidence:

- Trigger only from authorized tasks; create an isolated branch/worktree and record the input SHA.
- Set time/tool/token/spend budgets and typed blocked/failed/ready outcomes.
- Attach commands, results, screenshots, review evidence and resulting SHA to draft PRs.
- Untrusted PRs receive no provider/signing/model/lab credentials; no automatic gate waiver.

## [EV-012] Deliver a physically validated TestFlight beta

Complete product gates for the advertised local/manual charging assistant, sign and distribute a beta when Apple account access and distribution are authorized.

Completion evidence:

- Applicable domain, replay, contracts, UI and AI evaluation checks are green.
- Every advertised hardware tuple and lifecycle condition has measured evidence.
- Privacy/disclosures, accessibility, onboarding, deletion/revocation, failure recovery and install/upgrade checks pass.
- Attach signed archive provenance, beta report, support matrix and known limits; cloud support is optional unless included in advertised scope.

## Import after repository creation

The structured source is `.github/backlog.json`. Preview with:

```bash
python3 scripts/import-backlog.py
```

Once the remote repo exists and GitHub CLI is authenticated, explicitly create missing issues with:

```bash
python3 scripts/import-backlog.py --repository errordeveloper/ev-charging-assistant-ios --apply
```

The importer skips an existing issue with the exact prepared title. It does not assign people, launch agents, add labels, create milestones, or change repository rules.
