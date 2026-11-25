import Foundation

struct Shortcut: Hashable, Identifiable {
    let id: String
    let route: Route
    let title: String
    let subtitle: String
    let image: String?
    var round = false
}

@MainActor
@Observable
final class Shelf {
    let api: Spotify
    private(set) var playlists: [Playlist] = []
    private(set) var recent: [Track] = []
    private(set) var shortcuts: [Shortcut] = []
    private(set) var loaded = false

    init(api: Spotify) {
        self.api = api
    }

    func load(force: Bool = false) async {
        guard force || !loaded else { return }
        var fresh: [Playlist] = []
        do {
            try await api.playlists { fresh += $0 }
            playlists = fresh
        } catch {
            if !fresh.isEmpty {
                playlists = fresh
            }
        }
        if let plays = try? await api.recentPlays() {
            var seen = Set<String>()
            recent = plays.compactMap(\.track).filter { seen.insert($0.uri).inserted }
            shortcuts = await gather(plays)
        }
        loaded = true
    }

    private func gather(_ plays: [Played]) async -> [Shortcut] {
        var seen = Set<String>()
        var found: [Shortcut] = []
        for play in plays {
            guard let context = play.context, seen.insert(context.uri).inserted else { continue }
            switch context.type ?? "" {
            case "playlist":
                if let list = playlists.first(where: { $0.uri == context.uri }) {
                    found.append(Shortcut(id: context.uri, route: .playlist(list), title: list.name, subtitle: list.owner.displayName ?? "Playlist", image: list.images?.best(for: 300)))
                }
            case "album":
                if let album = play.track?.album, let id = album.id {
                    let by = (album.artists ?? []).map(\.name).joined(separator: ", ")
                    found.append(Shortcut(id: context.uri, route: .album(id), title: album.name, subtitle: by, image: album.images?.best(for: 300)))
                }
            case "artist":
                if let id = context.uri.split(separator: ":").last.map(String.init) {
                    let artist = try? await api.artist(id)
                    let name = artist?.name ?? play.track?.lead ?? ""
                    found.append(Shortcut(id: context.uri, route: .artist(id), title: name, subtitle: "Artist", image: artist?.images?.best(for: 300), round: true))
                }
            case "collection":
                found.append(Shortcut(id: context.uri, route: .liked, title: "Liked Songs", subtitle: "Your library", image: nil))
            default:
                break
            }
            if found.count == 10 {
                break
            }
        }
        return found
    }
}
