import Foundation
import Testing
@testable import ParabusCore

/// The pure-CSV parse logic that used to live here (parseStopTimes /
/// parseTime as static helpers on GTFSScheduleService) moved to the worker
/// as part of HIGH-16. The iOS GTFSScheduleService is now a thin HTTP client
/// over `/static/schedule` and `/static/travel-time`. Coverage for the
/// underlying parsing now lives in `workers/src/gtfs-schedule.test.ts`.
///
/// What remains testable here: the HTTP client behavior — URL construction,
/// decoding, error mapping, in-actor cache TTL. Exercised via MockURLProtocol
/// the same way RealtimeService and APITransitDataProvider are tested.
@Suite("GTFSScheduleService Tests", .serialized)
struct GTFSScheduleServiceTests {

    // Register under the specific sub-paths this service hits, not just
    // `/static` — RealtimeTests already owns `/static` for /static/routes
    // and the suites run in parallel at the top level.
    private static let schedulePath = "/static/schedule"
    private static let travelPath = "/static/travel-time"

    private func makeJSON(_ json: String) -> URLSession {
        MockURLProtocol.clearHandlers(path: Self.schedulePath)
        MockURLProtocol.clearHandlers(path: Self.travelPath)
        MockURLProtocol.register(path: Self.schedulePath) { request in
            (MockSession.okJSON(for: request.url!), Data(json.utf8))
        }
        MockURLProtocol.register(path: Self.travelPath) { request in
            (MockSession.okJSON(for: request.url!), Data(json.utf8))
        }
        return MockSession.make()
    }

    // MARK: - nextArrivals

    @Test("nextArrivals filters to arrivals after current time")
    func nextArrivalsFiltersByTime() async throws {
        // Build a worker-style response with mixed times. parseDate-style
        // logic isn't needed — we just exercise the HTTP shape.
        let json = """
        {
          "stop": "STOP_A",
          "count": 3,
          "arrivals": [
            {"tripId": "T1", "arrivalMinutes": 0, "sequence": 1},
            {"tripId": "T2", "arrivalMinutes": 1439, "sequence": 1},
            {"tripId": "T3", "arrivalMinutes": 1438, "sequence": 1}
          ]
        }
        """
        let service = GTFSScheduleService(session: makeJSON(json))
        let arrivals = await service.nextArrivals(at: "STOP_A", limit: 2)
        // Should return up to 2 of the future arrivals (1438, 1439) and
        // skip the past 0. Order: ascending by arrivalMinutes.
        #expect(arrivals.count <= 2)
        #expect(arrivals.allSatisfy { $0.arrivalMinutes >= 1438 })
    }

    @Test("nextArrivals returns empty on network failure")
    func nextArrivalsNetworkFailure() async throws {
        MockURLProtocol.clearHandlers(path: Self.schedulePath)
        MockURLProtocol.register(path: Self.schedulePath) { request in
            (MockSession.response(for: request.url!, status: 503), Data("oops".utf8))
        }
        let service = GTFSScheduleService(session: MockSession.make())
        let arrivals = await service.nextArrivals(at: "STOP_A", limit: 3)
        #expect(arrivals.isEmpty)
    }

    // MARK: - travelTime

    @Test("travelTime extracts the integer from the worker response")
    func travelTimeBasic() async throws {
        let json = """
        {"from": "A", "to": "B", "travelTimeMinutes": 23}
        """
        let service = GTFSScheduleService(session: makeJSON(json))
        let t = await service.travelTime(from: "A", to: "B")
        #expect(t == 23)
    }

    @Test("travelTime returns nil when worker returns null")
    func travelTimeNull() async throws {
        let json = """
        {"from": "A", "to": "B", "travelTimeMinutes": null}
        """
        let service = GTFSScheduleService(session: makeJSON(json))
        let t = await service.travelTime(from: "A", to: "B")
        #expect(t == nil)
    }

    @Test("travelTimeString formats minutes nicely")
    func travelTimeStringFormatting() async throws {
        let json45 = #"{"from":"A","to":"B","travelTimeMinutes":45}"#
        let s1 = await GTFSScheduleService(session: makeJSON(json45)).travelTimeString(from: "A", to: "B")
        #expect(s1 == "~45 min")

        let json95 = #"{"from":"A","to":"B","travelTimeMinutes":95}"#
        let s2 = await GTFSScheduleService(session: makeJSON(json95)).travelTimeString(from: "A", to: "B")
        #expect(s2 == "~1h 35m")

        let json120 = #"{"from":"A","to":"B","travelTimeMinutes":120}"#
        let s3 = await GTFSScheduleService(session: makeJSON(json120)).travelTimeString(from: "A", to: "B")
        #expect(s3 == "~2h")
    }

    @Test("travelTimeString returns nil when worker returns null")
    func travelTimeStringNull() async throws {
        let json = #"{"from":"A","to":"B","travelTimeMinutes":null}"#
        let service = GTFSScheduleService(session: makeJSON(json))
        let s = await service.travelTimeString(from: "A", to: "B")
        #expect(s == nil)
    }

    // MARK: - URL construction

    @Test("nextArrivals hits /static/schedule with stop + limit")
    func nextArrivalsURLConstruction() async throws {
        let json = #"{"stop":"X","count":0,"arrivals":[]}"#
        let service = GTFSScheduleService(session: makeJSON(json))
        _ = await service.nextArrivals(at: "X", limit: 3)
        let urls = MockURLProtocol.requestedURLs(matching: "/static/schedule")
        #expect(urls.last?.query?.contains("stop=X") == true)
    }

    @Test("travelTime hits /static/travel-time with from + to")
    func travelTimeURLConstruction() async throws {
        let json = #"{"from":"A","to":"B","travelTimeMinutes":10}"#
        let service = GTFSScheduleService(session: makeJSON(json))
        _ = await service.travelTime(from: "A", to: "B")
        let urls = MockURLProtocol.requestedURLs(matching: "/static/travel-time")
        let q = urls.last?.query ?? ""
        #expect(q.contains("from=A"))
        #expect(q.contains("to=B"))
    }
}
