import SwiftUI

struct LibraryView: View {
    @Environment(Shelf.self) private var shelf

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                category("Playlists", "music.note.list", .playlists)
                category("Artists", "music.mic", .artists)
                category("Albums", "square.stack", .albums)
                category("Songs", "music.note", .liked)

                Text(shelf.albums.isEmpty ? "Playlists" : "Recently Added")
                    .font(.title2.bold())
                    .padding(.top, 28)
                    .padding(.bottom, 12)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    if shelf.albums.isEmpty {
                        ForEach(shelf.playlists, id: \.id) { playlist in
                            NavigationLink(value: Route.playlist(playlist)) {
                                Card(title: playlist.name, subtitle: playlist.owner.displayName ?? "", image: playlist.images?.best(for: 300), size: nil)
                            }
                        }
                    } else {
                        ForEach(shelf.albums.prefix(20), id: \.self) { album in
                            if let id = album.id {
                                NavigationLink(value: Route.album(id)) {
                                    Card(title: album.name, subtitle: names(album), image: album.images?.best(for: 300), size: nil)
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .navigationTitle("Library")
        .refreshable {
            await shelf.load(force: true)
            await shelf.loadAlbums(force: true)
        }
        .task {
            await shelf.load()
            await shelf.loadAlbums()
        }
    }

    private func category(_ title: String, _ icon: String, _ route: Route) -> some View {
        NavigationLink(value: route) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30)
                    Text(title)
                        .font(.title3)
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 12)
                Divider()
                    .padding(.leading, 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func names(_ album: Album) -> String {
        (album.artists ?? []).map(\.name).joined(separator: ", ")
    }
}

struct PlaylistsView: View {
    @Environment(Shelf.self) private var shelf

    var body: some View {
        List {
            NavigationLink(value: Route.liked) {
                row(title: "Liked Songs", subtitle: "Playlist") {
                    LikedTile(size: 56)
                }
            }
            ForEach(shelf.playlists, id: \.id) { playlist in
                NavigationLink(value: Route.playlist(playlist)) {
                    row(title: playlist.name, subtitle: playlist.owner.displayName ?? "") {
                        Art(url: playlist.images?.best(for: 120), size: 56, radius: 5)
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Playlists")
        .refreshable { await shelf.load(force: true) }
        .task { await shelf.load() }
    }

    private func row<Thumb: View>(title: String, subtitle: String, @ViewBuilder thumb: () -> Thumb) -> some View {
        HStack(spacing: 14) {
            thumb()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct AlbumsView: View {
    @Environment(Shelf.self) private var shelf

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                ForEach(shelf.albums, id: \.self) { album in
                    if let id = album.id {
                        NavigationLink(value: Route.album(id)) {
                            Card(title: album.name, subtitle: (album.artists ?? []).map(\.name).joined(separator: ", "), image: album.images?.best(for: 300), size: nil)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .navigationTitle("Albums")
        .refreshable { await shelf.loadAlbums(force: true) }
        .task { await shelf.loadAlbums() }
    }
}

struct ArtistsView: View {
    @Environment(Shelf.self) private var shelf

    var body: some View {
        List {
            ForEach(shelf.artists, id: \.self) { artist in
                if let id = artist.id {
                    NavigationLink(value: Route.artist(id)) {
                        HStack(spacing: 14) {
                            Art(url: artist.images?.best(for: 120), size: 52, radius: 26)
                            Text(artist.name)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Artists")
        .refreshable { await shelf.loadArtists(force: true) }
        .task { await shelf.loadArtists() }
    }
}
