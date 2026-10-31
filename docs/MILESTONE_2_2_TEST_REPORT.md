# Milestone 2.2 verification report

31 October 2026 · Apple Silicon · macOS 27.0.1 · Xcode 27.0 / Swift 6.4 · deployment target macOS 14. Status is recorded only from completed checks.

## Implementation

The animation solver remains the same fixed-step 120 Hz model. Rendering now avoids rebuilding the static pin path unless the rope anchor changed and avoids resetting eye transforms unless the sleep state changes. A tick groups its layer mutations in one disabled-action transaction. A system-sleep flag and a display-sleep flag are tracked independently, so one wake notification cannot resume input or rendering while the other sleep condition remains active.

## Test and build status

Pending final integration. The Milestone 2.1 baseline was 47 XCTest cases with no failures or skips. Milestone 2.2 adds a combined system/display sleep ordering regression while retaining all previous cases. Fresh universal Debug/Release builds and matched performance data are recorded below when complete.

## Desktop, accessibility and display status

The M2.1 actual generated-input, owned-window fullscreen and scoped Stage Manager results remain evidence for those exact paths. They are not substituted for physical-mouse, spoken VoiceOver, Mission Control, Spaces, screen lock, real sleep/wake or monitor reconnection acceptance. No system setting, privacy prompt, normal user preferences or assets were changed for M2.2.

## Release assessment

Pending the final regression, performance, endurance and packaging gates. Developer ID signing, notarization, clean-machine installation, external-monitor hardware, Intel runtime and older macOS coverage remain separate release gates.
