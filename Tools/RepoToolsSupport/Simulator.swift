import Foundation

public enum SimulatorSelector {
    private struct Inventory: Decodable {
        var devices: [String: [Device]]
    }
    private struct Device: Decodable {
        var name: String
        var udid: String
        var isAvailable: Bool?
    }

    public static func select(from data: Data) throws -> String {
        let devices = try JSONDecoder().decode(Inventory.self, from: data).devices
        let runtimes = devices.keys.filter { $0.contains(".iOS-") }.sorted {
            $0.compare($1, options: .numeric) == .orderedDescending
        }
        for runtime in runtimes {
            if let device = devices[runtime]?.first(where: {
                $0.isAvailable == true && $0.name.hasPrefix("iPhone") && !$0.udid.isEmpty
            }) { return device.udid }
        }
        throw ToolError("No available iPhone simulator; install an iOS runtime in Xcode.")
    }
}
