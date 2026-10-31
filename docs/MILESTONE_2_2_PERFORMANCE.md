# Milestone 2.2 performance verification

## Method

The archived M2.1 Release app is copied to `.build/m22-before/Tether.app`. The changed universal Release app is measured with the same isolated diagnostic preferences. Each process scenario warms for ten seconds then records 61 CPU-time/RSS samples spanning about 60 seconds. CPU is process cumulative time divided by elapsed time, expressed as one-core percent. Runs are interactive-host observations, so repeated wind cases are retained instead of collapsed into a claim from one sample.

The prior 60-second six-wind Time Profiler trace attributed many samples to `OverlayManager.tick`, `CharmRenderer.render`, and Core Animation transaction commit, while the fixed-step solver appeared rarely. M2.2 therefore removes confirmed static layer mutations and batches the frame's layer changes without changing physics constants. A fresh Time Profiler and a disk-reserve-guarded allocation attempt remain pending final measurements.

## Results

Pending exact before/after harness completion. Raw samples, diagnostics, profile traces and leak scans are kept in `.build/m22-performance/`; portable summaries are added to `PERFORMANCE_BASELINE.json` after completion.

## Limits

The M2.1 Allocations trace failed after the volume ran out of space. M2.2 requires an 8 GiB reserve before recording and stops an instrumented run if remaining free space falls below 3 GiB. The earlier nonzero framework XPC roots were reproduced by a native control, which is evidence about attribution rather than leak-free certification.
