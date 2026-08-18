# Work Island — Critical Lessons and Prevention Rules

Last consolidated: 2026-08-16

This is not a chronological diary. It is ranked by potential damage and recurrence. Rules marked **STOP** must be resolved before proceeding. Repeated failure families are intentionally emphasized because they caused several regressions during this project.

## P0 — User data and preferences

### **STOP: Never use the user's live data for UI QA**

This failed more than once. Timer, Manual, History, and preference checks can create records or change settings even when the intended fixture appears isolated.

Why it happened:

- UI automation targeted a bundle path and relaunched it without the original environment.
- `CFFIXED_USER_HOME` isolated Application Support files but did not reliably isolate `UserDefaults`/`cfprefsd`.
- A seemingly harmless Dashboard check changed the production `hiddenDashboardCards` preference.
- A timer check can persist ActiveWork or a completed record before cleanup.
- A cold launch on a different active display rewrote `NSWindow Frame main` even though the main Window was not used during QA.

Prevention:

1. Prefer automated tests and let the user perform visual/functional acceptance.
2. If UI automation is explicitly required, use all three: unique bundle identifier, explicit app-owned storage override, and an isolated preferences suite/domain. Embed these as app-owned QA metadata, make `.qa.` bundles fail closed when any isolation value is missing or unsafe, and make production bundle identifiers ignore QA metadata.
3. Before the first state-changing UI action, fully stop every Work Island process and snapshot both the exact JSON and the complete production defaults domain.
4. Before each UI action, re-read the focused bundle and exact control target.
5. Afterward, compare JSON semantically and byte-wise where appropriate, and compare the entire preferences domain—not just intended keys.
6. Cold-launch once more after restoration and compare again.
7. Treat system-normalized window frames as preference drift too. If a post-restore cold launch deterministically normalizes an old-display frame, record the cause and restore the exact pre-QA value after the final launch.

### **STOP: A backup is evidence, not automatically the restore target**

The user legitimately created records during earlier verification windows. Restoring the older safety copy would have deleted real work.

Prevention:

- Re-read the live file's modification time, SHA-256, schema, Activity/Item/record counts, ActiveWork, and latest record before restoration.
- Derive those counts from the actual persisted schema or the app decoder. The UI says Records, but the compatibility JSON key is `sessions`; querying an assumed `records` key can misleadingly report zero.
- If live state is newer or semantically plausible, treat it as user-owned until proven otherwise.
- Restore only data known to be test contamination; preserve every legitimate newer change.
- Last-known hashes in Progress Report are never authoritative restore targets.

### Migrations must use schema version, never collection emptiness

An empty current-schema Activity or Item collection is valid. A prior migration treated emptiness as legacy state and recreated deleted defaults.

Prevention:

- Gate every migration by stored `schemaVersion`.
- Add cold-launch regression coverage for an empty current-schema file.
- Stable IDs remain authoritative; display names are editable labels.
- Preference migrations also need explicit version/key handling; JSON migration alone does not cover removed or reinterpreted preference keys.

## P0 — Build, process, and installation identity

### **STOP: A rebuilt bundle is not the installed or running app**

This caused repeated reports that changes were not reflected. `dist.noindex` was rebuilt while `/Applications/Work Island.app` or an older resident process was still being observed.

Required verification sequence:

1. Resolve every relevant PID and executable path.
2. Fully quit stale processes.
3. Build the intended channel.
4. Compare source, staging, and installed version/build metadata.
5. Copy the exact staging bundle to `/Applications` when installation is intended.
6. Launch that exact path and verify the new PID's executable path.
7. Compare staging and installed executable/resource hashes.
8. Use full Quit → cold launch cycles; reopening a resident process is not equivalent.

### Optical control ranges need rendered endpoint checks

The first Notch Glass mapping passed numeric unit tests, but its maximum
Refraction used only a thin 0.16-opacity edge and could become even less visible
when Bezel Depth was low. The user correctly perceived almost no useful change.
Increasing only that edge then made the perimeter look neon while the glass face
stayed comparatively unchanged.

The Blur label was also mapped from an assumption instead of the rendered
reference. The generator's Chromium path applies `blur(value / 2)`, then its SVG
lens, then `blur(value)`; at Blur `0`, both blur stages are literally `0px` while
the translucent fill and refraction remain. Mapping that endpoint to SwiftUI
`Glass.clear` still retained native backdrop processing and therefore did not
look remotely close to the reference's deliberately transparent zero endpoint.

A later Refraction approximation coupled the slider to directional tint,
reflection, and an angular chromatic gradient. With Frost and Blur at zero this
looked like a diagonal color wash rather than refraction. The reference instead
changes the scale of a centered SVG displacement lens, so the visible change is
substantially symmetric around the perimeter. Replacing that wash with a
uniform face tint and identical full-perimeter strokes fixed the asymmetry but
still did not refract the backdrop: the control continued to change only color
and edge decoration. Calling the old `0–250` cosmetic intensity “Refraction”
also obscured the fact that the reference varies a physical refractive index.

