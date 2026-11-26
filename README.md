# Needle

A Spotify tweak for iPhone. Hooks the real Spotify binary at runtime to turn on premium flags, replace the weighted shuffle with Fisher Yates, tint the Now Playing surface with the album's dominant color, and push high-resolution artwork to the lockscreen the way Apple Music does.

Works on jailbroken iOS 15 and up as a classic MobileSubstrate tweak. On stock iOS, the tweak dylib injects into a decrypted Spotify IPA with cyan or Sideloadly and sideloads through AltStore or a regular signing cert.

## Build

On Ubuntu or macOS with [Theos](https://theos.dev) installed:

```
cd Tweak
make package FINALPACKAGE=1
```

The output lands in `Tweak/packages/com.renn.needle_1.0.0_iphoneos-arm64.deb`. GitHub Actions does the same on every push to `main` and uploads the .deb to the `latest` release.

## Install

### Jailbroken

Open the .deb in Sileo or Zebra, respring.

### Stock iOS

1. Grab a decrypted Spotify IPA (same version you want to patch).
2. Unpack the .deb: `dpkg-deb -x Needle-latest.deb needle`
3. Pull the dylib: `needle/Library/MobileSubstrate/DynamicLibraries/Needle.dylib`
4. Inject into the IPA:
   ```
   pip install cyan
   cyan -i Spotify.ipa -o Needle-Spotify.ipa -f Needle.dylib
   ```
5. Sign and install with Sideloadly, AltStore or your own cert.

## Features

- Premium flags on (no ads, unlimited skips, any track from any playlist, scrubbing, 320k, Spotify Connect).
- Real shuffle. Fisher Yates on the queue instead of the weighted algorithm.
- Album-colored Now Playing. Palette extracted from the artwork, animates on every track change, flows into the tab bar.
- Lockscreen takeover. Artwork pushed to `MPNowPlayingInfoCenter` at 3000x3000 with Apple Music's service identifier set, so iOS gives it the big-art treatment.
- Telemetry calls neutered (see `HOOKS.md`).

See `Tweak/HOOKS.md` for which selectors need a class-dump pass against your exact Spotify version before the hook will land.

## Legacy

The original Web-API client lives in the `Needle/` folder with its `project.yml`. Kept for reference. The tweak path in `Tweak/` is where new work goes.
