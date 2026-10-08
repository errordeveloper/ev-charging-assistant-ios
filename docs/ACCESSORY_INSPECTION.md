# External Accessory inspection

## Task and acceptance criteria

User-requested feasibility task, 2026-10-08: inspect what the public iOS APIs expose when an iPhone connects to a vehicle. This is independent of EV-002's BLE adapter protocol gate.

- Show an explicit, timestamped snapshot of accessories exposed to this app: name, manufacturer, model, firmware, hardware, connection state and protocol names.
- Show current audio route inputs and outputs as connection clues, without activating or changing the audio session. A car-audio route is not proof of accessible telemetry; its absence does not rule out CarPlay.
- Allow manual refresh; replace previous results so disconnected accessories disappear. Clear snapshots when the screen leaves the foreground.
- Hide accessory serial numbers, connection IDs and audio port IDs unless explicitly revealed. Keep snapshots in memory, with no logs, export, persistence or network transmission.
- Show empty and restricted visibility honestly. Keep inspection independent from battery readings and demo/manual inputs.
- Exercise the screen using isolated synthetic UI fixtures and inspect simulator screenshots. Require a separate physical-device report before making hardware claims.

Non-goals: raw iAP2 access, battery decoding, opening EASession streams, guessed protocol declarations, CarPlay entitlements, pairing, network/port scans, background monitoring, vehicle commands or protocol support claims.

## Physical check

1. Install this branch on an iPhone and open **Inspect accessories** from the dashboard toolbar.
2. Connect the phone using the vehicle's normal wired or wireless CarPlay setup and tap Refresh in the app.
3. Check accessory metadata, visible protocol names and the audio route. Empty results mean only that iOS exposes no accessories to this app in this configuration.
4. Disconnect, refresh, and confirm that previously visible accessories disappear. Leave and reopen the screen to collect a fresh snapshot.
5. Record exact vehicle/model year/software, iPhone/iOS and connection method in a private hardware report. Redact names and identifiers before sharing screenshots. Do not commit private captures.

This app declares no supported accessory protocols because none are documented for the target vehicle. That can limit visibility. Finding a protocol name does not establish authorization, message format or battery support. An accessory may initially report no protocols while authentication is incomplete.

## Evidence checked 2026-10-08

- [EAAccessory](https://developer.apple.com/documentation/externalaccessory/eaaccessory): metadata and currently available protocol names.
- [Connected accessories](https://developer.apple.com/documentation/externalaccessory/eaaccessorymanager/connectedaccessories): only accessories connected and available to the app; results can change.
- [Supported accessory protocols](https://developer.apple.com/documentation/bundleresources/information-property-list/uisupportedexternalaccessoryprotocols): documented protocol names belong in Info.plist when an app implements them.
- [Audio routing](https://developer.apple.com/documentation/avfaudio/audio-routing): inspect current input/output routes.
- Installed iOS 27 SDK ExternalAccessory headers: EASession exposes streams for an accessory protocol, not a raw CarPlay iAP2 control-message subscription.

Software checks do not validate a vehicle. No physical accessory or CarPlay battery access is verified by this task.

## Software validation, 2026-10-08

- `swift test`: 25 tests passed (15 repository-tool tests and 10 EVCore tests).
- `swift run repo-tools validate`: passed.
- `.tools/xcodegen/bin/xcodegen generate`: passed.
- `git diff --check`: passed.
- App build and four UI behaviors verified on the iPhone 18 Pro simulator, iOS 27.0. The final full-suite run passed empty-state/background clearing, manual input/trip estimation and demo labeling. The identifier test initially failed because the automation tapped the switch label; its targeted rerun passed after targeting the control. No tests were skipped or disabled.

Full-suite command:

```bash
xcodebuild -project EVChargingAssistant.xcodeproj -scheme EVChargingAssistant \
  -destination 'platform=iOS Simulator,id=DCA96F20-4A04-4327-9D1A-C7F302E13652' \
  -derivedDataPath artifacts/DerivedData -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -resultBundlePath artifacts/AccessoryInspection-Verified.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

The passing targeted rerun used the same command with result path `artifacts/AccessoryInspection-Reveal.xcresult` and `-only-testing:EVChargingAssistantUITests/DashboardUITests/testAccessoryInspectionRefreshRemovesDisconnectedFixture`. The latter covers metadata/protocol visibility, identifiers hidden by default and revealed on request, removal on refresh after disconnect, and no battery reading created by inspection. Verbose system diagnostics were disabled after slow failure collection; assertions and screenshot attachments remained enabled.

Reviewed screenshots: [empty fixture](evidence/accessory-inspection-empty.png) and [expanded fixture](evidence/accessory-inspection-details.png). Both are synthetic simulator UI-test captures, not real accessory data or hardware evidence. The expanded screenshot was captured before identifiers were revealed. Screenshots came from the full-suite run; the subsequent change only corrected the test's tap target.

Not run: physical iPhone/vehicle inspection, signing/distribution, or protocol sessions. `scripts/test-ios.sh` was not separately rerun; its XcodeGen/build/UI steps were exercised by the explicit commands above.
