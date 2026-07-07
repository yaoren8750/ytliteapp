import UIKit

// MARK: - Autoplay

extension WatchViewController {
    func showAutoplayOverlay(for video: Video) {
        AppLog.player(
            "autoplay overlay: showing for \(video.id),"
                + " fullscreen=\(videoPlayerView?.isFullscreen == true)"
        )
        autoplayOverlay?.removeFromSuperview()
        let overlay = makeAutoplayOverlay(for: video)
        if let pv = videoPlayerView, pv.isFullscreen {
            overlay.translatesAutoresizingMaskIntoConstraints = true
            overlay.frame = pv.bounds
            overlay.autoresizingMask = [
                .flexibleWidth, .flexibleHeight
            ]
            pv.addSubview(overlay)
        } else {
            overlay
                .translatesAutoresizingMaskIntoConstraints
                = false
            playerContainer.addSubview(overlay)
            applyEdgeConstraints(
                overlay,
                to: playerContainer
            )
        }
        autoplayOverlay = overlay
        UIView.animate(withDuration: 0.25) {
            overlay.alpha = 1
        }
        overlay.startCountdown()
    }

    private func makeAutoplayOverlay(
        for video: Video
    ) -> AutoplayOverlayView {
        let overlay = AutoplayOverlayView(
            nextVideo: video,
            countdownSecs: 5
        )
        overlay.alpha = 0
        overlay.onPlay = { [weak self] in
            self?.dismissAutoplayOverlay()
            self?.navigateTo(video)
        }
        overlay.onCancel = { [weak self] in
            self?.dismissAutoplayOverlay()
        }
        return overlay
    }

    func applyEdgeConstraints(
        _ child: UIView,
        to parent: UIView
    ) {
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(
                equalTo: parent.topAnchor
            ),
            child.leadingAnchor.constraint(
                equalTo: parent.leadingAnchor
            ),
            child.trailingAnchor.constraint(
                equalTo: parent.trailingAnchor
            ),
            child.bottomAnchor.constraint(
                equalTo: parent.bottomAnchor
            )
        ])
    }

    func dismissAutoplayOverlay() {
        guard let overlay = autoplayOverlay else {
            return
        }
        autoplayOverlay = nil
        UIView.animate(
            withDuration: 0.2,
            animations: { overlay.alpha = 0 },
            completion: { _ in
                overlay.removeFromSuperview()
            }
        )
    }
}
