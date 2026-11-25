import SwiftUI

struct HomeView: View {
    @Environment(Shelf.self) private var shelf
    @Environment(Player.self) private var player
    @Environment(Auth.self) private var auth

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if !shelf.shortcuts.isEmpty {
                    section("Recently Played") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 14) {
                                ForEach(shelf.shortcuts) { item in
                                    NavigationLink(value: item.route) {
                                        Card(title: item.title, subtitle: item.subtitle, image: item.image, liked: item.route == .liked, round: item.round)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .contentMargins(.horizontal, 20, for: .scrollContent)
                    }
                }

                if !shelf.recent.isEmpty {
                    section("Recent Songs") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: Array(repeating: GridItem(.fixed(61), spacing: 0), count: 4), spacing: 18) {
                                ForEach(Array(shelf.recent.prefix(20).enumerated()), id: \.offset) { _, track in
                                    VStack(spacing: 0) {
                                        TrackRow(track: track)
                                            .onTapGesture { player.playTrack(track) }
                                        Divider()
                                            .padding(.leading, 60)
                                    }
                                    .containerRelativeFrame(.horizontal) { length, _ in
                                        length * 0.86
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .contentMargins(.horizontal, 20, for: .scrollContent)
                    }
                }

                section("Your Playlists") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 14) {
                            NavigationLink(value: Route.liked) {
                                Card(title: "Liked Songs", subtitle: "Playlist", image: nil, liked: true)
                            }
                            .buttonStyle(.plain)
                            ForEach(shelf.playlists, id: \.id) { playlist in
                                NavigationLink(value: Route.playlist(playlist)) {
                                    Card(title: playlist.name, subtitle: playlist.owner.displayName ?? "", image: playlist.images?.best(for: 300))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Sign Out", role: .destructive) { auth.signOut() }
                } label: {
                    if let avatar = player.avatar {
                        Art(url: avatar, size: 32, radius: 16)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable { await shelf.load(force: true) }
        .task { await shelf.load() }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal, 20)
            content()
        }
    }
}
