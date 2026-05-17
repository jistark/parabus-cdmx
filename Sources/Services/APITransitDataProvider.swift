import Foundation

// MARK: - API Response Models

/// Response from the Cloudflare Worker API
/// Maps to the backend schema without modifying existing app models
struct APIMetrobusResponse: Codable, Sendable {
    let lastUpdated: String
    let sourceTimestamp: String?
    let stale: Bool?
    let error: String?
    let sources: APISources
    let lines: [APILineStatus]
    let scheduledMaintenance: [APIMaintenanceInfo]
    let elevators: [APIElevatorInfo]
}

struct APISources: Codable, Sendable {
    let incidentes: APISourceStatus
    let mantenimiento: APISourceStatus
}

struct APISourceStatus: Codable, Sendable {
    let available: Bool
    let error: String?
}

/// Individual incident from the API
struct APILineIncident: Codable, Sendable {
    let status: String
    let statusText: String
    let affectedStations: [String]
    let details: String?
}

struct APILineStatus: Codable, Sendable {
    let line: String
    let lineId: String
    let status: String  // "normal", "delayed", "maintenance", "closure", "limited", "suspended", "protest"
    let statusText: String
    let affectedStations: [String]
    let details: String?
    /// All incidents for this line (new multi-incident support)
    let incidents: [APILineIncident]?
}

struct APIMaintenanceInfo: Codable, Sendable {
    let station: String
    let lineId: String
    let line: String
    let direction: String
    let reason: String
    let closurePeriod: String
}

struct APIElevatorInfo: Codable, Sendable {
    let station: String
    let lineId: String
    let line: String
    let direction: String
    let reason: String
    let estimatedRepair: String?
}

// MARK: - API Configuration

/// Configuration for the API provider.
///
/// These were previously `nonisolated(unsafe) static var` to "allow env
/// switching at runtime", but no code path ever wrote to them and the
/// URLSession config is captured into a `lazy var session` so mutation
/// would have left a stale session anyway. Making them `let` removes the
/// Swift 6 strict-concurrency race and the dishonest mutability hint.
/// If env switching is needed later, inject via initializer instead.
enum APIConfiguration {
    /// Base URL for the Cloudflare Worker API.
    static let baseURL: URL = URL(string: "https://metrobus-status.starkji.workers.dev")!

    /// Timeout for API requests in seconds.
    static let timeoutInterval: TimeInterval = 15.0
}

// MARK: - API Transit Data Provider

