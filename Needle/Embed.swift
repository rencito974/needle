import Foundation

@MainActor
enum Embed {
    private static var thumbs: [String: String] = [:]
    private static let agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    static func playlist(_ id: String) async throws -> [Track] {
        guard let url = URL(string: "https://open.spotify.com/embed/playlist/\(id)") else { return [] }
        var request = URLRequest(url: url)
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(decoding: data, as: UTF8.self)
        guard let tag = html.range(of: "id=\"__NEXT_DATA__\""),
              let open = html[tag.upperBound...].firstIndex(of: ">"),
              let close = html.range(of: "</script>", range: open..<html.endIndex) else {
            throw URLError(.cannotParseResponse)
        }
        let json = Data(html[html.index(after: open)..<close.lowerBound].utf8)
        let page = try JSONDecoder().decode(EmbedPage.self, from: json)
        return (page.props.pageProps.state.data.entity.trackList ?? []).compactMap(\.value).map(\.track)
    }

    static func thumbnail(_ trackID: String) async -> String? {
        if let hit = thumbs[trackID] {
            return hit
        }
        guard let url = URL(string: "https://open.spotify.com/oembed?url=https://open.spotify.com/track/\(trackID)"),
              let result = try? await URLSession.shared.data(from: url),
              let reply = try? JSONDecoder().decode(OEmbed.self, from: result.0),
              let thumb = reply.thumbnail_url else {
            return nil
        }
        thumbs[trackID] = thumb
        return thumb
    }
}

private struct OEmbed: Decodable {
    let thumbnail_url: String?
}

private struct EmbedTrack: Decodable {
    let uri: String
    let title: String
    let subtitle: String?
    let duration: Int?
    let isExplicit: Bool?

    var track: Track {
        Track(
            id: uri.split(separator: ":").last.map(String.init),
            name: title,
            uri: uri,
            durationMs: duration ?? 0,
            artists: (subtitle ?? "").components(separatedBy: ", ").map { Artist(id: nil, name: $0, uri: nil, images: nil) },
            album: nil,
            isLocal: false,
            explicit: isExplicit
        )
    }
}

private struct EmbedPage: Decodable {
    let props: Props

    struct Props: Decodable {
        let pageProps: PageProps
    }

    struct PageProps: Decodable {
        let state: Status
    }

    struct Status: Decodable {
        let data: Payload
    }

    struct Payload: Decodable {
        let entity: Entity
    }

    struct Entity: Decodable {
        let trackList: [Lenient<EmbedTrack>]?
    }
}