A subsequent correction generated a valid symmetric Convex Squircle RG map and
attached `CIDisplacementDistortion` through `CALayer.backgroundFilters`. Unit
tests proved the geometry and filter state, but the user again saw no change.
That result was correct: `backgroundFilters` filter content immediately behind a
layer in its own compositing hierarchy; the layer nested in the transparent
SwiftUI notch window did not gain access to another window's desktop backdrop.
Putting filters on `NSGlassEffectView`, the root window layer, or a SwiftUI
shader around native AppKit glass did not cross that compositor boundary either;
the shader/glass combination could also render an unsupported-effect warning.
Thus a generated map and a non-empty filter array were not visual evidence.

Public native glass can sample the cross-window backdrop, but it does not expose
the sampled texture to an arbitrary Convex Squircle displacement shader. Exact
CSS/SVG-style custom displacement of the raw desktop would require screen
capture or private compositor APIs, neither of which is appropriate here. An
interim public-API correction therefore kept index `1.00` neutral and mapped the
normalized Fresnel reflectance `((n − 1) / (n + 1))²` to the opacity of a
separate untinted native Clear Glass optical surface. This visibly changes
Apple-owned lensing/scattering while Blur remains independent; it is a native
approximation, not a claim of exact physical Convex Squircle displacement.
Frost and Bezel Depth remain fixed at `6` and `0`, and the incompatible old
cosmetic Refraction value is not silently reinterpreted.

On 2026-08-15 the user retired Refraction as an adjustable product feature.
The preference model still fixes it at the neutral compatibility index `1.00`,
removes the Settings row and dedicated rendered-QA fixture, and leaves every
old Refraction key untouched but ignored. This decision superseded the earlier
native-optical approximation; do not reintroduce a Refraction control without a
new explicit product decision.

Later that day the user explicitly authorized one narrower experiment: place an
`NSVisualEffectView` with `.behindWindow` blending under a separate non-root
child layer whose `backgroundFilters` contains the symmetric displacement map.
Version 0.11.30 implemented the fixed, non-persisted lens and automated tests
proved its hierarchy, filter input, symmetry, and crop geometry. The user's
physical check still showed no visible change. Version 0.11.31 removed the
render layer and its preview machinery instead of retaining ineffective
compositor work. This is now a confirmed dead end for this app architecture;
do not retry it without a materially different source of backdrop pixels.

The first Blur correction still switched between identity, clear, regular, and
several Material types at integer boundaries. Even when each mapping was
reasonable in isolation, `0` to `1` visibly jumped because the compositor path
changed. The final mapping keeps one native glass type and one Material type,
then fades both continuously with a low-end-weighted curve. Blur `0 / 1 / 2 /
12` mapped native glass to approximately `0% / 2.1% / 6.2% / 100%`. The user
later fixed Blur at `8` and removed the control, so the app now evaluates only
that accepted point and leaves the old Blur key untouched.

Prevention:

- Compare minimum, standard, the user's exact mixed endpoint, and all-maximum in
  a real expanded notch over detailed background content.
- Render adjacent low values such as `0 / 1 / 2`; min/default/max alone cannot
  reveal a perceptual step at an integer boundary.
- Keep the standard mapping exact when it represents an accepted appearance.
- Inspect the reference's live generated style and script before translating a
  named control. For a true Blur `0`, remove the native glass/material layers
  rather than treating `Glass.clear` as zero blur.
- Do not translate Refraction into color or decorative strokes. Keep index
  `1.00` neutral and use a new persistence key when an old cosmetic scale has no
  truthful migration.
- Do not infer cross-window backdrop rendering from a generated map, numeric
  unit tests, or a non-empty Core Animation filter array. Test exact Release
  output with a transparent foreground window over a separate detailed backdrop
  window and compare aligned pixels at the control endpoints.
- `CALayer.backgroundFilters` can process content behind a layer inside the
  applicable compositing hierarchy, but it does not make arbitrary pixels from
  another window available to a nested SwiftUI/AppKit layer. Verify this boundary
  before designing around Core Image displacement.
- State public-API limits explicitly. Native glass may own backdrop sampling and
  lensing without exposing that sampled backdrop to a custom shader; do not call
  a native optical-strength approximation exact Convex Squircle displacement.
- Keep the retired Refraction preference fixed at `1.00` and removed from
  Settings. Preserve old preference keys as inert compatibility data rather than
  deleting, migrating, or rewriting them on launch. Blur is likewise fixed at
  `8`; any explicitly approved optical experiment must use separate internal
  constants and must not silently revive those old keys.
