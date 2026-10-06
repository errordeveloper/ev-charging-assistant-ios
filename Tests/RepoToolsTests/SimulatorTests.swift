import Foundation
import Testing
@testable import RepoToolsSupport

@Test func selectsAvailableIPhoneFromNewestNumericIOSVersion() throws {
    let data = Data(#"""
    {"devices": {
      "com.apple.CoreSimulator.SimRuntime.iOS-26-2": [
        {"name":"iPhone Old","udid":"old","isAvailable":true}],
      "com.apple.CoreSimulator.SimRuntime.iOS-26-10": [
        {"name":"iPhone Unavailable","udid":"unavailable","isAvailable":false},
        {"name":"iPad","udid":"ipad","isAvailable":true},
        {"name":"iPhone New","udid":"new","isAvailable":true}],
      "com.apple.CoreSimulator.SimRuntime.tvOS-99-0": [
        {"name":"iPhone Other Platform","udid":"other","isAvailable":true}]
    }}
    """#.utf8)
    #expect(try SimulatorSelector.select(from: data) == "new")
}

@Test func emptyAndMalformedInventoriesFail() {
    #expect(throws: (any Error).self) { try SimulatorSelector.select(from: Data(#"{"devices":{}}"#.utf8)) }
    #expect(throws: (any Error).self) { try SimulatorSelector.select(from: Data("invalid".utf8)) }
}
