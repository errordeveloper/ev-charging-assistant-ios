import Testing
@testable import EVCore

@Test func estimateUsesUsableCapacityAndChecksReserve() throws {
    let result = try EnergyEstimator.estimate(
        distanceKM: 100, consumptionKWhPer100KM: 20, usableCapacityKWh: 80,
        departure: StateOfCharge(percent: 60), reserve: StateOfCharge(percent: 10)
    )
    #expect(result.tripEnergyKWh == 20)
    #expect(result.arrivalPercent == 35)
    #expect(result.meetsReserve)
}

@Test func insufficientEnergyRemainsVisible() throws {
    let result = try EnergyEstimator.estimate(
        distanceKM: 300, consumptionKWhPer100KM: 20, usableCapacityKWh: 80,
        departure: StateOfCharge(percent: 50), reserve: StateOfCharge(percent: 10)
    )
    #expect(result.arrivalPercent == -25)
    #expect(!result.meetsReserve)
}

@Test func zeroDistanceAndExactReserveBoundary() throws {
    let result = try EnergyEstimator.estimate(
        distanceKM: 0, consumptionKWhPer100KM: 20, usableCapacityKWh: 80,
        departure: StateOfCharge(percent: 10), reserve: StateOfCharge(percent: 10)
    )
    #expect(result.tripEnergyKWh == 0)
    #expect(result.meetsReserve)
}

@Test func invalidOrOverflowingInputsAreRejected() {
    for distance in [-1.0, .nan, .infinity, Double.greatestFiniteMagnitude] {
        #expect(throws: ValidationError.invalidEnergyInput) {
            try EnergyEstimator.estimate(
                distanceKM: distance, consumptionKWhPer100KM: 20, usableCapacityKWh: 80,
                departure: StateOfCharge(percent: 60), reserve: StateOfCharge(percent: 10)
            )
        }
    }
    #expect(throws: ValidationError.invalidEnergyInput) {
        try EnergyEstimator.estimate(
            distanceKM: 10, consumptionKWhPer100KM: 20, usableCapacityKWh: 0,
            departure: StateOfCharge(percent: 60), reserve: StateOfCharge(percent: 10)
        )
    }
}