/// Provider that fetches transit data from the Cloudflare Worker API
/// instead of scraping directly. Implements TransitDataProviding protocol.
actor APITransitDataProvider: TransitDataProviding {

    // MARK: - Private Properties

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfiguration.timeoutInterval
        config.timeoutIntervalForResource = APIConfiguration.timeoutInterval * 2
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    // MARK: - TransitDataProviding Implementation

    func fetchStatus() async throws -> ScrapingResult {
        let response = try await fetchAPIResponse()
        let lines = response.lines.map { convertToLineStatus($0) }

        return ScrapingResult(
            lines: lines,
            scrapedAt: parseDate(response.lastUpdated) ?? Date(),
            source: APIConfiguration.baseURL.appendingPathComponent("status")
        )
    }

    func fetchStatus(forLine lineNumber: String) async throws -> LineStatus? {
        // Use filtered endpoint for efficiency
        let url = APIConfiguration.baseURL
            .appendingPathComponent("status")
            .appending(queryItems: [URLQueryItem(name: "lines", value: lineNumber)])

        let response = try await fetchAPIResponse(from: url)
        return response.lines.first.map { convertToLineStatus($0) }
    }

    func fetchMaintenanceClosures() async throws -> MaintenanceResult {
        let response = try await fetchAPIResponse()
        let closures = response.scheduledMaintenance.map { convertToScheduledClosure($0) }

        return MaintenanceResult(
            closures: closures,
            scrapedAt: parseDate(response.lastUpdated) ?? Date(),
            source: APIConfiguration.baseURL.appendingPathComponent("status")
        )
    }

    // MARK: - Force Refresh

    /// Fetch with cache bypass
    func fetchStatus(forceRefresh: Bool) async throws -> ScrapingResult {
        var url = APIConfiguration.baseURL.appendingPathComponent("status")
        if forceRefresh {
            url = url.appending(queryItems: [URLQueryItem(name: "refresh", value: "true")])
        }

        let response = try await fetchAPIResponse(from: url)
        let lines = response.lines.map { convertToLineStatus($0) }

        return ScrapingResult(
            lines: lines,
            scrapedAt: parseDate(response.lastUpdated) ?? Date(),
            source: url
        )
    }

    // MARK: - Private Methods

    private func fetchAPIResponse(from url: URL? = nil) async throws -> APIMetrobusResponse {
        let requestURL = url ?? APIConfiguration.baseURL.appendingPathComponent("status")

        var request = URLRequest(url: requestURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Parabus-iOS/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ScraperError.networkError(
                    NSError(domain: "API", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid response type"
                    ])
                )
            }

            switch httpResponse.statusCode {
            case 200...299:
                break
            case 429:
                throw ScraperError.networkError(
                    NSError(domain: "API", code: 429, userInfo: [
                        NSLocalizedDescriptionKey: "Demasiadas solicitudes, intenta más tarde"
                    ])
                )
            case 500...599:
                throw ScraperError.networkError(
                    NSError(domain: "API", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Error del servidor, intenta más tarde"
                    ])
                )
            default:
                throw ScraperError.networkError(
                    NSError(domain: "API", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Error HTTP \(httpResponse.statusCode)"
                    ])
                )
            }

            do {
                return try decoder.decode(APIMetrobusResponse.self, from: data)
            } catch {
                throw ScraperError.parsingError("Error decodificando JSON: \(error.localizedDescription)")
            }

        } catch let error as ScraperError {
            throw error
        } catch {
            throw ScraperError.networkError(error)
        }
    }

    // MARK: - Model Conversion

    /// Convert API LineStatus to app's LineStatus model
    private func convertToLineStatus(_ apiLine: APILineStatus) -> LineStatus {
        // Use the incidents array if available (new multi-incident API)
        // Otherwise fall back to top-level fields (backwards compatibility)
        let incidents: [Incident]

        if let apiIncidents = apiLine.incidents, !apiIncidents.isEmpty {
            // Map all incidents from the API
            incidents = apiIncidents.compactMap { apiIncident -> Incident? in
                let status = convertAPIStatus(apiIncident.status)
                // Skip normal status incidents with no affected stations
                if status == .regular && apiIncident.affectedStations.isEmpty {
                    return nil
                }
                return Incident(
                    status: status,
                    affectedStations: apiIncident.affectedStations,
                    info: apiIncident.details
                )
            }
        } else {
            // Fall back to top-level fields (backwards compatibility)
            let status = convertAPIStatus(apiLine.status)
            if status != .regular || !apiLine.affectedStations.isEmpty {
                incidents = [
                    Incident(
                        status: status,
                        affectedStations: apiLine.affectedStations,
                        info: apiLine.details
                    )
                ]
            } else {
                incidents = []
            }
        }

        return LineStatus(
            lineNumber: apiLine.line,
            lineName: "Línea \(apiLine.line)",
            transportType: .metrobus,
            incidents: incidents,
            lastUpdated: Date()
        )
    }

    /// Convert API status string to ServiceStatus enum
    private func convertAPIStatus(_ apiStatus: String) -> ServiceStatus {
        switch apiStatus.lowercased() {
        case "normal":
            return .regular
        case "delayed":
            return .delayed
        case "maintenance":
            return .intervention
        case "closure":
            return .suspended
        case "limited":
            return .limited
        case "suspended":
            return .suspended
        case "protest":
            return .protest  // Urgent - triggers immediate notification
        default:
            return .unknown
        }
    }

    /// Convert API MaintenanceInfo to app's ScheduledClosure model
    private func convertToScheduledClosure(_ apiMaintenance: APIMaintenanceInfo) -> ScheduledClosure {
        ScheduledClosure(
            lineNumber: apiMaintenance.line,
            stationName: apiMaintenance.station,
            direction: ClosureDirection(from: apiMaintenance.direction),
            reason: ClosureReason(from: apiMaintenance.reason),
            closurePeriod: apiMaintenance.closurePeriod,
            parsedDates: nil,  // Could parse if needed
            hours: nil
        )
    }

    /// Parse ISO 8601 date string
    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}

// MARK: - Health Check

extension APITransitDataProvider {

    struct HealthStatus: Sendable {
        let isHealthy: Bool
        let cacheAge: Int?
        let timestamp: Date
    }

    /// Check if the API is healthy
    func checkHealth() async -> HealthStatus {
        let url = APIConfiguration.baseURL.appendingPathComponent("health")

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return HealthStatus(isHealthy: false, cacheAge: nil, timestamp: Date())
            }

            // Parse health response
            struct HealthResponse: Codable {
                let status: String
                let cacheAge: Int?
            }

            let health = try? decoder.decode(HealthResponse.self, from: data)

            return HealthStatus(
                isHealthy: health?.status == "ok",
                cacheAge: health?.cacheAge,
                timestamp: Date()
            )
        } catch {
            return HealthStatus(isHealthy: false, cacheAge: nil, timestamp: Date())
        }
    }
}

// MARK: - Convenience URL Extension

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)!
        var existing = components.queryItems ?? []
        existing.append(contentsOf: queryItems)
        components.queryItems = existing
        return components.url!
    }
}
