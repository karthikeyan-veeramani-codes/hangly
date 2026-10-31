# Milestone 2 implementation plan

## Audit

The existing app has a deterministic 120 Hz rope solver with eight-step catch-up cap; three vector artworks; one full-display NSPanel; one active selected character; per-character configuration and a velocity cache; SwiftUI Settings; version-1 Codable preferences; a UUID-based display resolver; validated PNG copies; NSStatusItem controls; and 21 XCTest cases. The single-character selection currently controls rendering, so changing a selection must be separated from adding/removing desktop instances.

## Implementation sequence and boundaries

1. Preserve the physics solver and all 21 tests. Add versioned decoding with explicit v1→v2 migration, a five-item built-in catalog, separate library assets / desktop instances, bounded instance operations and per-instance appearance/physics settings.
2. Add a reusable deterministic animation state machine. Extend the existing renderer with two new original vector characters, editable rope appearance, attachment point, opacity and safe whole-artwork reactions. Retain static rendering when settled.
3. Evolve OverlayManager to coordinate independent CharmSessions. Share one overlay panel per display, one simulation timer and one pointer sampler across characters. Keep the selected-character accessors for existing callers/tests. Update configuration in place, preserve velocities, and rebuild panels only for actual display/lifecycle changes.
4. Add an idempotent native library window with search, built-in/custom collections, thumbnails, add/remove/duplicate/delete/restore. Add a staged PNG/native-WebP import editor with checkerboard preview, scale, normalized attachment and name. Store validated content locally; cache decoded assets with bounded memory and reference-aware cleanup.
5. Extend native Settings and menu actions around the active arrangement. Preserve menu-only lifecycle, add startup restoration controls, frame quality and battery scheduling. Keep display UUID fallback without rewriting saved choices.
6. Run existing and new tests after each dependent slice; verify panel counts and owner cleanup, migration, library mutations, multiple independent physics/animation states, import failures, rope updates, shared pause/rest scheduling and display notifications.
7. Regenerate the existing Xcode file references, build universal Debug/Release, launch the final Release executable, package locally and repeat measured profiles at 1/3/6 active instances. Investigate the original paused/settled difference using comparable samples; make no improvement claims from noise.
8. Update README/architecture/manual matrix, Milestone 2 test report and baseline JSON with PASS/FAIL/BLOCKED/NOT TESTED. No commit, push, publishing, login registration, signing-credential use or notarization.

## Acceptance and constraints

Default desktop limit: 6; configurable 1–12 with a hard limit of 12, and at most 64 retained arrangements / 100 library entries. Imported assets have file-size, dimension and decoded-memory bounds. One panel per connected display avoids N full-screen windows and competing mouse capture. Hit testing routes to the frontmost visible character/rope and retains the gesture target until release. Normal fullscreen/Spaces limits and the existing pointer-sampling boundary latency remain documented. Physical monitor tests and macOS/Intel devices cannot be substituted with policy tests.

The user's checked list is treated as requested acceptance criteria; features are marked verified only after checks actually run.

## Completion record

| Requested phase | Result and evidence |
|---|---|
| 1 — Audit | PASS: existing modules and 21 tests reviewed; existing physics reused |
| 2 — Library | PASS implementation/business operations/window smoke; full manual gallery flow NOT TESTED |
| 3 — Multiple instances | PASS independent sessions, bounded operations and shared-panel tests |
| 4 — Animation | PASS deterministic transitions, paused reaction timing and Reduce Motion; visual feel NOT TESTED |
| 5 — Imports | PASS PNG/WebP validation, normalization, cache, corruption and deletion; full picker/editor workflow NOT TESTED |
| 6 — Settings | PASS implementation, persistence/migration and window reuse; full appearance/VoiceOver NOT TESTED |
| 7 — Rope | PASS in-place updates, finite sanitization, eased length and preserved solver tests |
| 8 — Displays | PASS fallback/notification policy; physical monitors BLOCKED and actual Spaces/sleep NOT TESTED |
| 9 — Menu | PASS actions/window reuse and status item lifecycle implementation; keyboard-only acceptance NOT TESTED |
| 10 — Performance | PASS final Release 1/3/6 short scenarios and two Instruments recordings; no improvement claim, endurance NOT TESTED |
| 11 — Tests | PASS all 37 tests, including the 21 originals, zero failures/skips with WindowServer |
| 12 — Delivery | PASS universal Debug/Release, final launch/gallery smoke, ad-hoc signature and DMG checksum; docs updated |

No commit, push, install, login registration, publication, Developer ID credential use or notarization occurred. Manual/credential-dependent gates are enumerated in MILESTONE_2_TEST_REPORT.md and MANUAL_TESTS.md.
