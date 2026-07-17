import UIKit

/// A single row in a `PlayerMenuOverlay`.
struct PlayerMenuItem {
    let title: String
    var isDestructive = false
    let handler: (() -> Void)?
}

/// The one menu UI for all player menus, inline and fullscreen alike.
/// A system alert could not serve the fullscreen case: there the player view
/// is attached directly to the window, above anything the watch controller
/// presents — and in iPhone landscape it is rotated by a transform, which a
/// presented alert would not follow. Hosting the menu in the player's own
/// hierarchy solves both; dismissal is a tap outside the panel.
final class PlayerMenuOverlay: UIView {
    /// `overVideo` keeps the player's dark chrome regardless of app theme;
    /// `themed` follows `ThemeManager` for menus hosted over regular UI.
    enum Style {
        case overVideo
        case themed
    }

    private var items: [PlayerMenuItem] = []
    private var style: Style = .overVideo
    private let panel = UIView()

    private var panelColor: UIColor {
        style == .overVideo
            ? UIColor.black.withAlphaComponent(0.9)
            : ThemeManager.shared.surface
    }

    private var titleColor: UIColor {
        style == .overVideo
            ? UIColor.white.withAlphaComponent(0.6)
            : ThemeManager.shared.secondaryText
    }

    private var rowColor: UIColor {
        style == .overVideo ? .white : ThemeManager.shared.primaryText
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleBackgroundTap(_:))
        )
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    static func show(
        in host: UIView,
        title: String,
        items: [PlayerMenuItem],
        style: Style = .overVideo
    ) {
        let overlay = PlayerMenuOverlay(frame: host.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.items = items
        overlay.style = style
        overlay.backgroundColor = UIColor.black
            .withAlphaComponent(style == .overVideo ? 0.4 : 0.25)
        overlay.buildContent(title: title)
        host.addSubview(overlay)
        overlay.alpha = 0
        UIView.animate(withDuration: 0.15) {
            overlay.alpha = 1
        }
    }

    // MARK: - Layout

    private func buildContent(title: String) {
        panel.backgroundColor = panelColor
        panel.layer.cornerRadius = 10
        panel.layer.masksToBounds = true
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = titleColor
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)
        let scroll = makeRowsScrollView()
        panel.addSubview(scroll)
        activatePanelConstraints(titleLabel: titleLabel, scroll: scroll)
    }

    private func makeRowsScrollView() -> UIScrollView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (index, item) in items.enumerated() {
            stack.addArrangedSubview(makeRow(item: item, index: index))
        }
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        let content = scroll.contentLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
        // Size the scroll view to its rows; breaks against the height caps
        // in `activatePanelConstraints` when the list is long.
        let fit = scroll.heightAnchor.constraint(equalTo: stack.heightAnchor)
        fit.priority = .defaultHigh
        fit.isActive = true
        return scroll
    }

    private func makeRow(item: PlayerMenuItem, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = index
        button.setTitle(item.title, for: .normal)
        button.setTitleColor(item.isDestructive ? .systemRed : rowColor, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        button.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
        return button
    }

    private func activatePanelConstraints(titleLabel: UILabel, scroll: UIScrollView) {
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: 280),
            panel.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, constant: -32),
            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -8),
            scroll.heightAnchor.constraint(lessThanOrEqualToConstant: 264)
        ])
    }

    // MARK: - Actions

    @objc
    private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        guard !panel.frame.contains(location) else {
            return
        }
        dismiss()
    }

    @objc
    private func rowTapped(_ button: UIButton) {
        guard button.tag < items.count else {
            return
        }
        let handler = items[button.tag].handler
        dismiss()
        handler?()
    }

    private func dismiss() {
        UIView.animate(
            withDuration: 0.15,
            animations: { self.alpha = 0 },
            completion: { _ in self.removeFromSuperview() }
        )
    }
}
