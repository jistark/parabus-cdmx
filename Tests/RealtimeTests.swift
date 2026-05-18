import Foundation
import Testing
@testable import ParabusCore

/// All realtime-feed tests live in a single serialized parent suite. Both
/// RealtimeService and RealtimeMapViewModel tests register handlers for
/// `/vehicles` and `/static` via MockURLProtocol — running them in parallel
/// suites caused last-write-wins handler collisions. Serializing the parent
/// (and the child suites inherit `.serialized`) keeps URL stub state stable
/// per test. APITransitDataProvider tests stay in their own parallel suite
/// since they only touch `/status`.
@Suite("Realtime", .serialized)
struct RealtimeTests {

    private static let vehiclesPath = "/vehicles"
    private static let staticPath = "/static"

    private static let emptyFeedJSON = """
    {
      "serviceActive": true,
      "feedTimestamp": 0,
      "decodedAt": "x",
      "count": 0,
      "vehicles": []
    }
    """

    private static let sampleStaticRoutesJSON = """
    {
      "generatedAt": "2026-05-17 14:00:00",
      "count": 2,
      "routes": {
        "100": {"routeId": "100", "line": "1", "longName": "L01a", "color": "D40D0D", "textColor": "FFFFFF"},
        "200": {"routeId": "200", "line": "3", "longName": "L03a", "color": "218D21", "textColor": "FFFFFF"}
      },
      "lineRoutes": {"1": ["100"], "3": ["200"]}
    }
    """

    private static func makeJSONSession(_ json: String) -> URLSession {
        MockURLProtocol.clearHandlers(path: Self.vehiclesPath)
        MockURLProtocol.clearHandlers(path: staticPath)
        MockURLProtocol.register(path: Self.vehiclesPath) { request in
            (MockSession.okJSON(for: request.url!), Data(json.utf8))
        }
        MockURLProtocol.register(path: staticPath) { request in
            (MockSession.okJSON(for: request.url!), Data(sampleStaticRoutesJSON.utf8))
        }
        return MockSession.make()
    }

    private static func makeStatusSession(_ status: Int, body: String) -> URLSession {
        MockURLProtocol.clearHandlers(path: Self.vehiclesPath)
        MockURLProtocol.register(path: Self.vehiclesPath) { request in
            (MockSession.response(for: request.url!, status: status), Data(body.utf8))
        }
        return MockSession.make()
    }

    // ========================================================================
    // MARK: - RealtimeService
    // ========================================================================

    @Suite("RealtimeService")
    struct ServiceTests {

        @Test("decodes a vehicles payload")
        func fetchVehiclesDecodes() async throws {
            let json = """
            {
              "serviceActive": true,
              "feedTimestamp": 1700000000,
              "decodedAt": "2026-05-17T20:00:00.000Z",
              "line": null,
              "filterApplied": false,
              "staticMissing": false,
              "count": 1,
              "vehicles": [
                {
                  "entityId": "ent-1",
                  "tripId": null,
                  "routeId": "19499",
                  "vehicleId": "V42",
                  "vehicleLabel": "Bus 42",
                  "lat": 19.5,
                  "lon": -99.1,
                  "bearing": 90.0,
                  "speed": 12.5,
                  "currentStopSequence": 7,
                  "stopId": "STOP_X",
                  "timestamp": 1700000000
                }
              ]
            }
            """
            let service = RealtimeService(session: makeJSONSession(json))
            let feed = try await service.fetchVehicles()
            #expect(feed.serviceActive == true)
            #expect(feed.count == 1)
            #expect(feed.vehicles.count == 1)
            #expect(feed.vehicles[0].routeId == "19499")
            #expect(feed.vehicles[0].bearing == 90.0)
        }

        @Test("service-inactive response has empty vehicles + serviceActive=false")
        func serviceInactive() async throws {
            let json = """
            {
              "serviceActive": false,
              "feedTimestamp": null,
              "decodedAt": "2026-05-17T05:00:00.000Z",
              "count": null,
              "vehicles": [],
              "message": "Operator tracking system not currently reporting"
            }
            """
            let service = RealtimeService(session: makeJSONSession(json))
            let feed = try await service.fetchVehicles()
            #expect(feed.serviceActive == false)
            #expect(feed.vehicles.isEmpty)
        }

