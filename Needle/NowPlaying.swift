import SwiftUI

struct NowPlaying: View {
    @Environment(Player.self) private var player
    @Environment(\.dismiss) private var dismiss
    @Namespace private var space
    @State private var lyrics = false
    @State private var panel: Panel?
    @State private var swipe: CGFloat = 0

    private let morph = Animation.spring(response: 0.5, dampingFraction: 0.86)

    enum Panel: String, Identifiable {
        case queue, devices
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Backdrop(url: player.track?.album?.images?.best(for: 300))
            VStack(spacing: 0) {
                bar
                if let track = player.track {
                    if lyrics {
                        compact(track)
                        LyricsPanel(track: track)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .mask(fade)
                            .transition(.opacity)
                    } else {
                        Spacer(minLength: 10)
                        cover(track)
                        Spacer(minLength: 10)
                        LyricTicker(track: track) {
                            withAnimation(morph) { lyrics = true }
                        }
                        .frame(height: 50)
                        .padding(.bottom, 14)
                        titleRow(track)
                    }
                    TimelineView(.periodic(from: .now, by: 0.5)) { context in
                        Scrubber(value: player.progress(at: context.date), total: Double(track.durationMs) / 1000) { seconds in
                            player.seek(to: seconds)
                        }
                    }
                    .padding(.top, 18)
                    controls
                        .padding(.top, 12)
                    footer
                        .padding(.top, 16)
                } else {
                    Spacer()
                    Text("Nothing playing")
                        .font(.title3.weight(.semibold))
                    Button("Open Spotify") { player.openSpotify() }
                        .padding(.top, 10)
                    Spacer()
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 10)
        }
        .tint(.white)
        .foregroundStyle(Color.white)
        .problems()
        .sheet(item: $panel) { which in
            switch which {
            case .queue:
                QueueSheet()
                    .environment(player)
            case .devices:
                DeviceSheet()
                    .environment(player)
            }
        }
    }

    private var bar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                round("chevron.down")
            }
            Spacer()
            Text(source)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 8)
            Spacer()
            Menu {
                if let track = player.track {
                    Button {
                        player.toggleLike()
                    } label: {
                        Label(player.liked ? "Remove from Liked Songs" : "Save to Liked Songs", systemImage: player.liked ? "heart.slash" : "heart")
                    }
                    if let id = track.id, let link = URL(string: "https://open.spotify.com/track/\(id)") {
                        ShareLink(item: link) {
                            Label("Share Song", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        player.open(track.uri)
                    } label: {
                        Label("Open in Spotify", systemImage: "arrow.up.forward.app")
                    }
                }
            } label: {
                round("ellipsis")
            }
        }
        .padding(.top, 14)
    }

    private func round(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .bold))
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.14), in: Circle())
    }

    private var source: String {
        if let name = player.session?.name, !name.isEmpty {
            return name
        }
        return player.track?.album?.name ?? ""
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
            .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
            .scaleEffect(player.playing ? 1 : 0.84)
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
            Art(url: track.album?.images?.best(for: 640), size: 58, radius: 6)
                .matchedGeometryEffect(id: "art", in: space)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(track.artistLine)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            like(24)
        }
        .padding(.top, 18)
        .padding(.bottom, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(morph) { lyrics = false }
        }
    }

    private func titleRow(_ track: Track) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                Text(track.artistLine)
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            like(30)
        }
    }

    private func like(_ size: CGFloat) -> some View {
        Button {
            player.toggleLike()
        } label: {
            Image(systemName: player.liked ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: size))
                .foregroundStyle(player.liked ? Theme.amber : Color.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(Press())
        .sensoryFeedback(.success, trigger: player.liked) { _, now in now }
    }

    private var controls: some View {
        HStack {
            Button {
                if player.session != nil {
                    player.reshuffle()
                } else {
                    player.toggleShuffle()
                }
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(shuffleOn ? Theme.amber : Color.white.opacity(0.75))
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
                    .frame(width: 60, height: 60)
            }
            Spacer()
            Button {
                player.togglePlay()
            } label: {
                Image(systemName: player.playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 48))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 76, height: 76)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: player.playing)
            Spacer()
            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
                    .frame(width: 60, height: 60)
            }
            Spacer()
            Button {
                player.cycleRepeat()
            } label: {
                Image(systemName: player.state?.repeatState == "track" ? "repeat.1" : "repeat")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(repeatOn ? Theme.amber : Color.white.opacity(0.75))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(Press())
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if let device = player.state?.device, device.type.lowercased() != "smartphone" {
                Label(device.name, systemImage: deviceIcon(device.type))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.amber)
                    .lineLimit(1)
            }
            HStack {
                Spacer()
                foot(lyrics ? "quote.bubble.fill" : "quote.bubble", on: lyrics) {
                    withAnimation(morph) { lyrics.toggle() }
                }
                Spacer()
                foot(deviceIcon(player.state?.device?.type), on: false) {
                    panel = .devices
                }
                Spacer()
                foot("list.bullet", on: false) {
                    panel = .queue
                }
                Spacer()
            }
        }
    }

    private func foot(_ icon: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(on ? Theme.amber : Color.white.opacity(0.75))
                .frame(width: 48, height: 44)
        }
        .buttonStyle(Press())
    }

    private var shuffleOn: Bool {
        player.session != nil || player.state?.shuffleState == true
    }

    private var repeatOn: Bool {
        (player.state?.repeatState ?? "off") != "off"
    }
}

struct Scrubber: View {
    let value: Double
    let total: Double
    let onSeek: (Double) -> Void
    @State private var drag: Double?

    var body: some View {
        let shown = drag ?? value
        VStack(spacing: 8) {
            GeometryReader { geo in
                let fraction = total > 0 ? min(max(shown / total, 0), 1) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.white.opacity(drag == nil ? 0.85 : 1))
                        .frame(width: geo.size.width * CGFloat(fraction))
                }
                .frame(height: drag == nil ? 5 : 10)
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
            .frame(height: 22)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: drag == nil)
            HStack {
                Text(clock(shown))
                Spacer()
                Text("-" + clock(max(total - shown, 0)))
            }
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(Color.white.opacity(drag == nil ? 0.55 : 0.9))
        }
    }
}

struct LyricTicker: View {
    let track: Track
    let open: () -> Void
    @Environment(Player.self) private var player
    @State private var lines: [Line] = []

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.3)) { context in
            let now = player.progress(at: context.date)
            let index = lines.lastIndex(where: { $0.time <= now + 0.2 }) ?? -1
            ZStack(alignment: .bottomLeading) {
                if index >= 0 && !lines[index].text.isEmpty {
                    Text(lines[index].text)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.white.opacity(0.88))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(index)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .clipped()
            .animation(.easeOut(duration: 0.35), value: index)
        }
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .task(id: track.uri) {
            lines = []
            let found = await LyricsStore.shared.lyrics(for: track)
            if case .synced(let synced) = found {
                lines = synced
            }
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
                    empty("No lyrics for this one")
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
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(.system(size: 30, weight: .bold))
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
                        proxy.scrollTo(max(value, 0), anchor: UnitPoint(x: 0.5, y: 0.35))
                    }
                }
                .onAppear {
                    proxy.scrollTo(max(current, 0), anchor: UnitPoint(x: 0.5, y: 0.35))
                }
            }
        }
    }

    private func shade(_ index: Int, _ current: Int) -> Color {
        if index == current {
            return .white
        }
        return Color.white.opacity(index < current ? 0.4 : 0.3)
    }
}
