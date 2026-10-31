# Build, signing and release

## Local artifacts

Run `./scripts/build.sh Debug` and `./scripts/build.sh Release`. Both scripts request arm64 and x86_64 slices. Check `lipo -archs dist/Release/Tether.app/Contents/MacOS/Tether`. Cross-compiling an Intel slice does not verify Intel runtime behavior.

Run `./scripts/package.sh` to make a compressed read-only DMG with an Applications shortcut. Only the generated `dist/Release/Tether.app` is replaced; user data is untouched. The package script uses an isolated temporary staging directory and removes it on exit. Without an identity the app is ad-hoc signed for evaluation, which is not trusted Developer ID distribution. Never advise users to disable Gatekeeper.

## Developer ID distribution

Use your own registered bundle identifier and development team for a real release. The sample identifier is `in.tether.desktop`. In Xcode's Signing & Capabilities, choose a team and Developer ID Application signing for distribution. Hardened runtime is enabled in the project. There are no runtime entitlements needed for current features. The current distribution is not App Store sandboxed.

With an available Developer ID Application certificate:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./scripts/package.sh
codesign --verify --strict --verbose=2 dist/Release/Tether.app
```

The script signs the main app with hardened runtime and timestamp, then signs the DMG. No nested executable code is bundled. Do not use `--deep` to paper over invalid signatures.

## Notarization (manual, authorized upload)

These steps contact Apple and need your developer credentials; they were not run during implementation. Store a notarytool Keychain profile using Apple's instructions; do not put secrets in this repository or shell history. With that existing profile:

```sh
xcrun notarytool submit dist/Tether-2.1.0.dmg --keychain-profile TetherNotary --wait
xcrun stapler staple dist/Tether-2.1.0.dmg
xcrun stapler validate dist/Tether-2.1.0.dmg
spctl --assess --type open --context context:primary-signature --verbose=2 dist/Tether-2.1.0.dmg
```

Check accepted status and investigate the notarytool log on failure. Test mounting the DMG, drag-installing the app in Applications and launching a quarantined download on a clean Mac. Notarizing the DMG contains the app in the submission. For a separately distributed ZIP/app, notarize that artifact and staple the app as well before archiving it.

## Release gate

Complete the manual matrix, Instruments idle/active profiling and leak checks on supported macOS versions and actual Intel hardware. Verify SMAppService on the installed signed bundle and check login behavior after logging out/in. Never enable login items as part of an automated test. Automatic updates using Sparkle are explicitly a later phase; no update checker is currently bundled.

References: [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register()).
