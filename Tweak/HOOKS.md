# Needle hook map

The scaffold uses selector and class names pulled from public Spotify tweak history (EeveeSpotify, Spotilife, SpotCompat). Spotify renames classes between versions, so every name below is UNVERIFIED until you class-dump the exact Spotify binary you plan to inject into. A hook on a non-existent class is silently a no-op in Logos, so nothing breaks, the feature just does nothing.

## Verification pass, preferred path: runtime probe

The probe dylib (`Probe.x`, opt-in build flag) replaces class-dump entirely. It enumerates the Objective-C runtime of the live Spotify process, including Swift classes once they have been instantiated, and writes a readable dump to `Documents/needle-probe.txt` inside the Spotify sandbox at three stages: 5s after launch, 30s after launch, and 120s after launch (give it a song to play).

### Windows one-shot

From this folder:
```
.\probe-build.ps1 -Ipa path\to\Spotify.ipa
```
Builds a probe variant through WSL + Theos, injects it into the Spotify IPA, outputs `Needle-Probe.ipa`. Sign with Sideloadly, install, open Spotify, play a track for two minutes.

### Pulling the dump off the phone
- Jailbroken: Filza to `/var/mobile/Containers/Data/Application/<Spotify UUID>/Documents/needle-probe.txt`
- Stock iOS: iMazing, 3uTools, or MacDroid file sharing, browse the Spotify app sandbox, copy `needle-probe.txt`

Paste the file into chat. I rewrite the `%hook` lines against the real class names.

## Verification pass, fallback: static class-dump

If the probe path is blocked (signing cert out, no .ipa to inject), classic static dump works too. Needs a decrypted binary.

```
unzip Spotify.ipa -d spot
cd spot/Payload/Spotify.app
ipsw class-dump Spotify --re "SPT|FreeTier|Shuffle|NowPlaying" > ../../../needle-dump.txt
```

Paste `needle-dump.txt`. Same destination as the probe output.

If a class in the list below has moved or renamed, update the `%hook` line in the matching .x file to the current name. Selector signatures are usually stable across renames.

## Classes used by file

All class names below were verified against Spotify 9.2.2's extracted string table (`Tweak/sptclasses.txt`, 4310 classes). Selector signatures come from EeveeSpotify and SpotveeC public source history. Where a selector is listed but the class rename moves it out from under the hook, the `%hook` silently no-ops, so a stale selector never crashes.

### Premium.x
- `SPTCoreProductState`, `SPTProductState`, `SPTNowPlayingProductState` -> `productStateValueForKey:` returns strings like "premium" / "1" / "0" for entitlement checks. Needle overrides the 25 keys that gate ads, skip limits, offline, shuffle, hi-fi, on-demand, download limits.
- `SPTPlayerRestrictions` -> `disallowXReasons` set getters. Needle returns empty set for all 21 reasons, so no control is grayed out.
- `SPTPlayerSuppressions` -> `suppressions` getter, returns empty set.
- `SPTAdsActionHandler` -> short-circuit `showAd:`, `shouldShowAd`, `isAdPlaying`.
- `SPTAccountProductInformationController` -> `productType` returns "premium", `isPremium` returns YES.

### Shuffle.x
- `SPTPlayerContext` -> `tracks` getter, returns Fisher-Yates when the context says shuffle is on.
- `SPTPlayerQueueImplementation` -> `setNextTracks:` intercepts and reshuffles.
- `SPTPlayerQueueWrapperImpl` -> `nextTracks` getter, reshuffle on read.
- `SPTContextualShuffle_ShuffleToggleModelImpl` -> smart-shuffle switch forced off so Spotify's recommendation reshuffler stays out of the way.

### Theme.x
- `SPTNowPlayingContainedViewController`, `SPTNowPlayingContainingViewController`, `SPTNowPlayingViewContainerViewController` -> three verified Now Playing containers. Needle inserts a gradient view behind content on viewDidLoad for each.
- `SPTNowPlayingBackgroundViewModel` -> `backgroundColor` and `primaryColor` getters overridden to return the live palette.
- `SPTNowPlayingContentCoverArtCell` -> `setArtworkImage:` / `setImage:` fire on every track change. Dominant-color pass runs on the utility queue, palette notification posts on main.
- `SPTTabBarContainer` -> locates its UITabBar subview, applies tint and dark chrome blur.

### Lockscreen.x
- `SPTNowPlayingInfoCenterArtworkDecorator` -> Spotify's own decorator that enriches the dictionary pushed to MPNowPlayingInfoCenter. Hook upsizes artwork to 3000x3000 and sets `MPNowPlayingInfoPropertyServiceIdentifier` to `com.apple.Music` for the Apple-Music lockscreen look.
- `MPNowPlayingInfoCenter` -> public MediaPlayer. Backstop hook so the enrichment lands even when Spotify stops using the decorator in a future build.

### Scrobble.x
- `SPTPlayer` -> `setCurrentTrack:` fires on every track open.
- `SPTPlayerTrack` -> metadata accessed through `respondsToSelector:` guards against `trackName`/`title`/`name`, `artistName`/`artist`/`artistTitle`, `albumName`/`album`/`albumTitle`. Falls through to whichever selector exists on this build. `duration` read through NSInvocation so a primitive return (double or long long) decodes right.
- `SPTPlayerState` and `SPTPlayerPositionStateImplementation` -> both `setPositionMs:` hooks tick the scrobble threshold timer.

