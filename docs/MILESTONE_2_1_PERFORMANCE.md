# Milestone 2.1 sustained performance verification

## Method and reproducibility

Run `python3 scripts/profile-milestone21.py` against the packaged universal Release app, native arm64 on the current macOS 27.0.1 host. The harness freezes/checks executable SHA-256 and uses isolated UserDefaults plus automatic quit. No normal arrangement, imported assets, login item, system setting or permission prompt is changed. No builds/tests run in parallel. The host remains interactive; user activity and OS caching/compression are ambient noise.

Process scenarios: 1/3/6 idle, 1/3/6 swinging, six with wind, paused, hidden, Settings open, library open, followed by repeated one-idle/one-paused. Each warms up for ten seconds, then collects 61 CPU-time/RSS samples spanning more than 60 seconds. CPU is cumulative process user+system CPU time divided by measured elapsed time, expressed as one-core percent. At 0.01-second CPU-time resolution, the aggregate percentage is finer than the old six-second samples. Per-second values remain quantized and are not used to claim sub-percent instantaneous precision.

Swing scenarios inject the same bounded click impulse every five seconds to sustain motion; this is a repeatable synthetic workload, not a physical mouse session. Idle/paused comparison disables optional ambient variation and inactivity sleep. Settings/library cases use their actual native windows. Diagnostic counters record warm/final app redraws, fixed steps, frame callbacks/max gap, asset decodes, render panels/input gates and timer states. These counters do not count WindowServer/Core Animation compositor work. Average callback frequency is a scheduling observation, not a verified display-presented frame rate. Maximum gap includes early process lifetime unless otherwise noted.

Separate instrumented PIDs (not mixed into CPU comparison samples) record 60-second Time Profiler sessions for pause and six-wind, a 60-second Allocations capture within a 150+ second import/duplicate/render/delete workload with early/late `leaks --noContent` scans, and an attempted 60-second Power Profiler recording. Tool failures/unsupported energy sources are recorded rather than counted as PASS. Stack logging/instrument overhead is not compared with uninstrumented RSS.

Raw evidence: `.build/m21-performance/`, including checkpoints, progress, per-process diagnostic JSON, samples, trace logs/exports and leak summaries. Portable numbers and exact binary hash are retained in `PERFORMANCE_BASELINE.json`; the previous M1/M2 baselines remain intact.

## Interpretation constraints

The M2 reference used roughly six-second samples: 6-wind 3.444% CPU and ~55 MiB RSS, with noisy settled/paused order. Comparing those directly with 60-second observations cannot establish a causal optimization win or regression. The pixel-input-gate change was justified by actual lost clicks, not arbitrary physics tuning. The body/rope solver constants are unchanged. Memory compression and lazy framework initialization can lower/raise RSS independently of leaks. A stable short trend and successful scan do not prove leak-free behavior over days or across every asset/device.

Completed results below retain failed recordings and invalid observations. No improvement or energy guarantee is claimed.

## Sustained process results

Final Release SHA-256: `addb36dd74b10e765057ab6df1cfec1777ceace5db49f7ea0d52e6779442617f`. Each row spans at least 60 measured seconds. RSS figures below are uninstrumented process RSS.

| Run | Companions | Workload | CPU / one core | RSS min–max MiB | Settled-state validation |
|---|---:|---|---:|---:|---|
| 01-1-idle | 1 | idle | 0.675% | 40.94–51.69 | zero overlay redraws/steps |
| 02-1-swing | 1 | swing | 1.649% | 44.08–44.81 | active workload |
| 03-3-idle | 3 | idle | 2.234% | 42.36–51.81 | INVALID settled sample: motion observed |
| 04-3-swing | 3 | swing | 3.631% | 43.97–51.89 | active workload |
| 05-6-idle | 6 | idle | 0.787% | 45.38–51.84 | zero overlay redraws/steps |
| 06-6-swing | 6 | swing | 4.780% | 46.39–46.64 | active workload |
| 07-6-wind | 6 | wind | 5.423% | 49.27–51.56 | active workload |
| 08-1-paused | 1 | paused | 0.837% | 51.50–51.55 | zero overlay redraws/steps |
| 09-1-hidden | 1 | hidden | 0.295% | 40.52–51.02 | zero overlay redraws/steps |
| 10-1-settings | 1 | settings | 3.410% | 54.95–89.27 | active workload |
| 11-1-library | 1 | library | 2.853% | 59.77–72.05 | active workload |
| 12-1-idle | 1 | idle | 0.672% | 44.08–51.64 | zero overlay redraws/steps |
| 13-1-paused | 1 | paused | 0.558% | 51.53–51.75 | zero overlay redraws/steps |
| 14-3-idle | 3 | idle repeat | 0.446% | 51.58–51.80 | zero overlay redraws/steps |

