import SwiftUI

// MARK: - Data Source Configuration

/// Determines how transit data is fetched
enum TransitDataSource: String, CaseIterable {
    /// Scrape directly from metrobus.cdmx.gob.mx (original behavior)
    case scraper

    /// Use Cloudflare Worker API (recommended for production)
    case api

    /// Current data source - API is the default (Worker must be deployed)
    /// Use .scraper as fallback if API is unavailable
    nonisolated(unsafe) static var current: TransitDataSource = .api
}

// MARK: - Environment Keys

private struct TransitDataProviderKey: EnvironmentKey {
    static var defaultValue: any TransitDataProviding {
        switch TransitDataSource.current {
        case .scraper:
            return MetrobusScraper()
        case .api:
            return APITransitDataProvider()
        }
    }
}

private struct CacheStorageKey: EnvironmentKey {
    static let defaultValue: any CacheStorageProviding = CacheManager()
}

// MARK: - Environment Values Extension

extension EnvironmentValues {
    var transitDataProvider: any TransitDataProviding {
        get { self[TransitDataProviderKey.self] }
        set { self[TransitDataProviderKey.self] = newValue }
    }

    var cacheStorage: any CacheStorageProviding {
        get { self[CacheStorageKey.self] }
        set { self[CacheStorageKey.self] = newValue }
    }
}

// MARK: - View Modifier for Previews

#if DEBUG
extension View {
    /// Injects mock dependencies for previews
    func withMockDependencies(
        lines: [LineStatus] = MetrobusScraper.mockData,
        shouldFail: Bool = false
    ) -> some View {
        self
            .environment(\.transitDataProvider, MockTransitDataProvider(
                lines: lines,
                shouldFail: shouldFail
            ))
            .environment(\.cacheStorage, InMemoryCacheStorage())
    }
}
#endif
