import Foundation

struct Line: Hashable {
    let time: Double
    let text: String
}

enum Lyrics: Equatable {
    case synced([Line])
    case plain(String)
    case instrumental
    case missing
}

private struct LrcRecord: Decodable {
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}

@MainActor
final class LyricsStore {
    static let shared = LyricsStore()
    private var cache: [String: Lyrics] = [:]

    func lyrics(for track: Track) async -> Lyrics {
        if let hit = cache[track.uri] {
            return hit
        }
        guard let found = await fetch(track) else {
            return .missing
        }
        cache[track.uri] = found
        return found
    }

    private func fetch(_ track: Track) async -> Lyrics? {
        let duration = Double(track.durationMs) / 1000
        var exact = [
            "track_name": track.name,
            "artist_name": track.lead,
            "duration": String(Int(duration.rounded())),
        ]
        if let album = track.album?.name {
            exact["album_name"] = album
        }
        do {
            let direct: LrcRecord? = try await lookup("get", exact)
            if let direct {
                return Self.read(direct)
            }
            let found: [LrcRecord]? = try await lookup("search", [
                "track_name": Self.clean(track.name),
                "artist_name": track.lead,
            ])
            let close = (found ?? []).filter { abs(($0.duration ?? duration) - duration) < 4 }
            let pick = close.first(where: { $0.syncedLyrics != nil })
                ?? close.first(where: { $0.plainLyrics != nil })
                ?? close.first
            guard let pick else { return .missing }
            return Self.read(pick)
        } catch {
            return nil
        }
    }

    private func lookup<T: Decodable>(_ endpoint: String, _ query: [String: String]) async throws -> T? {
        var parts = URLComponents(string: "https://lrclib.net/api/\(endpoint)")!
        parts.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        parts.percentEncodedQuery = parts.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        var request = URLRequest(url: parts.url!)
        request.setValue(Config.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 {
            return nil
        }
        guard status == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func read(_ record: LrcRecord) -> Lyrics {
        if let synced = record.syncedLyrics {
            let lines = parse(synced)
            if !lines.isEmpty {
                return .synced(lines)
            }
        }
        if let plain = record.plainLyrics, !plain.isEmpty {
            return .plain(plain)
        }
        if record.instrumental == true {
            return .instrumental
        }
        return .missing
    }

    private static func clean(_ title: String) -> String {
        var result = title
        for mark in [" - ", " (feat", " (with", " [feat"] {
            if let range = result.range(of: mark, options: .caseInsensitive) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result
    }

    static func parse(_ lrc: String) -> [Line] {
        var lines: [Line] = []
        for raw in lrc.split(whereSeparator: \.isNewline) {
            var rest = Substring(raw)
            var times: [Double] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                let parts = tag.split(separator: ":")
                if parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) {
                    times.append(minutes * 60 + seconds)
                }
                rest = rest[rest.index(after: close)...]
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            for time in times {
                lines.append(Line(time: time, text: text))
            }
        }
        return lines.sorted { $0.time < $1.time }
    }
}