The original three-idle row contains post-warm-up motion and is excluded as a settled baseline. Its cause was not established from endpoint counters, so it is not labelled a physics cost or blamed on a particular interaction; run 14 repeats the case with zero post-warm-up redraws/steps and 0.446% CPU over 60.50 seconds. Both observations are retained.

The paired one-idle values were about 0.675% and 0.672%; pause about 0.837% and 0.558%. The original paused > settled ordering reverses in the matched repeats. Hidden was 0.295%, despite no simulation/redraws after warm-up; an NSApplication, status item and passive event handling can still incur process activity on an interactive host. Thus zero timer/render work is verified structurally, while a sustained zero-CPU claim is not made. Settings/library costs include real SwiftUI/native UI and are reported separately.

## Instrument/tool findings

Both 60-second Time Profiler recordings completed and exported. Paused: 576 samples, 56 containing the pointer path, 13 precise-hit tests, and none containing physics/rendering. Six-wind: 1,189 samples, 518 containing shared simulation, 427 renderer, 41 pointer and 10 hit testing (inclusive counts overlap). These are sample counts, not exclusive percentages or frame-time guarantees.

**BLOCKED / failed recording:** the requested 60-second Allocations run returned 17; export returned 40. The log reports a malformed transferred trace, failure to attach and CoreData SQLite errors (`unable to open database file`). The import workload also recorded two out-of-space file-write errors. The host volume temporarily exhausted writable space during this run; after the instrumented process exited, about 3.1 GiB was available. No large failed trace remains in the project's measurement directory (~47 MiB), and no unrelated user files were removed. Do not mark this as a successful Allocations audit or retry a large capture without adequate free space.

**BLOCKED:** Power Profiler returned 2 and export 10, explicitly reporting: “The Power Profiler instrument is not supported on macOS. Record on iOS or iPadOS instead.” No power/energy budget is claimed.

**FAIL / nonzero findings requiring attribution:** live `leaks` scans returned 1. Early: 278 blocks / 17,664 bytes, two root NSXPCConnection cycles. Late: 417 blocks / 26,496 bytes, three root cycles. Allocation stacks are in AppIntents/LinkServices application-registry XPC setup and related system libraries; no Tether class is identified in those printed root stacks. This is evidence for the allocation origin, not proof the finding is harmless or an app-independent false positive. A matched minimal native control was subsequently tested, as described below. The actual workload completed 156 import/duplicate/render/delete cycles; two final input-file writes failed visibly in the diagnostic error ledger due to storage exhaustion.


## Matched native control and limits

The minimal AppKit/status-item/two-SwiftUI-window control in `scripts/native-leak-control.swift` contains no Tether classes. Its early scan found 417 blocks / 26,496 bytes with three root cycles; late found 412 / 26,240 with three roots, with matching AppIntents/LinkServices NSXPCConnection stacks. Logs are in `test-evidence/milestone-2.1/native-control-leaks-{early,late}.log`. This reproduces the particular framework roots independently of Tether. The scans still have nonzero findings; they are not a leak-free PASS or a replacement for the failed Allocations recording.

Uninstrumented steady-state RSS remained below 90 MiB for these built-in-character scenarios. The instrumented churn run ranged roughly 66–150 MiB and was affected by trace/stack-logging overhead and storage exhaustion; its endpoint trend cannot establish allocation stability. Large-image import peaks, ten-minute Allocations/endurance, actual battery energy and WindowServer attribution remain open. The six-swing uninstrumented callback gap reached about 68 ms; averages near 60 callbacks/s do not establish uniformly smooth presented frames.

**Assessment:** sustained process sampling and two Time Profiler recordings PASS. The invalid initial three-idle sample is excluded from settled comparisons. Allocations and energy are BLOCKED; leak scans have nonzero framework-root findings reproduced by a native control. No sustained energy target, leak-free certification or performance improvement over M2 is claimed.
