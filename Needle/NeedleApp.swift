import SwiftUI

@main
struct NeedleApp: App {
    @State private var auth: Auth
    @State private var player: Player
    @State private var shelf: Shelf

    init() {
        let auth = Auth()
        let api = Spotify(auth: auth)
        _auth = State(initialValue: auth)
        _player = State(initialValue: Player(api: api))
        _shelf = State(initialValue: Shelf(api: api))
    }

    var body: some Scene {
        WindowGroup {
            Root()
                .environment(auth)
                .environment(player)
                .environment(shelf)
                .tint(Theme.accent)
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.98, green: 0.18, blue: 0.29)
    static let deep = Color(red: 0.70, green: 0.05, blue: 0.27)
    static let ground = Color(red: 0.07, green: 0.07, blue: 0.08)
}

struct Root: View {
    @Environment(Auth.self) private var auth
    @Environment(Player.self) private var player
    @Environment(\.scenePhase) private var phase

    var body: some View {
        Group {
            if auth.signedIn {
                Shell()
            } else {
                SignIn()
            }
        }
        .onChange(of: phase, initial: true) { _, _ in sync() }
        .onChange(of: auth.signedIn) { _, _ in sync() }
    }

    private func sync() {
        if phase == .active && auth.signedIn {
            player.start()
        } else {
            player.stop()
        }
    }
}

struct SignIn: View {
    @Environment(Auth.self) private var auth
    @State private var busy = false
    @State private var failed: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Record()
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
            Text("Needle")
                .font(.system(size: 40, weight: .bold))
                .padding(.top, 28)
            Spacer()
            if let failed {
                Text(failed)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .padding(.bottom, 14)
            }
            Button {
                connect()
            } label: {
                Text(busy ? "Connecting" : "Connect Spotify")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(busy || Config.clientID.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func connect() {
        busy = true
        failed = nil
        Task {
            do {
                try await auth.signIn()
            } catch AuthError.cancelled {
            } catch {
                failed = "Spotify didn't let us in. Try again."
            }
            busy = false
        }
    }
}

struct Record: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                    .fill(Color(white: 0.08))
                Circle()
                    .fill(Color(white: 0.13))
                    .padding(side * 0.1)
                ForEach(1..<5) { ring in
                    Circle()
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        .padding(side * (0.13 + CGFloat(ring) * 0.045))
                }
                Circle()
                    .fill(Theme.accent)
                    .frame(width: side * 0.26, height: side * 0.26)
                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: side * 0.04, height: side * 0.04)
            }
            .frame(width: side, height: side)
        }
    }
}
