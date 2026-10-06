import CoreBluetooth
import Combine
import Foundation

struct NearbyDevice: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
}

/// Foreground discovery only. No peripheral connection, diagnostic requests,
/// vehicle identity, or battery decoding is implemented in this bootstrap.
@MainActor
final class BluetoothScanner: NSObject, ObservableObject, @preconcurrency CBCentralManagerDelegate {
    @Published private(set) var status = "Ready to discover nearby BLE devices"
    @Published private(set) var devices: [NearbyDevice] = []
    @Published private(set) var isScanning = false
    private var central: CBCentralManager?
    private var scanRequested = false
    private var stopTask: Task<Void, Never>?

    func start() {
        guard !ProcessInfo.processInfo.arguments.contains("-uitesting") else {
            status = "Bluetooth discovery is disabled for UI tests"
            return
        }
        scanRequested = true
        devices = []
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else {
            updateState()
        }
    }

    func stop() {
        scanRequested = false
        central?.stopScan()
        isScanning = false
        stopTask?.cancel()
        stopTask = nil
        status = "Discovery stopped"
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        updateState()
    }

    private func updateState() {
        guard let central else { return }
        switch central.state {
        case .poweredOn:
            status = "Bluetooth is on"
            guard scanRequested else { return }
            // An unfiltered scan is a bounded foreground discovery experiment.
            // The supported adapter will later use documented service UUIDs.
            central.scanForPeripherals(withServices: nil,
                                       options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
            isScanning = true
            status = "Discovering for 15 seconds"
            stopTask?.cancel()
            stopTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .seconds(15))
                } catch {
                    return
                }
                self?.stop()
            }
        case .poweredOff: resetScan(status: "Turn on Bluetooth to discover an adapter")
        case .unauthorized: resetScan(status: "Allow Bluetooth access in Settings")
        case .unsupported: resetScan(status: "Bluetooth is unavailable on this device")
        case .resetting: resetScan(status: "Bluetooth is resetting; try again")
        case .unknown: status = "Checking Bluetooth availability"
        @unknown default: resetScan(status: "Bluetooth is unavailable")
        }
    }

    private func resetScan(status: String) {
        scanRequested = false
        isScanning = false
        stopTask?.cancel()
        stopTask = nil
        self.status = status
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name ?? "Unnamed BLE device"
        let device = NearbyDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
    }
}