        @Test("line filter appends ?line=N to URL")
        func lineFilterURL() async throws {
            let service = RealtimeService(session: makeJSONSession(emptyFeedJSON))
            _ = try await service.fetchVehicles(line: "3")
            let urls = MockURLProtocol.requestedURLs(matching: vehiclesPath)
            #expect(urls.last?.query?.contains("line=3") == true)
        }

        @Test("fetchStaticRoutes decodes + memoizes for 6h")
        func staticRoutesMemoized() async throws {
            MockURLProtocol.clearHandlers(path: staticPath)
            let counter = Counter()
            MockURLProtocol.register(path: staticPath) { request in
                counter.increment()
                return (MockSession.okJSON(for: request.url!), Data(sampleStaticRoutesJSON.utf8))
            }
            let service = RealtimeService(session: MockSession.make())
            let r1 = try await service.fetchStaticRoutes()
            let r2 = try await service.fetchStaticRoutes()
            #expect(r1.count == 2)
            #expect(r2.count == 2)
            #expect(counter.value == 1, "memoization should have hit only once")
        }

        @Test("429 maps to TransitDataError.networkError")
        func http429() async throws {
            let service = RealtimeService(session: makeStatusSession(429, body: "rate limited"))
            await #expect(throws: TransitDataError.self) {
                _ = try await service.fetchVehicles()
            }
        }

