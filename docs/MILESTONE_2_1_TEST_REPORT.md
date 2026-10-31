# Milestone 2.1 verification report

31 October 2026 · Apple Silicon · macOS 27.0.1 · Xcode 27.0 / Swift 6.4 · deployment target remains macOS 14. Statuses: PASS, FAIL, BLOCKED, NOT TESTED. This report separates actual owned-window desktop exercises, deterministic tests and remaining human/hardware acceptance.

## Implementation and regressions

**PASS:** 47 XCTest cases, zero failures/skips in `.build/m21-tests-final.log`. All 37 originals are retained. Ten added regressions cover actual-position/event-time release estimation, held/invalid samples, transformed rope attachment at three sizes, recursive Retina scale, imported/vector transparency, gesture cancellation, overlapping target selection, Reduce Motion policy, native keyboard menu dispatch, named accessibility press, permanently click-through render panels and display-frame refresh. An actual temporary native fullscreen window and actual NSApplication hide/unhide are exercised too. The fixed-step physics architecture/constants are preserved.

**PASS:** universal Debug and Release builds (`x86_64 arm64`), Release launch/evidence smoke, local ad-hoc signature and DMG checksum checks. Artifacts: `dist/Debug/Tether.app`, `dist/Release/Tether.app`, `dist/Tether-2.1.0.dmg`. Logs: `.build/m21-debug-final.log`, `.build/m21-package-final.log`, `.build/m21-dmg-verify.log`. Trusted Developer ID distribution/notarization remains unverified.

Source changes: added pure DragTracker; refined renderer pivot/alpha/vector hit testing/scale/contrast; evolved OverlayManager with pixel input gates, event timestamps and lifecycle cancellation; polished gallery import/selection/deletion and native menu/Settings/reset/notice flows; added permission-guarded owned-window evidence and isolated profiling diagnostics. See `MILESTONE_2_1_UX_FINDINGS.md` for defect IDs, causes and before/after behavior.

## Actual desktop/input observations

| Check | Expected | Observed | Status / evidence |
|---|---|---|---|
| Normal owned underlay | Outside and clear-corner clicks reach it; body stays with companion | Counts increased for outside/corner, not body | PASS, `test-evidence/milestone-2.1/input-routing.json` |
| Rapid body→outside departure | Outside click reaches underlying window | Polling/full-surface approach failed; pixel-gate approach delivered 20/20 in the exercised run | PASS for exercised path after UX-07 fix; fast-entry/driver stress still manual |
| Generated drag/up | Capture, move and release without a leaked down | Captured, finite motion/release, no stuck capture, no underlay down | PASS mechanically; subjective physical-mouse feel NOT TESTED |
| Owned native fullscreen | Enter/exit and recover overlay | Actual enter/exit; WindowServer listed overlay on screen | PASS scoped to native reference; third-party compositor fidelity NOT TESTED |
| App hide/unhide | Timers stop and restore | Actual NSApplication hide/unhide passed | PASS, `desktop-integration.json` |
| Temporary fullscreen Space | Create/remove and receive OS changes | Enter/exit and active-Space notifications observed | PASS for creation/removal only |
| Lateral Space switching | Confirm leaving/re-entering the owned Space | Control-Left did not yield a confirmed departure on this host | NOT TESTED successfully; no shortcut/preferences changed |
| Mission Control | Observe interface entry and exit | Public app launch succeeded and Escape sent; no reliable Mission-Control AX identifier observed | NOT VERIFIED; no visual PASS inferred from launch alone |
| Menu-bar auto-hide | Fullscreen presentation follows system behavior | Owned fullscreen reported auto-hide-menu-bar presentation | PASS scoped API observation; physical hover/notch usability NOT TESTED |
| Stage Manager | Confirm enabled-mode owned windows | Native switch read 1; Release gallery/Settings/overlay listed on screen and owned captures inspected; restored 0 | PASS scoped launch/appearance; switching between other app groups NOT TESTED |
| Screen lock/unlock | Recover without stale input | No disruptive lock/wake performed | NOT TESTED |
| Display/system sleep | Actual hardware recovery | Notification/lifecycle tests pass; no hardware sleep cycle performed | NOT TESTED physically |
| App restart | Restore data without duplicates | Isolated store reconstruction and window reuse pass; diagnostic processes repeatedly launch/quit | PASS automated; normal signed-user launch-at-login NOT TESTED |
| External monitors / mixed scaling | Fallback and reconnect | Only one screen available; deterministic UUID/fallback/scale policy tests pass | BLOCKED physically |

