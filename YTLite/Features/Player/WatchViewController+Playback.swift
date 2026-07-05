import AVFoundation
import AVKit
import UIKit

// MARK: - Playback

extension WatchViewController {
    func startPlayback() {
        playbackFacade.watchtimeTracker.timeProvider = { [weak self] in
            self?.videoPlayerView?.player?.currentTime().seconds ?? 0
        }
        playbackFacade.start(
            videoId: initialVideo.id,
            apiClient: client,
            cancellationToken: pageLoadToken
        )
    }

    func attachPlayer(
        item: AVPlayerItem,
        minimizeStalling: Bool = true
    ) {
        guard !pageLoadToken.isCancelled else {
            return
        }
        resetPlaybackSurfaces()
        playerSpinner.stopAnimating()
        playerStatusLabel.isHidden = true
        PlaybackBufferPolicy.configure(item: item)
        startObservingPlayerItem(item)
        let player = AVPlayer(playerItem: item)
        PlaybackBufferPolicy.configure(
            player: player,
            waitsToMinimizeStalling: minimizeStalling
        )
        let pv = getOrCreatePlayerView()
        configureSponsorBlock(on: pv)
        playerContainer.bringSubviewToFront(pv)
        pv.attach(player: player)
        player.play()
    }

    func getOrCreatePlayerView() -> VideoPlayerView {
        if let existing = videoPlayerView {
            return existing
        }
        let playerView = VideoPlayerView()
        playerView
            .translatesAutoresizingMaskIntoConstraints
            = false
        playerView.delegate = self
        playerContainer.addSubview(playerView)
        applyEdgeConstraints(playerView, to: playerContainer)
        videoPlayerView = playerView
        playerView.setCaptionTracks(
            captionTracks,
            activeLanguage: activeSubtitleLanguage
        )
        playerView.onCCTapped = { [weak self] in
            self?.showSubtitlePicker()
        }
        return playerView
    }

    func configureSponsorBlock(
        on playerView: VideoPlayerView
    ) {
        sponsorBlock.attach(to: playerView)
        playerView.onTimeUpdate = { [weak self] time in
            self?.sponsorBlock.checkTime(time)
            NowPlayingService.shared.updatePosition(time)
            self?.videoPlayerView?.updateSubtitle(at: time)
        }
        playerView.onSkipTapped = { [weak self] in
            self?.sponsorBlock.skipCurrentSegment()
        }
        if !sponsorBlock.segments.isEmpty {
            playerView.setSponsorSegments(
                sponsorBlock.segments
            )
        }
    }

    func resetPlaybackSurfaces() {
        videoPlayerView?.player?.pause()
        if let existing =
            videoPlayerView?.player?.currentItem {
            stopObservingPlayerItem(existing)
        }
        videoPlayerView?.detach()
        NowPlayingService.shared.endSession()
    }
}
