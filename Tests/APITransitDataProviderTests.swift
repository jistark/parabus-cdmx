import Foundation
import Testing
@testable import ParabusCore

@Suite("APITransitDataProvider Tests", .serialized)
struct APITransitDataProviderTests {

    // Each test resets only its own path-prefix handlers, so suites running
    // in parallel (RealtimeServiceTests, etc.) don't clobber each other.
    private static let path = "/status"

    // MARK: - fetchStatus

    @Test("decodes a happy-path /status response")
    func fetchStatusDecodes() async throws {
        let json = """
        {
          "lastUpdated": "2026-05-17T20:00:00.000Z",
          "sourceTimestamp": "14:00",
          "sources": {
            "incidentes": {"available": true},
            "mantenimiento": {"available": true}
          },
          "lines": [
            {
              "line": "1",
              "lineId": "MB1",
              "status": "normal",
              "statusText": "Servicio Regular",
              "affectedStations": [],
              "details": null,
              "incidents": [
                {"status": "normal", "statusText": "Servicio Regular", "affectedStations": [], "details": null}
              ]
            },
            {
              "line": "2",
              "lineId": "MB2",
              "status": "delayed",
              "statusText": "Retraso",
              "affectedStations": ["Centro Medico"],
              "details": "Manifestacion",
              "incidents": [
                {"status": "delayed", "statusText": "Retraso", "affectedStations": ["Centro Medico"], "details": "Manifestacion"}
              ]
            }
          ],
          "scheduledMaintenance": [],
          "elevators": []
        }
        """

        let session = makeSession(json: json)
        let provider = APITransitDataProvider(session: session)

        let result = try await provider.fetchStatus()

        #expect(result.lines.count == 2)
        #expect(result.lines[0].lineNumber == "1")
        #expect(result.lines[0].status == .regular)
        #expect(result.lines[1].status == .delayed)
        #expect(result.lines[1].affectedStations == ["Centro Medico"])
    }

    @Test("status mapping covers all known worker values")
    func convertAPIStatusCovers() async throws {
        let cases: [(String, ServiceStatus)] = [
            ("normal", .regular),
            ("delayed", .delayed),
            ("maintenance", .intervention),
            ("limited", .limited),
            ("suspended", .suspended),
            ("protest", .protest),
            ("unknown", .unknown),
        ]

        for (apiValue, expected) in cases {
            let json = #"""
            {
              "lastUpdated": "2026-05-17T20:00:00.000Z",
              "sourceTimestamp": null,
              "sources": {"incidentes": {"available": true}, "mantenimiento": {"available": true}},
              "lines": [{
                "line": "1", "lineId": "MB1",
                "status": "\#(apiValue)", "statusText": "\#(apiValue)",
                "affectedStations": ["X"], "details": null,
                "incidents": [{"status": "\#(apiValue)", "statusText": "\#(apiValue)", "affectedStations": ["X"], "details": null}]
              }],
              "scheduledMaintenance": [], "elevators": []
            }
            """#

            let provider = APITransitDataProvider(session: makeSession(json: json))
            let result = try await provider.fetchStatus()
            #expect(result.lines[0].status == expected, "expected \(expected) for \(apiValue)")
        }
    }

    // MARK: - fetchAll

    @Test("fetchAll returns aligned status + maintenance from one response")
    func fetchAllDecodesBoth() async throws {
        let json = """
        {
          "lastUpdated": "2026-05-17T20:00:00.000Z",
          "sourceTimestamp": "14:00",
          "sources": {"incidentes": {"available": true}, "mantenimiento": {"available": true}},
          "lines": [
            {"line": "1", "lineId": "MB1", "status": "normal", "statusText": "Regular", "affectedStations": [], "details": null, "incidents": []}
          ],
          "scheduledMaintenance": [
            {"line": "3", "lineId": "MB3", "station": "Etiopia", "direction": "Ambos sentidos", "reason": "Mantenimiento", "closurePeriod": "Hoy"}
          ],
          "elevators": []
        }
        """

        let session = makeSession(json: json)
        let provider = APITransitDataProvider(session: session)

        let (status, maintenance) = try await provider.fetchAll(forceRefresh: false)

        #expect(status.lines.count == 1)
        #expect(maintenance.closures.count == 1)
        #expect(maintenance.closures[0].stationName == "Etiopia")
        // Same scrapedAt — the CRIT-06 invariant
        #expect(status.scrapedAt == maintenance.scrapedAt)
    }

    @Test("fetchAll forwards forceRefresh=true as ?refresh=true query param")
    func fetchAllForceRefreshURL() async throws {
        let provider = APITransitDataProvider(session: makeSession(json: """
        {
          "lastUpdated": "2026-05-17T20:00:00.000Z",
          "sourceTimestamp": null,
          "sources": {"incidentes": {"available": true}, "mantenimiento": {"available": true}},
          "lines": [],
          "scheduledMaintenance": [],
          "elevators": []
        }
        """))

        _ = try await provider.fetchAll(forceRefresh: true)

        let urls = MockURLProtocol.requestedURLs(matching: Self.path)
        #expect(urls.count >= 1)
        #expect(urls.last?.absoluteString.contains("refresh=true") == true)
    }

    // MARK: - HTTP status mapping

    @Test("429 maps to ScraperError.networkError")
    func http429() async throws {
        let provider = APITransitDataProvider(
            session: makeSession(status: 429, body: "rate limited")
        )
        do {
            _ = try await provider.fetchStatus()
            Issue.record("expected throw")
        } catch let ScraperError.networkError(underlying) {
            let nsError = underlying as NSError
            #expect(nsError.code == 429)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("500 maps to ScraperError.networkError")
    func http500() async throws {
        let provider = APITransitDataProvider(
            session: makeSession(status: 503, body: "service unavailable")
        )
        do {
            _ = try await provider.fetchStatus()
            Issue.record("expected throw")
        } catch let ScraperError.networkError(underlying) {
            let nsError = underlying as NSError
            #expect(nsError.code == 503)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("malformed JSON maps to ScraperError.parsingError")
    func parseFailure() async throws {
        let provider = APITransitDataProvider(
            session: makeSession(json: "this is not json")
        )
        do {
            _ = try await provider.fetchStatus()
            Issue.record("expected throw")
        } catch ScraperError.parsingError {
            // expected
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    // MARK: - Helpers

    private func makeSession(json: String) -> URLSession {
        MockURLProtocol.clearHandlers(path: Self.path)
        MockURLProtocol.register(path: Self.path) { request in
            (MockSession.okJSON(for: request.url!), Data(json.utf8))
        }
        return MockSession.make()
    }

    private func makeSession(status: Int, body: String) -> URLSession {
        MockURLProtocol.clearHandlers(path: Self.path)
        MockURLProtocol.register(path: Self.path) { request in
            (MockSession.response(for: request.url!, status: status), Data(body.utf8))
        }
        return MockSession.make()
    }
}
