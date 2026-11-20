# Midfold

Party games you play with the fold. Made for iPhone Duo, playable on every iPhone and iPad.

**Fold games** (one player, the hinge is the controller)
- **Fold Flight**: open the phone wider to climb, close it to dive, and steer a paper glider through the gaps.
- **Angle Lock**: fold to eight target angles and hold each one steady, against the clock.

**Face-to-face duels** (two players, one phone open flat between them; each half of the inner display turns toward its player and the fold is the centre line)
- **Quick Draw**: wait for green, tap first. Too early and the point goes across.
- **Tug Line**: tap as fast as you can to pull the knot over the fold to your side.
- **Odd Spot**: each player gets their own grid; find the one symbol that is different first.

On iPhones without a hinge the fold games are steered by tilting the phone or with a slider, and duels split the screen in two. Offline, no accounts, no ads. English and Turkish.

## Development

Native SwiftUI (iOS 17+, iPhone Duo APIs behind `#available(iOS 27.1, *)`), XcodeGen. Game logic is plain Swift in `Midfold/Logic` with XCTest in `MidfoldTests`.

```
brew install xcodegen && xcodegen generate
xcodebuild test -project Midfold.xcodeproj -scheme Midfold -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- `.github/workflows/ios-testflight.yml`: unit tests → App Store Connect check → archive → TestFlight (runner `xcode-27`).
- `.github/workflows/screenshots.yml`: App Store screenshots from the simulator (iPhone, iPad 13", iPhone Duo outer and inner display; the hinge is set with `tools/duo-hinge.m`).
- `scripts/strings.py` builds the string catalog, `scripts/icon.py` draws the icon.

Repository secrets: `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_PRIVATE_KEY`, `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `KEYCHAIN_PASSWORD`.

## License

MIT. `tools/duo-hinge.m` is vendored from tosbaha/duo-fold-control (MIT) at a pinned commit, see its header.
