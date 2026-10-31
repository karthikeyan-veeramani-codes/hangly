# Tether architecture — Milestone 2.1

Swift 6, macOS 14+, AppKit desktop integration, SwiftUI library/settings and Core Animation rendering. Local-only; no dependencies, analytics, accounts or background helpers.

## Models, migration and business rules

TetherCore owns deterministic `RopePhysics`, `Vector`, geometric display/hit-test policies, `Preferences`, `Charm`, RGBA/quality types and `CharacterAnimation`. Existing fixed-step physics remains unchanged: semi-implicit integration, exponential damping, taut constraint, velocity projection, 120 Hz timestep and maximum eight catch-up steps.

`Preferences.library` stores artwork templates (five originals plus custom imports). `Preferences.charms` stores independently configurable instances, including retained off-desktop arrangements. `activeIDs` determines desktop membership and stacking order. `selectedID` determines the Settings edit target; changing it has no effect on other instances. Instances reference artwork through `templateID/sourceID`. Duplication creates a new ID, not a shared physics/animation state. Persisted independent settings include size, opacity, visibility, rope/attachment/anchor, physics and display assignment. Transient velocities, interaction capture and animation progress are not persisted.

Codable decoding supplies defaults for additive fields and explicitly migrates schema 1 to schema 2. Version-1 custom artwork becomes library templates; saved choices survive. `PreferencesStore` sanitizes before one published assignment and encodes after mutation; its original persistence key remains available, with one version-1 migration backup. Unsupported/corrupt data produces a visible recovery notice rather than crashing. Library operations enforce six default active instances, configurable up to twelve, 64 retained instances and 100 templates. Lowering the active limit preserves excess instances off-desktop. Default restoration does not discard imports.

## Ownership and panels

AppDelegate owns PreferencesStore, DisplayManager, OverlayManager, MenuBarController and SettingsController. SettingsController shares one CharacterLibraryController with menu/library actions. Both UI controllers retain one reusable NSWindow with `isReleasedWhenClosed = false`; repeated actions order the existing window forward. Menu teardown cancels its observation and removes its NSStatusItem. App termination invalidates overlay timers, closes panels, stops display observation, clears asset caches and flushes preferences.

OverlayManager owns independent CharmSessions keyed by instance ID, plus one DisplayOverlay per assigned display, owning a click-through render panel and one pixel-sized input panel. Each session owns its configuration snapshot, rope engine, animation machine, gesture state and optional renderer. Off-desktop sessions retain only bounded lightweight state; their renderers/layers are released. Removed instances release their session entirely. A display panel hosts the sessions' renderer roots in `activeIDs` order, so hit routing and visual stacking agree. Deleting one character does not recreate unrelated panels.

Each panel is borderless, transparent, nonactivating and floating, with `canJoinAllSpaces`, `fullScreenAuxiliary` and `stationary`. It does not become key/main or create a Dock icon. Floating is useful above application content but below menus/system UI; normal-level windows would be occluded more often. Fullscreen, Stage Manager, Mission Control and system surfaces remain OS-controlled. No private APIs or screen-saver-level windows are used.

## Interaction and accessibility

InteractionController forwards mouse actions to OverlayManager. The manager captures one target ID until release, retaining the pointer-to-attachment offset so grabbing the body does not teleport it. Release velocity is bounded and stale held-release samples are discarded. Capture is cleared on hiding, removal and sleep. Point/rope tests route to the frontmost visible session. Each companion exposes a named accessibility button with a press-to-wake/swing action; SwiftUI controls retain native keyboard/accessibility behavior. Full VoiceOver navigation remains a manual verification item.

Actual owned-window probes confirmed a stale full-screen input region could swallow immediate departure clicks. Enabling native transparency with polling disabled also failed usable passthrough for the layer-backed surface on this host. Render panels now **always ignore mouse events**. A separate clear, nonactivating input gate is requested at one physical pixel at the current precise body/rope hit, with one allocated gate per display. AppKit's normal window capture carries mouseDragged/mouseUp after a down. A stale gate no longer spans the screen. Global/local mouse-movement monitors update promptly; one shared 30 Hz sampler remains as a fallback and release watchdog. No global mouse-down interception/replay or event tap is used. Gates are accessibility-hidden and cannot become key/main; hide/sleep/teardown clears them.

Bodies use inverse rendered transforms, vector fill/stroke/mask tests or a bounded imported-image alpha map. Grab offsets and delivered event timestamps feed a pure bounded actual-position DragTracker; constraint-forbidden cursor displacement cannot create artificial release velocity. Rope tolerance is visible half-width plus two points. The real probe delivered 20/20 rapid exits and captured/released generated dragging without leaking its down. Fast entry may still outrun gate placement, so physical mouse/driver and multi-monitor edge acceptance remains open.

## Rendering and animation