- Generate a fixed displacement bitmap once, then center and crop it during
  notch animation. Do not rebuild a 500×190 map on every animated layout or
  one-second Timeline update.
- Never switch native glass or Material types between adjacent slider integers.
  Keep one rendering path and interpolate opacity/radius across the full range.
- Unit-test endpoints and default invariants, but never claim those numeric tests
  prove perceptible or visually balanced output.

### Repeated adjustments must not accumulate preview ownership

The first slider-triggered preview reused a balanced request counter. Every
slider movement incremented it, but leaving Settings decremented it only once,
so a preview could remain requested after the owner disappeared. SwiftUI view
recomposition makes this especially easy to miss even when a simple open/close
test passes.

Prevention:

- Model a single Settings owner's preview as an idempotent requested Boolean,
  not a reference count.
- Carry a separate monotonically changing revision when every slider movement
  must retrigger a preview that pointer exit previously dismissed.
- Test several adjustments followed by one view disappearance, then verify both
  that the request is fully off and that a later adjustment can restart it.

Do not trust app appearance, bundle name, or `open -a` alone when several copies may exist.

### SwiftPM and Xcode are separate build graphs

SwiftPM automatically discovers source files; the hand-maintained Xcode project does not. A source addition can pass `swift test` and still be missing from the Store target.

Prevention:

- After every added, moved, renamed, or deleted Swift file, inspect Xcode file references and target membership.
- Run the complete SwiftPM tests.
- Build direct Release separately.
- Build or archive the Store target separately when the change is intended to ship there.

### Signing checks must prove the bundle, not merely inspect metadata

`codesign -d`/`-dv` can display information for an ad-hoc linker signature even when a proper app-bundle signature is absent.

Prevention:

- Make unsigned structural archive checks explicit.
- When signing is expected, require `codesign --verify --deep --strict`.
- Resolve `CFBundleExecutable` from the exact bundle before hashing; direct and Store executables have different filenames.
- Inspect both architecture slices when universal output is expected.

## P0 — Product semantics that must not regress

### Live recording belongs only in the notch

The Window recorder was repeatedly simplified but remained redundant until removed. A global recording-mode design also leaked Window-only Manual behavior into the notch.

On 2026-08-12, the user explicitly changed the earlier Window-only Manual decision and moved completed-record Manual entry into the notch. This does not make Manual live work: it still writes one completed record and never creates `ActiveWork`.

Current rule:

- Notch: Stopwatch, Timer, Pomodoro and all live controls, plus Manual completed-record entry.
- Dashboard: analytics and Total only; no Manual card or entry sheet.
- History Edit: correct an existing completed record only.

Do not reintroduce Window Start/Pause/Resume/Finish/Complete/Discard or Window Manual entry without an explicit product decision.

### Shared semantics do not require one interaction UI everywhere

The notch-style vertical Hours/Minutes/Step picker was once applied to a larger Manual form, felt unnatural there, and was reverted. On 2026-08-12, the user explicitly replaced that form with inline notch Add and requested the exact Timer duration UI for Manual. On 2026-08-15, Step itself moved out of both notch pickers into Settings while their Hours/Minutes subtree stayed shared.

Current rule:

- Notch Timer and Manual: the exact same vertical Hours/Minutes subtree with no local Step column.
- Settings > Timing owns one `1–59` minute Step for both modes. Keep the compatible `manualMinuteStep` key, route all readers and writers through `AppPreferences`, and do not rewrite current durations merely because Step changes.
- History Edit: direct compact Hours/Minutes menus plus its adjacent Step, backed by that same preference.
- Manual uses now as its anchor; Settings > Timing owns Start/End and defaults to End. Do not restore Date, Time, or Set As inside notch Add without a new product decision.
- A shared value does not require duplicating its configuration UI on every consumer.

### Terminology is a UI contract, not a schema rewrite request

User-facing names evolved from Subject/Task/Session to Activity/Item/Record. Renaming persisted model types and keys would add migration risk without product benefit.

Current rule:

- UI: Activity, Task, Routine, Item, Record.
- Internal compatibility names such as `WorkTask`, `tasks`, `taskID`, and `sessions` may remain.
- Never infer permission to change storage keys from a copy change.

### Identity symbols must not look completed

A checkmark beside a Task looked like completed state. The notch Task selector now uses an open circle; actual Complete/Restore controls retain completion semantics.

Moving a control also does not authorize changing its established glyph. Preserve the `macwindow` Open Window icon unless explicitly asked.

## P1 — Repeated layout and alignment regressions

Alignment and state movement were corrected many times. Treat this as a major regression family, not cosmetic polish.

### Painted edges matter more than container math

Failures included:

