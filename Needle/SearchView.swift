import SwiftUI

struct SearchView: View {
    @Environment(Player.self) private var player
    @State private var text = ""
    @State private var results: SearchResults?

    var body: some View {
        List {
            if let results {
                if let tracks = results.tracks?.items, !tracks.isEmpty {
                    Section {
                        ForEach(Array(tracks.enumerated()), id: \.offset) { _, track in
                            TrackRow(track: track)
                                .onTapGesture { player.playTrack(track) }
                        }
                    } header: {
                        heading("Songs")
                    }
                }
                if let artists = results.artists?.items, !artists.isEmpty {
                    Section {
                        ForEach(artists, id: \.self) { artist in
                            if let id = artist.id {
                                NavigationLink(value: Route.artist(id)) {
                                    row(artist.images?.best(for: 120), round: true, title: artist.name, subtitle: "Artist")
                                }
                            }
                        }
                    } header: {
                        heading("Artists")
                    }
                }
                if let albums = results.albums?.items, !albums.isEmpty {
                    Section {
                        ForEach(albums, id: \.self) { album in
                            if let id = album.id {
                                NavigationLink(value: Route.album(id)) {
                                    row(album.images?.best(for: 120), round: false, title: album.name, subtitle: albumLine(album))
                                }
                            }
                        }
                    } header: {
                        heading("Albums")
                    }
                }
                if let playlists = results.playlists?.items, !playlists.isEmpty {
                    Section {
                        ForEach(playlists, id: \.id) { playlist in
                            NavigationLink(value: Route.playlist(playlist)) {
                                row(playlist.images?.best(for: 120), round: false, title: playlist.name, subtitle: playlistLine(playlist))
                            }
                        }
                    } header: {
                        heading("Playlists")
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Search")
        .searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Artists, Songs, Albums and More")
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

    private func albumLine(_ album: Album) -> String {
        let names = (album.artists ?? []).map(\.name).joined(separator: ", ")
        return "Album · \(names)"
    }

    private func playlistLine(_ playlist: Playlist) -> String {
        let owner = playlist.owner.displayName ?? playlist.owner.id
        return "Playlist · \(owner)"
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(Color.primary)
            .textCase(nil)
    }

    private func row(_ image: String?, round: Bool, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Art(url: image, size: 48, radius: round ? 24 : 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ArtistView: View {
    let id: String
    @Environment(Player.self) private var player
    @State private var artist: Artist?
    @State private var albums: [Album] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                shelf("Albums", albums.filter { ($0.albumType ?? "album") == "album" })
                shelf("Singles & EPs", albums.filter { ($0.albumType ?? "album") != "album" })
            }
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard artist == nil else { return }
            artist = try? await player.api.artist(id)
            albums = (try? await player.api.artistAlbums(id)) ?? []
        }
    }

    private var hero: some View {
        Art(url: artist?.images?.best(for: 640), radius: 0)
            .overlay {
                LinearGradient(colors: [.clear, .clear, Color.black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 12) {
                    Text(artist?.name ?? "")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.white)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Button {
                        if let artist, let uri = artist.uri {
                            player.playContext(uri, at: nil, fallback: [], name: artist.name)
                        }
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.white)
                            .frame(width: 50, height: 50)
                            .background(Theme.accent, in: Circle())
                    }
                    .buttonStyle(Press())
                }
                .padding(20)
            }
    }

    @ViewBuilder
    private func shelf(_ title: String, _ items: [Album]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(items, id: \.self) { album in
                            if let albumID = album.id {
                                NavigationLink(value: Route.album(albumID)) {
                                    Card(title: album.name, subtitle: String((album.releaseDate ?? "").prefix(4)), image: album.images?.best(for: 300))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 20, for: .scrollContent)
            }
        }
    }
}
