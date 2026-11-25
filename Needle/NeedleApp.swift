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
                .preferredColorScheme(.dark)
                .tint(Theme.amber)
        }
    }
}

enum Theme {
    static let ground = Color(red: 0.055, green: 0.055, blue: 0.063)
    static let amber = Color(red: 0.96, green: 0.70, blue: 0.32)
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
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Record()
                .frame(width: 96, height: 96)
                .padding(.bottom, 28)
            Text("Needle")
                .font(.system(size: 48, weight: .bold, design: .rounded))
            Spacer()
            if let failed {
                Text(failed)
                    .font(.footnote)
                    .foregroundStyle(Color.red.opacity(0.9))
                    .padding(.bottom, 14)
            }
            Button {
                connect()
            } label: {
                Text(busy ? "Connecting" : "Connect Spotify")
                    .font(.headline)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 10))
            .controlSize(.large)
            .disabled(busy || Config.clientID.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Theme.ground)
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
                Circle().fill(Color(white: 0.11))
                ForEach(1..<6) { ring in
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .padding(side * (0.06 + CGFloat(ring) * 0.045))
                }
                Circle()
                    .fill(Theme.amber)
                    .frame(width: side * 0.3, height: side * 0.3)
                Circle()
                    .fill(Color(white: 0.11))
                    .frame(width: side * 0.05, height: side * 0.05)
            }
            .frame(width: side, height: side)
        }
    }
}
