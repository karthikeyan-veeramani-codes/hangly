# Milestone 2 verification report

31 October 2026 · Apple Silicon MacBook Pro · macOS 27.0.1 · Xcode 27.0 / Swift 6.4 · macOS 14 deployment target. Status terms: PASS, FAIL, BLOCKED, NOT TESTED. Checked boxes supplied in the request were treated as acceptance criteria, not as prior verification evidence.

## Implemented

- Native searchable/filterable Character Library with five original vector companions, thumbnails, built-in/custom collections, desktop chips, selection, add/remove/duplicate, custom artwork deletion and built-in restoration.
- Simultaneous independent desktop instances. Each owns settings, physics, animation and visibility. Default active limit six, configurable 1–12, hard cap twelve, 64 retained arrangements and 100 gallery entries. Removed desktop instances retain their configuration; forgetting an arrangement removes it permanently.
- Reusable idle/swinging/dragging/reacting/sleeping/waking/paused animation machine, occasional blink/nod, finite click reactions, inactivity sleep and interaction wake, Reduce Motion policy and safe whole-image transforms for imports.
- Staged PNG/native-WebP editor with checkerboard preview, scale/name/attachment, complete decoded-content validation, bounded dimensions/high-bit-depth decoded memory, normalized PNG storage, unique filenames, cache and reference-aware deletion.
- Native seven-section Settings; independent opacity, rope color/thickness/length, attachment, gravity/damping/wind/intensity, display assignment, startup restoration, quality and power policy. Version-1 migration retains data and one original-byte backup.
- Shared overlay panels and scheduling, matching z-order/hit routing, captured gesture target/offset, in-place settings updates preserving velocity, eased rope-length changes, display UUID fallback, safe-area/scale reconciliation and separate display/system sleep notifications.
- Menu actions for Show/Hide All, Pause/Resume All, Add Character, Character Library, Active Characters, Settings, About and Quit; reusable UI windows and explicit status item teardown.

## Automated checks

**PASS: all 21 original XCTest cases retained and passing.** Added 16 cases (seven core and nine AppKit) for **37 total**, with zero failures and zero skips in the WindowServer-enabled final run. Core tests verify library mutation, duplication/limits/deletion, persistence, startup restoration, schema migration, finite rope/appearance sanitization, animation transitions and Reduce Motion. AppKit tests verify independent session velocity, one display panel for several characters, appearance changes without velocity reset, eased rope changes, dormant renderer/session cleanup, arrangement restoration and migration backup, UUID fallback without overwriting saved display choice, cached decode, corrupt assets, path traversal rejection, duplicate file imports, reference/file deletion, native WebP normalization, shared pause/hide cleanup and idempotent library/settings windows opened through menu actions.

Original fixed-step equivalence, constraint/settling, catch-up bounds, import errors, settings recovery, display-selection policy, pause/rest scheduling, simulated sleep and owner-release tests still pass. Tests that need a screen explicitly skip on headless/restricted runners; the final run used WindowServer access and had none skipped. No test registers a login item or changes the normal user's arrangement.

Evidence: `.build/m2-tests-final.log`. SPM supplies the XCTest test products; the Xcode app scheme supplies universal build/run products. AppKit can defer release of an NSWindow through framework/autorelease ownership; teardown checks assert closed/detached panels, released session/renderers and stopped timers rather than requiring synchronous framework window deallocation.

## Build and packaging

- **PASS:** final universal Debug and Release Xcode builds; `lipo -archs` reports `x86_64 arm64` for both.
- **PASS:** final packaged Release executable launched/quit with six companions (`--smoke-test --profile-count 6`), exit 0, using isolated preferences.
- **PASS:** final Release gallery/settings smoke (`--gallery-smoke --profile-count 3`), exit 0.
- **PASS:** `codesign --verify --strict --verbose=2` on the ad-hoc-signed Release app.
- **PASS:** `hdiutil verify dist/Tether-2.0.0.dmg`, checksum valid.
- **PASS:** `plutil -lint` for Info.plist and the Xcode project.

Artifacts: `dist/Debug/Tether.app`, `dist/Release/Tether.app`, `dist/Tether-2.0.0.dmg`. Logs: `.build/m2-debug-final.log`, `.build/m2-package.log`, `.build/m2-release-smoke.log`, `.build/m2-release-gallery-smoke.log`, `.build/m2-dmg-verify.log`. Xcode's AppIntents metadata-extraction-skipped note is expected because this app has no AppIntents dependency. The new Xcode file references build both slices without suppressed Swift 6 errors.

Developer ID credentials, signing/notarization upload and clean-machine trust validation were not used. Local packaging is ad-hoc signing only.

## Performance investigation

The original one-character M1 baseline was settled 0.165%, wind 0.829%, paused 0.658%, hidden 0.000% at coarse sampling resolution, with roughly 48–54 MiB RSS. Those were short host-specific observations, not guarantees. M2's shared pointer sampler and physics scheduler replace independent full-screen character windows/timers. During review, repeated global-pointer queries inside the hit-test walk were reduced to one query per callback.

Two repeated settled/paused pairs show that ordering can reverse; the original paused-visible gap is not a stable observation. Both paths retain the same pointer sampler while simulation is suspended, and tests verify no continuous redraws or simulation while paused/resting. Quantized CPU-time samples on an interactive host cannot establish a small causal regression or improvement. Final data and exact binary hash are recorded in the performance section below and `PERFORMANCE_BASELINE.json`.

