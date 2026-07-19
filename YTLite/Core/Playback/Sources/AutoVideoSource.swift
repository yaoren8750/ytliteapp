import Foundation

/// Composite "Auto" strategy source: tries a fast primary source first and, on
/// any load failure, transparently retries with a fallback source. Quality
/// state is delegated to whichever inner source is active, so the player shell
/// keeps talking to a single `VideoSource`.
///
/// Audio tracks (dubs) are the in-place source switch this composite exists
/// for: the primary (android_vr) never lists dubs, so after it starts playing
/// the fallback is probed in the background for metadata only, its tracks are
/// surfaced through this facade, and picking one rebuilds playback on the
/// fallback and makes it the active source.
final class AutoVideoSource: VideoSource {
    private static let noTrackError = NSError(
        domain: "AutoVideoSource",
        code: 0,
        userInfo: [NSLocalizedDescriptionKey: "Audio track unavailable"]
    )

    private let primary: VideoSource
    private let makeFallback: () -> VideoSource
    /// The inner source currently answering playback/quality questions.
    private var active: VideoSource
    /// Lazily created fallback instance — shared between the background dub
    /// probe and a later switch, so the probed /player info is built on
    /// directly instead of being fetched twice.
    private var fallback: VideoSource?

    var kind: VideoSourceKind { active.kind }
    var supportsQualitySelection: Bool { active.supportsQualitySelection }
    var availableQualities: [VideoQuality] { active.availableQualities }
    var currentQuality: VideoQuality? { active.currentQuality }
    var currentCodecs: String? { active.currentCodecs }
    var supportsAudioTrackSelection: Bool { availableAudioTracks.count > 1 }
    /// The active source's tracks, or the fallback's probed ones while the
    /// primary (which never lists dubs) is playing.
    var availableAudioTracks: [AudioTrack] {
        let tracks = active.availableAudioTracks
        return tracks.isEmpty ? (fallback?.availableAudioTracks ?? []) : tracks
    }
    /// While the primary plays, the fallback's probe state answers — it
    /// marks the ORIGINAL track current, which is what the primary
    /// (android_vr) always plays.
    var currentAudioTrack: AudioTrack? {
        active.currentAudioTrack ?? fallback?.currentAudioTrack
    }

    init(primary: VideoSource, makeFallback: @escaping () -> VideoSource) {
        self.primary = primary
        self.makeFallback = makeFallback
        active = primary
    }

    func loadPlayback(
        videoId: String,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        active = primary
        primary.loadPlayback(
            videoId: videoId, cancellation: cancellation
        ) { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .success:
                self.probeFallbackAudioTracks(
                    videoId: videoId, cancellation: cancellation
                )
                completion(result)
            case .failure(let error):
                guard cancellation?.isCancelled != true else {
                    completion(result)
                    return
                }
                AppLog.player(
                    "auto: \(self.primary.kind) failed (\(error)), falling back"
                )
                self.loadFallback(
                    videoId: videoId,
                    cancellation: cancellation,
                    completion: completion
                )
            }
        }
    }

    func selectQuality(
        _ quality: VideoQuality,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        active.selectQuality(quality, completion: completion)
    }

    /// Delegates when the active source owns the track; otherwise rebuilds on
    /// the probed fallback and promotes it to active — only on success, so a
    /// failed switch leaves the current playback untouched.
    func selectAudioTrack(
        _ track: AudioTrack,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        if active.availableAudioTracks.contains(track) {
            active.selectAudioTrack(track, completion: completion)
            return
        }
        guard let fallback,
              fallback.availableAudioTracks.contains(track) else {
            completion(.failure(Self.noTrackError))
            return
        }
        AppLog.player(
            "auto: switching to \(fallback.kind) for audio track \(track.id)"
        )
        fallback.selectAudioTrack(track) { [weak self] result in
            if case .success = result {
                self?.active = fallback
            }
            completion(result)
        }
    }

    // MARK: - Private

    /// Background metadata probe — no pot mint, no playback preparation; the
    /// menu simply gains an "Audio track" entry once tracks land.
    private func probeFallbackAudioTracks(
        videoId: String, cancellation: CancellationToken?
    ) {
        guard cancellation?.isCancelled != true else {
            return
        }
        let source = fallback ?? makeFallback()
        fallback = source
        source.probeAudioTracks(videoId: videoId) { tracks in
            guard !tracks.isEmpty else {
                return
            }
            AppLog.player("auto: probe found \(tracks.count) audio tracks")
        }
    }

    private func loadFallback(
        videoId: String,
        cancellation: CancellationToken?,
        completion: @escaping (Result<PreparedPlayback, Error>) -> Void
    ) {
        let source = fallback ?? makeFallback()
        fallback = source
        active = source
        source.loadPlayback(
            videoId: videoId,
            cancellation: cancellation,
            completion: completion
        )
    }
}
