# Milestone 2.1 current acceptance

Use [the current report](MILESTONE_2_1_TEST_REPORT.md), [UX causes/fixes](MILESTONE_2_1_UX_FINDINGS.md), [sustained measurements](MILESTONE_2_1_PERFORMANCE.md), and [evidence scope](test-evidence/milestone-2.1/README.md). The M2 table below is historical and is superseded where actual 2.1 evidence exists.

| 2.1 check | Current scope/status |
|---|---|
| Crisp/aligned characters | PASS: inspected 44/88/160-point 1×/2× sheets, transformed attachment tests and native light/dark owned-window captures |
| Drag/release | PASS mechanically: generated native down/drag/up captured, moved, released, no underlying down; subjective physical-mouse feel remains NOT TESTED |
| Rope/animation | PASS deterministic timing/constraint/pivot/state tests; prolonged visual feel remains manual |
| Click-through | PASS in owned-window actual probe: ordinary clear clicks and 20/20 rapid exits with pixel input gates; fast-entry/driver cases remain manual |
| Gallery/settings/menu | PASS native key-equivalent/action/window reuse and inspected captures; complete picker/search/Tab workflows remain manual |
| Fullscreen/Spaces/Mission Control | PASS owned fullscreen enter/exit and Space creation/removal; lateral switching and Mission Control remain NOT VERIFIED; enabled Stage Manager owned-window launch/appearance passed and original setting restored |
| Physical multi-monitor | BLOCKED: one screen available; policy/refresh tests are not hardware evidence |
| VoiceOver/keyboard/Reduce Motion | PASS native labels/press, Command-L, actual approved Reduce Motion/contrast/VoiceOver toggles and owned native focus probe; all restored. Spoken focus order and complete keyboard workflows remain manual |
| Long CPU/leak/energy | Sustained final-binary harness results are in the performance report; unsupported tooling is recorded explicitly |
| Regression/builds | PASS 47 tests retaining all 37 originals; universal Debug/Release, local signature and DMG checks |

Never change system-wide accessibility/Stage Manager preferences without approval. The implementation adds a keyboard-accessible wake/swing action and keeps input gates out of the accessibility tree and keyboard focus.

---

# Milestone 2 verification matrix

Status vocabulary: **PASS** = actually checked as described; **FAIL** = a check failed; **BLOCKED** = required access/hardware unavailable; **NOT TESTED** = no completed acceptance check. Automated policy checks are never physical hardware verification.

## Acceptance checklist

| Acceptance criterion | Automated / local evidence | Manual acceptance status |
|---|---|---|
| Character gallery opens and allows adding | PASS: reusable NSHostingView window opens through menu; add, duplicate, remove, capacity and restoration operations tested | NOT TESTED: complete click-through search/filter/add flow |
| Multiple companions move independently | PASS: independent session velocity, animation model, configuration and shared panel tests | NOT TESTED: simultaneous visual interaction |
| Drag, release and animation are smooth | PASS: original fixed-step/constraint/settling tests, independent engines and reaction state transitions | NOT TESTED: physical mouse gesture feel and fast boundary clicks |
| Custom artwork import/delete | PASS: PNG, original WebP decode/normalization, malformed/oversized rejection, cache, separate duplicate imports, deletion of references/files | NOT TESTED: complete native picker → preview → save workflow and all attachment extremes |
| Settings persist after restart | PASS: new store reconstructed from isolated UserDefaults; arrangements/settings equal; v1 migration backup verified | NOT TESTED: manual normal-app quit/relaunch, login item approval |
| Rope/physics customization | PASS: finite sanitization, in-place appearance updates preserve velocity, eased length changes and existing solver tests | NOT TESTED: all controls at extremes during dragging |
| Display disconnection does not strand companions | PASS: deterministic UUID fallback without overwriting saved preferences; simulated sleep/wake | BLOCKED: physical monitor disconnection/reconnection not performed |
| Menu actions avoid duplicate windows | PASS: menu action opens gallery twice with same NSWindow; settings same; independent overlays share a display panel | NOT TESTED: keyboard-only menu navigation and long repeated menu use |
| Existing and new tests pass | PASS: full suite; see MILESTONE_2_TEST_REPORT.md | No manual substitute needed |
| Final Release launches | PASS: packaged universal executable smoke test with isolated preferences and automatic quit | NOT TESTED: quarantined install on a clean Mac |

