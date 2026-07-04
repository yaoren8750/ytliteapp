import Foundation

enum ServiceContainer {
    /// The app-wide HTTP transport: the URLSession core wrapped in decorators
    /// (logging now; authorizing/retrying to follow). Every service should route
    /// through this rather than touching URLSession directly.
    static let transport: HTTPTransport = LoggingTransport(
        AuthorizingTransport(URLSessionTransport())
    )

    // Single InnertubeClient instance shared across all service protocols.
    // Each property is typed to the narrowest protocol the caller needs — DIP in action.
    private static let client = InnertubeClient(transport: transport)

    static var feed: FeedService { client }
    static var history: HistoryService { client }
    static var search: SearchService { client }
    static var playlists: PlaylistService { client }
    static var channel: ChannelService { client }
    static var channelTabs: ChannelTabService { client }
    static var subscribedChannels: SubscribedChannelsService { client }
    static var watch: WatchService { client }
    static var engagement: EngagementService { client }
    static var account: AccountService { client }

    /// Legacy accessor — prefer narrow protocols above for new code.
    static var video: VideoService { client }
}
