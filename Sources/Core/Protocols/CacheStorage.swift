import Foundation

/// Protocol for caching transit data
/// Enables mocking and alternative storage implementations
protocol CacheStorageProviding: Sendable {
    func save(_ result: ScrapingResult) async throws
    func load() async throws -> CacheManager.CachedData?
    func loadIfValid() async throws -> CacheManager.CachedData?
    func clear() async throws
    func hasCachedData() async -> Bool
}

// MARK: - CacheManager Conformance

extension CacheManager: CacheStorageProviding {}

// MARK: - In-Memory Mock for Tests

#if DEBUG
actor InMemoryCacheStorage: CacheStorageProviding {
    private var storedData: CacheManager.CachedData?
    private let validitySeconds: TimeInterval

    init(validitySeconds: TimeInterval = 300) {
        self.validitySeconds = validitySeconds
    }

    func save(_ result: ScrapingResult) async throws {
        storedData = CacheManager.CachedData(
            lines: result.lines,
            cachedAt: result.scrapedAt,
            sourceURL: result.source.absoluteString
        )
    }

    func load() async throws -> CacheManager.CachedData? {
        storedData
    }

    func loadIfValid() async throws -> CacheManager.CachedData? {
        guard let data = storedData else { return nil }
        return data.age < validitySeconds ? data : nil
    }

    func clear() async throws {
        storedData = nil
    }

    func hasCachedData() async -> Bool {
        storedData != nil
    }
}
#endif
