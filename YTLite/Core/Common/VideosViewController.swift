import UIKit

/// A titled group of videos rendered as one collection-view section.
struct VideoSection {
    let title: String?
    var videos: [Video]
}

class VideosViewController: UIViewController {
    // MARK: - Type Properties

    static let skeletonCount = 9

    // MARK: - Instance Properties

    var columns: Int { 5 }

    private(set) var sections: [VideoSection] = []
    private(set) var collectionView: UICollectionView?
    let channelViewControllerFactory: (String, String) -> UIViewController
    let videoRouter: VideoRouter
    let spinner = UIActivityIndicatorView(style: .white)
    var isLoadingInitial = true
    var isLoadingMore = false

    private var continuationToken: String?
    private var seenVideoIds: Set<String> = []

    var currentContinuation: String? { continuationToken }
    var videoCount: Int { sections.reduce(0) { $0 + $1.videos.count } }

    init(
        channelViewControllerFactory: @escaping (
            String,
            String
        ) -> UIViewController,
        videoRouter: VideoRouter = .shared
    ) {
        self.channelViewControllerFactory = channelViewControllerFactory
        self.videoRouter = videoRouter
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupSpinner()
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateItemSize()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { [weak self] _ in
            self?.updateItemSize()
            self?.collectionView?
                .collectionViewLayout.invalidateLayout()
        }
    }

    // MARK: - Methods

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 8
        layout.sectionInset = UIEdgeInsets(
            top: 12, left: 8, bottom: 12, right: 8
        )

        let cv = UICollectionView(
            frame: view.bounds,
            collectionViewLayout: layout
        )
        cv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        registerViews(in: cv)
        cv.dataSource = self
        cv.delegate = self
        cv.prefetchDataSource = self

        let refresh = UIRefreshControl()
        refresh.addTarget(
            self,
            action: #selector(handleRefresh),
            for: .valueChanged
        )
        cv.refreshControl = refresh

        view.addSubview(cv)
        collectionView = cv
    }

    private func registerViews(in cv: UICollectionView) {
        cv.register(
            VideoCell.self,
            forCellWithReuseIdentifier: VideoCell.reuseId
        )
        cv.register(
            VideoSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: VideoSectionHeaderView.reuseId
        )
    }

    private func setupSpinner() {
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            spinner.centerYAnchor.constraint(
                equalTo: view.centerYAnchor
            )
        ])
        spinner.startAnimating()
    }

    @objc
    func handleRefresh() {}

    func handleScroll(_ scrollView: UIScrollView) {}

    // Override in subclasses to load next page
    func handleLoadMore() {}

    // Kept in the class body (not the extension) so subclasses can
    // override it.
    func openVideo(_ video: Video) {
        videoRouter.open(
            video: video,
            from: self
        )
    }

    func updateItemSize() {
        guard let collectionView,
              let layout = collectionView
                  .collectionViewLayout
                  as? UICollectionViewFlowLayout
        else {
            return
        }
        let inset = layout.sectionInset.left
            + layout.sectionInset.right
        let spacing = layout.minimumInteritemSpacing
            * CGFloat(max(columns - 1, 0))
        let available = collectionView.bounds.width
            - inset - spacing
        let width = floor(available / CGFloat(columns))
        let height: CGFloat = width * (9.0 / 16.0) + 92
        let newSize = CGSize(
            width: width,
            height: height
        )
        if layout.itemSize != newSize {
            layout.itemSize = newSize
            layout.invalidateLayout()
        }
    }

    @objc
    func applyTheme() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        collectionView?.backgroundColor = theme.background
    }
}

// MARK: - Page Management

extension VideosViewController {
    func video(at indexPath: IndexPath) -> Video {
        sections[indexPath.section].videos[indexPath.item]
    }

    /// Number of videos after the given index path (for the
    /// load-more trigger).
    func videosRemaining(after indexPath: IndexPath) -> Int {
        var remaining = sections[indexPath.section].videos.count
            - indexPath.item - 1
        for section in sections.dropFirst(indexPath.section + 1) {
            remaining += section.videos.count
        }
        return remaining
    }

    func openChannel(for video: Video) {
        guard let channelId = video.channelId else {
            return
        }
        navigationController?.pushViewController(
            channelViewControllerFactory(
                channelId,
                video.channelName
            ),
            animated: true
        )
    }

    func endRefreshing() {
        collectionView?.refreshControl?.endRefreshing()
    }

    /// Splits the page's videos into sections following its shelf
    /// partition, deduplicating against already-shown videos.
    private func makeSections(from page: FeedPage) -> [VideoSection] {
        let shelves = page.shelves
            ?? [FeedShelf(title: nil, count: page.videos.count)]
        var result: [VideoSection] = []
        var index = 0
        for shelf in shelves {
            let end = min(index + shelf.count, page.videos.count)
            let slice = page.videos[index..<end].filter {
                seenVideoIds.insert($0.id).inserted
            }
            index = end
            if !slice.isEmpty {
                result.append(
                    VideoSection(title: shelf.title, videos: slice)
                )
            }
        }
        let rest = page.videos.dropFirst(index).filter {
            seenVideoIds.insert($0.id).inserted
        }
        if !rest.isEmpty {
            result.append(VideoSection(title: nil, videos: rest))
        }
        return result
    }

    func setPage(_ page: FeedPage) {
        isLoadingInitial = false
        seenVideoIds = []
        sections = makeSections(from: page)
        continuationToken = page.continuation
        isLoadingMore = false
        collectionView?.reloadData()
    }

    func appendPage(_ page: FeedPage) {
        let newSections = makeSections(from: page)
        let insertStart = sections.count
        sections.append(contentsOf: newSections)
        continuationToken = page.continuation
        isLoadingMore = false

        if isLoadingInitial {
            isLoadingInitial = false
            collectionView?.reloadData()
        } else if !newSections.isEmpty {
            collectionView?.insertSections(
                IndexSet(insertStart..<sections.count)
            )
        }
    }

    func finishLoadingMore() {
        isLoadingMore = false
    }
}
