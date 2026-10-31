# Milestone 2.1 UX findings

Evidence is scoped: deterministic tests, actual generated input in an owned window, native WindowServer state, and permission-guarded captures of Tether windows. These are not claims of every OS/hardware scenario or subjective physical-mouse feel.

## UX-01 — Transparent/rotated hit areas (fixed)

Before: a 0.6-size circle selected a body, ignoring transparent PNG pixels, crescent holes, path corners, rotation and reaction scale. The calculated center also ignored the current transform.

Cause: input and accessibility used an approximation unrelated to rendered model geometry.

After: invert the actual artwork layer transform, test native vector fill/stroke/mask paths, and sample a bounded 256-square alpha mask for imported aspect-fit images. Bounding-box rejection avoids traversing paths when the pointer is far away. Rope tolerance is half its visible width plus two points. Accessibility uses transformed bounds. Regression tests cover clear corners, imported alpha, overlapping z-order and transformed attachment/Retina state.

## UX-02 — Requested motion became release velocity (fixed)

Before: drag read global cursor/processing time and calculated velocity from requested displacement. A cursor moving beyond a taut constraint could imply a throw the bob never made. Single events and timing stalls could spike it.

After: use delivered event coordinates and timestamps, retain the original pointer offset, and fit actual constrained bob positions within a 100 ms/16-sample window. Duplicate/out-of-order/non-finite timestamps and stale held release return safe results; the existing 1800-point/s limit remains. No solver constants changed. Deterministic straight motion, constraint-only cursor movement, invalid times and held release pass. Actual generated mouse-down/drag/up captured, moved, released and did not leak the down to the owned underlay.

## UX-03 — Gesture lifecycle and unnecessary frame callbacks (fixed)

Before: pause/focus/Space/app-hide boundaries could retain capture. The animation scheduler could remain alive with its only character being manually dragged. App hide did not suspend the complete scene.

After: cancel capture on pause/disable, application activation changes, Space changes, app hide, removal and sleep; reschedule immediately on begin/end/cancel. Handle actual NSApplication hide/unhide independently from the user's global visibility preference. Main-thread accessibility actions use an isolated action object and a safe handoff if called off-main. Native hide/unhide and deterministic cancellation checks pass.

## UX-04 — Rope pivot and scale propagation (fixed)

Before: regular body transforms compensated for attachment, but an additive idle rotation still pivoted about the body center. Nested mask scale was not recursively updated.

After: the layer anchorPoint is the artwork attachment itself and body.position is the bob. Rotation, reaction and additive idle transforms all use that pivot. Contents scale propagates through every descendant and mask. The existing original vector artwork remains. Shadows provide restrained separation from light/dark backgrounds, and Increase Contrast can add a fine outline. Artwork sheets at 44/88/160 points, 1×/2× on light/dark backgrounds were generated and inspected without screen capture. Full compositor UI captures use ScreenCaptureKit only after an existing-permission preflight succeeds.

## UX-05 — Library/settings/menu flow (fixed)

Before: no selected-chip checkmark, mixed unlabelled collection, immediate deletion of an imported template plus its active duplicates, blocking import decode with no progress, and selected-character menu routing to General. Settings lacked reset and keyboard swing actions.

After: selected chip feedback/accessible labels, distinct collection headings, clear bulk removal names, confirmation when deleting artwork with active instances, background validated decode with progress/disabled Add while busy, inline dismissible notices instead of competing modal notices, selected-instance Settings navigation, reset appearance/physics and animation controls, and an enabled-state-aware native menu/Settings action to wake/swing. Existing reusable windows and native theme are preserved. Keyboard Command-L menu dispatch and named accessibility press actions are tested; full spoken VoiceOver acceptance is still a manual gate.

## UX-06 — Existing display panel retained an old frame (fixed)

Before: a display-parameter reconciliation updated renderer/session geometry but not an already-created panel's frame when the same display identifier changed dimensions.

After: refresh the existing render panel frame and backing scale in place. A forced-wrong-frame regression confirms restoration without replacing unrelated windows. This is a policy/implementation check, not physical monitor reconnection verification.

## UX-07 — Rapid departure could swallow an unrelated click (fixed for the exercised path; boundary limits remain)

Actual reproduction: ordinary outside/corner clicks reached the temporary owned underlay, but an immediate body→outside click was swallowed. Repeating the case with movement notifications alone still delivered 0/20 outside clicks in one run. A diagnostic with the whole render panel enabled and polling disabled captured outside/corner clicks too; native transparency alone did not provide a usable layer-backed per-pixel input mask on this host. This experiment remains recorded in `native-transparency.json` and is not a production mode.

Root cause: stale `ignoresMouseEvents = false` made a full-screen input surface eligible until the next pointer update. Shape testing after mouse-down cannot retroactively deliver that down to another process.

Fix: render panels permanently ignore mouse input. Each display has one separate nonactivating, accessibility-hidden input gate, requested at one physical pixel, placed at the current body/rope hit point. Global/local movement observations update it promptly; the sampler remains as a fallback. Once a down starts, AppKit's normal window gesture capture carries drag/up outside that tiny frame. Stale input can no longer cover the entire screen. Input gates are hidden on suspension and closed on teardown; rendering remains one shared panel per display. No clicks are intercepted/replayed globally and normal operation requests no Accessibility permission.

Actual post-fix check: ordinary outside/corner clicks reached the underlay, body clicks stayed with the companion, 20/20 immediate exit clicks reached the underlay, and generated dragging captured/released with finite motion and no underlying down. This is evidence for those paths, not proof of every timing/driver case. A very fast entry can still outrun gate placement and pass through to the underlying app. Further physical-mouse/driver and multiple-display boundary acceptance remains required.

## Desktop/access limitations

The actual bundled process reports existing Screen Recording and Accessibility access. No permission request was made. Captures filter to windows owned by Tether. Pointer/focus and temporary fullscreen state are restored after probes. The earlier restricted/unbundled preflight results do not describe the final bundled process.

Actual owned fullscreen enter/exit and WindowServer overlay presence passed. Controlled Space/Mission Control commands were attempted and their observed notifications/identifiers retained; only confirmed observations are marked PASS in the test report. After explicit approval and profiling, native VoiceOver, Reduce Motion and Increase Contrast were temporarily enabled, checked and restored off. Actual Reduce Motion stopped steady wind simulation after settling; native Tab/VoiceOver-next focus stayed within the owned Settings window, without spoken-audio certification. Increase Contrast enabled the public app policy and extra artwork sheets. Stage Manager observations and final restoration are recorded in the test report. Real sleep/lock recovery remains manual. One display was available, so physical monitor reconnection is BLOCKED.
