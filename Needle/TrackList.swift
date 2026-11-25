import SwiftUI

private struct TitleSpot: PreferenceKey {
    static let defaultValue: CGFloat = 1000

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct TrackList: View {
    let route: Route
    @Environment(Player.self) private var player
    @State private var tracks: [Track] = []
    @State private var title = ""
    @State private var byline = ""
    @State private var meta = ""
    @State private var image: String?
    @State private var context: String?
    @State private var locked = false
    @State private var embedded = false
    @State private var loading = true
    @State private var showTitle = false

    private var isAlbum: Bool {
        if case .album = route { return true }
        return false
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                header
                if locked {
                    Text("Couldn't load the songs, but Play and Shuffle still work")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                }
                ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                    VStack(spacing: 0) {
                        TrackRow(track: track, art: !isAlbum, number: isAlbum ? index + 1 : nil)
                            .onTapGesture { play(from: index) }
                        Divider()
                            .padding(.leading, isAlbum ? 40 : 60)
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 8)
                }
                if loading {
                    ProgressView()
                        .padding(.vertical, 24)
                } else if !tracks.isEmpty {
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(showTitle ? title : "")
        .navigationBarTitleDisplayMode(.inline)
        .onPreferenceChange(TitleSpot.self) { value in
            showTitle = value < 104
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(spacing: 0) {
            Group {
                if route == .liked {
                    LikedTile(size: 250, radius: 10)
                } else {
                    Art(url: image, size: 250, radius: 10)
                }
            }
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            .padding(.top, 8)

            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 18)
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: TitleSpot.self, value: geo.frame(in: .global).maxY)
                    }
                }
            if !byline.isEmpty {
                Text(byline)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            if !meta.isEmpty {
                Text(meta)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            HStack(spacing: 14) {
                action("Play", "play.fill") { playAll() }
                action("Shuffle", "shuffle") { shuffleAll() }
                    .disabled(loading && !locked)
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private func action(_ text: String, _ icon: String, run: @escaping () -> Void) -> some View {
        Button {
            run()
        } label: {
            Label(text, systemImage: icon)
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var summary: String {
        let minutes = tracks.reduce(0) { $0 + $1.durationMs } / 60000
        let songs = tracks.count == 1 ? "1 song" : "\(tracks.count) songs"
        if embedded && tracks.count >= 100 {
            return "Showing the first 100 songs"
        }
        if minutes >= 60 {
            return "\(songs), \(minutes / 60) hr \(minutes % 60) min"
        }
        return "\(songs), \(minutes) minutes"
    }

    private func play(from index: Int) {
        let rest = Array(tracks[index...])
        if let context {
            player.playContext(context, at: tracks[index], fallback: rest, name: title)
        } else {
            player.playList(rest, name: title)
        }
    }

    private func playAll() {
        if let context {
            player.playContext(context, at: nil, fallback: tracks, name: title, inOrder: true)
        } else {
            player.playList(tracks, name: title)
        }
    }

    private func shuffleAll() {
        if let context, tracks.isEmpty || (embedded && tracks.count >= 100) {
            player.shuffleContext(context)
        } else {
            player.shuffle(tracks, name: title)
        }
    }

    private func borrow(_ id: String) async {
        if let found = try? await Embed.playlist(id), !found.isEmpty {
            tracks = found
            embedded = true
        } else {
            locked = true
        }
    }

    private func load() async {
        guard tracks.isEmpty, !locked else { return }
        loading = true
        await player.loadUser()
        switch route {
        case .liked:
            title = "Liked Songs"
            context = player.userID.map { "spotify:user:\($0):collection" }
            try? await player.api.liked { batch in
                tracks += batch
            }
        case .playlist(let playlist):
            title = playlist.name
            image = playlist.images?.best(for: 400)
            context = playlist.uri
            byline = playlist.owner.displayName ?? ""
            let mine = playlist.owner.id == player.userID || playlist.collaborative == true
            if mine {
                do {
                    try await player.api.playlistTracks(playlist.id) { tracks += $0 }
                } catch {
                    if tracks.isEmpty {
                        await borrow(playlist.id)
                    }
                }
            } else {
                await borrow(playlist.id)
            }
        case .album(let id):
            guard let page = try? await player.api.album(id) else { break }
            let album = page.summary
            title = page.name
            image = page.images?.best(for: 400)
            context = page.uri
            byline = page.artists.map(\.name).joined(separator: ", ")
            let year = String((page.releaseDate ?? "").prefix(4))
            let kind = (page.albumType ?? "album").capitalized
            meta = [kind, year].filter { !$0.isEmpty }.joined(separator: " · ")
            tracks = page.tracks.items.map { $0.on(album) }
            if let next = page.tracks.next {
                try? await player.api.all(next) { (more: [Track]) in
                    tracks += more.map { $0.on(album) }
                }
            }
        default:
            break
        }
        loading = false
    }
}
