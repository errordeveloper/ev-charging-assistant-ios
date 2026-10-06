import Foundation
import Testing
@testable import EVCore

@Test func stateOfChargeRejectsInvalidValuesAndDecode() throws {
    for value in [-1.0, 100.01, .infinity, -.infinity, .nan] {
        #expect(throws: ValidationError.invalidStateOfCharge) {
            try StateOfCharge(percent: value)
        }
    }
    #expect(try StateOfCharge(percent: 0).percent == 0)
    #expect(try StateOfCharge(percent: 100).percent == 100)
    #expect(throws: ValidationError.invalidStateOfCharge) {
        try JSONDecoder().decode(StateOfCharge.self, from: Data("101".utf8))
    }
}

@Test func selectionRejectsStaleFutureWrongVehicleAndDemoReadings() throws {
    let now = Date(timeIntervalSince1970: 1_000)
    func reading(_ source: TelemetrySource, age: TimeInterval,
                 vehicle: String = "test-car") throws -> BatteryReading {
        try BatteryReading(vehicleID: vehicle, stateOfCharge: StateOfCharge(percent: 65),
                           observedAt: now.addingTimeInterval(-age), source: source)
    }
    let staleBLE = try reading(.bluetooth, age: 31)
    let cloud = try reading(.cloud, age: 20)
    let futureBLE = try reading(.bluetooth, age: -10)
    let wrongCar = try reading(.bluetooth, age: 0, vehicle: "other-car")
    let demo = try reading(.demo, age: 0)
    #expect(TelemetrySelector.select([staleBLE, cloud, futureBLE, wrongCar, demo],
                                   vehicleID: "test-car", at: now) == cloud)
    #expect(TelemetrySelector.select([demo], vehicleID: "test-car", at: now) == nil)
    #expect(TelemetrySelector.select([demo], vehicleID: "test-car", at: now,
                                   allowDemo: true) == demo)
    #expect(TelemetrySelector.select([staleBLE], vehicleID: "test-car", at: now) == nil)
}

@Test func freshBLEWinsAndNewestReadingWinsWithinOneSource() throws {
    let now = Date(timeIntervalSince1970: 1_000)
    let soc = try StateOfCharge(percent: 55)
    let olderBLE = try BatteryReading(vehicleID: "v", stateOfCharge: soc,
                                     observedAt: now.addingTimeInterval(-10), source: .bluetooth)
    let newerBLE = try BatteryReading(vehicleID: "v", stateOfCharge: soc,
                                     observedAt: now.addingTimeInterval(-5), source: .bluetooth)
    let cloud = try BatteryReading(vehicleID: "v", stateOfCharge: soc,
                                  observedAt: now, source: .cloud)
    #expect(TelemetrySelector.select([cloud, olderBLE, newerBLE], vehicleID: "v", at: now) == newerBLE)
    #expect(olderBLE.isFresh(at: now.addingTimeInterval(20)))
    #expect(!olderBLE.isFresh(at: now.addingTimeInterval(21)))
    #expect(!olderBLE.isFresh(at: now, maxAge: -1))
}

@Test func readingDecodeUsesTheSameValidationAsConstruction() {
    let json = Data(#"{"vehicleID":" ","stateOfCharge":55,"observedAt":0,"source":"cloud"}"#.utf8)
    #expect(throws: ValidationError.invalidVehicleID) {
        try JSONDecoder().decode(BatteryReading.self, from: json)
    }
}
