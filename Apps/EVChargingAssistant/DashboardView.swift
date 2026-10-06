import SwiftUI
import EVCore

struct DashboardView: View {
    @StateObject private var model = AppModel()
    @StateObject private var bluetooth = BluetoothScanner()
    @Environment(\.scenePhase) private var scenePhase
    @State private var percent = 65.0
    @State private var distanceKM = 100.0
    @State private var consumption = 18.0
    @State private var usableCapacity = 77.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Battery") {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if let reading = model.reading {
                            Text("\(reading.stateOfCharge.percent, specifier: "%.0f")%")
                                .font(.largeTitle)
                                .accessibilityIdentifier("batteryPercent")
                            Text(reading.source == .demo ? "Demo battery" : "Manual battery")
                                .accessibilityIdentifier("batterySource")
                            Text(reading.isFresh(at: context.date) ? "Recent reading" : "Stale reading — update required")
                            Text("Updated \(reading.observedAt.formatted(date: .omitted, time: .standard))")
                        } else {
                            Text("No battery reading")
                                .accessibilityIdentifier("batteryUnavailable")
                        }
                    }
                    Slider(value: $percent, in: 0...100, step: 1) {
                        Text("Manual battery percentage")
                    }
                    Text("Manual input: \(percent, specifier: "%.0f")%")
                    Button("Use manual battery") {
                        model.setBattery(percent: percent, source: .manual)
                    }.accessibilityIdentifier("manualBattery")
                    Button("Load demo battery") {
                        model.setBattery(percent: 65, source: .demo)
                    }.accessibilityIdentifier("loadDemo")
                }

                Section("Bluetooth discovery") {
                    Text(bluetooth.status)
                    Button(bluetooth.isScanning ? "Stop discovery" : "Discover BLE devices") {
                        if bluetooth.isScanning { bluetooth.stop() } else { bluetooth.start() }
                    }.accessibilityIdentifier("discoverBLE")
                    ForEach(bluetooth.devices) { device in
                        VStack(alignment: .leading) {
                            Text(device.name)
                            Text("Identity unverified · \(device.rssi) dBm")
                                .font(.caption)
                        }
                    }
                    Text("Battery telemetry needs a validated adapter and vehicle profile.")
                        .font(.caption)
                }

                Section("Trip energy experiment") {
                    LabeledContent("Distance (km)") {
                        TextField("km", value: $distanceKM, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    LabeledContent("Consumption (kWh/100 km)") {
                        TextField("kWh/100 km", value: $consumption, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    LabeledContent("Usable capacity (kWh)") {
                        TextField("kWh", value: $usableCapacity, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    Button("Estimate trip energy") {
                        model.calculate(distanceKM: distanceKM, consumption: consumption, capacity: usableCapacity)
                    }.disabled(model.reading == nil)
                        .accessibilityIdentifier("estimateTrip")
                    if let estimate = model.estimate {
                        Text("Modeled arrival: \(estimate.arrivalPercent, specifier: "%.1f")%")
                            .accessibilityIdentifier("arrivalEstimate")
                        Text(estimate.meetsReserve ? "Meets the modeled 10% reserve" : "Below the modeled 10% reserve")
                        Text("Recalculate after changing inputs. This estimate uses constant consumption.")
                            .font(.caption)
                    }
                    if let message = model.message {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("EV Charging Assistant")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { bluetooth.stop() }
        }
    }
}
