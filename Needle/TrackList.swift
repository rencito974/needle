import SwiftUI

struct TrackList: View {
    let route: Route
    @Environment(Player.self) private var player
    @State private var tracks: [Track] = []
    @State private var title = ""
    @State private var subtitle = ""
    @State private var image: String?
    @State private var context: String?
    @State private var locked = false
    @State private var loading = true
    @State private var tint = Color(white: 0.2)

    private var isAlbum: Bool {
        if case .album = route { return true }
        return false
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                if locked {
                    Text("Spotify only shares the songs of playlists you own")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                    TrackRow(track: track, art: !isAlbum, number: isAlbum ? index + 1 : nil)
                        .padding(.leading, 16)
                        .padding(.trailing, 6)
                        .onTapGesture { play(from: index) }
                }
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Theme.ground)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: image) { await updateTint() }
    }

    private var header: some View {
        VStack(spacing: 18) {
            Group {
                if route == .liked {
                    LikedTile(size: 228, radius: 10)
                } else {
                    Art(url: image, size: 228, radius: 10)
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 24, y: 12)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            HStack(spacing: 22) {
                Button {
                    shuffleAll()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .disabled(loading && !locked)
                Button {
                    playAll()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 64, height: 64)
                        .background(Theme.amber, in: Circle())
                }
            }
            .buttonStyle(Press())
            .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            LinearGradient(colors: [tint, Theme.ground], startPoint: .top, endPoint: .bottom)
                .frame(height: 660)
                .offset(y: -240)
        }
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
        if tracks.isEmpty, let context {
            player.shuffleContext(context)
        } else {
            player.shuffle(tracks, name: title)
        }
    }

    private func updateTint() async {
        if route == .liked {
            tint = Theme.amber.opacity(0.32)
            return
        }
        guard let image, let color = await Artwork.shared.tint(image) else { return }
        withAnimation(.easeInOut(duration: 0.4)) { tint = color }
    }

    private func load() async {
        guard tracks.isEmpty, !locked else { return }
        loading = true
        switch route {
        case .liked:
            title = "Liked Songs"
            await player.loadUser()
            context = player.userID.map { "spotify:user:\($0):collection" }
            try? await player.api.liked { batch in
                tracks += batch
                subtitle = "\(tracks.count) songs"
            }
        case .playlist(let playlist):
            title = playlist.name
            image = playlist.images?.best(for: 300)
            context = playlist.uri
            subtitle = playlist.owner.displayName ?? ""
            do {
                try await player.api.playlistTracks(playlist.id) { tracks += $0 }
                if let count = playlist.count, playlist.owner.id == player.userID {
                    let owner = playlist.owner.displayName ?? ""
                    let songs = count == 1 ? "1 song" : "\(count) songs"
                    subtitle = owner.isEmpty ? songs : "\(owner) · \(songs)"
                }
            } catch let error as APIError where error.status == 403 {
                locked = true
            } catch {
                locked = tracks.isEmpty
            }
        case .album(let id):
            guard let page = try? await player.api.album(id) else { break }
            let album = page.summary
            title = page.name
            image = page.images?.best(for: 300)
            context = page.uri
            let year = String((page.releaseDate ?? "").prefix(4))
            subtitle = [page.artists.map(\.name).joined(separator: ", "), year]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            tracks = page.tracks.items.map { $0.on(album) }
            if let next = page.tracks.next {
                try? await player.api.all(next) { (more: [Track]) in
                    tracks += more.map { $0.on(album) }
                }
            }
        case .artist:
            break
        }
        loading = false
    }
}