- a compact child control reserving a wider invisible frame;
- a large hit target making a visible border wider than expected;
- HStack spacing plus a child's hidden fixed width producing an unexpected gap;
- equal outer widths while clock glyphs still had different positions;
- a centered segmented picker drifting inside an otherwise aligned row;
- native controls with different intrinsic widths missing a shared trailing edge.
- equal-width Pomodoro columns whose headings still looked inconsistent because sibling field subtrees mixed leading and trailing alignment.
- equal-width Pomodoro wrappers while the shorter Sessions menu kept a narrower painted width, making the visible Long–Sessions gap larger than the declared HStack spacing.
- an explicit width applied to the native Pomodoro Picker still leaving its AppKit bezel at intrinsic width, despite the geometry test passing.
- replacing that Picker with a borderless custom Menu fixed ownership of the painted width but also removed the familiar native selection bezel, changing visual style beyond the requested spacing fix.
- returning `NSPopUpButton` directly from `NSViewRepresentable` still let its intrinsic content size exceed the 76-point SwiftUI wrapper; the bezels overlapped and erased the intended 10-point gaps.
- a full-width `Spacer` inside every Distribution legend row pushed short Activity names and their percentages to opposite edges even though both belonged to one compact data pair.
- Activity-page constants matched the shared `28 pt` margin and `900 pt` cap, but applying `.contentMargins(..., for: .scrollContent)` around a generic native `List` did not move its actual row content. The rendered row retained its native 8/9-point horizontal gutters and began at the pane top, so Activity cards alone missed the sibling pages' painted left, right, and top edges while the numeric test still passed.

Prevention:

- Inspect the full modifier chain of the actual painted child.
- Separate painted frame, hit target, reserved layout width, and container width in reasoning and tests.
- Use explicit shared trailing slots for native controls that must align.
- Render sibling fields that need identical painted alignment through one shared subtree; matching outer widths alone is not completion evidence.
- Do not assume `.frame(width:)` stretches a native Picker's AppKit bezel. For a layout-only correction, host a native `NSPopUpButton` directly so its painted bounds can be fixed while preserving the standard bezel; use a custom label/background only when a style change is explicitly intended.
- Preserve the existing control class, bezel, and interaction style when the request is only about alignment or spacing. Treat native-to-custom replacement as a separate visual product change.
- A SwiftUI `.frame` is not proof that a directly represented AppKit control adopted that size. Put the control inside a fixed-intrinsic-size `NSView`, constrain all four child edges, and lower horizontal compression resistance so the painted bezel is forced to the container bounds.
- When only scroll content needs a margin or width cap, keep the scroll container itself full-width and apply content margins inside it. Padding or constraining the outer `List` also moves its native scrollbar and makes sibling pages look misaligned.
- For a native `List`, verify that the chosen modifier changes the rendered row frame; do not infer that a shared scroll-margin value is consumed. Keep the List full-pane for its scrollbar, align each actual row through one shared wrapper that accounts for the native row gutters and reserved scroller width, and compare offscreen rendered frames at both constrained and capped widths.
- When sibling pages must start at one height, derive every top content inset—including a native List's scroll-content margin—from one shared constant. Four repeated literal `28` values can look correct until one path changes independently.
- For paired label/value legends, use intrinsic Grid columns with an explicit maximum label width instead of a row-filling `Spacer`; alignment should not create unrelated visual distance.
- Compare screenshots or user feedback against painted edges, not only frame constants.
- Add geometry regressions for critical constants and shared subtrees, but treat them as structural checks rather than proof of painted output.

### Conditional controls require reserved geometry

Activity/Item/Note rows and Start/Pause/Finish/Complete buttons shifted when recording state changed. Button ratios also ignored inter-button gaps. In 0.11.34, the idle Activity picker inherited a `34 pt` control height while the active Activity/clock identity inherited a different implicit height; their shared parent therefore centered the painted Activity label on slightly different pixel origins when Start was pressed.

Prevention:

- Prefer one stable row whose content locks or changes in place over conditional replacement of whole row structures.
- When a state change must swap row subtrees, give idle, active, and completion variants one shared explicit row height. Do not let each state's tallest child determine its vertical origin independently.
- Reserve the final width for state-specific controls.
- Include gaps when computing 1:1:2 or equal-width button layouts.
- A fixed-width digital clock must budget its longest semantic value.
- Pair the structural height regression with actual before/after screenshots and painted-pixel comparison; a matching constant alone cannot prove zero visible movement.

### Timer and Pomodoro must share the exact clock subtree

Approximate offsets still produced visible movement. Equal outer widths were insufficient because glyph origins differed.

Current structural fix:

- Both modes render the same `IslandIdleDigitalClock` subtree at the same coordinates.
- Timer's chevron is overlaid and does not participate in layout.

Do not solve future drift with another mode-specific magic offset. Fix the shared painted subtree.

### One-line forms require a width budget and minimum Window size

Activity, Item, and Start/Add rows broke when the Window became too narrow.

