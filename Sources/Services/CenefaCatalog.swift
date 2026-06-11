// Sources/Services/CenefaCatalog.swift
import Foundation

// MARK: - Dataset types (mirror workers/src/data/cenefas-types.ts)

struct CenefaStop: Codable, Sendable, Equatable {
    let stopId: String
    let name: String
    let pictogram: String
}

struct CenefaDirection: Codable, Sendable, Equatable {
    let destination: String
    let gtfsRouteIds: [String]
    let gtfsHeadsigns: [String]
    let stops: [CenefaStop]
}

struct CenefaStyle: Codable, Sendable, Equatable {
    let colors: [String]
    let notes: String?
}

struct CenefaService: Codable, Sendable, Equatable {
    let id: String
    let type: String
    let lines: [String]
    let directions: [CenefaDirection]
    let style: CenefaStyle
}

struct CenefaLine: Codable, Sendable, Equatable {
    let line: String
    let services: [CenefaService]
}

struct CenefaDataset: Codable, Sendable, Equatable {
    let version: String
    let lines: [CenefaLine]

    /// Services whose any direction passes through the platform stop.
    func services(at stopId: String) -> [CenefaService] {
        lines.flatMap(\.services).filter { service in
            service.directions.contains { $0.stops.contains { $0.stopId == stopId } }
        }
    }

    /// Match via `service.lines` (interlínea belongs to both), not the parent.
    func services(forLine line: String) -> [CenefaService] {
        lines.flatMap(\.services).filter { $0.lines.contains(line) }
    }
}

// MARK: - Catalog actor

/// Fetches /static/cenefas at most once per 24h; persists to the caches
/// directory so a fresh launch works offline with the last-known dataset.
/// Mirrors the GTFSScheduleService actor + small-cache pattern.
actor CenefaCatalog {
    static let shared = CenefaCatalog()

    private var dataset: CenefaDataset?
    private var fetchedAt: Date?

    private static let cacheTTL: TimeInterval = 24 * 3600
    private static var diskURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("cenefas.json")
    }

    /// Exposed for testing: the expiry rule, free of clock/IO.
    static func isExpired(fetchedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) > cacheTTL
    }

    func current() async -> CenefaDataset? {
        if let dataset, let fetchedAt, !Self.isExpired(fetchedAt: fetchedAt, now: Date()) {
            return dataset
        }
        if let fetched = await fetchRemote() {
            dataset = fetched
            fetchedAt = Date()
            persist(fetched)
            return fetched
        }
        // Network failed: keep serving whatever we have (memory, then disk).
        if dataset == nil { dataset = loadFromDisk() }
        return dataset
    }

    func services(at stopId: String) async -> [CenefaService] {
        await current()?.services(at: stopId) ?? []
    }

    func services(forLine line: String) async -> [CenefaService] {
        await current()?.services(forLine: line) ?? []
    }

    // MARK: - IO

    private func fetchRemote() async -> CenefaDataset? {
        let url = APIConfiguration.baseURL.appendingPathComponent("static/cenefas")
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(CenefaDataset.self, from: data)
    }

    private func persist(_ dataset: CenefaDataset) {
        if let data = try? JSONEncoder().encode(dataset) {
            try? data.write(to: Self.diskURL, options: .atomic)
        }
    }

    private func loadFromDisk() -> CenefaDataset? {
        guard let data = try? Data(contentsOf: Self.diskURL) else { return nil }
        return try? JSONDecoder().decode(CenefaDataset.self, from: data)
    }
}