Last.fm threshold: elapsed >= 30s AND (elapsed >= half the duration OR elapsed >= 240s). Standard rule. Creds read from CFPreferences at `com.renn.needle`.

### Settings.x
- `SPTNowPlayingBar` -> long-press on `didMoveToWindow` opens the in-app settings panel.

### Artwork.x
No Spotify classes. Pure CoreGraphics palette extractor plus a notification bus.

## Build dependent config

| Value               | Where         | Provenance                            | Status                         |
|---------------------|---------------|----------------------------------------|---------------------------------|
| Bundle id filter    | Needle.plist  | Spotify App Store listing              | verified                       |
| Min iOS target      | Makefile 15.0 | class-dump of recent Spotify           | verified                       |
| Entitlement classes | Premium.x     | sptclasses.txt dump of Spotify 9.2.2   | verified on 9.2.2              |
| Shuffle classes     | Shuffle.x     | sptclasses.txt dump                    | verified on 9.2.2              |
| UI classes          | Theme.x       | sptclasses.txt dump                    | verified on 9.2.2              |
| Scrobble classes    | Scrobble.x    | sptclasses.txt dump                    | verified on 9.2.2              |
| Settings trigger    | Settings.x    | SPTNowPlayingBar in sptclasses.txt     | verified on 9.2.2              |
| Decorator hook      | Lockscreen.x  | SPTNowPlayingInfoCenterArtworkDecorator| verified on 9.2.2              |
| MP public methods   | Lockscreen.x  | Apple public MediaPlayer                | verified                       |
| Service identifier override | Lockscreen.x | private iOS flag, stable on 15-18| unverified on 19+              |
| Product-state keys  | Premium.x     | EeveeSpotify public source              | selector verified, keys drift  |

Selector signatures on `%hook` lines use the EeveeSpotify convention. If Spotify renamed a selector since that fork, the hook silently no-ops, so the worst case is a feature doing nothing, never a crash.

## Install path

1. Build on Ubuntu or macOS: `cd Tweak && make package FINALPACKAGE=1`
2. `packages/com.renn.needle_1.0.0_iphoneos-arm64.deb` drops out.
3. Jailbroken device: install the .deb through Sileo or Zebra.
4. Stock iOS: unpack a decrypted Spotify IPA, pull Needle.dylib out of the .deb's `Library/MobileSubstrate/DynamicLibraries/`, inject with cyan:
   ```
   cyan -i Spotify.ipa -o Needle-Spotify.ipa -f Needle.dylib
   ```
   Resign the output IPA with Sideloadly, AltStore or your own cert and install to the iPhone.

## Preferences

Two paths, same keys, same `com.renn.needle` domain.

**Jailbreak:** the `Preferences/` subproject builds `NeedlePrefs.bundle` into `/Library/PreferenceBundles/` and installs an entry at `/Library/PreferenceLoader/Preferences/NeedlePrefs.plist`. Needle shows up in the Settings app.

**Stock iOS sideload:** `Settings.x` provides the same panel as an in-app UIViewController, presented from a long-press on `SPTNowPlayingBarViewController`'s view (0.6s hold, haptic feedback on fire). On first launch a one-time alert tells the user where the gesture is.

Both paths write through `Prefs.x`, which writes to the sandbox NSUserDefaults AND to CFPreferences `kCFPreferencesAnyUser`. Reads check CFPreferences first, fall back to the sandbox. Means a write from the jailbreak PreferenceBundle is seen by the hooks, and a write from the in-app UI on sideload is also seen by the hooks, no conditional logic needed.

Last.fm setup flow: register an API account at last.fm/api/account/create, paste the API key and shared secret into the panel, tap "Open Last.fm sign in", approve the app in Safari, copy the session key out of the callback URL, paste back into the Session key field. Scrobbling activates on the next track start.

## Scripts in this folder

- `inject.ps1` wraps pyzule-rw. Takes an IPA and a .deb (or finds the newest one in `packages/`), spits out an injected IPA ready to sign. Run `.\inject.ps1 -Ipa Spotify.ipa`.
- `probe-build.ps1` builds the probe variant through WSL, then runs `inject.ps1` on the result. One command gets you a Spotify IPA with method tracing live inside.

Both scripts need Python on PATH. pyzule-rw auto-installs on first run.

## Known gaps

- Entitlement overrides work until Spotify switches to server-authoritative entitlement. When that hits, the fix is to intercept the protobuf response from `spclient.wg.spotify.com/account-attributes` and rewrite the `type` field to `premium`. Needs a hook on `SPTHTTPRequestFinishedWithResponse` or NSURLProtocol, out of scope for v1.
- Lockscreen full-screen treatment on iOS 16+ reads `MPNowPlayingInfoPropertyServiceIdentifier`. iOS 19 tightened this. If the big art does not come up on 19, the alternative is the Live Activity path, a separate target.
- Dominant color extraction runs on every artwork swap. The mini-bar sometimes fires twice per track, so the palette may flicker on first paint. Fix with a hash guard on CGImageGetDataProvider if it bothers you.
