import UIKit

class HomeViewController: VideosViewController {
    let service: FeedService
    private let cache: AppCache
    /// Per-shelf continuation queue collected from parsed pages. When the
    /// section list runs out (~100 videos), pages get their continuation
    /// backfilled from here so scrolling keeps going (the Recommended
    /// shelf alone is effectively endless).
    var shelfQueue: [ShelfContinuation] = []
    /// True once pagination switched from the section list to shelf
    /// tokens. Failures then skip to the next shelf instead of
    /// retrying (a dead shelf token would stall the scroll forever).
    var isDrainingShelves = false
    /// Title of the shelf currently being drained — labels its pages.
    var drainTitle: String?
    let categories = HomeCategory.all
    var selectedCategoryIndex = 0
    /// Bumped on every category switch / refresh; async completions
    /// compare it so a stale response can't overwrite the new feed.
    var feedGeneration = 0
    /// Session-lifetime cache so tab switches don't refetch.
    var categoryCache: [String: FeedPage] = [:]
    var isChipBarHidden = false
    private var lastScrollY: CGFloat = 0
    lazy var chipBar = ChipBarView()

    override var columns: Int {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return 1
        }
        let width = view.bounds.width
        if width < 500 {
            return 1
        }
        return width > view.bounds.height ? 3 : 2
    }

    lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.text = "Couldn't load feed\nPull down to retry"
        label.textColor = .lightGray
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    lazy var signInEmptyView: SignInEmptyStateView = {
        let emptyView = SignInEmptyStateView(message: "Sign in to see your recommendations")
        emptyView.isHidden = true
        emptyView.onSignIn = { [weak self] in self?.toolbarOpenProfile() }
        return emptyView
    }()

    init(
        service: FeedService,
        cache: AppCache = .shared,
        channelViewControllerFactory: @escaping (
            String,
            String
        ) -> UIViewController,
        videoRouter: VideoRouter = .shared
    ) {
        self.service = service
        self.cache = cache
        super.init(
            channelViewControllerFactory: channelViewControllerFactory,
            videoRouter: videoRouter
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Home"
        AppLog.home("viewDidLoad")
        setupEmptyViews()
        setupChipBar()
        setupToolbar()
        observeSignOut()
        observeTokenRefresh()
        loadCachedOrFetchFeed()
    }

    private func observeSignOut() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSignOut),
            name: .userDidSignOut,
            object: nil
        )
    }

    func loadCachedOrFetchFeed() {
        cache.loadHomeFeed { [weak self] cachedPage in
            guard let self else {
                return
            }
            if let cachedPage {
                AppLog.home("cache-hit → showing \(cachedPage.videos.count) videos instantly")
                self.isLoadingInitial = false
                self.spinner.stopAnimating()
                self.resetShelfDrain()
                self.setPage(self.enqueueShelves(from: cachedPage))
            } else {
                AppLog.home("no cache → loading from network")
                self.loadFeed()
            }
        }
    }

    private func setupToolbar() {
        ToolbarManager.shared.install(in: self)
    }

    @objc
    private func handleSignOut() {
        ScreenVisitTracker.reset()
        cache.clearHomeFeed()
        categoryCache = [:]
        setPage(FeedPage(videos: [], continuation: nil))
        toolbarRefreshProfileButton()
        chipBar.setSelected(0)
        selectCategory(at: 0)
    }

    override func handleRefresh() {
        feedGeneration += 1
        if let browseId = categories[selectedCategoryIndex].browseId {
            categoryCache[browseId] = nil
            loadCategory(browseId)
        } else {
            cache.clearHomeFeed()
            loadFeed()
        }
    }

    override func handleScroll(_ scrollView: UIScrollView) {
        let top = scrollView.adjustedContentInset.top
        let y = scrollView.contentOffset.y + top
        defer {
            lastScrollY = y
        }
        if y <= 8 {
            setChipBarHidden(false)
        } else if y - lastScrollY > 4 {
            setChipBarHidden(true)
        } else if y - lastScrollY < -4 {
            setChipBarHidden(false)
        }
    }

    private func showFeedError() {
        if OAuthClient.shared.isAnonymous {
            signInEmptyView.isHidden = false
        } else {
            errorLabel.isHidden = false
        }
    }

    func loadFeed() {
        let t0 = Date()
        AppLog.home("network fetch start")
        errorLabel.isHidden = true
        signInEmptyView.isHidden = true
        resetShelfDrain()
        let generation = feedGeneration
        service.fetchHomeFeed { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.feedGeneration == generation else {
                    return
                }
                let ms = Int(Date().timeIntervalSince(t0) * 1_000)
                self.spinner.stopAnimating()
                self.endRefreshing()
                switch result {
                case .success(let page):
                    AppLog.home("network fetch done \(ms)ms videos=\(page.videos.count)")
                    self.cache.setHomeFeed(page)
                    self.setPage(self.enqueueShelves(from: page))
                case .failure(let err):
                    AppLog.home("network fetch failed \(ms)ms: \(err)")
                    self.setPage(FeedPage(videos: [], continuation: nil))
                    self.showFeedError()
                }
            }
        }
    }

    override func handleLoadMore() {
        guard let continuation = currentContinuation else {
            finishLoadingMore()
            return
        }

        let generation = feedGeneration
        service.fetchNextPage(continuation: continuation) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.feedGeneration == generation else {
                    return
                }
                switch result {
                case .success(let page):
                    self.appendPage(self.enqueueShelves(from: page))
                case .failure where self.isDrainingShelves:
                    self.appendPage(self.backfilled(
                        FeedPage(videos: [], continuation: nil)
                    ))
                case .failure:
                    self.finishLoadingMore()
                }
            }
        }
    }
}