CharmRenderer extends the original CALayer/CAShapeLayer system with Luna and Nori, rope color/thickness, opacity and normalized artwork attachment. Body transforms rotate/scale about that attachment so the rope remains connected during a reaction or swing. Imported PNGs use whole-image transforms, never assumed facial layers. Scale changes propagate to layers for Retina rendering. The gallery uses fitted previews, with an optional decoded-image override for staged imports.

CharacterAnimation is a deterministic per-instance state machine with idle, swinging, dragging, reacting, sleeping, waking and paused phases. Interaction resets inactivity; sleep occurs only when motion has settled. Reaction/wake deadlines and sine-shaped reaction scaling avoid conflicting whole-image effects. Pause freezes reaction time. Reduce Motion disables wind and ambient transforms and reduces click impulses; respecting the system preference is user-configurable. Idle blinks/nods are occasional finite Core Animation effects, stopped on interaction/pause/suspension. Static idle/sleep poses do not continuously redraw.

Configuration changes update engines/renderers in place. Appearance edits preserve velocity. Anchor changes shift the existing coordinate frame; requested rope length eases toward its target without a position reset. Bounded fixed-step physics is preserved. Conservative bounds keep the artwork reachable even with extreme attachment choices.

## Shared scheduling and power

One main-runloop simulation timer serves all active moving/reacting sessions at 30/60 Hz. Each engine receives bounded elapsed time and the original fixed-step solver. Resting sessions are skipped and do not render; when no session needs frames, that timer is invalidated. A single 30 Hz pointer sampler remains while any companion is visible. A one-second ambient timer handles inactivity/deadlines, occasional idle events and power-source changes; it does not redraw unless state changes. Pause stops simulation/ambient scheduling. Hidden rendering always stops; with the default pause-when-hidden policy all three timers stop. Display/system sleep stops everything.

Battery status is read through public IOKit power-source APIs. Opt-in battery reduction lowers frame scheduling to 30 Hz and spaces out ambient events. Simulation still uses the same fixed timestep. Subscriptions coalesce preference/display changes on the next main-loop turn so sliders do not create duplicate reconciliation work. Weak timer/observer closures prevent manager retention.

## Displays

DisplayManager observes NSScreen parameter changes, maps live CGDirectDisplayIDs to UUID strings and exposes screen name/frame/scale. Every instance keeps its saved UUID and normalized x anchor. Missing displays temporarily resolve to the primary or first available display without rewriting the saved choice. A recognized returning UUID restores it. Reconciliation adapts frames, root layers, scale factors and containment without rebuilding every character. Notched screens honor the reported top safe-area inset. UUIDs may change with hardware/configuration; no stronger permanence guarantee is made.

Full system sleep and display-only sleep are both observed. Wake refreshes NSScreen data and rebuilds panels from current configurations, preserving session state. Hardware reconfiguration, actual sleep, mixed-DPI monitors and older OS behavior still need physical testing.

## Import and storage

CharacterLibrary presents a staged import editor: choose → validate → checkerboard preview → name/scale/attachment → save/add. Validation checks ImageIO-decoded type, complete single frame, file bytes, dimensions and conservative decoded memory including high-bit-depth sources. PNG and runtime-supported native WebP are accepted; WebP is normalized to PNG. Unique app-managed names prevent overwrite; duplicate imports are separate entries. No external file URLs are retained.

AssetCache uses NSCache with a 16-item / 64 MiB advisory bound and downsampled 640-pixel images. Validation occurs before caching; invalid assets are remembered to avoid repeated decode attempts, and a placeholder/notice handles missing files. Active layers may retain their own bounded image contents independently of cache eviction. Deletion removes all referencing instances and only unreferenced managed files; failed deletion preserves the library entry. The native WebP test fixture is an original one-pixel image; no codec dependency ships with the app.

## Verification and release

The 21 original XCTest cases remain. Added tests cover migration, library operations and limits, independent sessions, caching and malformed assets, WebP normalization, in-place rope updates, display fallback, shared scheduling, cleanup and reused menu/UI windows. Tests run through SPM; Xcode owns universal app builds. Short Release measurements at 1/3/6 instances, binary hash and remaining manual gates are recorded in `docs/MILESTONE_2_TEST_REPORT.md` and `docs/PERFORMANCE_BASELINE.json`.

Builds and DMG packaging are local and ad-hoc signed by default. Developer ID signing, notarization and clean-machine distribution require credentials and explicit authorization. Automatic updates are deferred. App Store sandbox distribution is not configured.

## Public API references

[NSPanel](https://developer.apple.com/documentation/appkit/nspanel), [ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents), [window collection behavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct), [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) and [registration](https://developer.apple.com/documentation/servicemanagement/smappservice/register()) describe the platform boundaries. API availability was checked by compiling against the installed SDK; platform behavior is not inferred to be verified on untested systems.

Milestone 2.1 adds safe accessibility action dispatch, staged off-main import validation, reset/notice/selection UI, native keyboard alternatives, actual owned fullscreen/hide checks, permission-guarded ScreenCaptureKit evidence and isolated sustained diagnostics. Public API references and defect evidence are linked in the 2.1 UX/performance/test reports.
