import UIKit

class SearchViewController: UIViewController {
    let service: SearchService
    let channelViewControllerFactory: (
        String,
        String
    ) -> UIViewController
    let videoRouter: VideoRouter
    private(set) var results: [Video] = []
    private var lastQuery: String = ""
    private var activeSearchQuery: String?
    private var searchCancellationToken = CancellationToken()
    private var continuationToken: String?
    private var isLoadingNextPage = false

    private let searchBar = UISearchBar()
    let tableView = UITableView()
    private let refreshControl = UIRefreshControl()

    init(
        service: SearchService,
        channelViewControllerFactory: @escaping (
            String,
            String
        ) -> UIViewController,
        videoRouter: VideoRouter = .shared
    ) {
        self.service = service
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
        title = "Search"
        setupSearchBar()
        setupTableView()
        applyTheme()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search YouTube"
        searchBar.text = lastQuery.isEmpty ? nil : lastQuery
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            searchBar.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            searchBar.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            )
        ])
    }

    private func setupTableView() {
        tableView.register(
            SubscriptionVideoCell.self,
            forCellReuseIdentifier: SubscriptionVideoCell.reuseId
        )
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 320
        tableView.separatorInset = UIEdgeInsets(
            top: 0, left: 12, bottom: 0, right: 12
        )
        tableView.translatesAutoresizingMaskIntoConstraints = false
        refreshControl.addTarget(
            self,
            action: #selector(handleRefresh),
            for: .valueChanged
        )
        tableView.refreshControl = refreshControl
        view.addSubview(tableView)
        activateTableConstraints()
    }

    private func activateTableConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(
                equalTo: searchBar.bottomAnchor
            ),
            tableView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            tableView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            tableView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
    }

    @objc
    private func applyTheme() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        tableView.backgroundColor = theme.background
        tableView.separatorColor = theme.separator
        searchBar.barStyle = theme.barStyle
        searchBar.backgroundColor = theme.background
        searchBar.keyboardAppearance = theme.isDark ? .dark : .default
        tableView.reloadData()
    }

    @objc
    private func handleRefresh() {
        guard !lastQuery.isEmpty else {
            refreshControl.endRefreshing()
            return
        }
        search(query: lastQuery)
    }
}

// MARK: - Search flow

extension SearchViewController {
    private func search(query: String) {
        let normalizedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedQuery.isEmpty else {
            clearSearchResults()
            return
        }

        let cancellationToken = beginSearch(for: normalizedQuery)
        service.search(
            query: normalizedQuery,
            continuation: nil,
            cancellationToken: cancellationToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                guard self.shouldApplyResult(
                    for: normalizedQuery,
                    cancellationToken: cancellationToken
                ) else {
                    return
                }
                self.applySearchResult(result, append: false)
            }
        }
    }

    func loadNextPage() {
        guard let token = continuationToken,
              !isLoadingNextPage,
              !lastQuery.isEmpty else {
            return
        }
        isLoadingNextPage = true
        let query = lastQuery
        let cancellationToken = searchCancellationToken
        service.search(
            query: query,
            continuation: token,
            cancellationToken: cancellationToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.isLoadingNextPage = false
                guard self.shouldApplyResult(
                    for: query,
                    cancellationToken: cancellationToken
                ) else {
                    return
                }
                self.applySearchResult(result, append: true)
            }
        }
    }

    private func beginSearch(for query: String) -> CancellationToken {
        searchCancellationToken.cancel()
        let cancellationToken = CancellationToken()
        searchCancellationToken = cancellationToken
        lastQuery = query
        activeSearchQuery = query
        return cancellationToken
    }

    private func applySearchResult(
        _ result: Result<SearchPage, Error>,
        append: Bool
    ) {
        refreshControl.endRefreshing()
        switch result {
        case .success(let page):
            results = append ? results + page.videos : page.videos
            continuationToken = page.continuation
            tableView.reloadData()
        case .failure(let error):
            // Silently keep the current page when a next-page load fails.
            if !append {
                presentSearchError(error)
            }
        }
    }

    private func presentSearchError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: "OK", style: .default)
        )
        present(alert, animated: true)
    }

    private func shouldApplyResult(
        for query: String,
        cancellationToken: CancellationToken
    ) -> Bool {
        searchCancellationToken === cancellationToken
            && activeSearchQuery == query
            && !cancellationToken.isCancelled
    }

    private func clearSearchResults() {
        searchCancellationToken.cancel()
        searchCancellationToken = CancellationToken()
        activeSearchQuery = nil
        lastQuery = ""
        results = []
        continuationToken = nil
        isLoadingNextPage = false
        refreshControl.endRefreshing()
        tableView.reloadData()
    }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else {
            return
        }
        searchBar.resignFirstResponder()
        search(query: query)
    }

    func searchBar(
        _ searchBar: UISearchBar,
        textDidChange searchText: String
    ) {
        if searchText.isEmpty {
            clearSearchResults()
        }
    }
}