Prevention:

- Calculate the row's real intrinsic/fixed widths plus spacing before promising one line.
- Keep the centralized 840×540 minimum and 960×650 default synchronized between SwiftUI and AppKit.
- Do not make a main Window wider solely to hide one oversized sheet; size the sheet or row appropriately.

### Native List scrollbar visibility can change painted card width

Activities originally let the native `List` auto-hide its vertical scroller.
With too few Activities to scroll, the list reclaimed the scroller strip and
painted cards wider than they were once scrolling became possible. Matching
only the nominal content margins did not stabilize the painted right edge.

Prevention:

- Keep the native vertical scroller allocated even when the Activity list is too
  short to scroll; do not infer width stability from equal SwiftUI margins.
- Compare the same Window width with both non-scrollable and scrollable fixtures.
- Dashboard, Activities, History, and Settings must use the same 28-point
  scroll-content top inset semantics so their first visible content shares one
  top edge.
- Test the painted first-row frame itself after the List has completed AppKit
  layout. A test that compares only declared margins and width caps can pass
  while `.contentMargins` is ineffective for the native row subtree.

### Native glass must stay on deliberate, stable surfaces

Applying native Liquid Glass to the full Window background, every repeated child control, and surfaces rebuilt inside periodic `TimelineView` closures made the interface feel heavy. On 2026-08-15 the user therefore chose a notch-only boundary. On 2026-08-18 the user explicitly reopened the decision and approved a narrower Window experiment: content surfaces remain Classic, while Dashboard periods/arrows, Routine schedule selections, shared opt-in action buttons, and the one-time notch-introduction banner use official native Glass. This supersedes the absolute notch-only ban, not the evidence against broad or frequently rebuilt Glass.

Prevention:

- Keep native `glassEffect` out of Window backgrounds, cards, sidebar surfaces, lists, fields, status, charts, chips, and repeated row controls. Add a Window Glass surface only through an explicit opt-in shared style; Settings and History segmented choices remain Classic.
- Keep the native glass surface outside periodic `TimelineView` content so one-second analytics/notch updates do not recreate it.
- Render repeated notch chips and secondary buttons with lightweight tinted fills, borders, and one restrained shadow.
- Do not reuse a Glass action surface's semantic tint as its label color. Start, Add, Finish, Pause, Resume, and Discard use one high-contrast white label treatment with bold weight and a restrained dark shadow. Keep this treatment Glass-only so Classic action colors do not drift. Give actions separate high-saturation Glass surfaces: Start/Resume green, Pause orange, Finish indigo, and Discard red. Resume must alias Start's RGB and tint opacity directly rather than duplicate literals; unit-test exact equality so later tuning cannot make them diverge.
- Keep the expanded notch's native glass shell stable and avoid duplicate glow shadows unless profiling shows they are justified.
- SwiftUI's public native `Glass` surface exposes regular/clear/identity, tint, and interactivity—not arbitrary CSS-style Frost, Blur, Refraction, or Bezel Depth values. Public Core Animation/Core Image filters do not automatically gain cross-window backdrop access, so they cannot be assumed to supply a missing custom-displacement stage. Keep unsupported controls out of Settings instead of assigning them misleading decorative effects.
- Refraction is no longer a product control. Keep the neutral `1.00` compatibility value separate from fixed Blur `8`, and never render an optical layer merely because an old preference key remains. The failed fixed backdrop-lens experiment was removed after the user confirmed no visible change.
- Graph and Distribution retain their established chevron symbols and fixed navigation geometry, but on macOS 26+ those symbols now sit on round interactive Glass; older macOS retains the borderless fallback. Do not change identity symbols merely to obtain Glass.
- Verify both interaction feel and idle/active CPU with an isolated bundle before installing. A successful compile or geometry test does not prove compositor responsiveness.
- Transparency alone does not create a rich glass look. Native glass derives much of its luminosity and color from the content behind it, so a small notch over a dark or uniform menu-bar background cannot match a high-key reference render automatically.
- Compare regular and clear glass over the same realistic fixture before choosing. Clear can expose more background but also wash out dense white labels; prefer regular plus restrained local reflection when legibility wins.

### Liquid experiments must not leak beyond their approved surface

A shared moving-selection control and per-Activity notch tint were initially applied to both appearance modes. Later, Liquid materials spread across the Window before the user had approved that scope. Motion and material remain separate decisions: a moving selection does not imply Glass. The current Window contract therefore uses an explicit `.classic` or `.glass` selection surface at each call site instead of deriving it from Notch Style.

Prevention:

