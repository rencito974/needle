import Foundation
import UIKit

struct Session {
    var name: String
    var tracks: [Track]
    var index: Int

    var current: Track? { tracks.indices.contains(index) ? tracks[index] : nil }
    var upcoming: [Track] { Array(tracks.dropFirst(index + 1)) }
}

@MainActor
@Observable
final class Player {
    let api: Spotify
    private(set) var state: PlayerState?
    private(set) var fetched = Date()
    private(set) var session: Session?
    private(set) var queued: [Track] = []
    private(set) var liked = false
    private(set) var problem: String?
    private(set) var userID: String?
    private(set) var avatar: String?

    @ObservationIgnored private var poller: Task<Void, Never>?
    @ObservationIgnored private var commanded = Date.distantPast
    @ObservationIgnored private var likedFor: String?
    @ObservationIgnored private var pending: (@MainActor () async throws -> Void)?

    init(api: Spotify) {
        self.api = api
    }

    var track: Track? { state?.item }
    var playing: Bool { state?.isPlaying ?? false }

    func progress(at date: Date) -> Double {
        guard let state, let track = state.item else { return 0 }
        var ms = Double(state.progressMs)
        if state.isPlaying {
            ms += date.timeIntervalSince(fetched) * 1000
        }
        return min(ms, Double(track.durationMs)) / 1000
    }