## Detailed manual procedure

1. **First launch and gallery** — Launch `dist/Release/Tether.app`. Confirm no Dock icon, leaf/count in menu bar. Open library with both menu actions; confirm one window. Search for Luna, filter Custom/Built-in, clear search, add 3–6 companions. Each add should be reachable and avoid an occupied initial anchor. Use desktop chips to select, duplicate and remove. Restore built-ins should retain custom artwork and existing instances.
2. **Independent interaction** — Swing one companion while another settles. Drag near each artwork's edge and rope, hold still, then release; the grab should preserve pointer offset and a held release should avoid a stale throw. Click asleep/awake companions. Right-click to swing, duplicate/remove and pause all. Test overlapping companions: the visually frontmost one should receive input.
3. **Underlying applications** — Click, type, drag and select in apps/desktop away from body/rope; move quickly across hit boundaries and assess fast entry into the one-pixel input gate. Confirm system menu, menu-bar auto-hide and notch regions stay usable.
4. **Import** — Choose your own transparent/non-square PNG, complete native WebP, large/high-bit-depth PNG, malformed/truncated file and animated image. Preview checkerboard, edit name/size/attachment, cancel without saving, then save/add. Reimport same artwork and verify separate entries. Delete one template with duplicate active instances; other artwork must remain. Delete/replace a managed file externally in an isolated account and relaunch to verify placeholder/notice.
5. **Settings and persistence** — Adjust every section, selected-instance name/size/opacity/visibility, rope thickness/color/attachment/length, gravity/damping/wind/intensity, animation speed/idle/blink/sleep, quality, startup/restore and active limit. Verify independent changes, keyboard navigation and immediate feedback. Pause during a reaction and resume. Hide/show and close/reopen UI windows. Quit/relaunch with restoration on/off and startup visibility on/off. Original v1 data migration should preserve its recorded values and backup.
6. **Displays** — On real hardware, connect/disconnect/rearrange monitors, switch primary screen, change resolution/Retina scaling, disconnect while sleeping, then reconnect. Every instance should fall back temporarily and return when its saved UUID is recognized. Confirm anchors stay reachable and no duplicate panels survive. UUID changes across hardware configurations are not guaranteed to reconnect automatically; reassign in Settings.
7. **Spaces and lifecycle** — Test Safari/video/editor fullscreen, Mission Control, Stage Manager and menu-bar auto-hide. Visibility remains subject to macOS policy. Sleep system and display during drag and wake. Toggle visibility 100 times, switch templates and remove all companions. No stranded capture/panel should remain.
8. **Accessibility and appearance** — Test VoiceOver per-companion press-to-wake actions and Settings/library navigation, keyboard-only operation, macOS Reduce Motion and light/dark appearance. Native view-cache snapshots were useful for artwork/layout but did not reliably include system-composited controls/materials. Milestone 2.1 obtained existing capture access and inspected actual Tether-only composited captures; older M2 view snapshots remain historical evidence.
9. **Login and distribution** — Only in a signed installed app, opt in/out of login registration, approve if required and log out/in. Download a notarized DMG on a clean machine, mount, drag-install and launch. No such login registration or upload is performed by automated tests/builds.

## Performance and endurance

Run the final Release binary with no builds/tests in parallel. `scripts/profile-milestone21.py` uses isolated preferences and sustained 60+ second samples; use the M2.1 report and baseline JSON for current data. The earlier `profile-milestone2.py` short samples remain historical. Record actual hardware, power source, OS, image sizes, count, quality and Reduce Motion state. Compare medians and variability rather than individual coarse percentages.

Use Instruments Time Profiler/Activity Monitor for at least 60 seconds per state, and Allocations/Leaks/energy recording for at least 10 minutes of adding/removing, importing/deleting, gestures, hide/show, Settings/library reopen and display changes. Monitor WindowServer separately. Check stable post-warm-up allocations; cached image/SwiftUI resources may remain while their reusable UI windows exist. Session/renderer cleanup tests do not constitute a complete leak audit.

PASS structural gates: original bounded catch-up, zero continuous redraw growth at rest/pause, invalidated simulation/pointer timers while hidden, and independent session/renderer release. Long-run leak/energy, older macOS, physical Intel and real multi-display tests remain NOT TESTED/BLOCKED as described in the milestone report.
