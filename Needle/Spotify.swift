import Foundation

struct APIError: Error {
    let status: Int
    let reason: String?
}

@MainActor
final class Spotify {
    let auth: Auth
    private let decoder: JSONDecoder

    init(auth: Auth) {
        self.auth = auth
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func raw(_ method: String, _ path: String, query: [String: String] = [:], body: [String: Any]? = nil) async throws -> Data {
        let address = path.hasPrefix("http") ? path : "https://api.spotify.com/v1\(path)"
        guard var parts = URLComponents(string: address) else {
            throw APIError(status: 0, reason: nil)
        }
        if !query.isEmpty {
            let extra = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            parts.queryItems = (parts.queryItems ?? []) + extra
            parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = parts.url else {
            throw APIError(status: 0, reason: nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if method != "GET" {
            request.httpBody = Data()
        }
        var force = false
        var last = 0
        for _ in 0..<3 {
            let token = try await auth.accessToken(force: force)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            last = http?.statusCode ?? 0
            switch last {
            case 200..<300:
                return data
            case 401:
                force = true
            case 429:
                let wait = Double(http?.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2
                try await Task.sleep(for: .seconds(min(wait, 8)))
            default:
                throw APIError(status: last, reason: Self.reason(data))
            }
        }
        throw APIError(status: last, reason: nil)
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let data = try await raw("GET", path, query: query)
        return try decoder.decode(T.self, from: data)
    }

    func send(_ method: String, _ path: String, query: [String: String] = [:], body: [String: Any]? = nil) async throws {
        _ = try await raw(method, path, query: query, body: body)
    }

    func all<T: Decodable>(_ path: String, query: [String: String] = [:], each: ([T]) -> Void) async throws {
        var params = query
        if params["limit"] == nil {
            params["limit"] = "50"
        }
        var next: String? = path
        while let url = next {
            let page: Page<T> = try await get(url, query: url.hasPrefix("http") ? [:] : params)
            each(page.items)
            next = page.next
        }
    }

    func me() async throws -> Me {
        try await get("/me")
    }

    func player() async throws -> PlayerState? {
        let data = try await raw("GET", "/me/player")
        if data.isEmpty {
            return nil
        }
        return try decoder.decode(PlayerState.self, from: data)
    }

    func devices() async throws -> [Device] {
        let list: DeviceList = try await get("/me/player/devices")
        return list.devices
    }

    func queue() async throws -> [Track] {
        let reply: QueueReply = try await get("/me/player/queue")
        return reply.queue
    }

    func recentPlays() async throws -> [Played] {
        let page: Page<Played> = try await get("/me/player/recently-played", query: ["limit": "50"])
        return page.items
    }

    func recent() async throws -> [Track] {
        try await recentPlays().compactMap(\.track)
    }

    func play(_ body: [String: Any], device: String?) async throws {
        let query = device.map { ["device_id": $0] } ?? [:]
        try await send("PUT", "/me/player/play", query: query, body: body)
    }

    func pause() async throws {
        try await send("PUT", "/me/player/pause")
    }

    func skip() async throws {
        try await send("POST", "/me/player/next")
    }

    func previous() async throws {
        try await send("POST", "/me/player/previous")
    }

    func seek(_ ms: Int) async throws {
        try await send("PUT", "/me/player/seek", query: ["position_ms": String(max(ms, 0))])
    }

    func shuffle(_ on: Bool) async throws {
        try await send("PUT", "/me/player/shuffle", query: ["state": on ? "true" : "false"])
    }

    func repeatMode(_ mode: String) async throws {
        try await send("PUT", "/me/player/repeat", query: ["state": mode])
    }

    func transfer(_ id: String, play: Bool) async throws {
        try await send("PUT", "/me/player", body: ["device_ids": [id], "play": play])
    }

    func enqueue(_ uri: String) async throws {
        try await send("POST", "/me/player/queue", query: ["uri": uri])
    }

    func saved(_ uris: [String]) async throws -> [Bool] {
        guard !uris.isEmpty else { return [] }
        return try await get("/me/library/contains", query: ["uris": uris.prefix(40).joined(separator: ",")])
    }

    func save(_ uris: [String]) async throws {
        try await send("PUT", "/me/library", query: ["uris": uris.prefix(40).joined(separator: ",")])
    }

    func unsave(_ uris: [String]) async throws {
        try await send("DELETE", "/me/library", query: ["uris": uris.prefix(40).joined(separator: ",")])
    }

    func playlists(each: ([Playlist]) -> Void) async throws {
        try await all("/me/playlists", each: each)
    }

    func liked(each: ([Track]) -> Void) async throws {
        try await all("/me/tracks") { (items: [TrackItem]) in
            each(items.compactMap(\.track))
        }
    }

    func playlistTracks(_ id: String, each: ([Track]) -> Void) async throws {
        try await all("/playlists/\(id)/items", query: ["additional_types": "track"]) { (items: [PlaylistEntry]) in
            each(items.compactMap(\.track))
        }
    }

    func savedAlbums(each: ([Album]) -> Void) async throws {
        try await all("/me/albums") { (items: [SavedAlbum]) in
            each(items.compactMap(\.album))
        }
    }

    func followedArtists() async throws -> [Artist] {
        let reply: Followed = try await get("/me/following", query: ["type": "artist", "limit": "50"])
        return reply.artists.items
    }

    func album(_ id: String) async throws -> AlbumPage {
        try await get("/albums/\(id)")
    }

    func artist(_ id: String) async throws -> Artist {
        try await get("/artists/\(id)")
    }

    func artistAlbums(_ id: String) async throws -> [Album] {
        do {
            let page: Page<Album> = try await get("/artists/\(id)/albums", query: ["include_groups": "album,single", "limit": "50"])
            return page.items
        } catch let error as APIError where error.status == 400 {
            let page: Page<Album> = try await get("/artists/\(id)/albums", query: ["include_groups": "album,single", "limit": "10"])
            return page.items
        }
    }

    func search(_ text: String) async throws -> SearchResults {
        try await get("/search", query: ["q": text, "type": "track,artist,album,playlist", "limit": "10"])
    }

    private static func reason(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any] else {
            return nil
        }
        return (error["reason"] as? String) ?? (error["message"] as? String)
    }
}
