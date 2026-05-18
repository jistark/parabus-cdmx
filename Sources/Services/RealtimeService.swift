import Foundation

/// Fetches realtime + static GTFS data from the Metrobús worker.
/// Mirrors the architecture of `APITransitDataProvider` — same baseURL,
/// timeout, error type. Pure data layer; no UI state.
actor RealtimeService {
    static let shared = RealtimeService()

    private let decoder = JSONDecoder()

    private let session: URLSession

    /// Production initializer uses a sensible default URLSession. Tests pass
    /// an ephemeral session with a MockURLProtocol in its protocolClasses.
    init(session: URLSession? = nil) {
        self.session = session ?? {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = APIConfiguration.timeoutInterval
            config.timeoutIntervalForResource = APIConfiguration.timeoutInterval * 2
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            return URLSession(configuration: config)
        }()
    }

    /// In-memory memoization of /static/routes. The worker regenerates the
    /// underlying GTFS daily at midnight; cache up to 6h on the client to
    /// avoid re-fetching ~30KB per app session while still picking up
    /// schema changes intraday if needed.
    private var staticRoutesCache: (response: StaticRoutesResponse, loadedAt: Date)?
    private let staticRoutesTTL: TimeInterval = 6 * 60 * 60

    // MARK: - Public API

    /// Fetch live vehicle positions, optionally filtered by line number ("1"…"7").
    func fetchVehicles(line: String? = nil) async throws -> RealtimeFeed {
        var url = APIConfiguration.baseURL.appendingPathComponent("vehicles")
        if let line {
            url = url.appending(queryItems: [URLQueryItem(name: "line", value: line)])
        }
        return try await get(url, as: RealtimeFeed.self)
    }

    /// Fetch the route catalog (87 routes across 7 lines). Memoized for 6h.
    func fetchStaticRoutes() async throws -> StaticRoutesResponse {
        if let cached = staticRoutesCache,
           Date().timeIntervalSince(cached.loadedAt) < staticRoutesTTL {
            return cached.response
        }
        let url = APIConfiguration.baseURL.appendingPathComponent("static/routes")
        let response = try await get(url, as: StaticRoutesResponse.self)
        staticRoutesCache = (response, Date())
        return response
    }

    // MARK: - Private

    private func get<T: Decodable>(_ url: URL, as: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Parabus-iOS/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw TransitDataError.networkError(
                    NSError(domain: "RealtimeService", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
                )
            }

            switch http.statusCode {
            case 200...299:
                break
            case 429:
                throw TransitDataError.networkError(
                    NSError(domain: "RealtimeService", code: 429,
                            userInfo: [NSLocalizedDescriptionKey: "Demasiadas solicitudes, intenta más tarde"])
                )
            case 503:
                throw TransitDataError.networkError(
                    NSError(domain: "RealtimeService", code: 503,
                            userInfo: [NSLocalizedDescriptionKey: "Datos no disponibles temporalmente"])
                )
            case 500...599:
                throw TransitDataError.networkError(
                    NSError(domain: "RealtimeService", code: http.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Error del servidor"])
                )
            default:
                throw TransitDataError.networkError(
                    NSError(domain: "RealtimeService", code: http.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
                )
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw TransitDataError.parsingError(
                    "Error decodificando \(T.self): \(error.localizedDescription)"
                )
            }
        } catch let error as TransitDataError {
            throw error
        } catch {
            throw TransitDataError.networkError(error)
        }
    }
}
