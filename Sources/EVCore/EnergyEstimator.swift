import Foundation

public struct EnergyEstimate: Equatable, Sendable {
    /// A simple point estimate; not a route feasibility guarantee.
    public let tripEnergyKWh: Double
    public let arrivalPercent: Double
    public let meetsReserve: Bool
}

public enum EnergyEstimator {
    /// Usable capacity, not advertised/gross capacity. A negative arrival means
    /// the modeled trip exceeds available energy; do not clamp it to zero.
    public static func estimate(distanceKM: Double, consumptionKWhPer100KM: Double,
                                usableCapacityKWh: Double, departure: StateOfCharge,
                                reserve: StateOfCharge) throws -> EnergyEstimate {
        guard distanceKM.isFinite, distanceKM >= 0,
              consumptionKWhPer100KM.isFinite, consumptionKWhPer100KM > 0,
              usableCapacityKWh.isFinite, usableCapacityKWh > 0 else {
            throw ValidationError.invalidEnergyInput
        }
        let energy = distanceKM * consumptionKWhPer100KM / 100
        let arrival = departure.percent - energy / usableCapacityKWh * 100
        guard energy.isFinite, arrival.isFinite else {
            throw ValidationError.invalidEnergyInput
        }
        return EnergyEstimate(tripEnergyKWh: energy, arrivalPercent: arrival,
                              meetsReserve: arrival >= reserve.percent)
    }
}
