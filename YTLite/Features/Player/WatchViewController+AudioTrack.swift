import UIKit

// MARK: - Audio-track (dub) picker
//
// Fully source-driven, like the quality picker: the active `VideoSource` owns
// its audio tracks and how switching works. No source-specific logic here.

extension WatchViewController {
    func showAudioTrackPicker() {
        guard let source = playbackFacade.activeVideoSource,
              source.supportsAudioTrackSelection else {
            return
        }
        let items = source.availableAudioTracks.map { track -> PlayerMenuItem in
            let isCurrent = track == source.currentAudioTrack
            let title = isCurrent
                ? "✓ \(track.displayName)" : track.displayName
            return PlayerMenuItem(title: title) { [weak self] in
                self?.selectAudioTrack(track, source: source)
            }
        }
        presentPlayerMenu(title: "Audio track", items: items)
    }

    private func selectAudioTrack(
        _ track: AudioTrack,
        source: VideoSource
    ) {
        guard track != source.currentAudioTrack else {
            return
        }
        let resumeTime = videoPlayerView?.player?.currentTime()
        playerStatusLabel.text = "Loading \(track.displayName)..."
        playerStatusLabel.isHidden = false
        source.selectAudioTrack(track) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let prepared):
                    self?.attachPrepared(prepared, resumeAt: resumeTime)
                case .failure:
                    self?.showPlaybackError("Audio track switch failed.")
                }
            }
        }
    }
}
