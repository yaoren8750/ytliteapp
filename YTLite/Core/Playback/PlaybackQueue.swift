import Foundation

final class PlaybackQueue {
    static let shared = PlaybackQueue()
    private(set) var videos: [Video] = []
    private(set) var playlistTitle: String?

    var hasNext: Bool {
        videos.count > 1
    }

    var currentVideo: Video? {
        videos.first
    }

    /// The upcoming video without advancing — navigation syncs the queue
    /// itself via `seekTo` once the next page loads.
    var nextVideo: Video? {
        hasNext ? videos[1] : nil
    }

    private init() {}

    func setQueue(
        _ videos: [Video],
        title: String? = nil
    ) {
        self.videos = videos
        self.playlistTitle = title
    }

    func seekTo(videoId: String) {
        guard let idx = videos.firstIndex(
            where: { $0.id == videoId }
        ) else {
            return
        }
        if idx > 0 {
            videos.removeFirst(idx)
        }
    }

    func clear() {
        videos = []
        playlistTitle = nil
    }
}