Commands were confined to owned temporary windows/Space and restored pointer/focus/fullscreen state. No login item or permission prompt was changed. After profiling and explicit approval, the four system settings described below were temporarily exercised and restored. Native transparency alone was separately probed and failed full-surface passthrough; it is not normal production configuration.

## Visual and accessibility evidence

**PASS (reviewed artifacts):** all five original characters at 44/88/160 points on light/dark backgrounds, 1×/2× rendering sheets; no observed stretching, clipping or detached rope in those poses. True composited app-owned light/dark gallery and Characters Settings images were captured using ScreenCaptureKit after an existing-access preflight succeeded. Selection, controls, readable labels and spacing were inspected. Expected scroll-viewport truncation of the second gallery row is not artwork clipping. Screenshots are in `docs/test-evidence/milestone-2.1/`; NSView-cache images are explicitly distinguished from compositor evidence.

**PASS (programmatic/native action):** Command-L menu key-equivalent opens the library, window reuse, named companion accessibility button/action, disabled-state behavior while paused, transformed accessibility bounds, explicit keyboard/menu swing alternative and injected Reduce Motion policy. Native controls retain keyboard semantics/focus indications.

**PASS, scoped actual system checks after approval:** Increase Contrast enabled the public app flag and contrast artwork sheets. Reduce Motion enabled the actual Release policy: the wind scenario settled, then added zero steps/redraws and stopped its simulation timer. With VoiceOver enabled, six Tab and three VoiceOver-next commands stayed within the owned Settings window; observed native checkbox/incrementor focus is recorded in `voiceover-keyboard-focus.json`. This does not certify spoken audio or complete VoiceOver cursor order. Stage Manager was confirmed enabled by the exact main switch, and Release-owned gallery/Settings/overlay windows were on screen; their compositor captures were inspected. Switching third-party app groups remains untested.

**PASS, restoration:** `motion-restored.json`, `contrast-restored.json`, `voiceover-restored.json` and `stage-restored.json` confirm original off states. Stage Manager's related Show Items, Recent Apps, Widgets and Separate Spaces controls retain their original values. Existing Screen Recording and Accessibility access were rechecked as true inside the final Release (`permissions-rechecked.json`), never requested automatically. Only Tether-owned windows were captured.

**NOT TESTED:** complete Tab order, every keyboard-only workflow, spoken VoiceOver announcements, prolonged physical drag feel and all appearance sections at every dynamic text size.

## Performance and release readiness

The exact final Release binary completed fourteen 60+ second process scenarios and two 60-second Time Profiler recordings. The repeated three-idle run validated zero redraws/steps at 0.446% CPU; six-wind measured 5.423%, hidden 0.295%. The initial three-idle run contained motion and is excluded from settled comparisons. Allocations failed with storage exhaustion; Power Profiler is unsupported on macOS. Nonzero NSXPCConnection leak roots were also reproduced by a minimal native control; this is not leak-free certification. Actual completed results are recorded in `MILESTONE_2_1_PERFORMANCE.md` and `PERFORMANCE_BASELINE.json`; no short-run speed or energy improvement is presumed.

**Release assessment:** functional local candidate with concrete UX defects fixed and stronger desktop evidence. Full production readiness is still gated on physical displays/older macOS/Intel, real sleep/lock, full Stage Manager group switching and Mission Control/Spaces acceptance, spoken accessibility/physical gesture checks, sustained/endurance limits identified in the performance report, Developer ID signing, notarization and clean-machine distribution. No commit, push, publication or distribution occurred.


## Final permission-grant recheck

The final Release hash remains `addb36dd74b10e765057ab6df1cfec1777ceace5db49f7ea0d52e6779442617f`; signature, plist/project lint and universal slices were rechecked. After the user's manual grant, bundled preflight reports Accessibility=true and Screen Recording=true. The actual Release repeated the input probe: 20/20 rapid outside clicks delivered; generated drag captured, moved ~81.75 points, released at ~307.89 points/s without stuck capture or an underlay down. Diagnostics report no errors. See `final-release-desktop.json`, `input-routing.json` and `stage-manager/owned-windows.json`. This is generated native-input evidence, not subjective physical-mouse acceptance.
