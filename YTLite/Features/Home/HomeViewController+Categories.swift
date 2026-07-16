import UIKit

// MARK: - Category chips & shelf drain

extension HomeViewController {
    func setupEmptyViews() {
        view.addSubview(errorLabel)
        view.addSubview(signInEmptyView)
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            signInEmptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            signInEmptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            signInEmptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            signInEmptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }

    func setChipBarHidden(_ hidden: Bool) {
        guard isChipBarHidden != hidden else {
            return
        }
        isChipBarHidden = hidden
        UIView.animate(withDuration: 0.22) {
            self.chipBar.alpha = hidden ? 0 : 1
            self.chipBar.transform = hidden
                ? CGAffineTransform(
                    translationX: 0,
                    y: -ChipBarView.preferredHeight
                )
                : .identity
        }
    }

    func setupChipBar() {
        chipBar.setLabels(categories.map { $0.label })
        chipBar.onSelect = { [weak self] index in
            self?.selectCategory(at: index)
        }
        view.addSubview(chipBar)
        NSLayoutConstraint.activate([
            chipBar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            chipBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chipBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        collectionView?.contentInset.top = ChipBarView.preferredHeight
        collectionView?.scrollIndicatorInsets.top = ChipBarView.preferredHeight
    }

    func selectCategory(at index: Int) {
        selectedCategoryIndex = index
        feedGeneration += 1
        resetShelfDrain()
        errorLabel.isHidden = true
        signInEmptyView.isHidden = true
        if let cv = collectionView {
            cv.setContentOffset(
                CGPoint(x: 0, y: -cv.adjustedContentInset.top),
                animated: false
            )
        }
        guard let browseId = categories[index].browseId else {
            showSkeleton()
            loadCachedOrFetchFeed()
            return
        }
        if let cached = categoryCache[browseId] {
            AppLog.home("category \(browseId) cache-hit")
            setPage(cached)
            return
        }
        showSkeleton()
        loadCategory(browseId)
    }

    private func showSkeleton() {
        setPage(FeedPage(videos: [], continuation: nil))
        isLoadingInitial = true
        collectionView?.reloadData()
    }

    func loadCategory(_ browseId: String) {
        let t0 = Date()
        let generation = feedGeneration
        AppLog.home("category \(browseId) fetch start")
        service.fetchCategoryFeed(browseId: browseId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.feedGeneration == generation else {
                    return
                }
                let ms = Int(Date().timeIntervalSince(t0) * 1_000)
                self.spinner.stopAnimating()
                self.endRefreshing()
                switch result {
                case .success(let page):
                    AppLog.home("category done \(ms)ms videos=\(page.videos.count)")
                    self.categoryCache[browseId] = page
                    self.setPage(page)
                case .failure(let err):
                    AppLog.home("category failed \(ms)ms: \(err)")
                    self.setPage(FeedPage(videos: [], continuation: nil))
                    self.errorLabel.isHidden = false
                }
            }
        }
    }

    func resetShelfDrain() {
        shelfQueue = []
        isDrainingShelves = false
        drainTitle = nil
    }

    /// Stashes the page's per-shelf tokens, then backfills the page
    /// continuation from the queue once the section list is exhausted.
    func enqueueShelves(from page: FeedPage) -> FeedPage {
        if let shelves = page.shelfContinuations {
            shelfQueue.append(contentsOf: shelves)
        }
        var page = page
        if isDrainingShelves {
            if page.shelves == nil, !page.videos.isEmpty {
                page.shelves = [
                    FeedShelf(title: drainTitle, count: page.videos.count)
                ]
            }
            // Shelves are topical rows — rotate this shelf's token to
            // the back of the queue so consecutive fetches alternate
            // topics instead of draining one row into a wall of it.
            if let next = page.continuation {
                shelfQueue.append(
                    ShelfContinuation(title: drainTitle, token: next)
                )
                page.continuation = nil
            }
        }
        return backfilled(page)
    }

    func backfilled(_ page: FeedPage) -> FeedPage {
        guard page.continuation == nil, !shelfQueue.isEmpty else {
            return page
        }
        AppLog.home(
            "section list exhausted → draining shelf queue"
                + " (\(shelfQueue.count) left)"
        )
        var page = page
        let next = shelfQueue.removeFirst()
        drainTitle = next.title
        page.continuation = next.token
        isDrainingShelves = true
        return page
    }
}
