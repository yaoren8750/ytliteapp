import UIKit

// MARK: - UICollectionViewDataSource

extension VideosViewController: UICollectionViewDataSource {
    func numberOfSections(
        in collectionView: UICollectionView
    ) -> Int {
        isLoadingInitial ? 1 : sections.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        isLoadingInitial
            ? VideosViewController.skeletonCount
            : sections[section].videos.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView
            .dequeueReusableCell(
                withReuseIdentifier: VideoCell.reuseId,
                for: indexPath
            ) as? VideoCell
        else {
            return UICollectionViewCell()
        }
        cell.forceGridLayout = true
        if isLoadingInitial {
            cell.configureSkeleton()
            return cell
        }
        let video = video(at: indexPath)
        cell.configure(with: video)
        cell.onChannelTap = { [weak self] in
            self?.openChannel(for: video)
        }
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                  ofKind: kind,
                  withReuseIdentifier: VideoSectionHeaderView.reuseId,
                  for: indexPath
              ) as? VideoSectionHeaderView
        else {
            return UICollectionReusableView()
        }
        let title = isLoadingInitial
            ? nil : sections[indexPath.section].title
        header.configure(title: title)
        return header
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension VideosViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard !isLoadingInitial else {
            return
        }
        openVideo(video(at: indexPath))
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard !isLoadingInitial,
              !isLoadingMore,
              currentContinuation != nil,
              videosRemaining(after: indexPath) < 4
        else {
            return
        }
        isLoadingMore = true
        handleLoadMore()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        guard !isLoadingInitial,
              section < sections.count,
              sections[section].title != nil
        else {
            return .zero
        }
        return CGSize(
            width: collectionView.bounds.width,
            height: VideoSectionHeaderView.height
        )
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        // The default per-section inset would double the vertical gap
        // between stacked sections — only the first keeps a top inset.
        UIEdgeInsets(
            top: section == 0 ? 12 : 0,
            left: 8,
            bottom: 12,
            right: 8
        )
    }

    func scrollViewDidScroll(
        _ scrollView: UIScrollView
    ) {
        handleScroll(scrollView)
    }
}
