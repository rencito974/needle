import SwiftUI

struct HomeView: View {
    @Environment(Shelf.self) private var shelf
    @Environment(Player.self) private var player
    @Environment(Auth.self) private var auth

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                LazyVGrid(columns: columns, spacing: 8) {
                    NavigationLink(value: Route.liked) {
                        QuickTile(title: "Liked Songs", image: nil)
                    }
                    ForEach(shelf.playlists.prefix(7), id: \.id) { playlist in
                        NavigationLink(value: Route.playlist(playlist)) {
                            QuickTile(title: playlist.name, image: playlist.images?.best(for: 120))
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                if !shelf.shortcuts.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Jump back in")
                            .font(.title2.bold())
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 14) {
                                ForEach(shelf.shortcuts) { item in
                                    NavigationLink(value: item.route) {
                                        Card(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .contentMargins(.horizontal, 16, for: .scrollContent)
                    }
                }

                if !shelf.recent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recently played")
                            .font(.title2.bold())
                            .padding(.bottom, 4)
                        ForEach(Array(shelf.recent.prefix(12).enumerated()), id: \.offset) { _, track in
                            TrackRow(track: track)
                                .onTapGesture { player.playTrack(track) }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Sign out", role: .destructive) { auth.signOut() }
                } label: {
                    if let avatar = player.avatar {
                        Art(url: avatar, size: 30, radius: 15)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }
            }
        }
        .refreshable { await shelf.load(force: true) }
        .task { await shelf.load() }
    }
}

struct QuickTile: View {
    let title: String
    let image: String?

    var body: some View {
        HStack(spacing: 10) {
            if let image {
                Art(url: image, size: 56, radius: 0)
            } else {
                LikedTile(size: 56, radius: 0)
            }
            Text(title)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
        }
        .frame(height: 56)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
    }
}

struct Card: View {
    let item: Shortcut

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.route == .liked {
                LikedTile(size: 148, radius: 8)
            } else {
                Art(url: item.image, size: 148, radius: item.round ? 74 : 8)
            }
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 148, alignment: .leading)
        .contentShape(Rectangle())
    }
}
