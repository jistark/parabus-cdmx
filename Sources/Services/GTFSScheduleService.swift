import Foundation

// MARK: - GTFS Schedule Service

/// Schedule-based ETA helper. Now backed by the Cloudflare Worker's
/// `/static/schedule` and `/static/travel-time` endpoints (HIGH-16
/// completion). Previously this actor loaded a 56MB bundled
/// `stop_times.txt` on demand and parsed in-process; the bundle is gone,
/// the worker is the single source of truth, and freshness now matches
/// Sinoptico's daily upstream regen instead of the App Store release
/// cadence.
///
/// Trade-off: ETAs require network. Offline behavior: `nextArrivals` and
/// `travelTime` return empty/nil rather than crashing, so UI degrades to
/// "no ETA available" rather than stale-but-displayed data. A short-term
/// cache (UserDefaults per stop) could restore last-known offline values
/// — punted as a future enhancement.
actor GTFSScheduleService {
    static let shared = GTFSScheduleService()

    // MARK: - Dependencies

    private let session: URLSession

    /// Tiny in-actor cache keyed by stopId. The worker already aggressively
    /// caches in KV (per-stop, 30h TTL); this cache just avoids repeating
    /// the network round-trip when the same view asks twice in quick
    /// succession (e.g. CommuteLegCard.loadTravelTime + an ETA refresh).
    /// 5-minute TTL is short enough to pick up Sinoptico's hourly schedule
    /// drift but long enough to absorb tab-switch retries.
    private var stopCache: [String: (arrivals: [ScheduledArrival], loadedAt: Date)] = [:]
    private let stopCacheTTL: TimeInterval = 5 * 60

    init(session: URLSession? = nil) {
        self.session = session ?? {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = APIConfiguration.timeoutInterval
            config.timeoutIntervalForResource = APIConfiguration.timeoutInterval * 2
            return URLSession(configuration: config)
        }()
    }

    // MARK: - Public API

    /// Get next scheduled arrivals for a station.
    func nextArrivals(at stationId: String, limit: Int = 3) async -> [ScheduledArrival] {
        do {
            let arrivals = try await loadStopSchedule(stationId)
            let now = currentTimeInMinutes()
            return arrivals
                .filter { $0.arrivalMinutes >= now }
                .sorted { $0.arrivalMinutes < $1.arrivalMinutes }
                .prefix(limit)
                .map { $0 }
        } catch {
            print("GTFSSchedule: nextArrivals failed for \(stationId): \(error)")
            return []
        }
    }

    /// Get ETA string for next arrival at a station.
    func etaString(for stationId: String) async -> String? {
        let arrivals = await nextArrivals(at: stationId, limit: 1)
        guard let next = arrivals.first else { return nil }

        let now = currentTimeInMinutes()
        let minutesUntil = next.arrivalMinutes - now

        if minutesUntil <= 0 {
            return "Llegando"
        } else if minutesUntil == 1 {
            return "1 min"
        } else if minutesUntil < 60 {
            return "\(minutesUntil) min"
        } else {
            let hours = minutesUntil / 60
            let mins = minutesUntil % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }

    /// Calculate travel time between two stations on the same line.
    /// Hits the worker's pre-aggregated /static/travel-time endpoint —
    /// avoids transferring both stops' full schedules just to compute one
    /// average integer.
    func travelTime(from originId: String, to destinationId: String) async -> Int? {
        do {
            let url = APIConfiguration.baseURL
                .appendingPathComponent("static/travel-time")
                .appending(queryItems: [
                    URLQueryItem(name: "from", value: originId),
                    URLQueryItem(name: "to", value: destinationId),
                ])
            let response = try await get(url, as: TravelTimeResponse.self)
            return response.travelTimeMinutes
        } catch {
            print("GTFSSchedule: travelTime failed for \(originId)→\(destinationId): \(error)")
            return nil
        }
    }

    /// Get formatted travel time string.
    func travelTimeString(from originId: String, to destinationId: String) async -> String? {
        guard let minutes = await travelTime(from: originId, to: destinationId) else {
            return nil
        }
        if minutes < 60 {
            return "~\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "~\(hours)h \(mins)m" : "~\(hours)h"
        }
    }

    // MARK: - Network

    private func loadStopSchedule(_ stopId: String) async throws -> [ScheduledArrival] {
        if let cached = stopCache[stopId],
           Date().timeIntervalSince(cached.loadedAt) < stopCacheTTL {
            return cached.arrivals
        }

        // Request a larger window (limit=20) so the in-actor cache can serve
        // multiple subsequent nextArrivals(limit:) calls from one fetch.
        let url = APIConfiguration.baseURL
            .appendingPathComponent("static/schedule")
            .appending(queryItems: [
                URLQueryItem(name: "stop", value: stopId),
                URLQueryItem(name: "limit", value: "20"),
            ])
        let response = try await get(url, as: ScheduleResponse.self)
        let arrivals = response.arrivals.map {
            ScheduledArrival(
                tripId: $0.tripId,
                stopId: stopId,
                arrivalMinutes: $0.arrivalMinutes,
                sequence: $0.sequence
            )
        }
        stopCache[stopId] = (arrivals, Date())
        return arrivals
    }

    private func get<T: Decodable>(_ url: URL, as: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Parabus-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw TransitDataError.networkError(
                NSError(domain: "GTFSSchedule", code: code,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
            )
        }
        return try SharedCoders.plainDecoder.decode(T.self, from: data)
    }

    private func currentTimeInMinutes() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        return hour * 60 + minute
    }
}

// MARK: - Wire types (mirror worker /static/schedule + /static/travel-time)

private struct ScheduleResponse: Decodable {
    let stop: String
    let count: Int
    let arrivals: [WireArrival]
}

private struct WireArrival: Decodable {
    let tripId: String
    let arrivalMinutes: Int
    let sequence: Int
}

private struct TravelTimeResponse: Decodable {
    let from: String
    let to: String
    let travelTimeMinutes: Int?
}

// MARK: - Scheduled Arrival

struct ScheduledArrival: Identifiable {
    let id = UUID()
    let tripId: String
    let stopId: String
    let arrivalMinutes: Int // Minutes since midnight
    let sequence: Int

    var arrivalTime: String {
        let hours = arrivalMinutes / 60
        let minutes = arrivalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

// MARK: - CommuteSchedule Extension

extension CommuteSchedule {
    /// Get ETA info for the commute
    func getETAInfo() async -> CommuteETAInfo? {
        guard let ida = ida, ida.isEnabled else { return nil }

        let etaString = await GTFSScheduleService.shared.etaString(for: ida.startStation.id)
        let travelTime = await GTFSScheduleService.shared.travelTimeString(
            from: ida.startStation.id,
            to: ida.endStation.id
        )

        return CommuteETAInfo(
            nextArrival: etaString,
            travelTime: travelTime
        )
    }
}

struct CommuteETAInfo {
    let nextArrival: String?
    let travelTime: String?

    var hasData: Bool {
        nextArrival != nil || travelTime != nil
    }
}
