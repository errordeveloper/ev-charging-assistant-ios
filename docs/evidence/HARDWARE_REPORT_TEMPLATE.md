# Hardware validation report

Status: NOT EXECUTED. Copy this template for an actual test; do not mark support without measured evidence.

| Field | Recorded value |
|---|---|
| Report ID/date/tester | |
| App commit SHA and build | |
| Phone and iOS | |
| Adapter model/firmware | |
| Vehicle make/model/year/software | |
| Profile ID/version and protocol provenance | |
| Metric meaning: display/BMS/other | |
| GATT UUIDs/properties/pairing evidence | |
| Approved request allowlist and poll limit | |
| Conditions and session duration | |
| Sample count, latency p50/p95, discrepancy | |
| Reconnect sample count and p50/p95 | |
| Locked/background/system termination/force-quit results | |
| Vehicle sleep and 12V measurements | |
| Explicit stop and no-traffic result | |
| Source licenses/permission for fixtures | |
| Private evidence location and sanitized fixture paths | |
| Failures, unknowns, and limits | |
| Supported tuple/conditions, if accepted | |

Do not put VINs, user routes, raw personal Bluetooth IDs, credentials, or identifying device names in the committed report. Private originals may be referenced by an access-controlled evidence ID.

## Results

| Scenario | Expected target | Actual result | Pass/fail/not run | Evidence ID |
|---|---|---|---|---|
| Foreground SoC | Documented metric; accurate and fresh | | NOT RUN | |
| Disconnect/reconnect | Visible loss/staleness and bounded recovery | | NOT RUN | |
| Bluetooth disabled/permission revoked | Clear recoverable state | | NOT RUN | |
| Locked/background | Characterize supported delivery, no assumptions | | NOT RUN | |
| App lifecycle | Characterize relaunch and termination limits | | NOT RUN | |
| Vehicle charging/asleep | Correct state and no unwanted wake loop | | NOT RUN | |
| User stops | No diagnostic traffic afterward | | NOT RUN | |
| Passenger-observed trip | Recorded freshness and consumption comparison | | NOT RUN | |

Record targets separately from measurements. A failed or incomplete scenario narrows support rather than being hidden by a successful foreground test.
