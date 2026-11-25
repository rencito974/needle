import SwiftUI

enum Route: Hashable {
    case liked
    case playlist(Playlist)
    case album(String)
    case artist(String)
}

extension View {
    func routes() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .artist(let id):
                ArtistView(id: id)
            default:
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
            NavigationStack {
                HomeView().routes()
            }
            .safeAreaInset(edge: .bottom) { mini }
            .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack {
                SearchView().routes()
            }
            .safeAreaInset(edge: .bottom) { mini }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                LibraryView().routes()
            }
            .safeAreaInset(edge: .bottom) { mini }
            .tabItem { Label("Library", systemImage: "books.vertical.fill") }
        }
        .problems()
        .sheet(isPresented: $expanded) {
            NowPlaying()
                .environment(player)
                .presentationDragIndicator(.hidden)
        }
        .task { await player.loadUser() }
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
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    @State private var tint = Color(white: 0.16)

    var body: some View {
        if let track = player.track {
            HStack(spacing: 11) {
                Art(url: track.album?.images?.best(for: 100), size: 40, radius: 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.name)
                        .font(.subheadline.weight(.semibold))
                    Text(track.artistLine)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .lineLimit(1)
                Spacer(minLength: 6)
                Button {
                    player.toggleLike()
                } label: {
                    Image(systemName: player.liked ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(player.liked ? Theme.amber : Color.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 36, height: 40)
                }
                Button {
                    player.togglePlay()
                } label: {
                    Image(systemName: player.playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 40, height: 40)
                }
            }
            .buttonStyle(Press())
            .foregroundStyle(Color.white)
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint)
            }
            .overlay(alignment: .bottom) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let total = max(Double(track.durationMs) / 1000, 1)
                    let done = min(player.progress(at: context.date) / total, 1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18))
                            Capsule().fill(Color.white).frame(width: geo.size.width * CGFloat(done))
                        }
                    }
                }
                .frame(height: 2)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
            }
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            .padding(.horizontal, 8)
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
            .task(id: track.album?.images?.best(for: 64)) {
                guard let url = track.album?.images?.best(for: 64),
                      let color = await Artwork.shared.tint(url) else {
                    return
                }
                withAnimation(.easeInOut(duration: 0.5)) { tint = color }
            }
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
                Art(url: track.album?.images?.best(for: 100), size: 48, radius: 4)
                    .overlay {
                        if current {
                            ZStack {
                                Color.black.opacity(0.45)
                                Bars(active: player.playing)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                    }
            } else if let number {
                ZStack {
                    if current {
                        Bars(active: player.playing)
                    } else {
                        Text("\(number)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 26)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .foregroundStyle(current ? Theme.amber : Color.primary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if track.explicit == true {
                        Image(systemName: "e.square.fill")
                            .font(.caption2)
                    }
                    Text(track.artistLine)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct Bars: View {
    let active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !active)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3) { bar in
                    let wave = abs(sin(time * (4.6 + Double(bar) * 1.9) + Double(bar) * 1.3))
                    RoundedRectangle(cornerRadius: 1)
                        .frame(width: 3, height: CGFloat(active ? 3 + 10 * wave : 3))
                }
            }
            .frame(width: 13, height: 13, alignment: .bottom)
        }
        .foregroundStyle(Theme.amber)
    }
}

struct LikedTile: View {
    var size: CGFloat = 52
    var radius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.amber.opacity(0.18))
            .overlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.36))
                    .foregroundStyle(Theme.amber)
            }
            .frame(width: size, height: size)
    }
}

struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .background {
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0))
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
