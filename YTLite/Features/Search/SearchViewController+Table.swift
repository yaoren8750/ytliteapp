import UIKit

// MARK: - Results table

extension SearchViewController: UITableViewDataSource {
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        results.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SubscriptionVideoCell.reuseId,
            for: indexPath
        ) as? SubscriptionVideoCell else {
            return UITableViewCell()
        }
        let video = results[indexPath.row]
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

extension SearchViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        let video = results[indexPath.row]
        videoRouter.open(video: video, from: self)
    }

    func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard indexPath.row >= results.count - 4 else {
            return
        }
        loadNextPage()
    }
}
