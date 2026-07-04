import Foundation

// MARK: - Transport model

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct HTTPRequest {
    var method: HTTPMethod
    var url: URL
    var headers: [String: String]
    var body: Data?

    init(
        method: HTTPMethod,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

struct HTTPResponse {
    let status: Int
    let headers: [String: String]
    let data: Data
}

/// The single abstraction over the HTTP transport. All networking flows through
/// a `HTTPTransport` so cross-cutting concerns (auth, logging, retry) compose as
/// decorators and the only `URLSession` user is `URLSessionTransport`.
///
/// Failures are reported as `APIError` (the app-wide error type). Cancellation
/// is honoured via `CancellationToken`; a cancelled request never calls back.
protocol HTTPTransport: AnyObject {
    func send(
        _ request: HTTPRequest,
        cancellationToken: CancellationToken?,
        completion: @escaping (Result<HTTPResponse, Error>) -> Void
    )
}
