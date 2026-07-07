import Foundation

// MARK: - Pivot Parsing (Mix / Playlist)

extension InnertubeClient {
    static func parsePivotPlaylist(
        json: [String: Any],
        currentVideoId: String
    )
        -> (title: String, videos: [Video])? {
        // The pivot now carries generic 3-item suggestion shelves for EVERY
        // video (server change, 2026-07). Only a shelf that contains the
        // currently watched video is an active playlist/mix queue — those
        // come from watchNext requests carrying a playlistId.
        for section in pivotSections(from: json) {
            let videos = extractPivotVideos(from: section)
            guard videos.contains(where: { $0.id == currentVideoId }) else {
                continue
            }
            return (extractPivotTitle(from: section), videos)
        }
        return nil
    }
}

// MARK: - Private Helpers

private extension InnertubeClient {
    static func pivotSections(
        from json: [String: Any]
    )
        -> [[String: Any]] {
        json.digArray(
            "contents",
            "singleColumnWatchNextResults",
            "pivot",
            "sectionListRenderer",
            "contents"
        ) ?? []
    }

    static func extractPivotVideos(
        from section: [String: Any]
    )
        -> [Video] {
        let shelf = section["shelfRenderer"]
            as? [String: Any]
        let content = shelf?["content"]
            as? [String: Any]
        let horizontal = content?[
            "horizontalListRenderer"
        ] as? [String: Any]
        let items = horizontal?["items"]
            as? [[String: Any]] ?? []
        return items.compactMap { item in
            guard let tile = item["tileRenderer"]
                as? [String: Any]
            else {
                return nil
            }
            return parseTileRenderer(tile)
        }
    }

    static func extractPivotTitle(
        from section: [String: Any]
    )
        -> String {
        let shelf = section["shelfRenderer"]
            as? [String: Any]
        // Current responses put the header under `headerRenderer`;
        // older ones used `header`.
        let header = shelf?["headerRenderer"] as? [String: Any]
            ?? shelf?["header"] as? [String: Any]
        let titleRenderer = header?[
            "playlistShelfHeaderRenderer"
        ] as? [String: Any]
        return simpleText(
            from: titleRenderer?["title"]
        ) ?? "Mix"
    }
}
