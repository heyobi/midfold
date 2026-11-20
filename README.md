# Midfold: Pump to Fly

An arcade flight made for iPhone Duo. Hold the phone sideways, half open, and pump the hinge: every close-then-open is a wing flap for Kip, a little bird folded from paper. Quick, deep pumps flap hard; small ones make small hops. On other iPhones and iPads you tap to flap.

- 3 worlds × 6 levels: Paper Meadow (gates), Gusty Cliffs (drafts, sliding gates), Ink Caves (narrow tunnels)
- 3 stars and 3 feathers per level, Endless mode, a daily course that is the same for everyone
- Haptics scaled by flap strength, generated paper sounds, parallax, particles, screen shake, instant retry
- Game Center leaderboards (Endless, total stars) and achievements
- Free: Paper Meadow and the daily course. One-time purchase: the other worlds and Endless. No ads, no tracking, offline. English and Turkish.

## How the pump works

`Midfold/Logic/Pump.swift` reads the hinge angle from `onHingeChange` (iOS 27.1). It smooths it lightly, follows the closing stroke with a few degrees of hysteresis, and fires a flap when the stroke turns around. The strength comes from the stroke's depth and its fastest closing speed, scaled by the sensitivity setting. A minimum depth and a short cooldown stop tremor and sensor jitter from flapping. Unit tests feed it synthetic angle series: fast and slow pumps, jitter, and irregular sample times.

## Development

Native SwiftUI (iOS 17+, iPhone Duo APIs behind `#available(iOS 27.1, *)`), XcodeGen. Game logic is plain Swift in `Midfold/Logic` with XCTest in `MidfoldTests`.

```
brew install xcodegen && xcodegen generate
xcodebuild test -project Midfold.xcodeproj -scheme Midfold -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- `.github/workflows/ios-testflight.yml`: unit tests → App Store Connect check → archive → TestFlight (runner `xcode-27`).
- `.github/workflows/screenshots.yml`: App Store screenshots from the simulator (iPhone, iPad 13", iPhone Duo outer and inner display). The hinge is set to each shot's angle with `tools/duo-hinge.m`.
- `scripts/compose-screens.py` adds captions, `scripts/strings.py` builds the string catalog, `scripts/sounds.py` draws the sound effects, `scripts/icon.py` draws the icon, `scripts/listing.py` writes the 5-language store text.

Repository secrets: `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`, `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `KEYCHAIN_PASSWORD`.

## License

MIT. `tools/duo-hinge.m` is vendored from tosbaha/duo-fold-control (MIT) at a pinned commit, see its header.
