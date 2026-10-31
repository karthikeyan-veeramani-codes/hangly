# Tether — Milestone 2.1

An original native macOS desktop companion app. Add a few friends from the Character Library, hang them anywhere, drag them and let go to swing. Swift 6 · macOS 14+ · Apple Silicon and Intel builds · no external dependencies, accounts, network services or telemetry.

## Start

```sh
./scripts/build.sh Debug
open dist/Debug/Tether.app
```

Or open `Tether.xcodeproj`, select the **Tether** scheme and run. Tether lives behind the leaf icon in the menu bar and has no Dock icon. Choose **Character Library…** or **Add Character…** to browse the gallery. Search and filter the five original built-ins (Pip, Mallow, Sol, Luna and Nori) or your custom collection. Add a character with one click; use its desktop chip to select, duplicate or remove it. Settings edits the selected instance. Close either window and reopen it without creating another window.

Each desktop companion has independent rope physics, reaction/sleep state, size, opacity, attachment point, rope color/thickness, gravity, damping, wind, swing intensity, anchor, display and visibility. Selection does not replace other companions. Click to react, drag/release to swing, or right-click for quick controls. Show/Hide All and Pause/Resume All are in the leaf menu. Original vector artwork is drawn in Core Animation, with no copied third-party characters.

The default desktop limit is six; Settings allows 1–12. Up to 64 arrangements and 100 gallery entries are retained. Removing a companion from the desktop preserves its arrangement. Use **Forget Arrangement** in Settings for an off-desktop companion to permanently remove that saved instance. Duplicate makes a new independent instance of the same artwork. Restore Built-in Collection restores gallery entries without deleting your imports or existing arrangement.

## Bring your own artwork

Choose **Add Character…** in the library. Pick a PNG, or a WebP if this Mac's native ImageIO supports it. Review it against a checkerboard, enter a name, set its size and normalized rope attachment point, then **Save & Add to Desktop**. The attachment is relative to the rendered square artwork box; non-square images preserve their aspect ratio inside it. Imported static images only receive whole-image transforms.

Validation checks decoded content rather than extension: one complete frame, at most 20 MB input, up to 4096 × 4096 pixels and 64 MiB worst-case decoded RGBA storage. High-bit-depth images are restricted by decoded size too. WebP is normalized to PNG. Animated files are rejected. Files receive unique names in app-managed storage; importing the same artwork again makes a separate gallery entry without overwriting anything. Delete custom artwork through its gallery context menu to remove all of its companions and its copied file when no references remain. Missing/corrupt managed artwork uses a placeholder and an explanatory notice.

## Preferences and startup

Settings contains General, Characters, Rope & Physics, Animation, Displays, Performance and About. Changes are applied immediately and persisted. Startup visibility and restoring the previous arrangement are explicit controls. When arrangement restoration is off, startup keeps only the selected instance on the desktop. Launch at login is opt-in; install a signed app in Applications before evaluating it.

Version-1 preferences migrate to version 2 while preserving character sizes, anchors, display choices, custom files and damping. The original preference key remains discoverable; its original version-1 bytes are backed up once under `Tether.preferences.v1.migrationBackup`. Arrangements are restored after restart; transient velocities/reaction progress are session-only. UserDefaults domain: `in.tether.desktop`. Artwork: `~/Library/Application Support/Tether/Characters`. Nothing is uploaded.

## Builds, tests and release

Requires full Xcode with macOS SDK and Swift 6. Verified locally with Xcode 27.0 / Swift 6.4 on macOS 27.0.1. macOS 14 is the deployment target; actual older macOS and Intel runtime tests remain separate release gates.

```sh
./scripts/test.sh
./scripts/build.sh Debug
./scripts/build.sh Release
lipo -archs dist/Release/Tether.app/Contents/MacOS/Tether
./scripts/package.sh
```

Outputs: `dist/Debug/Tether.app`, `dist/Release/Tether.app`, `dist/Tether-2.1.0.dmg`. Both app builds contain `arm64` and `x86_64`. The package script ad-hoc signs locally unless a Developer ID identity is explicitly provided. It does not install, publish, upload, notarize or enable launch at login.

`Package.swift` supplies core and AppKit XCTest targets. Open it in Xcode to use generated package test schemes; the app's own Xcode scheme builds/runs the app, while `scripts/test.sh` runs the package tests. After adding/removing source files, run `python3 scripts/generate-project.py` to update deterministic Xcode file references. The original icon is committed; its native drawing and ICNS packager are in `scripts/`.

For short repeatable performance scenarios, run `python3 scripts/profile-milestone2.py` after the Release build with no other builds/tests running. It uses isolated preferences and automatic quit. A graphical login/WindowServer is required for UI checks; restricted runners explicitly skip display-dependent tests. The final results are recorded in [the milestone test report](docs/MILESTONE_2_TEST_REPORT.md).

## Platform behavior

One transparent, nonactivating render panel per assigned display contains all companions on that display. Each display also has one tiny nonactivating input gate; the render panel always ignores mouse input. They share a single animation scheduler, pointer sampler and occasional ambient timer. Physics stays at 120 Hz with an eight-step catch-up cap; frame quality is 30 or 60 Hz. Battery mode lowers animation frequency and idle variation frequency. Resting characters do not continuously redraw; idle variations are occasional Core Animation effects. Pause stops simulation and ambient animation. Hidden characters do not render; the default hidden policy also stops physics. System/display sleep stops all companion timers.

Vector/mask/image-alpha body hit tests and narrow rope tolerance drive a pixel-sized input gate at the cursor. Global/local movement updates plus a 30 Hz fallback keep it current; AppKit carries a started drag until release. The render surface permanently ignores clicks, so a stale full-screen hit region cannot swallow unrelated clicks. An actual owned-window probe delivered 20/20 rapid departures after this change. Very fast entry can still outrun gate placement and pass through, and physical driver/multi-display boundary acceptance remains a manual gate. No event taps, Accessibility permission or Screen Recording permission are requested by the app.

Display UUID choices are retained when a screen disconnects, with a temporary primary-display fallback. Reconnection to a recognized UUID restores placement. Anchor positions are normalized; logical sizes remain points. Notched screens use their reported top safe-area inset. Identifiers are not guaranteed across all hardware configurations. Public floating/Spaces/fullscreen flags provide best-effort visibility; macOS controls Mission Control, Stage Manager, fullscreen composition and protected system UI.

See [ARCHITECTURE.md](ARCHITECTURE.md), [milestone plan](docs/MILESTONE_2_PLAN.md), [milestone results](docs/MILESTONE_2_TEST_REPORT.md), [manual matrix](docs/MANUAL_TESTS.md), and [signing/notarization instructions](docs/RELEASE.md). The original `TEST_REPORT.md` records Milestone 1 and is retained as historical evidence.

Current verification: [Milestone 2.1 results](docs/MILESTONE_2_1_TEST_REPORT.md), [UX findings](docs/MILESTONE_2_1_UX_FINDINGS.md), [sustained performance](docs/MILESTONE_2_1_PERFORMANCE.md), and [owned-window evidence](docs/test-evidence/milestone-2.1/README.md). The final integration suite has 47 cases, preserving the previous 37. Sustained isolated checks are reproducible with `python3 scripts/profile-milestone21.py`.
