import SwiftUI

struct LibraryView: View {
    @Environment(Player.self) private var player
    @Environment(Shelf.self) private var shelf

    var body: some View {
        List {
            NavigationLink(value: Route.liked) {
                HStack(spacing: 12) {
                    LikedTile(size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Liked Songs")
                        Text("Playlist")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowSeparator(.hidden)
            ForEach(shelf.playlists, id: \.id) { playlist in
                NavigationLink(value: Route.playlist(playlist)) {
                    HStack(spacing: 12) {
                        Art(url: playlist.images?.best(for: 120), size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(playlist.name)
                                .lineLimit(1)
                            Text(detail(playlist))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Library")
        .refreshable { await shelf.load(force: true) }
        .task { await shelf.load() }
    }

    private func detail(_ playlist: Playlist) -> String {
        if playlist.owner.id == player.userID, let count = playlist.count {
            return count == 1 ? "Playlist · 1 song" : "Playlist · \(count) songs"
        }
        return "Playlist · \(playlist.owner.displayName ?? playlist.owner.id)"
    }
}
