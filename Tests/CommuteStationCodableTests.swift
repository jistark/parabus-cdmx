import Foundation
import Testing
@testable import ParabusCore

/// CommuteStation was changed (REVIEW MED-10) from required `latitude`/`longitude`
/// (with a default `0.0` sentinel) to `Double?`. A custom `init(from:)` maps
/// encoded zeros to nil so existing CommuteSchedule payloads in UserDefaults
/// keep their original `hasCoordinates` semantics after upgrade.
@Suite("CommuteStation Codable Tests")
struct CommuteStationCodableTests {

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    // MARK: - Backward-compat decoding

    @Test("legacy {lat: 0.0, lon: 0.0} payload decodes with both nil")
    func legacyZeroPair() throws {
        let json = """
        {"id":"1_14","name":"Insurgentes","lineNumber":"1","latitude":0.0,"longitude":0.0}
        """.data(using: .utf8)!

        let station = try Self.decoder.decode(CommuteStation.self, from: json)

        #expect(station.latitude == nil)
        #expect(station.longitude == nil)
        #expect(station.hasCoordinates == false)
    }

    @Test("legacy mixed payload — only latitude zero — decodes to (nil, real)")
    func legacyMixedLatZero() throws {
        let json = """
        {"id":"1_14","name":"Insurgentes","lineNumber":"1","latitude":0.0,"longitude":-99.1623}
        """.data(using: .utf8)!

        let station = try Self.decoder.decode(CommuteStation.self, from: json)

        #expect(station.latitude == nil)
        #expect(station.longitude == -99.1623)
        // hasCoordinates requires BOTH non-nil
        #expect(station.hasCoordinates == false)
    }

    @Test("real coordinates pass through to non-nil")
    func realCoordinates() throws {
        let json = """
        {"id":"1_14","name":"Insurgentes","lineNumber":"1","latitude":19.4262,"longitude":-99.1623}
        """.data(using: .utf8)!

        let station = try Self.decoder.decode(CommuteStation.self, from: json)

        #expect(station.latitude == 19.4262)
        #expect(station.longitude == -99.1623)
        #expect(station.hasCoordinates == true)
    }

    @Test("missing lat/lon fields decode to nil")
    func missingCoordinateFields() throws {
        let json = """
        {"id":"1_14","name":"Insurgentes","lineNumber":"1"}
        """.data(using: .utf8)!

        let station = try Self.decoder.decode(CommuteStation.self, from: json)

        #expect(station.latitude == nil)
        #expect(station.longitude == nil)
        #expect(station.hasCoordinates == false)
    }

    // MARK: - Roundtrip

    @Test("roundtrip preserves nil coordinates")
    func roundtripNilCoordinates() throws {
        let original = CommuteStation(
            id: "1_14",
            name: "Insurgentes",
            lineNumber: "1",
            latitude: nil,
            longitude: nil
        )

        let data = try Self.encoder.encode(original)
        let decoded = try Self.decoder.decode(CommuteStation.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.latitude == nil)
        #expect(decoded.longitude == nil)
        #expect(decoded.hasCoordinates == false)
    }

    @Test("roundtrip preserves real coordinates")
    func roundtripRealCoordinates() throws {
        let original = CommuteStation(
            id: "1_14",
            name: "Insurgentes",
            lineNumber: "1",
            latitude: 19.4262,
            longitude: -99.1623
        )

        let data = try Self.encoder.encode(original)
        let decoded = try Self.decoder.decode(CommuteStation.self, from: data)

        #expect(decoded.latitude == 19.4262)
        #expect(decoded.longitude == -99.1623)
        #expect(decoded.hasCoordinates == true)
    }
}
