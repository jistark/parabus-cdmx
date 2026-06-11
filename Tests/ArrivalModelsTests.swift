// Tests/ArrivalModelsTests.swift
import Foundation
import Testing
@testable import ParabusCore

@Suite("Arrival models decoding")
struct ArrivalModelsTests {

    @Test func decodesFullRealtimeResponse() throws {
        let json = """
        {
          "serviceActive": true,
          "feedTimestamp": 1750000000,
          "feedAgeSeconds": 12,
          "realtimeStale": false,
          "stop": "S2N",
          "rows": [{
            "serviceId": "L2-regular",
            "line": "2",
            "destination": "Tacubaya",
            "state": "arriving",
            "etaMinutes": null,
            "vehicleId": "MB-1234",
            "source": "realtime"
          }]
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ArrivalsResponse.self, from: json)
        #expect(response.serviceActive)
        #expect(response.feedAgeSeconds == 12)
        #expect(response.rows.count == 1)
        #expect(response.rows[0].state == .arriving)
        #expect(response.rows[0].etaMinutes == nil)
        #expect(response.rows[0].source == .realtime)
    }

    @Test func decodesScheduledFallbackAndStaleFlags() throws {
        let json = """
        {
          "serviceActive": false,
          "feedTimestamp": null,
          "feedAgeSeconds": null,
          "realtimeStale": false,
          "stop": "S2N",
          "rows": [{
            "serviceId": "L2-regular",
            "line": "2",
            "destination": "Tepalcates",
            "state": "scheduled",
            "etaMinutes": 7,
            "vehicleId": null,
            "source": "schedule"
          }]
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ArrivalsResponse.self, from: json)
        #expect(!response.serviceActive)
        #expect(response.rows[0].state == .scheduled)
        #expect(response.rows[0].etaMinutes == 7)
    }

    @Test func unknownStateFailsLoudly() {
        let json = """
        {"serviceActive":true,"feedTimestamp":1,"feedAgeSeconds":1,"realtimeStale":false,"stop":"X","rows":[{"serviceId":"s","line":"1","destination":"d","state":"teleporting","etaMinutes":null,"vehicleId":null,"source":"realtime"}]}
        """.data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(ArrivalsResponse.self, from: json)
        }
    }
}
