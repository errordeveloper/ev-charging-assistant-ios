import EVCore
import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var reading: BatteryReading?
    @Published private(set) var estimate: EnergyEstimate?
    @Published private(set) var message: String?

    func setBattery(percent: Double, source: TelemetrySource, now: Date = .now) {
        do {
            reading = try BatteryReading(
                vehicleID: source == .demo ? "demo-vehicle" : "manual-vehicle",
                stateOfCharge: StateOfCharge(percent: percent), observedAt: now, source: source
            )
            estimate = nil
            message = nil
        } catch {
            message = "Enter a battery percentage between 0 and 100."
        }
    }

    func calculate(distanceKM: Double, consumption: Double, capacity: Double, now: Date = .now) {
        guard let reading, reading.isFresh(at: now) else {
            estimate = nil
            message = "Update the battery reading before estimating a trip."
            return
        }
        do {
            estimate = try EnergyEstimator.estimate(
                distanceKM: distanceKM, consumptionKWhPer100KM: consumption,
                usableCapacityKWh: capacity, departure: reading.stateOfCharge,
                reserve: StateOfCharge(percent: 10)
            )
            message = nil
        } catch {
            estimate = nil
            message = "Check distance, consumption, and usable battery capacity."
        }
    }
}
