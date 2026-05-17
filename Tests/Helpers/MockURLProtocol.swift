import Foundation

/// URLProtocol subclass that intercepts every request handled by a URLSession
/// whose configuration includes it in `protocolClasses`. Tests register
/// path-prefix-keyed handlers so multiple test suites can run in parallel
/// against the same MockURLProtocol class without clobbering each other —
/// each suite tests a service that hits a different path (`/status` vs
/// `/vehicles` vs `/static/routes` ...).
///
/// All state is protected by an NSLock since URLProtocol callbacks come in
/// on URLSession's delegate queue, not the test's actor.
///
/// Usage:
///   ```swift
///   MockURLProtocol.register(path: "/status") { request in
///       (response, jsonData)
///   }
///   let session = MockSession.make()
///   ```
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    private nonisolated(unsafe) static var pathHandlers: [(prefix: String, handler: Handler)] = []
    private nonisolated(unsafe) static var allRequestedURLs: [URL] = []

    /// Register a handler for any request whose URL path starts with `prefix`.
    /// Last registration wins for overlapping prefixes (so tests can override).
    static func register(path prefix: String, handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }
        pathHandlers.removeAll { $0.prefix == prefix }
        pathHandlers.append((prefix, handler))
    }

    /// Clear handlers registered for paths starting with `prefix`. Use to
    /// reset state between tests in the same suite.
    static func clearHandlers(path prefix: String) {
        lock.lock(); defer { lock.unlock() }
        pathHandlers.removeAll { $0.prefix == prefix }
        allRequestedURLs.removeAll { $0.path.hasPrefix(prefix) }
    }

    /// URLs intercepted whose path starts with the given prefix, in order seen.
    static func requestedURLs(matching prefix: String) -> [URL] {
        lock.lock(); defer { lock.unlock() }
        return allRequestedURLs.filter { $0.path.hasPrefix(prefix) }
    }

    private static func handlerForPath(_ path: String) -> Handler? {
        lock.lock(); defer { lock.unlock() }
        // Prefer the longest matching prefix (more specific wins).
        return pathHandlers
            .filter { path.hasPrefix($0.prefix) }
            .sorted { $0.prefix.count > $1.prefix.count }
            .first?.handler
    }

    private static func recordRequestedURL(_ url: URL) {
        lock.lock(); defer { lock.unlock() }
        allRequestedURLs.append(url)
    }

    // MARK: - URLProtocol overrides

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: "MockURLProtocol", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "request has no URL"]
            ))
            return
        }
        Self.recordRequestedURL(url)
        guard let handler = Self.handlerForPath(url.path) else {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: "MockURLProtocol", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "no handler for path \(url.path)"]
            ))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Convenience: build an ephemeral URLSession wired to MockURLProtocol.
enum MockSession {
    static func make() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Build a 200 OK HTTPURLResponse for a URL with a JSON content type.
    static func okJSON(for url: URL) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    static func response(for url: URL, status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}
