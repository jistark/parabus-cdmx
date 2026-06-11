// Sources/Services/ArrivalsService.swift
import Foundation

/// Thin client for GET /arrivals?stop=<id>. No state logic here — the worker
/// derives everything (spec: approach A). In-actor cache TTL matches the
/// polling cadence (25s) so a re-render never duplicates a request.
actor ArrivalsService {
    static let shared = ArrivalsService()

    private var cache: [String: (response: ArrivalsResponse, fetchedAt: Date)] = [:]
    private static let cacheTTL: TimeInterval = 25

    static func isExpired(fetchedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > cacheTTL
    }

    /// Latest arrival rows for a platform stop. `nil` = network failure with
    /// nothing cached — callers fall back to GTFSScheduleService.
    func arrivals(at stopId: String) async -> ArrivalsResponse? {
        if let hit = cache[stopId], !Self.isExpired(fetchedAt: hit.fetchedAt, now: Date()) {
            return hit.response
        }

        var components = URLComponents(
            url: APIConfiguration.baseURL.appendingPathComponent("arrivals"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "stop", value: stopId)]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = APIConfiguration.timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Parabus-iOS/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, urlResponse) = try? await URLSession.shared.data(for: request),
              (urlResponse as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(ArrivalsResponse.self, from: data) else {
            return cache[stopId]?.response // stale-if-error: old beats nothing
        }

        cache[stopId] = (decoded, Date())
        return decoded
    }
}
