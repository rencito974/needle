import SwiftUI

struct SearchView: View {
    @Environment(Player.self) private var player
    @State private var text = ""
    @State private var results: SearchResults?

    var body: some View {
        List {
            if let results {
                if let tracks = results.tracks?.items, !tracks.isEmpty {
                    Section("Songs") {
                        ForEach(Array(tracks.enumerated()), id: \.offset) { _, track in
                            TrackRow(track: track)
                                .onTapGesture { player.playTrack(track) }
                        }
                    }
                }
                if let artists = results.artists?.items, !artists.isEmpty {
                    Section("Artists") {
                        ForEach(artists, id: \.self) { artist in
                            if let id = artist.id {
                                NavigationLink(value: Route.artist(id)) {
                                    HStack(spacing: 12) {
                                        Art(url: artist.images?.best(for: 100), size: 46, radius: 23)
                                        Text(artist.name)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
                if let albums = results.albums?.items, !albums.isEmpty {
                    Section("Albums") {
                        ForEach(albums, id: \.self) { album in
                            if let id = album.id {
                                NavigationLink(value: Route.album(id)) {
                                    HStack(spacing: 12) {
                                        Art(url: album.images?.best(for: 100), size: 46)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(album.name)
                                                .lineLimit(1)
                                            Text((album.artists ?? []).map(\.name).joined(separator: ", "))
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if let playlists = results.playlists?.items, !playlists.isEmpty {
                    Section("Playlists") {
                        ForEach(playlists, id: \.id) { playlist in
                            NavigationLink(value: Route.playlist(playlist)) {
                                HStack(spacing: 12) {
                                    Art(url: playlist.images?.best(for: 100), size: 46)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(playlist.name)
                                            .lineLimit(1)
                                        Text(playlist.owner.displayName ?? playlist.owner.id)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Search")
        .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Songs, artists, albums")
        .autocorrectionDisabled()
        .task(id: text) {
            let query = text.trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                results = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            if let found = try? await player.api.search(query) {
                results = found
            }
        }
    }
}

struct ArtistView: View {
    let id: String
    @Environment(Player.self) private var player
    @State private var artist: Artist?
    @State private var albums: [Album] = []

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 16) {
                Art(url: artist?.images?.best(for: 300), size: 140, radius: 70)
                Text(artist?.name ?? "")
                    .font(.title.bold())
                Button {
                    if let artist, let uri = artist.uri {
                        player.playContext(uri, at: nil, fallback: [], name: artist.name)
                    }
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 10))
                .controlSize(.large)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 18, trailing: 20))

            ForEach(albums, id: \.self) { album in
                if let albumID = album.id {
                    NavigationLink(value: Route.album(albumID)) {
                        HStack(spacing: 12) {
                            Art(url: album.images?.best(for: 120), size: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(album.name)
                                    .lineLimit(1)
                                Text(line(album))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard artist == nil else { return }
            artist = try? await player.api.artist(id)
            albums = (try? await player.api.artistAlbums(id)) ?? []
        }
    }

    private func line(_ album: Album) -> String {
        let year = String((album.releaseDate ?? "").prefix(4))
        let kind = (album.albumType ?? "").capitalized
        return [year, kind].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
