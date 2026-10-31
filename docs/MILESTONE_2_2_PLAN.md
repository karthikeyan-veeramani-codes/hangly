# Milestone 2.2 plan

31 October 2026. Preserve macOS 14, Swift 6 and universal slices. Preserve all 47 tests and existing physics/character architecture. Normal preferences/assets and global settings stay untouched. No publication or notarization.

## Audit and evidence

Read M1, M2 and M2.1 reports, architecture, baseline JSON and owned-window evidence. The archived M2.1 exact Release is `.build/m22-before/Tether.app`, SHA-256 `addb36dd74b10e765057ab6df1cfec1777ceace5db49f7ea0d52e6779442617f`. The 60-second six-wind trace has 518 inclusive tick samples, 427 renderer and 429 Core Animation transaction commit samples versus three RopePhysics.advance samples. Each character currently begins/commits its own outer transaction; inspect a fresh exact-binary trace before batching one frame's mutations. Do not tune wind/solver constants from short CPU samples.

Potential risks: hidden mode with pauseWhenHidden=false intentionally simulates; event monitors remain installed while hidden; separate system/display sleep notifications share one flag; inactive arrangements are retained up to 64; framework XPC leak roots reproduced by native control. Verify behavior with focused regressions.

## Execution

1. Run the 47-test baseline; fresh 60-second before process samples and Time Profiler against archived Release.
2. Fix confirmed rendering transaction/scheduling and lifecycle defects. Add meaningful tests for each. Use explicit per-frame transaction grouping and avoid static layer invalidation if the trace supports it; retain 120 Hz solver/30 or 60 Hz frame delivery.
3. Add bounded isolated endurance diagnostics with counters: 100 show/hide, pause/resume, switches, add/remove, drag/release; 50 import/delete; repeated UI reopen and deterministic display fallback. Record runtime assertions, lifecycle resource counts and memory samples.
4. Run targeted tests, then full strict Swift 6 suite and universal Debug/Release once at integration. Freeze final hash, sign locally, package/verify DMG and smoke both app/UI.
5. Repeat matched 60–180 second scenarios, six-wind Time Profiler, sustained wind and endurance; run live Leaks early/late. Check disk reserve before Allocations; avoid another full-volume recording. Record tool failures.
6. Recheck existing permission access without requesting it. Actual human physical-mouse/spoken VoiceOver acceptance remains unverified unless supplied; do not substitute generated input/API state. Preserve single-monitor BLOCKED status. Request approval only if an additional disruptive system action is necessary.
7. Deliver test/performance/stability reports, update manual matrix, baseline JSON and release gates. Explicit PASS/FAIL/BLOCKED/NOT TESTED.
