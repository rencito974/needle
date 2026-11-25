import SwiftUI

struct NowPlaying: View {
    @Environment(Player.self) private var player
    @Environment(\.dismiss) private var dismiss
    @Namespace private var space
    @State private var mode: Mode = .art
    @State private var devices = false
    @State private var swipe: CGFloat = 0

    enum Mode {
        case art, lyrics, queue
    }

    private let morph = Animation.spring(response: 0.5, dampingFraction: 0.86)

    var body: some View {
        ZStack {
            Backdrop(url: player.track?.album?.images?.best(for: 300))
            VStack(spacing: 0) {
                grabber
                if let track = player.track {
                    switch mode {
                    case .art:
                        Spacer(minLength: 16)
                        cover(track)
                        Spacer(minLength: 16)
                        titleRow(track)
                    case .lyrics:
                        compact(track)
                        LyricsPanel(track: track)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .mask(fade)
                            .transition(.opacity)
                    case .queue:
                        compact(track)
                        QueuePanel()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity)
                    }
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        Scrubber(value: player.progress(at: context.date), total: Double(track.durationMs) / 1000) { seconds in
                            player.seek(to: seconds)
                        }
                    }
                    .padding(.top, mode == .art ? 22 : 10)
                    controls
                    VolumeBar()
                        .padding(.top, 4)
                    footer
                        .padding(.top, 14)
                } else {
                    Spacer()
                    Text("Not Playing")
                        .font(.title3.weight(.semibold))
                    Button("Open Spotify") { player.openSpotify() }
                        .padding(.top, 10)
                    Spacer()
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 6)
        }
        .tint(.white)
        .foregroundStyle(Color.white)
        .environment(\.colorScheme, .dark)
        .problems()
        .sheet(isPresented: $devices) {
            DeviceSheet()
                .environment(player)
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.35))
            .frame(width: 38, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, minHeight: 28)
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
    }

    private var fade: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(color: .clear, location: 0),
                Gradient.Stop(color: .black, location: 0.08),
                Gradient.Stop(color: .black, location: 0.86),
                Gradient.Stop(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func cover(_ track: Track) -> some View {
        Art(url: track.album?.images?.best(for: 640), radius: 10)
            .matchedGeometryEffect(id: "art", in: space)
            .layoutPriority(1)
            .shadow(color: .black.opacity(0.4), radius: 28, y: 16)
            .scaleEffect(player.playing ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: player.playing)
            .offset(x: swipe)
            .rotationEffect(.degrees(Double(swipe) / 30))
            .gesture(
                DragGesture(minimumDistance: 16)
                    .onChanged { value in
                        swipe = value.translation.width * 0.6
                    }
                    .onEnded { value in
                        let distance = value.translation.width
                        if distance < -80 {
                            player.next()
                        } else if distance > 80 {
                            player.previous()
                        }
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { swipe = 0 }
                    }
            )
            .sensoryFeedback(.selection, trigger: track.uri)
    }

    private func compact(_ track: Track) -> some View {
        HStack(spacing: 12) {
            Art(url: track.album?.images?.best(for: 640), size: 64, radius: 6)
                .matchedGeometryEffect(id: "art", in: space)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(track.artistLine)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            likeCircle
            moreMenu
        }
        .padding(.top, 14)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(morph) { mode = .art }
        }
    }

    private func titleRow(_ track: Track) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(track.artistLine)
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            likeCircle
            moreMenu
        }
    }

    private var likeCircle: some View {
        Button {
            player.toggleLike()
        } label: {
            Image(systemName: player.liked ? "heart.fill" : "heart")
                .font(.system(size: 14, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.15), in: Circle())
        }
        .buttonStyle(Press())
        .sensoryFeedback(.success, trigger: player.liked) { _, now in now }
    }

    private var moreMenu: some View {
        Menu {
            if let track = player.track {
                Button {
                    player.toggleLike()
                } label: {
                    Label(player.liked ? "Remove from Liked Songs" : "Add to Liked Songs", systemImage: player.liked ? "heart.slash" : "heart")
                }
                if let id = track.id, let link = URL(string: "https://open.spotify.com/track/\(id)") {
                    ShareLink(item: link) {
                        Label("Share Song", systemImage: "square.and.arrow.up")
                    }
                }
                Button {
                    devices = true
                } label: {
                    Label("Play on Another Device", systemImage: "hifispeaker.2")
                }
                Button {
                    player.open(track.uri)
                } label: {
                    Label("Open in Spotify", systemImage: "arrow.up.forward.app")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.15), in: Circle())
        }
    }

    private var controls: some View {
        HStack {
            Spacer()
            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 34))
                    .frame(width: 80, height: 80)
            }
            Spacer()
            Button {
                player.togglePlay()
            } label: {
                Image(systemName: player.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 46))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 80, height: 80)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: player.playing)
            Spacer()
            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 34))
                    .frame(width: 80, height: 80)
            }
            Spacer()
        }
        .buttonStyle(Press())
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let device = player.state?.device, device.type.lowercased() != "smartphone" {
                Button {
                    devices = true
                } label: {
                    Label("Playing on \(device.name)", systemImage: deviceIcon(device.type))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Spacer()
                toggle(mode == .lyrics ? "quote.bubble.fill" : "quote.bubble", on: mode == .lyrics) {
                    withAnimation(morph) { mode = mode == .lyrics ? .art : .lyrics }
                }
                Spacer()
                RoutePicker()
                    .frame(width: 44, height: 36)
                Spacer()
                toggle("list.bullet", on: mode == .queue) {
                    withAnimation(morph) { mode = mode == .queue ? .art : .queue }
                }
                Spacer()
            }
        }
    }

    private func toggle(_ icon: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Color.white.opacity(on ? 1 : 0.65))
                .frame(width: 44, height: 36)
                .background(Color.white.opacity(on ? 0.2 : 0), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct Scrubber: View {
    let value: Double
    let total: Double
    let onSeek: (Double) -> Void
    @State private var drag: Double?

    var body: some View {
        let shown = drag ?? value
        VStack(spacing: 6) {
            GeometryReader { geo in
                let fraction = total > 0 ? min(max(shown / total, 0), 1) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.white.opacity(drag == nil ? 0.8 : 1))
                        .frame(width: geo.size.width * CGFloat(fraction))
                }
                .frame(height: drag == nil ? 7 : 12)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let width = max(geo.size.width, 1)
                            drag = Double(min(max(gesture.location.x / width, 0), 1)) * total
                        }
                        .onEnded { _ in
                            if let picked = drag {
                                onSeek(picked)
                            }
                            drag = nil
                        }
                )
            }
            .frame(height: 24)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: drag == nil)
            HStack {
                Text(clock(shown))
                Spacer()
                Text("-" + clock(max(total - shown, 0)))
            }
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color.white.opacity(drag == nil ? 0.5 : 0.9))
        }
    }
}

