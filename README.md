# Needle

A Spotify client for iPhone with a real shuffle, a queue you can edit, synced lyrics and album-colored playback. It drives the official Spotify app through the Web API, so the Spotify app has to be installed and the account needs Premium.

## Setup

1. Create an app at [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) with the Web API enabled and the redirect URI `needle://callback`.
2. Put its client ID in `Needle/Config.swift`.
3. Push to `main`. GitHub Actions builds an unsigned `Needle.ipa` and attaches it to the `latest` release.
4. Sign the IPA with your certificate and install it.

## Building

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`, so there is no `.xcodeproj` in the repo. On a Mac: `xcodegen generate`, then open `Needle.xcodeproj`.

Lyrics come from [LRCLIB](https://lrclib.net).
