import SwiftUI

struct AccessoryInspectionView: View {
    @StateObject private var inspector = AccessoryInspector()
    @Environment(\.scenePhase) private var scenePhase
    @State private var revealIdentifiers = false
    @State private var expandedAccessories: Set<Int> = []

    var body: some View {
        List {
            Section {
                Text("Connect your car normally, then refresh to see what iOS makes available to this app.")
                Text("Inspection only — no battery reading or vehicle commands.")
                    .font(.caption)
                if let snapshot = inspector.snapshot {
                    Text("Checked \(snapshot.observedAt.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption)
                    if snapshot.isFixture {
                        Text("Inspection fixture — no hardware evidence")
                    }
                    #if targetEnvironment(simulator)
                    Text("Simulator — physical accessory access is not validated")
                        .font(.caption)
                    #endif
                }
            }

            if let snapshot = inspector.snapshot {
                Section("Accessories visible to this app (\(snapshot.accessories.count))") {
                    if snapshot.accessories.isEmpty {
                        Text("No accessories exposed to this app")
                            .accessibilityIdentifier("noExposedAccessories")
                    }
                    ForEach(snapshot.accessories) { accessory in
                        DisclosureGroup(isExpanded: Binding(
                            get: { expandedAccessories.contains(accessory.id) },
                            set: { expanded in
                                if expanded { expandedAccessories.insert(accessory.id) }
                                else { expandedAccessories.remove(accessory.id) }
                            }
                        )) {
                            accessoryDetails(accessory)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(available(accessory.name))
                                Text("\(available(accessory.manufacturer)) · \(accessory.protocols.count) visible protocols")
                                    .font(.caption)
                            }
                        }
                    }
                    Text("This is not a list of all paired Bluetooth devices. Empty results do not rule out CarPlay or iAP2. Visibility depends on iOS, accessory authentication and app protocol support.")
                        .font(.caption)
                }

                Section("CarPlay and audio clues") {
                    Text(snapshot.audioPorts.contains(where: \.isCarAudio)
                         ? "Car-audio route reported by iOS"
                         : "No car-audio route reported in this snapshot")
                    Text("Audio routes are clues, not a CarPlay connection test. This app does not activate an audio session; an existing CarPlay connection may not appear here.")
                        .font(.caption)
                    ForEach(snapshot.audioPorts) { port in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(port.direction): \(available(port.name))")
                            Text("Type: \(port.type) · Channels: \(port.channels)")
                                .font(.caption)
                            if revealIdentifiers {
                                Text("Port ID: \(available(port.uid))").font(.caption.monospaced())
                            }
                        }
                    }
                    Text("Gear, parked state and battery level: not available through this inspector.")
                        .font(.caption)
                }

                Section("App configuration") {
                    Text("iOS \(UIDevice.current.systemVersion)")
                    Text("App \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"))")
                    if snapshot.declaredProtocols.isEmpty {
                        Text("No accessory protocols declared by this app")
                    } else {
                        ForEach(snapshot.declaredProtocols, id: \.self) { Text($0) }
                    }
                    Text("A visible protocol name does not establish permission or a battery data format. No raw CarPlay iAP2 messages are exposed here.")
                        .font(.caption)
                }
            } else {
                Text("Inspection cleared. Refresh while the app is active.")
            }

            Section("Privacy") {
                Toggle("Reveal identifiers", isOn: $revealIdentifiers)
                    .accessibilityIdentifier("revealAccessoryIdentifiers")
                Text("Results stay in memory and clear when you leave this screen or the app becomes inactive. Names and identifiers can identify your equipment; redact them before sharing screenshots.")
                    .font(.caption)
            }
        }
        .navigationTitle("Accessory inspection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Refresh") { inspector.refresh() }
                .disabled(scenePhase != .active)
                .accessibilityIdentifier("refreshAccessories")
        }
        .onAppear { if scenePhase == .active { inspector.refresh() } }
        .onDisappear { clear() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { clear() }
        }
    }

    private func accessoryDetails(_ accessory: InspectedAccessory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                detail("Name", accessory.name)
                detail("Manufacturer", accessory.manufacturer)
                detail("Model", accessory.model)
                detail("Firmware", accessory.firmware)
                detail("Hardware", accessory.hardware)
                detail("Connection at inspection", accessory.connected ? "Connected" : "Disconnected")
                if revealIdentifiers {
                    detail("Serial number", accessory.serial)
                    detail("Session connection ID", String(accessory.id))
                }
            }
            Group {
                Text("Visible protocols").font(.headline)
                if accessory.protocols.isEmpty {
                    Text("No protocols exposed in this snapshot. Authentication may still be in progress.")
                }
                ForEach(Array(accessory.protocols.enumerated()), id: \.offset) { _, name in
                    Text(name).font(.body.monospaced()).textSelection(.enabled)
                }
                Text("These are protocol declarations, not decoded messages or verified capabilities.")
                    .font(.caption)
            }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(available(value)).textSelection(.enabled)
        }
    }

    private func available(_ value: String) -> String {
        value.isEmpty ? "Not reported" : value
    }

    private func clear() {
        inspector.clear()
        revealIdentifiers = false
        expandedAccessories.removeAll()
    }
}
