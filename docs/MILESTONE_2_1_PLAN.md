# Milestone 2.1 — implementation and verification plan

## Baseline audit

Read the M2 architecture, README, release/manual reports and both baseline generations. All 37 baseline tests passed before edits (`.build/m21-baseline-tests.log`). Reuse the fixed 120 Hz/eight-step rope solver, independent sessions, one panel per display and existing library/preferences.

Confirmed code-level defects to reproduce and fix:

- UX-01: broad circular body hit regions intercept transparent corners/holes and do not follow actual rotation/reaction transforms. Imported alpha is ignored. Match model-layer geometry and image alpha, keeping only a small explicit rope tolerance.
- UX-02: drag samples use current global cursor and processing time instead of event coordinates/timestamps; velocity uses requested rather than constrained displacement. Extract a bounded timestamped actual-position estimator, retain grab offset and test held/stale/rapid samples.
- UX-03: paused/focus/Space changes can retain capture; an all-dragged scene can keep a useless frame timer. Clear gestures at lifecycle boundaries and suspend scheduling immediately.
- UX-04: idle rotation pivots around the body center, breaking attachment alignment; nested mask/layer Retina scale propagation is incomplete. Pivot all body transforms at the attachment and test layer geometry recursively.
- UX-05: selected gallery chips have no selected feedback, custom deletion is immediate even with active duplicates, imports decode on main and offer no progress, selected-character menu opens General, Settings has no reset. Improve those existing flows without a new theme.
- UX-06: menu/settings lack an explicit keyboard alternative to swing a selected companion; accessibility bounds use an unrotated approximation and hide/show does not cover app hide notifications. Add accessible actions and actual transformed bounds.

Risks: pointer-gated full-screen panels still have sampling transition latency, so full input passthrough cannot be certified from hit tests alone. Native view-cache captures omit compositor materials. Physical displays/VoiceOver/system workflows need actual access; do not toggle system settings or request capture permission automatically.

## Execution order

1. Baseline tests and audit (complete).
2. Timestamped drag/precise geometry/renderer/lifecycle fixes with focused regressions. Preserve solver constants and all old tests.
3. Gallery/settings/menu/accessibility polish, import responsiveness and validation, reset flows. Test actual owned windows and native actions.
4. Generate app-owned layer and UI evidence in `docs/test-evidence/milestone-2.1`, sizes 44/88/160 at 1×/2×, light/dark backgrounds. Distinguish deterministic rendering sheets from desktop screenshots. Record privacy preflight, displays and available desktop capabilities without requesting permissions.
5. Final integration: strict Swift 6 tests, universal Debug/Release, actual Release/GUI smoke, signature and local DMG checks. No publication/distribution.
6. Freeze the exact Release binary. Sample CPU/RSS after warm-up for at least 60 seconds across 1/3/6 idle/swing, 6 wind, pause, hide, Settings and library; repeat settled/paused. Instrument actual PIDs with Time Profiler, Allocations and Leaks; attempt energy tooling where available. Record counter/frame/decode evidence and sustained import/teardown checks. No builds/tests during measurements.
7. Record all results/defect causes/limitations in UX findings, performance report, test report, baseline JSON and manual matrix. No invented manual PASS. Physical monitor absence is BLOCKED; unperformed OS workflows remain NOT TESTED.

## Acceptance interpretation

Pass deterministic geometry and event-pipeline checks, native menu/UI lifecycle/accessibility properties, all existing/new tests and universal builds. Manual subjective feel, system compositor appearance, third-party fullscreen, Mission Control/Spaces/Stage Manager, actual sleep/lock and hardware reconnection require actual observation. Record what was observed, evidence, status and defect IDs separately; leave these gates open where unavailable. Do not claim complete production readiness.


## Completion record

Seven confirmed defects are documented in UX findings. The rapid-departure reproduction required permanently click-through render panels plus a separate one-pixel input gate per display; full-screen polling alone failed the real input test. All 37 originals plus ten regressions pass, universal app/DMG gates pass, and the exact Release binary remained frozen through fourteen sustained scenarios and instrument runs. Approved accessibility toggles were exercised after profiling and restored. Remaining actual desktop, hardware, allocation/energy and distribution limits are explicit in the final reports. No commit or push was performed.