    func start() {
        guard poller == nil else { return }
        poller = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(self.pace()))
            }
        }
        if let action = pending {
            pending = nil
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                run(action)
            }
        }
    }

    func stop() {
        poller?.cancel()
        poller = nil
    }

    func refresh() async {
        do {
            let fresh = try await api.player()
            apply(fresh)
        } catch {
            return
        }
    }

    func loadUser() async {
        guard userID == nil, let me = try? await api.me() else { return }
        userID = me.id
        avatar = me.images?.best(for: 64)
    }

    func togglePlay() {
        if playing {
            freeze(playing: false)
            run { try await self.api.pause() }
        } else {
            freeze(playing: true)
            run { try await self.api.play([:], device: nil) }
        }
    }

    func next() {
        run { try await self.api.skip() }
    }

    func previous() {
        run { try await self.api.previous() }
    }

    func seek(to seconds: Double) {
        guard var current = state else { return }
        current.progressMs = Int(seconds * 1000)
        state = current
        fetched = Date()
        run { try await self.api.seek(Int(seconds * 1000)) }
    }

    func toggleShuffle() {
        guard var current = state else { return }
        current.shuffleState.toggle()
        state = current
        let value = current.shuffleState
        run { try await self.api.shuffle(value) }
    }

    func cycleRepeat() {
        guard var current = state else { return }
        let modes = ["off", "context", "track"]
        let mode = modes[((modes.firstIndex(of: current.repeatState) ?? 0) + 1) % modes.count]
        current.repeatState = mode
        state = current
        run { try await self.api.repeatMode(mode) }
    }

    func toggleLike() {
        guard let uri = track?.uri else { return }
        let value = !liked
        liked = value
        Task {
            do {
                if value {
                    try await api.save([uri])
                } else {
                    try await api.unsave([uri])
                }
            } catch {
                if likedFor == uri {
                    liked = !value
                }
                flag(error)
            }
        }
    }

    func enqueue(_ track: Track) {
        run {
            try await self.api.enqueue(track.uri)
            self.queued.append(track)
        }
    }

    func transfer(to device: Device) {
        guard let id = device.id else { return }
        let keep = playing
        run { try await self.api.transfer(id, play: keep) }
    }

    func openSpotify() {
        open("spotify:")
    }

    func open(_ uri: String) {
        guard let url = URL(string: uri) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func playContext(_ uri: String, at track: Track?, fallback: [Track], name: String, inOrder: Bool = false) {
        var body: [String: Any] = ["context_uri": uri]
        if let track {
            body["offset"] = ["uri": track.uri]
        }
        let payload = body
        let unshuffle = inOrder && state?.shuffleState == true
        run {
            do {
                if unshuffle {
                    try? await self.api.shuffle(false)
                }
                try await self.api.play(payload, device: nil)
                self.session = nil
                self.commanded = Date()
            } catch let error as APIError where (error.status == 400 || error.status == 403) && !fallback.isEmpty {
                try await self.begin(fallback, name: name)
            }
        }
    }

    func playList(_ tracks: [Track], name: String) {
        run { try await self.begin(tracks, name: name) }
    }

    func playTrack(_ track: Track) {
        if let album = track.album?.uri {
            playContext(album, at: track, fallback: [track], name: track.album?.name ?? track.name)
        } else {
            playList([track], name: track.name)
        }
    }

    func shuffle(_ tracks: [Track], name: String) {
        run {
            let recent = Set(((try? await self.api.recent()) ?? []).map(\.uri))
            try await self.begin(Shuffle.deal(tracks, avoiding: recent), name: name)
        }
    }

    func shuffleContext(_ uri: String) {
        run {
            try? await self.api.shuffle(true)
            try await self.api.play(["context_uri": uri], device: nil)
            self.session = nil
        }
    }

    func reshuffle() {
        guard let session, let current = session.current else { return }
        rebuild(current, Shuffle.deal(session.upcoming, avoiding: []))
    }

    func replaceUpcoming(_ tracks: [Track]) {
        guard let current = session?.current else { return }
        rebuild(current, tracks)
    }

    func run(_ action: @escaping @MainActor () async throws -> Void) {
        commanded = Date()
        Task {
            do {
                try await action()
                problem = nil
            } catch let error as APIError where error.status == 404 {
                await recover(action)
            } catch AuthError.signedOut {
                return
            } catch {
                flag(error)
            }
            try? await Task.sleep(for: .milliseconds(400))
            await refresh()
        }
    }

    private func rebuild(_ current: Track, _ upcoming: [Track]) {
        let ms = Int(progress(at: Date()) * 1000)
        let resume = playing
        let name = session?.name ?? ""
        run {
            try await self.begin([current] + upcoming, name: name, at: ms)
            if !resume {
                try await self.api.pause()
            }
        }
    }

    private func begin(_ tracks: [Track], name: String, at ms: Int = 0) async throws {
        let playable = tracks.filter { $0.isLocal != true }
        guard !playable.isEmpty else { return }
        if state?.shuffleState != false {
            try? await api.shuffle(false)
        }
        var limit = 300
        while true {
            let slice = Array(playable.prefix(limit))
            do {
                try await api.play(["uris": slice.map(\.uri), "position_ms": ms], device: nil)
                session = Session(name: name, tracks: slice, index: 0)
                commanded = Date()
                if var current = state {
                    current.shuffleState = false
                    state = current
                }
                return
            } catch let error as APIError where (error.status == 400 || error.status == 413) && limit > 50 {
                limit = 50
            }
        }
    }

    private func recover(_ action: @escaping @MainActor () async throws -> Void) async {
        let devices = (try? await api.devices()) ?? []
        if let phone = devices.first(where: { $0.type.lowercased() == "smartphone" }), let id = phone.id {
            do {
                try await api.transfer(id, play: false)
                try? await Task.sleep(for: .milliseconds(700))
                try await action()
                problem = nil
                return
            } catch {
                pending = action
                openSpotify()
                return
            }
        }
        pending = action
        openSpotify()
    }

    private func pace() -> Double {
        guard let state, state.isPlaying, let track = state.item else { return 5 }
        let left = Double(track.durationMs - state.progressMs) / 1000 - Date().timeIntervalSince(fetched)
        return max(0.5, min(2, left + 0.4))
    }

    private func freeze(playing: Bool) {
        guard var current = state else { return }
        current.progressMs = Int(progress(at: Date()) * 1000)
        current.isPlaying = playing
        state = current
        fetched = Date()
    }

    private func apply(_ fresh: PlayerState?) {
        let before = state?.item?.uri
        state = fresh
        fetched = Date()
        guard let fresh, let uri = fresh.item?.uri else { return }
        if uri != before {
            checkLiked(uri)
        }
        if let spot = queued.firstIndex(where: { $0.uri == uri }) {
            queued.removeSubrange(...spot)
        }
        follow(uri, context: fresh.context?.uri)
    }

    private func follow(_ uri: String, context: String?) {
        guard var current = session, Date().timeIntervalSince(commanded) > 4 else { return }
        if context != nil {
            session = nil
            return
        }
        let tracks = current.tracks
        let ahead = tracks.indices.dropFirst(current.index).first(where: { tracks[$0].uri == uri })
        if let index = ahead ?? tracks.firstIndex(where: { $0.uri == uri }), index != current.index {
            current.index = index
            session = current
        }
    }

    private func checkLiked(_ uri: String) {
        liked = false
        likedFor = uri
        Task {
            guard let value = try? await api.saved([uri]).first, likedFor == uri else { return }
            liked = value
        }
    }

    private func flag(_ error: Error) {
        let text: String
        if let error = error as? APIError {
            switch error.status {
            case 403: text = "Spotify blocked that"
            case 429: text = "Spotify needs a breather, try again soon"
            default: text = "Spotify returned an error (\(error.status))"
            }
        } else {
            text = "Can't reach Spotify"
        }
        problem = text
        Task {
            try? await Task.sleep(for: .seconds(3))
            if problem == text {
                problem = nil
            }
        }
    }
}