        @Test("503 maps to TransitDataError.networkError")
        func http503() async throws {
            let service = RealtimeService(session: makeStatusSession(503, body: "unavailable"))
            await #expect(throws: TransitDataError.self) {
                _ = try await service.fetchVehicles()
            }
        }

        @Test("malformed JSON maps to TransitDataError.parsingError")
        func parseFailure() async throws {
            let service = RealtimeService(session: makeJSONSession("not valid json {"))
            await #expect(throws: TransitDataError.self) {
                _ = try await service.fetchVehicles()
            }
        }
    }

    // ========================================================================
    // MARK: - RealtimeMapViewModel
    // ========================================================================

    @Suite("RealtimeMapViewModel")
    struct ViewModelTests {

        @Test("startPolling is idempotent — does not spawn parallel loops")
        @MainActor
        func startPollingIdempotent() async throws {
            let counter = Counter()
            let service = Self.makeService(counter: counter, vehiclesJSON: Self.emptyFeedJSON)
            let vm = RealtimeMapViewModel(service: service, pollInterval: .milliseconds(50))
            vm.startPolling()
            vm.startPolling()
            vm.startPolling()
            try await Task.sleep(for: .milliseconds(120))
            vm.stopPolling()
            #expect(counter.value <= 4, "expected ≤4 fetches; got \(counter.value)")
        }

        @Test("stopPolling cancels in-flight refresh")
        @MainActor
        func stopPollingCancels() async throws {
            let counter = Counter()
            let service = Self.makeService(counter: counter, vehiclesJSON: Self.emptyFeedJSON)
            let vm = RealtimeMapViewModel(service: service, pollInterval: .seconds(1))
            vm.startPolling()
            try await Task.sleep(for: .milliseconds(80))
            let baseline = counter.value
            vm.stopPolling()
            try await Task.sleep(for: .milliseconds(300))
            #expect(counter.value == baseline)
        }

        @Test("selectedLine.didSet triggers an immediate refresh")
        @MainActor
        func selectedLineTriggersRefresh() async throws {
            let counter = Counter()
            let service = Self.makeService(counter: counter, vehiclesJSON: Self.emptyFeedJSON)
            let vm = RealtimeMapViewModel(service: service, pollInterval: .seconds(60))
            vm.startPolling()
            try await Task.sleep(for: .milliseconds(80))
            let baseline = counter.value
            vm.selectedLine = "1"
            try await Task.sleep(for: .milliseconds(80))
            vm.stopPolling()
            #expect(counter.value > baseline)
        }

        @Test("setting selectedLine to same value does NOT refetch")
        @MainActor
        func selectedLineSameValueNoRefetch() async throws {
            let counter = Counter()
            let service = Self.makeService(counter: counter, vehiclesJSON: Self.emptyFeedJSON)
            let vm = RealtimeMapViewModel(service: service, pollInterval: .seconds(60))
            vm.startPolling()
            try await Task.sleep(for: .milliseconds(80))
            let baseline = counter.value
            vm.selectedLine = nil
            try await Task.sleep(for: .milliseconds(80))
            vm.stopPolling()
            #expect(counter.value == baseline)
        }

        @Test("fetchOnce populates vehicles and lastUpdated on success")
        @MainActor
        func fetchPopulatesVehicles() async throws {
            let json = """
            {
              "serviceActive": true,
              "feedTimestamp": 1700000000,
              "decodedAt": "2026-05-17T20:00:00.000Z",
              "count": 1,
              "vehicles": [
                {
                  "entityId": "ent-1",
                  "tripId": null, "routeId": "19499",
                  "vehicleId": "V42", "vehicleLabel": "Bus 42",
                  "lat": 19.5, "lon": -99.1,
                  "bearing": 90.0, "speed": 12.5,
                  "currentStopSequence": null, "stopId": null, "timestamp": 1700000000
                }
              ]
            }
            """
            let service = Self.makeService(counter: Counter(), vehiclesJSON: json)
            let vm = RealtimeMapViewModel(service: service, pollInterval: .seconds(60))
            await vm.refresh()
            #expect(vm.vehicles.count == 1)
            #expect(vm.vehicles[0].vehicleId == "V42")
            #expect(vm.lastUpdated != nil)
            #expect(vm.serviceInactive == false)
            #expect(vm.errorMessage == nil)
        }

        @Test("fetchOnce surfaces error on network failure")
        @MainActor
        func fetchSurfacesError() async throws {
            MockURLProtocol.clearHandlers(path: Self.vehiclesPath)
            MockURLProtocol.register(path: Self.vehiclesPath) { request in
                (MockSession.response(for: request.url!, status: 503), Data("oops".utf8))
            }
            let service = RealtimeService(session: MockSession.make())
            let vm = RealtimeMapViewModel(service: service, pollInterval: .seconds(60))
            await vm.refresh()
            #expect(vm.errorMessage != nil)
            #expect(vm.vehicles.isEmpty)
        }

        @Test("serviceInactive=true when feed reports operator offline")
        @MainActor
        func serviceInactiveFlag() async throws {
            let json = """
            {
              "serviceActive": false,
              "feedTimestamp": null,
              "decodedAt": "x",
              "count": null,
              "vehicles": [],
              "message": "off"
            }
            """
            let service = Self.makeService(counter: Counter(), vehiclesJSON: json)
            let vm = RealtimeMapViewModel(service: service, pollInterval: .seconds(60))
            await vm.refresh()
            #expect(vm.serviceInactive == true)
            #expect(vm.vehicles.isEmpty)
        }

        @Test("routeIdToLine index loads from /static/routes on startPolling")
        @MainActor
        func routeIndexLoads() async throws {
            let counter = Counter()
            let service = Self.makeService(counter: counter, vehiclesJSON: Self.emptyFeedJSON)
            let vm = RealtimeMapViewModel(service: service, pollInterval: .seconds(60))
            vm.startPolling()
            try await Task.sleep(for: .milliseconds(120))
            vm.stopPolling()
            #expect(vm.line(forRouteId: "100") == "1")
            #expect(vm.line(forRouteId: "200") == "3")
            #expect(vm.line(forRouteId: "999") == nil)
        }

        // Reach into the parent suite's helpers.
        private static func makeService(counter: Counter, vehiclesJSON: String) -> RealtimeService {
            MockURLProtocol.clearHandlers(path: Self.vehiclesPath)
            MockURLProtocol.clearHandlers(path: staticPath)
            MockURLProtocol.register(path: Self.vehiclesPath) { request in
                counter.increment()
                return (MockSession.okJSON(for: request.url!), Data(vehiclesJSON.utf8))
            }
            MockURLProtocol.register(path: staticPath) { request in
                (MockSession.okJSON(for: request.url!), Data(sampleStaticRoutesJSON.utf8))
            }
            return RealtimeService(session: MockSession.make())
        }

        private static let vehiclesPath = "/vehicles"
        private static let staticPath = "/static"
        private static let emptyFeedJSON = RealtimeTests.emptyFeedJSON
        private static let sampleStaticRoutesJSON = RealtimeTests.sampleStaticRoutesJSON
    }
}

// MARK: - Shared counter helper

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return n }
    func increment() { lock.lock(); defer { lock.unlock() }; n += 1 }
}
