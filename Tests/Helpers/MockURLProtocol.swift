import Foundation

/// URLProtocol subclass that intercepts every request handled by a URLSession
/// whose configuration includes it in `protocolClasses`. Tests register a
/// handler closure to decide how each request resolves.
///
/// Usage:
///   ```swift
///   MockURLProtocol.handler = { request in
///       (HTTPURLResponse(...)!, jsonData)
///   }
///   let config = URLSessionConfiguration.ephemeral
///   config.protocolClasses = [MockURLProtocol.self]
///   let session = URLSession(configuration: config)
///   ```
///
/// `nonisolated(unsafe)` on the handler is acceptable here because: (a) it's
/// test-only code, (b) each test sets and consumes the handler within a
/// single async test method so there's no real cross-thread race, (c) the
/// Swift Testing framework runs test methods serially within a suite.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    /// Handler decides how to respond to each intercepted request.
    /// Throw to simulate a transport failure; return `(response, data)` to
    /// simulate a successful HTTP response (any status code).
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    /// Tracks each URL the session attempts to load. Tests can assert on this
    /// to verify URL construction (path, query items).
    nonisolated(unsafe) static var requestedURLs: [URL] = []

    static func reset() {
        handler = nil
        requestedURLs = []
    }

    // MARK: - URLProtocol overrides

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url {
            Self.requestedURLs.append(url)
        }
        guard let handler = Self.handler else {
            let err = NSError(
                domain: "MockURLProtocol",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "no handler registered"]
            )
            client?.urlProtocol(self, didFailWithError: err)
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