- `appearanceStyle` may affect `TimerIslandView`; ordinary Window components must not read it for rendering. Window Glass is a fixed per-control product decision, not another consequence of Notch Style.
- Keep matched-geometry spring motion independent from surface material. Dashboard and Routine choices explicitly opt into Glass; Settings, History, and all other choices stay on the neutral Classic surface.
- Any Liquid-only label contrast, tint, border, shadow, or transparency rule must include an explicit appearance condition; a semantic color parameter alone is not sufficient.
- When no source history is available, preserve a known prior app bundle, give it an isolated identity/data/defaults domain, and compare the same fixture side by side before accepting Classic compatibility.
- Treat “Classic unchanged” as its own acceptance requirement, not as an inference from Liquid looking correct.
- “Remove the faint frame” does not authorize removing the card face. Treat fill/material, tint, corner shape, shadow, explicit border, and the native glass optical rim as separate layers; first identify which layer the user means.
- Removing an explicit stroke does not remove the optical perimeter introduced by native `glassEffect`. When a Liquid content card must keep its face but lose that rim, use the standard Material/tint/shadow face without native glass on that card, and compare it against the preserved Classic bundle.
- When the user asks one page to match sibling pages, visual parity means using the exact same shared modifier call. Do not preserve page-specific border/native-glass flags merely because they can be tuned to look similar; remove the divergent path.
- Increasing tint opacity alone can make colored glass look muddier because white overlays and neutral material remain mixed in. For a vivid result, evaluate hue separation, saturation, white overlay, highlight, and border tint together while keeping Classic colors on their separate branch.

## P1 — Hover, notch interaction, and lifecycle

### Physical hover cannot be proven through accessibility automation

This mistake recurred. Accessibility clicks do not reproduce `NSTrackingArea` entry/exit, cursor velocity, hardware-notch geometry, or real menu ownership.

Current collaboration rule:

- Implement and unit-test state/geometry invariants.
- Install the exact build.
- Ask the user to physically verify hover, rapid exit, click modes, progress skin, dot placement, and drag feel.
- Do not claim those interactions are fixed solely from Computer Use.

### SwiftUI hover alone was unreliable for a nonactivating notch panel

The panel needed AppKit `NSTrackingArea`. Recreating tracking areas during animated resize caused chatter; a delayed collapse felt like input lag; filtering transient exits without a convergence path could leave the notch expanded.

Prevention:

- Keep tracking-area ownership stable through animation.
- Reconcile global pointer position against the final frame while expanded.
- Collapse immediately enough to feel direct; never add an unbounded suppression path.
- Physical safe-area geometry must determine collapsed sizing instead of guessed notch constants.

### Notch motion timing must stay identical in both directions

A percentage label is misleading if it scales only the AppKit frame or only the SwiftUI content transition. It can also invert user expectations if a higher “speed” multiplies duration.

The former adjustable percentage was retired, and the user later selected a fixed
`75%` on 2026-08-16. The app now fixes panel movement at `0.24 s` and content
response at `0.32 s` and ignores the legacy preference key.

A later motion regression survived mathematically centered frame tests because
`NSWindow` integralized a fractional origin and width independently. On the
1470-point built-in display, the physical notch center is `735.5`, not the
screen midpoint `735.0`; old live bounds placed an expanded timer at center
`735.0` and a collapsed Manual notch at `734.5`. The root SwiftUI spring and
`0.97` insertion scale simultaneously animated content geometry, creating the
brief impression that the shell floated before attaching. Manual Add could
also replace its Details subtree before the panel finished collapsing. A
second Manual regression appeared when Add was pressed after changing duration:
the duration popover dismissal, Add-state replacement, and shell collapse all
started together, so the notch appeared to shrink incorrectly.

Prevention:

- Apply the same fixed timing to opening and closing. Do not leave a hidden close-only duration.
- Keep the fixed value out of Settings and leave the old preference key untouched.
- Use the physical notch gap midpoint from the auxiliary top areas as the horizontal anchor; fall back to screen center only when no physical notch geometry exists.
- Derive both integral horizontal edges from that single anchor and keep the top edge fixed. Do not pass independently fractionalized origin/width values to `NSWindow`, because its rounding can shift alternating frames by 0.5–1 point.
- Let the AppKit panel animation own shell geometry. SwiftUI content may cross-fade, but a root spring or insertion scale must not animate the shell or imply a detached/floating start.
- When an action both changes content state and collapses the panel, keep the outgoing subtree stable until the collapse transition finishes; Manual Details must not reflow into Activities during shrink.
- When an action originates while its popover is open, own that presentation state in the parent and dismiss the popover before scheduling the shell collapse. Do not make popover teardown and panel resizing compete in the same frame.
- For Manual Add confirmation, morph one label instead of overlapping old/new labels, lock duplicate input, keep the outgoing subtree stable, and reset it only after collapse completes. Product-timed closure must explicitly set the panel collapsed after the confirmed hold; it must not depend on hover exit.
- Test both numeric timing constants and sample the full geometry path, then compare actual Core Graphics window bounds after real isolated actions. Physical feel still requires the user's pointer check.