struct LyricsPanel: View {
    let track: Track
    @State private var lyrics: Lyrics?

    var body: some View {
        Group {
            if let lyrics {
                switch lyrics {
                case .synced(let lines):
                    SyncedLyrics(lines: lines)
                case .plain(let text):
                    ScrollView(showsIndicators: false) {
                        Text(text)
                            .font(.title2.weight(.bold))
                            .lineSpacing(10)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 40)
                    }
                case .instrumental:
                    empty("Instrumental")
                case .missing:
                    empty("Lyrics aren't available for this song")
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: track.uri) {
            lyrics = nil
            lyrics = await LyricsStore.shared.lyrics(for: track)
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Color.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SyncedLyrics: View {
    let lines: [Line]
    @Environment(Player.self) private var player

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let now = player.progress(at: context.date)
            let current = lines.lastIndex(where: { $0.time <= now + 0.25 }) ?? -1
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(shade(index, current))
                                .scaleEffect(index == current ? 1 : 0.97, anchor: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .id(index)
                                .onTapGesture { player.seek(to: line.time) }
                                .animation(.easeOut(duration: 0.3), value: current)
                        }
                    }
                    .padding(.vertical, 160)
                }
                .onChange(of: current) { _, value in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) {
                        proxy.scrollTo(max(value, 0), anchor: UnitPoint(x: 0.5, y: 0.3))
                    }
                }
                .onAppear {
                    proxy.scrollTo(max(current, 0), anchor: UnitPoint(x: 0.5, y: 0.3))
                }
            }
        }
    }

    private func shade(_ index: Int, _ current: Int) -> Color {
        if index == current {
            return .white
        }
        return Color.white.opacity(index < current ? 0.4 : 0.28)
    }
}
