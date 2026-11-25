import SwiftUI

enum Route: Hashable {
    case liked
    case playlist(Playlist)
    case album(String)
    case artist(String)
    case playlists
    case albums
    case artists
}

extension View {
    func routes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .artist(let id):
                ArtistView(id: id)
            case .playlists:
                PlaylistsView()
            case .albums:
                AlbumsView()
            case .artists:
                ArtistsView()
            case .liked, .playlist, .album:
                TrackList(route: route)
            }
        }
    }

    func problems() -> some View {
        modifier(Problems())
    }
}

struct Shell: View {
    @Environment(Player.self) private var player
    @State private var expanded = false

    var body: some View {
        TabView {
            stack(HomeView())
                .tabItem { Label("Home", systemImage: "house.fill") }
            stack(LibraryView())
                .tabItem { Label("Library", systemImage: "square.stack.fill") }
            stack(SearchView())
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
        .problems()
        .sheet(isPresented: $expanded) {
            NowPlaying()
                .environment(player)
                .presentationDragIndicator(.hidden)
        }
        .task { await player.loadUser() }
    }

    private func stack<Content: View>(_ content: Content) -> some View {
        NavigationStack {
            content.routes()
        }
        .safeAreaInset(edge: .bottom) { mini }
    }

    @ViewBuilder private var mini: some View {
        if player.track != nil {
            MiniPlayer { expanded = true }
        }
    }
}

struct Problems: ViewModifier {
    @Environment(Player.self) private var player

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let problem = player.problem {
                    Text(problem)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: player.problem)
    }
}

struct MiniPlayer: View {
    @Environment(Player.self) private var player
    let open: () -> Void

    var body: some View {
        if let track = player.track {
            HStack(spacing: 12) {
                Art(url: track.album?.images?.best(for: 100), size: 44, radius: 8)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                Text(track.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    player.togglePlay()
                } label: {
                    Image(systemName: player.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 21))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 38, height: 38)
                }
                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 21))
                        .frame(width: 38, height: 38)
                }
            }
            .buttonStyle(Press())
            .foregroundStyle(Color.primary)
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { open() }
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let x = value.translation.width
                        let y = value.translation.height
                        if y < -30 && abs(y) > abs(x) {
                            open()
                        } else if x < -60 {
                            player.next()
                        } else if x > 60 {
                            player.previous()
                        }
                    }
            )
        }
    }
}

struct TrackArt: View {
    let track: Track
    var size: CGFloat = 48
    @State private var fallback: String?

    var body: some View {
        Art(url: track.album?.images?.best(for: 100) ?? fallback, size: size, radius: 5)
            .task(id: track.uri) {
                guard track.album == nil, let id = track.id else { return }
                fallback = await Embed.thumbnail(id)
            }
    }
}

struct TrackRow: View {
    let track: Track
    var art = true
    var number: Int?
    var menu = true
    @Environment(Player.self) private var player

    var body: some View {
        let current = player.track?.uri == track.uri
        HStack(spacing: 12) {
            if art {
                TrackArt(track: track)
                    .overlay {
                        if current {
                            ZStack {
                                Color.black.opacity(0.4)
                                Bars(active: player.playing, tint: .white)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                    }
            } else if let number {
                ZStack {
                    if current {
                        Bars(active: player.playing, tint: Theme.accent)
                    } else {
                        Text("\(number)")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(track.name)
                        .lineLimit(1)
                    if track.explicit == true {
                        Image(systemName: "e.square.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if art {
                    Text(track.artistLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if menu {
                Menu {
                    Button {
                        player.enqueue(track)
                    } label: {
                        Label("Add to Queue", systemImage: "text.badge.plus")
                    }
                    if let id = track.id, let link = URL(string: "https://open.spotify.com/track/\(id)") {
                        ShareLink(item: link) {
                            Label("Share Song", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.vertical, art ? 6 : 11)
        .contentShape(Rectangle())
    }
}

struct Bars: View {
    let active: Bool
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !active)) { context in
            let time: Double = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3) { bar in
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 3, height: height(bar, time))
                }
            }
            .frame(width: 13, height: 13, alignment: .bottom)
        }
        .foregroundStyle(tint)
    }

    private func height(_ bar: Int, _ time: Double) -> CGFloat {
        guard active else { return 3 }
        let index = Double(bar)
        let speed: Double = 4.6 + index * 1.9
        let phase: Double = time * speed + index * 1.3
        let wave: Double = abs(sin(phase))
        return CGFloat(3 + 10 * wave)
    }
}

struct LikedTile: View {
    var size: CGFloat?
    var radius: CGFloat = 5

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(LinearGradient(colors: [Theme.accent, Theme.deep], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: (size ?? 140) * 0.34))
                    .foregroundStyle(Color.white)
            }
            .frame(width: size, height: size)
            .aspectRatio(1, contentMode: .fit)
    }
}

struct Card: View {
    let title: String
    let subtitle: String
    let image: String?
    var liked = false
    var round = false
    var size: CGFloat? = 160

    var body: some View {
        VStack(alignment: round ? .center : .leading, spacing: 7) {
            Group {
                if liked {
                    LikedTile(size: size, radius: 8)
                } else {
                    Art(url: image, size: size, radius: round ? 500 : 8)
                }
            }
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            VStack(alignment: round ? .center : .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: size, alignment: round ? .center : .leading)
        .contentShape(Rectangle())
    }
}

struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .background {
                Circle()
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.1 : 0))
                    .padding(-6)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

func clock(_ seconds: Double) -> String {
    let whole = max(Int(seconds.rounded(.down)), 0)
    return String(format: "%d:%02d", whole / 60, whole % 60)
}

func deviceIcon(_ type: String?) -> String {
    switch (type ?? "").lowercased() {
    case "smartphone": return "iphone"
    case "computer": return "laptopcomputer"
    case "speaker": return "hifispeaker"
    case "tv": return "tv"
    case "tablet": return "ipad"
    case "automobile": return "car"
    case "gameconsole": return "gamecontroller"
    default: return "speaker.wave.2"
    }
}
