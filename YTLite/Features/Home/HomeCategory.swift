import Foundation

/// A chip on the home screen. `browseId == nil` is the personalized
/// home feed; the rest are one-shot TV destination pages (no
/// pagination — the server returns the whole page at once).
struct HomeCategory {
    static let all: [HomeCategory] = [
        HomeCategory(label: "All", browseId: nil),
        HomeCategory(label: "Live", browseId: BrowseID.liveDestination),
        HomeCategory(label: "News", browseId: BrowseID.newsDestination),
        HomeCategory(label: "Gaming", browseId: BrowseID.gamingDestination),
        HomeCategory(label: "Sports", browseId: BrowseID.sportsDestination),
        HomeCategory(label: "Learning", browseId: BrowseID.learningDestination),
        HomeCategory(label: "Fashion", browseId: BrowseID.fashionDestination)
    ]

    let label: String
    let browseId: String?
}
