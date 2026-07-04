import Foundation

enum DirectPlaybackClient: Equatable, CustomStringConvertible {
    case androidVR
    case web

    var description: String {
        clientName
    }

    var clientName: String {
        switch self {
        case .androidVR:
            "ANDROID_VR"
        case .web:
            "WEB"
        }
    }

    var clientVersion: String {
        switch self {
        case .androidVR:
            "1.65.10"
        case .web:
            "2.20231121.08.00"
        }
    }

    var clientHeaderName: String {
        switch self {
        case .androidVR:
            "28"
        case .web:
            "1"
        }
    }

    var userAgent: String {
        switch self {
        case .androidVR:
            "com.google.android.apps.youtube.vr.oculus/"
                + "1.65.10 (Linux; U; Android 12L;"
                + " eureka-user Build/SQ3A.220605.009.A1) gzip"
        case .web:
            UserAgent.chromeMac
        }
    }

    /// Whether this client uses cookie-based auth instead of OAuth Bearer token
    var usesCookieAuth: Bool {
        switch self {
        case .androidVR:
            true
        case .web:
            false
        }
    }

    /// Whether the /player body needs contentCheckOk / racyCheckOk / playbackContext flags
    var requiresContentCheckFlags: Bool {
        true
    }

    var pipelineStrategy: PlaybackPipelineStrategy {
        switch self {
        case .androidVR:
            AndroidVRPipelineStrategy()
        case .web:
            WebClientPipelineStrategy()
        }
    }

    var context: [String: Any] {
        switch self {
        case .androidVR:
            InnertubeContexts.androidVR
        case .web:
            InnertubeContexts.web
        }
    }

    var playerURLSuffix: String {
        switch self {
        case .androidVR:
            "?prettyPrint=false"
        case .web:
            ""
        }
    }

    /// Normalises a signed media URL for direct playback: replaces `pot`/`cver`
    /// query params with this client's values (the segment CDN requires a
    /// matching client version, plus `pot` when a token is available).
    func directURL(baseURL: URL, poToken: String?) -> URL {
        guard var components = URLComponents(
            url: baseURL, resolvingAgainstBaseURL: false
        ) else {
            return baseURL
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "pot" || $0.name == "cver" }
        if let poToken, !poToken.isEmpty {
            items.append(URLQueryItem(name: "pot", value: poToken))
        }
        items.append(URLQueryItem(name: "cver", value: clientVersion))
        components.queryItems = items
        return components.url ?? baseURL
    }

    /// Build HTTP headers for stream requests (AVPlayer asset loading, direct URL fetches)
    func streamHeaders(visitorData: String?) -> [String: String] {
        var headers: [String: String] = [
            HTTPHeader.accept: "*/*",
            HTTPHeader.acceptLanguage: "*",
            HTTPHeader.userAgent: userAgent,
            HTTPHeader.xYoutubeClientName: clientHeaderName,
            HTTPHeader.xYoutubeClientVersion: clientVersion
        ]
        switch self {
        case .web:
            headers[HTTPHeader.referer] = AppURLs.YouTube.base + "/"
            headers[HTTPHeader.origin] = AppURLs.YouTube.base
            headers[HTTPHeader.xOrigin] = AppURLs.YouTube.base
        case .androidVR:
            break
        }
        if let visitorData, !visitorData.isEmpty {
            headers[HTTPHeader.xGoogVisitorId] = visitorData
        }
        return headers
    }

    /// Build HTTP headers for /player API requests
    func apiHeaders(token: String, visitorData: String?) -> [String: String] {
        var headers: [String: String] = [HTTPHeader.contentType: HTTPHeaderValue.contentTypeJSON]
        if !usesCookieAuth {
            headers[HTTPHeader.authorization] = "Bearer \(token)"
        }
        headers[HTTPHeader.xYoutubeClientName] = clientHeaderName
        headers[HTTPHeader.xYoutubeClientVersion] = clientVersion
        headers[HTTPHeader.userAgent] = userAgent
        switch self {
        case .web:
            break
        case .androidVR:
            headers[HTTPHeader.origin] = AppURLs.YouTube.base
            if let visitorData, !visitorData.isEmpty {
                headers[HTTPHeader.xGoogVisitorId] = visitorData
            }
        }
        return headers
    }
}