## Visual and hardware verification

- **PASS:** native gallery/settings windows open, stay visible and are reused by repeated actions; artwork/layout snapshots were generated from the app's own views. Three-companion diagnostic launch also succeeded.
- **NOT TESTED:** full compositor appearance, native-control/vibrancy correctness in both light/dark, complete mouse-driven import/search/filter workflows, keyboard-only/VoiceOver acceptance, sleep visual feel and fast click-through boundaries. View-cache snapshots omit or misrender some system-composited controls/materials and are not full appearance acceptance. `CGPreflightScreenCaptureAccess` returned false; no permission request or whole-desktop capture was made.
- **PASS (simulation/policy only):** missing UUID fallback without changing saved preference; simulated display-sleep/wake and deterministic disconnect/reconnect policy tests.
- **BLOCKED:** physical external monitor disconnect/reconnect and mixed-DPI display testing; no extra monitor was exercised. Real sleep/reconfiguration, menu auto-hide/notch and fullscreen/Spaces/Mission Control/Stage Manager behavior remain NOT TESTED.
- **NOT TESTED:** actual Intel execution, macOS 14–26 runtime, installed signed app's login approval/logout-login cycle, long Allocations/Leaks/energy/endurance runs, notarization and quarantined clean-machine installation. Universal slices do not prove hardware/OS coverage.

## Files and modules changed

Core: extended Preferences/Charm schema and library operations; added Animation.swift; original Physics.swift preserved. App: evolved OverlayManager/renderer/interaction, preferences store, lifecycle, Settings/menu and importer; added CharacterLibrary.swift and PowerState.swift. Tests: added Milestone2Tests.swift and Milestone2AppTests.swift without replacing original tests. Build: regenerated existing Xcode file references, updated app/version-2 DMG metadata and added reproducible milestone profiling script. Documentation: README, architecture, plan, manual matrix, release instructions, milestone report and baseline JSON. No commit, push, publication or notarization was performed.

See `MANUAL_TESTS.md` for the remaining acceptance workflow and `RELEASE.md` for credential-dependent release steps.

## Final Release measurements

Binary SHA-256: `5ec795e3f1b17c293845fb0af5c9f266bada6f979f927c287e603013755e855d`. Five-second warm-up, seven process CPU-time/RSS samples spanning about six seconds per scenario. No builds or tests ran during either full measurement pass. Ambient variation and inactivity sleep were disabled for comparable steady-state cases; the ambient case used default idle behavior. CPU is percentage of one core; 0.01-second CPU-time resolution makes small figures coarse. The reported RAM range is resident memory, not decoded import peak memory.

| Active | Mode | CPU | RSS range (MiB) |
|---:|---|---:|---:|
| 1 | idle | 0.165% | 54.50–54.72 |
| 1 | paused | 1.152% | 54.48–54.81 |
| 1 | idle | 0.987% | 54.36–54.59 |
| 1 | paused | 0.494% | 54.36–54.67 |
| 1 | wind | 1.316% | 54.22–54.47 |
| 1 | hidden | 0.000% | 54.03–54.38 |
| 3 | idle | 0.657% | 54.55–54.83 |
| 3 | wind | 1.481% | 54.61–54.80 |
| 6 | idle | 0.821% | 54.66–54.95 |
| 6 | wind | 3.444% | 54.70–54.97 |
| 6 | ambient | 0.986% | 54.62–54.84 |

The M1 reference and both repeated M2 settled/paused pairs remain visible in the baseline data. The final settled range was 0.165–0.987% and paused was 0.494–1.152%; their ordering reverses across pairs. The one-character wind sample (1.316%) exceeded the old 0.829% short observation. Six-character wind was 3.444%, with RSS still around 55 MiB. No performance improvement or CPU target achievement is claimed from these brief, noisy measurements. Hidden was zero at the sampling resolution, consistent with the tested timer suspension. Longer matched runs are needed to characterize active rendering cost and energy usage.

**PASS:** final Release scenario measurements completed at 1/3/6 instances; exact binary hash recorded. **NOT TESTED:** sustained CPU/energy targets, long-term allocation growth, large-image import peak RSS and actual battery discharge endurance. The first pre-refinement M2 pass remains locally in `.build/m2-performance-before-pointer.json`; it is not substituted for the final-binary data.

## Final Instruments evidence

**PASS:** seven-second Time Profiler recordings attached to the exact final Release PIDs in paused/one-instance and wind/six-instance modes, both recorder exits 0; exported tables confirm the Release executable in sampled backtraces. The paused trace has 21 CPU samples, five containing the pointer path and none containing the simulation or renderer path. The six-wind trace has 177 samples, 97 containing the shared simulation path and 85 containing the renderer path (inclusive counts overlap). Sampling is statistical and these small counts are not a long-term CPU budget or proof of every callback's absence.

Local evidence: `.build/M2-paused-1.trace`, `.build/M2-wind-6.trace`, their `-toc.xml` and `-samples.xml` exports, and `-instruments.log` files. This corroborates the automated pause/rest checks and identifies the retained visible-pointer sampler as intentional work. The repeated process samples still do not isolate a stable paused-versus-idle CPU difference. Long matching Time Profiler/Allocations/Leaks/energy runs remain a release gate.
