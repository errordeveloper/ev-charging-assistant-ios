import AVFAudio
import Combine
import ExternalAccessory
import Foundation

struct InspectedAccessory: Identifiable {
    let id: Int
    let name: String
    let manufacturer: String
    let model: String
    let firmware: String
    let hardware: String
    let serial: String
    let connected: Bool
    let protocols: [String]
}

struct InspectedAudioPort: Identifiable {
    let id: Int
    let direction: String
    let name: String
    let type: String
    let uid: String
    let channels: Int
    let isCarAudio: Bool
}

struct AccessoryInspection {
    let observedAt: Date
    let accessories: [InspectedAccessory]
    let audioPorts: [InspectedAudioPort]
    let declaredProtocols: [String]
    let isFixture: Bool
}

/// Snapshot-only inspection. Never opens a session, configures audio, or writes to hardware.
@MainActor
final class AccessoryInspector: ObservableObject {
    @Published private(set) var snapshot: AccessoryInspection?
    private var fixtureRefreshCount = 0

    func refresh() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uitesting") {
            // UI automation cannot inspect real accessories, even if launched on a phone.
            let populated = ProcessInfo.processInfo.arguments.contains("-accessory-fixture")
                && fixtureRefreshCount == 0
            fixtureRefreshCount += 1
            snapshot = AccessoryInspection(
                observedAt: .now,
                accessories: populated ? [InspectedAccessory(
                    id: 1, name: "Fixture head unit", manufacturer: "Example manufacturer",
                    model: "Fixture model", firmware: "1.0", hardware: "A",
                    serial: "FIXTURE-SERIAL", connected: true,
                    protocols: ["com.example.inspection.fixture"]
                )] : [],
                audioPorts: [], declaredProtocols: [], isFixture: true
            )
            return
        }
        #endif

        let accessories = EAAccessoryManager.shared().connectedAccessories.map { accessory in
            InspectedAccessory(
                id: accessory.connectionID, name: accessory.name,
                manufacturer: accessory.manufacturer, model: accessory.modelNumber,
                firmware: accessory.firmwareRevision, hardware: accessory.hardwareRevision,
                serial: accessory.serialNumber, connected: accessory.isConnected,
                protocols: accessory.protocolStrings.sorted()
            )
        }.sorted { $0.id < $1.id }
        let route = AVAudioSession.sharedInstance().currentRoute
        let ports = route.inputs.map { ("Input", $0) } + route.outputs.map { ("Output", $0) }
        snapshot = AccessoryInspection(
            observedAt: .now, accessories: accessories,
            audioPorts: ports.enumerated().map { index, entry in
                InspectedAudioPort(
                    id: index, direction: entry.0, name: entry.1.portName,
                    type: entry.1.portType.rawValue, uid: entry.1.uid,
                    channels: entry.1.channels?.count ?? 0,
                    isCarAudio: entry.1.portType == .carAudio
                )
            },
            declaredProtocols: (Bundle.main.object(forInfoDictionaryKey:
                "UISupportedExternalAccessoryProtocols") as? [String] ?? []).sorted(),
            isFixture: false
        )
    }

    func clear() {
        snapshot = nil
    }
}
