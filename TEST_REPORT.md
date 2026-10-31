> Current Milestone 2.1: [47 passing tests, universal builds and verification limits](docs/MILESTONE_2_1_TEST_REPORT.md).

> Historical Milestone 1 report. Current Milestone 2 results: [37 passing tests, universal builds and verification limits](docs/MILESTONE_2_TEST_REPORT.md).

# Tether verification report

Date: 31 October 2026. Host: Apple Silicon MacBook Pro, macOS 27.0.1, Xcode 27.0, Swift 6.4. Deployment target: macOS 14.0. No verification is claimed on macOS 14, physical Intel Macs or external monitors.

## Verified

- Swift Package debug compilation with Swift 6 strict concurrency.
- Xcode Debug and Release app builds with both `arm64` and `x86_64` slices. `lipo -archs` confirmed both architectures.
- **21 XCTest cases passed, zero failures, zero skipped** in the final WindowServer-enabled run: 8 physics tests, 5 model/preferences/display-policy tests and 8 AppKit integration tests.
- Bundled Release executable launched and quit successfully using `--smoke-test`, with isolated test preferences. This is a launch/lifecycle check, not a visual acceptance test.
- Release app ad-hoc code signature verified with `codesign --verify --strict`.
- Generated DMG checksum verified with `hdiutil verify`.
- Info.plist and Xcode project passed `plutil -lint`.
- Original app icon generated using AppKit paths, packaged as ICNS and visually inspected. No third-party character or icon assets.

## Automated coverage

Physics: fixed-step equivalence across 30/60 Hz frame delivery, taut rope constraint, natural settling, velocity bounds, screen containment, bounded catch-up, invalid deltas, rest/wake, wind, accumulator reset and rope hit geometry. A 12,000-step XCTest microbenchmark records wall time without an asserted cross-device speed target.

Models: Codable round-trip, independent character configuration, malformed JSON, unsupported schema, invalid values, path traversal rejection, duplicate IDs, missing selection/characters and deterministic disconnect/reconnect/headless display fallback.

AppKit: isolated UserDefaults persistence and corrupt recovery, validated PNG copy plus malformed/oversized rejection, panel replacement and idempotent teardown, weak owner release, paused rendering suspension, hidden timer suspension, cached independent character velocity, rest-triggered timer/render suspension, and simulated display-sleep/wake notification handling. Notification simulation does not verify actual hardware sleep or reconfiguration.

## Preliminary profiling

An Instruments Time Profiler recording attached to the exact universal Release binary's arm64 process and completed successfully. Five seconds of recording produced 95 CPU samples; the exported backtraces confirm the Release executable path. Local files: `.build/Tether-release-idle.trace`, `.build/profile-release-toc.xml`, `.build/time-profile.xml`. The earlier launch-by-bundle recording resolved a Debug registration and is excluded from the baseline.

A separate quieter measurement used isolated preferences, five seconds of warm-up, then seven `ps` samples spanning about six seconds per state. CPU below is the change in cumulative process CPU time divided by elapsed time, expressed as a fraction of one core. The 0.01-second CPU-time resolution makes small percentages coarse. No builds or tests ran during this repeat. These are short implementation-stage measurements; the final subsequent changes added sleep notification observers and import error presentation, not a full repeated performance certification.

| State | CPU, one core | RSS range |
|---|---:|---:|
| Settled, wind off | 0.165% | 53.38–53.53 MiB |
| Wind enabled | 0.829% | 53.38–53.48 MiB |
| Paused, visible | 0.658% | 53.47–53.59 MiB |
| Hidden | 0.000% at sampling resolution | 47.94–53.17 MiB |

Raw short-run data remains in `.build/performance-baseline.json`; portable summary is in `docs/PERFORMANCE_BASELINE.json`. A previous run overlapped with builds/tests and had larger transient CPU/RSS; it is excluded from the quieter baseline. Neither run proves absence of long-term allocation growth or low energy usage on all systems.

After establishing this baseline, provisional **investigation thresholds on this host** are >1% median CPU for settled/paused, >3% with wind, >0.2% hidden, or >100 MiB warmed RSS with a built-in character and Settings closed. Repeat with longer samples and noise bands before accepting a regression. Large custom images can legitimately exceed that RSS threshold. Structural gates (verified in tests): zero redraw growth after rest/pause, no companion timers while hidden/asleep, at most eight fixed steps per update, and owner release after teardown. These thresholds are not advertised product guarantees.

## Findings corrected

The first integration run exposed recursive publication during preference sanitization. Sanitization now happens before a single published assignment; persistence and lifecycle tests cover the path. Panel input capture is cleared on suspension; held releases discard stale velocity; switching characters preserves independent motion. Display-only sleep now stops timers as well as full system sleep. Import errors now appear immediately even when initiated outside Settings.

Restricted runners can fail to launch Apple's SwiftUI compiler macro service or expose no NSScreen displays. Final Xcode builds and integration tests were run with the required local compiler/WindowServer access. Missing displays cause explicit skips in display-dependent scheduling tests; the final run had none.

## Not yet verified / release gates

- Manual visual acceptance: dragging feel, fast hit-boundary clicks, transparent interaction with underlying apps, VoiceOver, light/dark Settings, actual fullscreen/Spaces/Mission Control/Stage Manager behavior and menu-bar auto-hide/notches.
- Physical external monitor disconnect/reconnect, screen arrangement, mixed Retina scaling and actual display/system sleep/wake.
- Runtime on macOS 14–26 and physical Intel Macs; a successfully built slice is not a runtime test.
- Long Time Profiler/Allocations/Leaks/energy recordings and endurance testing. Weak-reference teardown checks and short RSS samples are not a complete leak audit.
- Installed signed app's launch-at-login behavior and user approval flow. Tests did not register a login item.
- Developer ID signing, notarization, Gatekeeper acceptance and clean-machine distribution. Credentials were unavailable and no upload was attempted.

Use `docs/MANUAL_TESTS.md` for the remaining matrix and `docs/RELEASE.md` for signing and notarization. The app is functional and locally buildable; a trusted production release remains gated on these checks.
