import Foundation

enum Config {
    static let clientID = "7bfb3fa2014c421cb315fd3b2fe92360"
    static let redirectURI = "needle://callback"
    static let scheme = "needle"
    static let userAgent = "Needle/1.0"
    static let scopes = [
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing",
        "user-read-recently-played",
        "user-top-read",
        "user-library-read",
        "user-library-modify",
        "playlist-read-private",
        "playlist-read-collaborative",
        "playlist-modify-private",
        "playlist-modify-public",
    ]
}