### Menus are part of notch interaction even outside the panel frame

The notch went dark or collapsed while a selector menu was open. Global menu notifications alone were not deterministic enough.

Prevention:

- Bracket app-owned `NSMenu.popUp` with an explicit nested interaction lease.
- Treat menu tracking as ownership of the notch until synchronous dismissal.
- Do not rely only on pointer-inside-panel checks.

### The notch intentionally has no hover descriptions

The request includes native `.help`, not just custom overlays. Removing one while leaving the other still violates the product rule.

Prevention:

- Keep accessibility labels and values.
- Keep `.hoverHelp` and `.help` out of notch source.
- Ordinary Window icon buttons still require prompt help; native Help alone may be too delayed, so use the established immediate AppKit-backed hover label where appropriate.

### LSUIElement residency and visible-window activation are separate

Issues included disappearing on cold launch, Dock/Cmd+Tab behavior drifting, UI inspection reopening a hidden Window, and login launch depending on a SwiftUI Window's `onAppear`.

Prevention:

- Background startup and notch creation belong in `AppDelegate`, not Window appearance.
- Promote activation policy only while the main Window or Settings is visible; demote after the last Window closes.
- After closing, verify residency with PID/LaunchServices state before inspecting app UI, because UI inspection itself can reactivate it.
- Launch at Login may be changed only by the canonical `/Applications` bundle, never QA/staging copies.
- Final login-launch acceptance requires a real user logout/restart.

### MenuBarExtra was incompatible with this lifecycle

A SwiftUI `MenuBarExtra` caused the UIElement app to terminate during cold launch. The product later removed the menu-bar item entirely. Do not reintroduce it casually.

## P1 — Timer, calendar, and recurrence correctness

### Deadline semantics beat callback timing

A delayed scheduler callback must not lengthen a countdown record. Timer completion records the planned interval and deadline, not the callback's actual arrival time.

### Pomodoro Break is never work

Break phases must contribute zero duration to Total, History, Heatmap, Graph, Distribution, and Stats. Keep this invariant covered at store and analytics boundaries.

### Paused time is not a work segment

ActiveWork restoration requires explicit dates and segments. Do not reconstruct elapsed duration from vague wall-clock deltas that include pauses.

### Calendar layout and aggregation must change together

Changing week start or Day Starts affects both visible labels and allocation boundaries. A calendar label alone does not guarantee a complete range.

Prevention:

- Week is Sunday–Saturday everywhere current product behavior expects it.
- Month is first through last calendar day.
- Graph/Distribution range generation must include inactive days.
- Day Starts shifts Dashboard logical-day allocation and visible anchors together, but deliberately does not change Routine recurrence or stored timestamps.

### Routine completion does not determine row membership

Completing a Routine marks the current occurrence; it remains in the Routines list and resets at the next scheduled occurrence. Only one-time Tasks move to Completed.

### One mixed Item list needs one persisted order

Separate Task and Routine sort orders cannot preserve native drag insertion across a mixed list. Keep one per-Activity `sortOrder` domain for all incomplete Tasks and Routines.

### Optional Item must distinguish `None` from ambient selection

Manual's explicit `None` must not silently inherit the Item currently selected in the notch. Use an explicit resolution policy and retain regression coverage.

## P1 — LaunchServices, Spotlight, icons, and artifacts

### Development bundles create duplicate launcher results

Ordinary dist/archive folders were indexed by Show Apps. An initially clean or tail-filtered LaunchServices dump later surfaced dozens of delayed stale archive records; unregistering only the newest visible path was not a complete cleanup.

Prevention:

- Keep all non-installed `.app` and `.xcarchive` products in `.noindex` directories with `.metadata_never_index` where appropriate.
- Unregister any staging bundle explicitly launched during QA.
- Perform launcher cleanup only after all build and UI work.
- Parse the complete LaunchServices dump and unregister every non-`/Applications` Work Island path, not only the last few lines or the newest build.
- Run the full unregister/register pass twice with a delay, then inspect the complete filtered dump again and verify Spotlight separately.
- A sandboxed empty `mdls`/`mdfind`/`lsregister` result is not conclusive. Repeat the smallest read-only check with host access when needed.

### Icon replacement needs exact-source reuse and cache busting

Old icons remained visible because multiple bundles and caches used the same resource identity. A hand-redrawn site icon also visibly drifted from the user-supplied brand asset.

Prevention:

- Reuse the approved PNG pixels; do not redraw or approximate.
- Preserve aspect ratio and visually verify the live surface.
- Use a new content-addressed ICNS filename, bump version/build, cleanly replace the bundle, and verify resource hashes/signature.
- App Store AppIcon asset catalog and direct-distribution ICNS are separate deliverables.

### Documented artifacts can disappear

