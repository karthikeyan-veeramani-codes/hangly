# Evidence scope

- `artwork-{light,dark}-{1,2}x.png`: deterministic app-owned CALayer render sheets, all five original characters at 44/88/160 points. These are rendering/layout evidence, not desktop screenshots.
- `*-{light,dark}-composited.png`: ScreenCaptureKit images filtered to Tether-owned windows only, after `CGPreflightScreenCaptureAccess` confirmed existing access. No other application content is captured.
- `gallery.png`, `settings.png`, `desktop.png` (if present): older NSView-cache diagnostic images. Native compositor controls/materials may be omitted; these do not establish appearance correctness.
- `desktop-integration.json`: actual native owned-window fullscreen and app hide/unhide integration test. WindowServer presence is not a guarantee of visibility over every third-party fullscreen app.
- `input-routing.json`: actual generated clicks/drag inside a temporary owned underlay, counts and outcomes. The normal production renderer is click-through; pixel input gates route intended input. Probe restores pointer/focus.
- `native-transparency.json`: diagnostic experiment deliberately enabling the full-screen render surface and disabling pointer gating. It failed passthrough and is not normal application configuration.
- `workspace-integration.json`: attempted controlled keyboard/public Mission Control launch and observed OS state, not inferred visual acceptance.
- capability JSON: read-only privacy/accessibility/display policy observations. No permission prompt is issued by capability reads. After explicit approval, separate native helpers temporarily exercised four global settings after profiling; restoration evidence is listed below.

Full sustained raw measurements and Instruments traces are in `.build/m21-performance/`; their portable summary and exact binary hash are recorded in the performance report and baseline JSON. No notarization or trusted-distribution acceptance is implied.


- `permissions-rechecked.json`, `final-release-desktop.json`, current `input-routing.json`: final frozen Release after manual permission grant; Accessibility/Screen Recording true, 20/20 rapid exits, clean generated drag/release.
- `*-enabled.json`, `*-app-state.json`, `*-restored.json`: approved native VoiceOver/Reduce Motion/Increase Contrast checks and restoration off. `voiceover-keyboard-focus.json` records only owned focus, not audio. `increase-contrast/` contains additional artwork sheets.
- `stage-final-state.json`: exact main Stage Manager switch observed enabled; `stage-manager/` captures only Release-owned windows in that session. `stage-restored.json` confirms main switch off and related options unchanged. These images cannot prove app-group transition behavior or other applications' presentation.
- `native-control-leaks-{early,late}.log`: matched minimal native control reproduces the specific NSXPCConnection roots found by live scans; no leak-free certification.
