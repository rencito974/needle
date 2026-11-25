import Foundation

struct Picture: Decodable, Hashable {
    let url: String
    let width: Int?
}

extension Array where Element == Picture {
    func best(for size: Int) -> String? {
        let sorted = self.sorted { ($0.width ?? 0) < ($1.width ?? 0) }
        return (sorted.first(where: { ($0.width ?? 0) >= size }) ?? sorted.last)?.url
    }
}

struct Artist: Decodable, Hashable {
    let id: String?
    let name: String
    let uri: String?
    let images: [Picture]?
}

struct Album: Decodable, Hashable {
    let id: String?
    let name: String
    let uri: String?
    let images: [Picture]?
    let artists: [Artist]?
    let releaseDate: String?
    let albumType: String?
}

struct Track: Decodable, Hashable {
    let id: String?
    let name: String
    let uri: String
    let durationMs: Int
    let artists: [Artist]
    var album: Album?
    let isLocal: Bool?
    let explicit: Bool?

    var artistLine: String { artists.map(\.name).joined(separator: ", ") }
    var lead: String { artists.first?.name ?? "" }

    func on(_ album: Album) -> Track {
        var copy = self
        copy.album = album
        return copy
    }
}

struct Owner: Decodable, Hashable {
    let id: String
    let displayName: String?
}

struct Total: Decodable, Hashable {
    let total: Int?
}

struct Playlist: Decodable, Hashable {
    let id: String
    let name: String
    let uri: String
    let images: [Picture]?
    let owner: Owner
    let collaborative: Bool?
    let items: Total?
    let tracks: Total?

    var count: Int? { items?.total ?? tracks?.total }
}

struct Me: Decodable {
    let id: String
    let displayName: String?
    let images: [Picture]?
}

struct Played: Decodable {
    let track: Track?
    let context: PlayContext?

    enum Keys: String, CodingKey {
        case track, context
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        track = try? c.decode(Track.self, forKey: .track)
        context = try? c.decode(PlayContext.self, forKey: .context)
    }
}

struct Lenient<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

struct Page<T: Decodable>: Decodable {
    let items: [T]
    let next: String?
    let total: Int?

    enum Keys: String, CodingKey {
        case items, next, total
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        items = (try c.decodeIfPresent([Lenient<T>].self, forKey: .items) ?? []).compactMap(\.value)
        next = try? c.decodeIfPresent(String.self, forKey: .next)
        total = try? c.decodeIfPresent(Int.self, forKey: .total)
    }
}

struct TrackItem: Decodable {
    let track: Track?

    enum Keys: String, CodingKey {
        case track
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        track = try? c.decode(Track.self, forKey: .track)
    }
}

struct PlaylistEntry: Decodable {
    let track: Track?

    enum Keys: String, CodingKey {
        case item, track
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        track = (try? c.decode(Track.self, forKey: .item)) ?? (try? c.decode(Track.self, forKey: .track))
    }
}

struct AlbumPage: Decodable {
    let id: String
    let name: String
    let uri: String
    let images: [Picture]?
    let artists: [Artist]
    let releaseDate: String?
    let albumType: String?
    let tracks: Page<Track>

    var summary: Album {
        Album(id: id, name: name, uri: uri, images: images, artists: artists, releaseDate: releaseDate, albumType: albumType)
    }
}

struct Device: Decodable, Hashable {
    let id: String?
    let isActive: Bool
    let name: String
    let type: String
}

struct DeviceList: Decodable {
    let devices: [Device]
}

struct PlayContext: Decodable, Hashable {
    let uri: String
    let type: String?
}

struct PlayerState: Decodable {
    var device: Device?
    var shuffleState: Bool
    var repeatState: String
    var progressMs: Int
    var isPlaying: Bool
    var item: Track?
    var context: PlayContext?

    enum Keys: String, CodingKey {
        case device, shuffleState, repeatState, progressMs, isPlaying, item, context
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        device = try? c.decode(Device.self, forKey: .device)
        shuffleState = (try? c.decode(Bool.self, forKey: .shuffleState)) ?? false
        repeatState = (try? c.decode(String.self, forKey: .repeatState)) ?? "off"
        progressMs = (try? c.decode(Int.self, forKey: .progressMs)) ?? 0
        isPlaying = (try? c.decode(Bool.self, forKey: .isPlaying)) ?? false
        item = try? c.decode(Track.self, forKey: .item)
        context = try? c.decode(PlayContext.self, forKey: .context)
    }
}

struct QueueReply: Decodable {
    let queue: [Track]

    enum Keys: String, CodingKey {
        case queue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        queue = ((try? c.decode([Lenient<Track>].self, forKey: .queue)) ?? []).compactMap(\.value)
    }
}

struct SearchResults: Decodable {
    let tracks: Page<Track>?
    let artists: Page<Artist>?
    let albums: Page<Album>?
    let playlists: Page<Playlist>?
}