The historical notarized ZIP was later absent even though its creation had been recorded. Before sharing, verify the actual artifact exists, extract it, and validate the extracted app. Do not substitute an older preserved `.app` bundle.

## P1 — Direct distribution and notarization

- Apple Developer Program membership does not automatically create a Developer ID Application identity.
- Sandbox Keychain checks can falsely report an identity missing; repeat the narrow check with approved host access.
- Credential entry is always a user-operated boundary. Never put Apple ID passwords, app-specific passwords, keys, or tokens in chat, scripts, arguments, logs, or notes.
- A successful `notarytool submit --wait` upload followed by timeout does not cancel server-side processing. Preserve the submission ID and query status or try stapling later before resubmitting.
- Signing identity, Hardened Runtime, secure timestamp, notarization acceptance, stapling, and Gatekeeper assessment are separate checks.
- A notarization ticket applies to the exact signed binary. Any change requires the full pipeline again.
- Create the final ZIP only after stapling, then extract and revalidate signature, ticket, Gatekeeper, architectures, version, and checksum.

## P1 — App Store and TestFlight

- Read `AppStore/Submission Checklist.md` completely before running any Store build or archive command, even for unsigned local QA. On 2026-08-15 the unsigned build 65 archive was started before this read; no upload or account change occurred, but the order was wrong. Refresh the checklist and current build number first.
- Developer ID ZIPs are not Store packages. Store distribution requires the permanent bundle ID, Xcode target/archive, Apple Distribution signing, App Sandbox, privacy resources, metadata, and container migration plan.
- A development-signed archive does not prove App ID registration, Distribution identity/profile availability, or App Store Connect readiness.
- Local signing may work while Xcode account authentication is stale. Resolve account-manager warnings before upload.
- App ID registration and App Store Connect app-record creation are separate durable actions.
- Match the App Store version record to `CFBundleShortVersionString`; every uploaded build number must be unique.
- A processed TestFlight upload is not tester availability, App Review submission, approval, or release.
- Nested App Store Connect editors may require both their own Done/Save and the parent page Save. Reload from fresh navigation to confirm persistence.
- Free price and storefront availability are independent. Free distribution does not remove legal/trader choices. Never infer or change them for the user.
- A successful upload must not be “undone” by deleting durable Apple records. Continue with a newer build or version.
- Existing direct data does not automatically move into the Store sandbox; use explicit Export/Import.
- Public Pages deployment is asynchronous. A first 404 may be temporary; wait for workflow success and verify live HTTPS content.
- Repository read access does not prove write capability. Verify published content by the actual live file/blob.
- Screenshots must be checked after reload for order, dimensions, current terminology, and pointer artifacts.

## P2 — Tooling and command hygiene

- An exact user-supplied repository URL and commit identify the intended destination. Before creating any repository, inspect that target's branch, tree, visibility, and Pages settings. Do not infer that a separate private source repository is preferred merely because the named repository currently contains only a public site; integrate with its existing history and preserve its published files, or ask before choosing a different destination.
- Quote every path containing spaces.
- Never place Markdown backticks inside a double-quoted shell argument; zsh executes them as command substitution. Use a single-quoted literal search pattern or escape-free fixed-string input instead.
- A computed `some View` helper that contains local declarations and builds a modifier chain needs an explicit `return` or `@ViewBuilder`; add the annotation when extracting a SwiftUI branch instead of waiting for opaque-return inference to fail.
- Core Image does not expose every documented filter input as a Swift global constant. In the macOS 26.5 SDK, `kCIInputDisplacementImageKey` was unavailable even though `CIDisplacementDistortion` and its `inputDisplacementImage` input exist. Use the filter's declared input key, keep it centralized, and cover the KVC input with a unit test instead of assuming a C constant is imported.
- SwiftPM, Clang, iconutil, Keychain, Spotlight, and signing tools can fail misleadingly inside a sandbox. Repeat only the smallest necessary command with approved host access.
- `iconutil` can report `Invalid Iconset` in a restricted environment even when the iconset is valid.
- Avoid recursive traversal of protected Store container paths; it can hang. Use app-provided Import/Export and explicit paths.
- Computer Use shortcuts use one key-combination string such as `super+w`; do not invent a modifiers field.
- Persistent Computer Use targets can keep or revive an old application identity; re-resolve the focused bundle before every state-changing action.
- Build-wrapper options must match the wrapper's documented interface. Do not assume shell environment overrides are accepted as positional arguments.
- For release assets, verify file order and exact pixel source instead of relying on names or thumbnails.

## How to maintain this file

Add or strengthen an entry only when a failure teaches a reusable prevention rule. Do not append routine success logs, version-by-version history, or resolved one-off details. If a new issue is another instance of an existing family—data contamination, stale process, painted alignment, physical hover, or release-boundary confusion—update that family and make the recurrence explicit.
