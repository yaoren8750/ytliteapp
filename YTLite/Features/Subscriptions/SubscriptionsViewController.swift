import UIKit

class SubscriptionsViewController: UIViewController {
    static let skeletonCount = 6
    let service: FeedService
    let cache: AppCache
    let channelViewControllerFactory: (
        String,
        String
    ) -> ChannelViewController
    let videoRouter: VideoRouter
    var videos: [Video] = []
    var continuationToken: String?
    var isLoadingMore = false
    var seenVideoIds: Set<String> = []
    var sortDatesByVideoId: [String: Date] = [:]
    let tableView = UITableView()
    let spinner = UIActivityIndicatorView(style: .white)
    var isLoadingInitial = true
    var signInPrompt: SignInEmptyStateView?

    init(
        service: FeedService,
        cache: AppCache = .shared,
        channelViewControllerFactory: @escaping (
            String,
            String
        ) -> ChannelViewController,
        videoRouter: VideoRouter = .shared
    ) {
        self.service = service
        self.cache = cache
        self.channelViewControllerFactory = channelViewControllerFactory
        self.videoRouter = videoRouter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Subscriptions"
        AppLog.subs("viewDidLoad")
        setupTableView()
        setupSpinner()
        setupSignInPrompt()
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowShortsChange),
            name: .showShortsSettingDidChange,
            object: nil
        )
        ToolbarManager.shared.install(in: self)
        observeTokenRefresh()
        loadInitialContent()
    }

    @objc
    func applyTheme() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        tableView.backgroundColor = theme.background
        tableView.separatorColor = theme.separator
        tableView.reloadData()
    }

    @objc
    func handleRefresh() {
        cache.clearSubscriptionsFeed()
        loadFeed()
    }

    @objc
    func handleShowShortsChange() {
        cache.clearSubscriptionsFeed()
        loadFeed()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        logVisibleVideos()
    }
}

extension SubscriptionsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isLoadingInitial ? SubscriptionsViewController.skeletonCount : videos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SubscriptionVideoCell.reuseId,
            for: indexPath
        ) as? SubscriptionVideoCell else {
            return UITableViewCell()
        }
        if isLoadingInitial {
            cell.configureSkeleton()
            return cell
        }
        let video = videos[indexPath.row]
        cell.configure(with: video)
        cell.onChannelTap = { [weak self] in
            guard let self else {
                return
            }
            guard let channelId = video.channelId else {
                return
            }
            self.navigationController?.pushViewController(
                self.channelViewControllerFactory(
                    channelId,
                    video.channelName
                ),
                animated: true
            )
        }
        return cell
    }
}

extension SubscriptionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isLoadingInitial else {
            return
        }
        let video = videos[indexPath.row]
        videoRouter.open(video: video, from: self)
    }

    func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard !isLoadingInitial,
              !isLoadingMore,
              continuationToken != nil,
              indexPath.row >= videos.count - 4
        else { return }

        isLoadingMore = true
        loadMore()
    }
}
