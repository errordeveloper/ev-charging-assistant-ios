import Foundation

public enum ValidationError: Error, Equatable {
    case invalidStateOfCharge
    case invalidVehicleID
    case invalidEnergyInput
}

public struct StateOfCharge: Codable, Equatable, Sendable {
    public let percent: Double

    public init(percent: Double) throws {
        guard percent.isFinite, (0...100).contains(percent) else {
            throw ValidationError.invalidStateOfCharge
        }
        self.percent = percent
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(percent: container.decode(Double.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(percent)
    }
}

public enum TelemetrySource: String, Codable, Sendable {
    case bluetooth, cloud, manual, demo

    public var defaultMaxAgeSeconds: TimeInterval {
        switch self {
        case .bluetooth: 30
        case .cloud: 300
        case .manual: 1_800
        case .demo: 60
        }
    }

    fileprivate var priority: Int {
        switch self {
        case .bluetooth: 0
        case .cloud: 1
        case .manual: 2
        case .demo: 3
        }
    }
}

public struct BatteryReading: Codable, Equatable, Sendable {
    public let vehicleID: String
    public let stateOfCharge: StateOfCharge
    public let observedAt: Date
    public let source: TelemetrySource

    public init(vehicleID: String, stateOfCharge: StateOfCharge,
                observedAt: Date, source: TelemetrySource) throws {
        guard !vehicleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.invalidVehicleID
        }
        self.vehicleID = vehicleID
        self.stateOfCharge = stateOfCharge
        self.observedAt = observedAt
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case vehicleID, stateOfCharge, observedAt, source
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            vehicleID: container.decode(String.self, forKey: .vehicleID),
            stateOfCharge: container.decode(StateOfCharge.self, forKey: .stateOfCharge),
            observedAt: container.decode(Date.self, forKey: .observedAt),
            source: container.decode(TelemetrySource.self, forKey: .source)
        )
    }

    public func isFresh(at now: Date, maxAge: TimeInterval? = nil) -> Bool {
        let age = now.timeIntervalSince(observedAt)
        let limit = maxAge ?? source.defaultMaxAgeSeconds
        return age.isFinite && limit.isFinite && limit >= 0 && age >= 0 && age <= limit
    }
}

public enum TelemetrySelector {
    /// Demo data is opt-in and must never substitute for a real vehicle reading.
    public static func select(_ readings: [BatteryReading], vehicleID: String,
                              at now: Date, allowDemo: Bool = false) -> BatteryReading? {
        readings.filter {
            $0.vehicleID == vehicleID && $0.isFresh(at: now)
                && (allowDemo || $0.source != .demo)
        }.sorted {
            if $0.source.priority == $1.source.priority {
                return $0.observedAt > $1.observedAt
            }
            return $0.source.priority < $1.source.priority
        }.first
    }
}
