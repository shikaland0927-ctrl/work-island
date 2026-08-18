# Work Island — Current Handoff

Last consolidated: 2026-08-18

This file is the canonical current-state handoff for the next Codex task. It is intentionally weighted toward product invariants, current architecture, unresolved acceptance, and safe next actions. Superseded chronological progress has been removed.

## Read order and trust model

Before working on Work Island, read in this order:

1. workspace `../AGENTS.md` (from this file's directory, that is `../../AGENTS.md`)
2. `README.md`
3. `AGENTS.md`
4. this file
5. `note/Mistakes.md`

Read `TODO.md` only when the user asks for TODO work. Read `IDEAS.md` only when the user asks to discuss or implement ideas.

This is a snapshot, not live evidence. Inspect current source metadata, bundles, processes, persistence, and external Apple state before acting. Never restore an old data hash merely because the live file differs from the value recorded here.

## Collaboration and verification contract

The user wants to perform visual and functional acceptance themselves.

- Codex should implement, run automated tests and non-interactive checks, install the exact intended build when appropriate, then ask the user to verify a short list of concrete interactions.
- Do not drive the app UI simply to prove appearance, animation, hover, click count, drag feel, notch geometry, login launch, or real-time behavior when the user can check it.
- Use state-changing UI automation only when explicitly requested or genuinely necessary, and then only with isolated storage, isolated preferences, a unique bundle identity, and full pre/post state checks.
- Physical notch behavior can never be accepted solely through accessibility automation.
- Never check off a user-verification item without the user's report.

## Product definition

Work Island is an English-language native macOS work timer inspired by the interaction model of NotchBox. The app lives as a compact panel around the physical MacBook notch and expands by Hover, Single Click, or Double Click.

Core hierarchy and vocabulary:

- `Activity`: reusable top-level category such as Math or App Development.
- `Task`: one-time child item. Completing it moves it to Completed; it can be restored or deleted.
- `Routine`: recurring Day/Week/Month child item. Completing it marks only the current occurrence and keeps the Routine visible until its next cycle.
- `Item`: neutral UI umbrella when either a Task or Routine may be selected.
- `Record`: one completed unit in History. Avoid reviving the old user-facing term `Session`.

Product principles that have been repeated often and must remain stable:

- Remove redundant headings, explanations, dates, and labels. Prefer concise or single-word copy.
- Do not repeat a navigation title inside the page.
- Keep controls visually still when state or mode changes. Reserve geometry for conditional content.
- Align the painted edges of controls, especially right edges; container frames alone are not enough.
- Preserve established symbols when moving controls. Identity symbols must not resemble completion symbols.
- Timer and Manual share one notch Hours/Minutes duration control and one Settings-owned minute Step; History Edit deliberately keeps its compact Window editor.

## Current user-visible behavior

### Notch

- The collapsed notch is pure black with no border, accent, text, or chevron.
- Appearance defaults to Classic. The user-facing choices are `Classic | Glass`; the persisted raw value remains `liquidGlass` for compatibility. Glass changes only the expanded notch shell and controls; the collapsed notch remains exactly black.
- In Glass, the expanded shell uses native glass with a reduced black tint, a vivid indigo cast, and lightweight vertically balanced reflection/rim layers so the underlying desktop reads through without washing out white content. Selected Activities use one high-saturation blue-indigo glass color. Start and Add use vivid green; Resume aliases that exact Start RGB and opacity rather than duplicating values. Pause uses vivid orange, Finish vivid indigo, and Discard vivid red. Start, Add, Finish, Pause, Resume, and Discard use the same bold high-contrast white label treatment with a restrained dark shadow. The lightweight control surfaces use less white overlay so these colors do not turn gray. Classic keeps its established Activity and action colors.
- Glass optics are fixed: Blur `8`, Refraction `1.00`, Frost `6`, and Bezel Depth `0`; none appears in Settings and there is no settings-driven notch preview. Legacy optical keys remain untouched but ignored. The visually ineffective 0.11.30 `.behindWindow` plus non-root `CIDisplacementDistortion` experiment was removed in 0.11.31 after the user confirmed that it still produced no visible change.
- A separate click-through dot appears immediately to its right only while active: green while running, orange while paused.
- Activity name, optional Item, note, timer, and controls appear only while expanded.
- The expanded notch is the only live-recording surface.
- Live methods are Stopwatch, Timer, and Pomodoro. Manual is available in the same Method menu but creates one completed record and never creates `ActiveWork`.
- Manual shows the same duration clock and vertical Hours/Minutes picker as Timer. Add immediately creates one completed record from the selected Activity, optional Item, Note, and current moment. After a successful Add, any open duration popover closes first, the single Add label fades into Added, Added remains fully visible for one second, and the notch then closes even if the pointer is still hovering. Duplicate Add input remains locked, and the outgoing Manual/Details subtree stays intact until collapse finishes.
- Manual has no Date, Time, or Set As controls in the notch. `Settings > Timing > Set As` chooses whether now is the record's Start or End and defaults to End.
- Start, Pause, Resume, Finish, Complete, and paused-only Discard are available as appropriate.
- Discard never creates a History record.
- Finish records work but leaves a selected Task/Routine open. Complete records work and completes the selected Task or current Routine occurrence.
- Without an Item, paused controls are Resume : Discard : Finish = 1 : 1 : 2. With an Item, Resume, Discard, Finish, and Complete have equal widths. State changes must not shift Finish.
- Activity, optional Item, and Note remain editable while idle. They lock without shifting when recording starts. Idle, active, and completion Activity/clock identities share one explicit `34 pt` row height, so pressing Start does not move the painted Activity label vertically.
- The leading circular `macwindow` control opens the main Window.
- Task identity uses a neutral open circle; completion controls use completion-oriented symbols.
- The notch intentionally has no hover descriptions, including native `.help`. Accessibility labels remain.
- Timer and Manual use the exact same compact vertical `Hours | Minutes` picker. One shared `1–59` minute Step lives in `Settings > Timing`; History Edit keeps compact Hours/Minutes menus with its adjacent Step control backed by the same preference.
- Timer and Pomodoro use the exact same clock subtree and coordinates. Timer's chevron is an overlay and must not move the digits.
- Elapsed durations remove only the leading field zero: `00:00` → `0:00`, `02:05` → `2:05`, `02:03:04` → `2:03:04`. Inner minute/second fields remain padded.
- Timer completes and records at the planned deadline even if the scheduler callback is late.
- Pomodoro alternates Focus, Break, and Long Break. Only Focus contributes work records or analytics.
- Optional progress uses the right side, bottom, and left side of the notch, never the top. The collapsed panel grows only enough to reveal that skin.
- Completion Alert is Temporary or Persistent.
- Timer and Pomodoro completions keep their existing content and controls but make the identity/clock row ring silently in short horizontal/rotational bursts. Done stays still, no audio API is used, and Reduce Motion disables the effect.
- Hover expansion uses AppKit tracking, immediate pointer reconciliation, and a short close animation. Owned menus count as active notch interaction so the panel does not collapse while choosing an option.
- Opening and closing both use the fixed `75%` timing: `0.24 s` panel movement and `0.32 s` content response. Notch Speed is absent from Settings; the legacy `notchOpenSpeedPercent` key remains untouched but ignored. AppKit alone animates the shell frame; expanded/compact SwiftUI content cross-fades without the former `0.97` scale insertion or a root spring, so the notch never appears to float away from the screen before opening.
- Every intermediate panel frame stays attached to the screen top and is rebuilt around the physical notch gap's midpoint; displays without a notch fall back to the screen center. Both horizontal edges are integralized from that single anchor instead of letting `NSWindow` round origin and width independently, so timer/progress and Manual collapse remain left/right symmetric even when the requested width has the opposite parity from the physical center. Interrupted motion is normalized to the same top/center anchor.

Refraction feasibility, researched against the macOS 26.5 SDK and Apple documentation on 2026-08-15:

- SwiftUI `Glass` publicly exposes `regular`, `clear`, `identity`, `tint`, and `interactive`; it exposes neither a refractive-index parameter nor the compositor's sampled background texture/readback. The visible tint in the current notch is a material/compositing instruction, not a `CIImage` owned by Work Island.
- Inverting the visible blur is therefore blocked before the deconvolution step. It would also be numerically unstable: blur and system material processing discard or mix the high-frequency line detail that refraction needs.
- The final `.behindWindow` plus non-root `backgroundFilters` trial also produced no visible line bending in the user's physical check. The experiment and its render layer were removed rather than leaving ineffective compositor work in the notch. `IslandConvexSquircleLens` remains only as a tested mathematical reference, not a rendered effect.
- The deterministic custom route is ScreenCaptureKit: capture the display while excluding Work Island, crop the raw region, apply displacement, then blur/tint/mask. It does not need inverse blur, but it requires Screen Recording consent and adds continuous capture, synchronization, latency, energy, privacy, and Store-review costs. Do not add it without an explicit product decision.

### Main Window

- Navigation order: Dashboard, Activities, History, Settings.
- `Notch Style` still changes only the expanded notch. The Window does not read that preference, but on macOS 26+ a small fixed set of control-layer surfaces always uses official native Glass: selected Dashboard periods, Graph/Distribution arrows, selected Routine schedule choices, shared opt-in primary/secondary actions, and the one-time notch introduction banner. Older macOS uses the existing Classic fallbacks.
- The shared segmented control keeps its still outer track, labels, and damped spring. Dashboard period and Routine schedule selections opt into a restrained indigo-tinted interactive Glass surface; Settings choices and History Start/End deliberately retain the Classic selected surface.
- The Window background remains the uniform system background; cards, sidebar status, Total, charts, lists, fields, chips, and repeated row controls remain Classic. Native Glass controls are kept outside periodic `TimelineView` content so refreshes do not recreate their compositor surfaces.
- Default size is 960×650; minimum is 840×540. The layout should not compress below this into broken rows.
- Dashboard, Activities, History, and Settings use the same scroll-content container semantics and 28-point top inset, aligning Total/Status, New Activity, the History header, and General. Activities keeps its native `List`, permanently reserves its vertical scroller, and therefore keeps card width stable whether or not its content can scroll.
- The app appears in Dock and Command-Tab while the main Window or Settings is visible, then returns to accessory/background behavior after the last Window closes.
- Closing the main Window leaves the notch resident.
- Ambiguous icon-only Window controls require accessibility labels, native Help fallback, and immediate hover labels. This rule does not apply to the notch.

Dashboard:

- Total and Status are permanent side-by-side cards at the top. Total shows today's duration without a mini chart. Status has no `All time` subtitle and shows Streak, Longest Streak, and Best Day in that order.
- Optional cards are Heatmap, Graph, and Distribution. Settings controls their visibility and native drag order; Status does not appear in Settings. Heatmap color is fixed to Indigo and has no Settings control.
- Heatmap is Sunday-first, covers 365 days, includes inactive cells, and has no Less/More legend.
- Graph uses activity-colored stacked bars for complete Sunday–Saturday Weeks or complete calendar Months.
- Graph and Distribution keep the established 20-point chevrons in the fixed 44-point navigation slot, now with round interactive native Glass surfaces on macOS 26+ and borderless Classic fallbacks on older macOS.
- Distribution uses complete calendar Day, Week, or Month periods. Its legend is an intrinsic two-column Grid, so Activity names and their percentage/duration values remain near one another instead of being pushed to opposite edges.
- Day Starts changes Dashboard logical-day allocation and period anchors only; it does not alter Routine recurrence or stored timestamps.

Activities:

- Starts directly with New Activity and the list; there is no repeated page title/description.
- Activity cards use the exact same shared Classic `.workCard()` surface and corner geometry as Dashboard, History, and Settings. There is no Activity-only frame or glass override.
- The native Activities scroll container spans the full detail pane so its scrollbar shares the same trailing edge as Dashboard, History, and Settings. Each real List row now uses one alignment wrapper that compensates the native 8/9-point row gutters and reserved 17-point scroller width; its painted left, right, and top edges match the ordinary page container at constrained and capped widths while card geometry and native drag behavior remain unchanged.
- New Activity uses the concise placeholder `e.g. Thesis, Client work`; the older `English` example is removed.
- Activities can be created, renamed, drag-reordered, archived, restored, and deleted with confirmation.
- Each Activity owns one mixed native drag-ordered list of incomplete Tasks and all Routines.
- Completed Tasks move to a collapsible Completed section and return to their saved slot when restored.
- Routines support Day/Week/Month intervals, weekdays, dates 1–31, Last, and ordinal weekday patterns. Their frequency, Dates/Pattern, and ordinal selections use the same selective Glass treatment as Dashboard periods on macOS 26+.
- A completed Routine stays in place with a cycle-aware restore state and resets for its next scheduled occurrence.
- Edit sits immediately left of Archive. Archived Restore/Delete and all ambiguous icon actions keep immediate Window hover help.

History:

- One newest-first all-time list; no presentation tabs or `By Task` page.
- Only total record count and total duration appear above the list.
- Each record keeps stable Activity identity plus Task/Routine name/type snapshots, date, time range, duration, and optional Note.
- Empty Note sections are omitted.
- Edit can change Note, calendar Date, 24-hour Time, Start/End anchor, Hours, Minutes, and Step; Delete is explicit.

Settings and onboarding:

- General: Notch Style, Launch at Login, Day Starts, and Open Notch mode. Notch Style retains the existing `appearanceStyle` key but now displays `Classic | Glass` and controls only the expanded notch. Blur, optical parameters, and Notch Speed have no Settings sections or rows.
- Timing: Alert, compact Progress, Manual Set As Start/End, shared Timer/Manual Step, and Pomodoro Focus/Break/Long/Sessions. Step defaults to `5 min`, reuses the compatible `manualMinuteStep` key, and does not rewrite Timer or Manual's current duration when changed. The Pomodoro fields use one shared trailing-aligned native `NSPopUpButton` subtree; the standard macOS bezels themselves fill the same 76-point columns with equal 10-point visible gaps.
- Dashboard: optional Heatmap/Graph/Distribution visibility/order. Heatmap is fixed Indigo; Total and Status are not configurable. Its three-row reorder list uses balanced top/bottom insets and a rounded outer shape.
- First run asks only for one initial Activity and Launch at Login, then shows `Move your pointer to the notch.` once.
- Existing valid data must never trigger onboarding merely because an Activity or Item collection is empty.

## Architecture and important paths

Source of truth:

    /Users/shikazeriku/obsidian/app_development/WorkIsland

The app root is a Git repository whose canonical remote is the public `https://github.com/shikaland0927-ctrl/work-island`. The existing public-site history through commit `61ae75a4c1aa1b6c63240a4c281b609edcc3e876` remains intact; the app source was integrated on top while the root GitHub Pages HTML/CSS/SVG blobs stayed unchanged. The integration is currently on `agent/migrate-app-source` in draft PR `#1`; public `main` remains at the Pages-only commit until the user authorizes the final merge. Build products, QA data, real-data backups, archives, signing material, credentials, and environment files are excluded from tracking. The mistakenly created private `work-island-app` repository is retained only as a noncanonical backup and must not receive routine development pushes.

Entry points:

- Direct development and tests: `Package.swift`
- Mac App Store archive: `WorkIsland.xcodeproj`
- SwiftUI app lifecycle: `Sources/WorkIsland/WorkIslandApp.swift`
- AppKit lifecycle and window activation: `Sources/WorkIsland/App/AppDelegate.swift`
- Notch panel, physical geometry, hover, click policy, status dot, exact completion scheduling: `Sources/WorkIsland/App/IslandPanelController.swift`
- Notch UI: `Sources/WorkIsland/Views/TimerIslandView.swift`
- Main navigation: `Sources/WorkIsland/Views/RootView.swift`
- Dashboard: `Sources/WorkIsland/Views/DashboardView.swift`
- Notch and Manual Add: `Sources/WorkIsland/Views/TimerIslandView.swift`
- Activities, Tasks, and Routines: `Sources/WorkIsland/Views/TasksView.swift`
- History and Edit: `Sources/WorkIsland/Views/HistoryView.swift`
- Shared Window duration inputs: `Sources/WorkIsland/Views/SessionInputControls.swift`
- Settings: `Sources/WorkIsland/Views/SettingsView.swift`
- Store, commands, migrations, JSON persistence: `Sources/WorkIsland/Store/WorkTimerStore.swift`
- Preferences: `Sources/WorkIsland/Models/AppPreferences.swift`
- Item/recurrence model: `Sources/WorkIsland/Models/ActivityItem.swift`
- Build and release scripts: `Scripts/`
- Store metadata/checklist: `AppStore/`

Architectural invariants:

- SwiftUI owns ordinary Window content; AppKit `NSPanel` owns the notch.
- `WorkTimerStore` is the source of truth for Activities, Items, ActiveWork, records, timing transitions, analytics inputs, migrations, Import, and Export.
- The internal top-level model remains `WorkTask`, with persisted `tasks`, `taskID`, and `sessions` compatibility keys. User-facing copy remains Activity/Record; do not rename the persistence schema merely for terminology.
- Stable UUIDs back Activity and Item relationships; History also preserves title/type snapshots after rename or deletion.
- `dashboardStats` derives current and longest streaks from positive-duration logical days across the full available history. Empty logical days break a streak; the current streak may ignore only an empty current logical day.
- SwiftPM and the hand-maintained Xcode project are separate build graphs. Added or moved source files require verification in both.

## Persistence and migration

Direct-build storage:

    ~/Library/Application Support/WorkIsland/work-data.json

Direct-build preferences domain:

    local.shikazeriku.work-island

Current JSON schema is 6:

- schema 2: Activity library and stable IDs
- schema 3: Task/Routine items
- schema 4: Activity order
- schema 5: mixed Item order
- schema 6: Timer/Pomodoro state

Current source behavior seeds a default Activity only when no storage file exists. Migration decisions must use the stored schema version. An existing schema-6 file with zero Activities is valid and must remain empty.

The Store bundle `com.shikazeriku.workisland` is sandboxed and stores data in its own container. It does not automatically inherit direct-build data. Use File > Export in the direct app and File > Import in the Store app. Import writes `work-data-before-import.json` beside the Store data before replacement.

Current direct data state, reverified after installing the native-control-Glass build without launching it on 2026-08-18—a safety reference, not a restore target:

- SHA-256: `15fd7f563c1acdb54d0d71957704afd179e8ef683e07d3cabd207c138e273d81`
- schema 6
- 3 Activities
- 0 child Items
- 50 records
- no ActiveWork
- complete exported preferences SHA-256: `f7f93e460c1196759afed23f942897c9076bcf1b809f8d96bd6bb62f3c4ef728`

The current byte-for-byte safety snapshot is `.qa-backups.noindex/20260818-2352-pre-native-control-glass`. Its pre-install and post-install preference exports match exactly. Always inspect the live file and complete preferences domain again before any restoration; their hashes, record count, and ActiveWork can legitimately change after this verification.

## Current build and installed state

Last verified on 2026-08-18:

Direct development channel:

- Source `Info.plist`: version 0.11.39, build 91
- Staging: `dist.noindex/Work Island.app`
- Installed: `/Applications/Work Island.app`
- Bundle ID: `local.shikazeriku.work-island`
- Staging and installed executable SHA-256 matched: `1b0493f95b5d51fd7636ab725e44d05a8e3ae3a397ed1dc05f688bd17aa93662`
- Development bundle is ad-hoc signed, not a friend-beta release.
- The replaced installed 0.11.38 build 90 bundle is preserved at `dist.previous.noindex/Work Island 0.11.38 (90)-installed-replaced-by-0.11.39.app`; earlier preserved bundles remain under the same `.noindex` directory.
- The unlaunched broad-scope intermediate 0.11.39 bundle is also preserved at `dist.previous.noindex/Work Island 0.11.39 (91)-pre-scope-adjustment.app`; the installed 0.11.39 is the later narrowed build.
- The new installed bundle has not been launched; the user owns visual and functional acceptance.

Store channel:

- Local target: version 1.0.0, build 75
- Permanent bundle ID: `com.shikazeriku.workisland`
- Latest local archive: `dist.appstore.noindex/Work Island 1.0.0 (75)-20260818-235625.xcarchive`
- Archive is unsigned structural QA only, universal `x86_64 arm64`
- Archived executable SHA-256: `4b77c3f8fe4a4edf1e9c18223fad03bc08688ed0f7ce20bdcd5656655b970b16`
- It has not been Distribution-signed, exported, uploaded, assigned to testers, or selected for review.

Verification baseline:

- All 119 Swift tests passed for the 0.11.39 source. The selective-control regression protects the restrained Glass tint and the existing 44-point Dashboard navigation geometry. Existing coverage continues to include fixed `75%` motion, Activity row alignment, Manual confirmation timing, the shared `34 pt` notch Activity row, vivid notch Glass actions, exact Resume/Start equality, fixed Blur `8`, fixed Indigo Heatmap, fresh Step `5 min`, inert legacy keys, `Classic | Glass` copy, persistent Activity scroller allocation, Status layout, and previous timer/data/recurrence behavior.
- On 2026-08-16 the user confirmed that the Activity page edge alignment and concise New Activity placeholder were correctly fixed.
- Direct Release, strict ad-hoc bundle verification, staging/install hash parity, and unsigned universal Store archive checks passed. No new source file was added, so SwiftPM and Xcode continue to compile the same source membership.
- Computer Use clicked the real Start control in an isolated Glass-notch copy of the production Activity fixture before and after the fix. The fixed before/after Activity crop had best vertical displacement `0 px`, correlation `0.9999995879`, and identical luminance centroids at thresholds 200, 220, and 240. Evidence is under `.qa.noindex/activity-layout-20260815-150503/` as `user-before-idle.jpg`, `user-before-running.jpg`, `user-after-idle.jpg`, and `user-after-running.jpg`.
- Computer Use also executed Timer Start and Manual Add from both the normal and Details layouts before and after the motion fix using six isolated QA bundle identities under `.qa.noindex/notch-motion-20260815-161751/`. Actual Core Graphics window bounds exposed the rounding defect: the old expanded timer was `x=485, width=500, center=735.0` and the old collapsed Manual notch was `x=646, width=177, center=734.5`, while the physical notch center is `735.5`. The fixed expanded timer was `x=485, width=501, center=735.5`; the fixed collapsed Manual notch was `x=647, width=177, center=735.5`; all four observed terminal bounds remained at top-origin `y=0`.
- Computer Use reproduced the duration-dependent Manual defect under `.qa.noindex/manual-duration-feedback-20260815-173639/` by opening the duration popover, changing `30` to `45 min`, and clicking Add while the popover was still open. In the final isolated bundle, the popover disappeared first, the disabled button exposed `Added` with a checkmark, and the notch explicitly collapsed after the full label morph plus one-second hold while the cursor remained over the former button position and a QA interaction lease still pinned normal hover behavior. Exactly one `2700 s` fixture record was added, the fixture stayed without ActiveWork, and the outgoing subtree did not reflow during shrink.
- The 0.11.39 install occurred only after stopping the old process and snapshotting production JSON plus the complete preferences domain. Staging/install binaries match exactly, strict ad-hoc signature verification passes, and both production files remained byte-for-byte unchanged. The new build remains stopped until the user launches it.
- No source file was added, moved, or removed. Direct Release and the unsigned universal Store archive both compile the same existing source membership.
- LaunchServices and Spotlight were checked after cleanup and expose only `/Applications/Work Island.app`; staging, archive, derived, and preserved bundles remain confined to `.noindex` paths.
- Treat this as a baseline only; rerun the relevant checks after source changes.

## Pending user acceptance

These are not confirmed defects. They require the user's physical interaction and must not be checked off by Codex:

1. Confirm the notch remains physically attached to the screen top for the entire opening animation, with no initial floating/scale-up moment. It must expand and collapse symmetrically around the physical notch center.
2. Open Settings and confirm Notch Style reads `Classic | Glass`, with no Notch Glass section and no Notch Speed or Heatmap Color row. Switch styles and confirm only the expanded notch responds to that preference; the fixed Window control Glass must not switch with it.
3. Switch Timer ↔ Pomodoro and confirm the visible clock does not move.
4. Switch Timer ↔ Manual and confirm both duration controls have the same two-column Hours/Minutes layout with no Step column. In Manual, confirm Add has no Date, Time, or Set As popup.
5. On a fresh preferences domain, confirm Settings > Timing > Step starts at `5 min`. Change the single Step and confirm both Timer and Manual minute choices use it while their current durations remain unchanged. Confirm Focus, Break, Long, and Sessions retain the standard macOS selection bezel while using equal-width menus, equal visible gaps—including Long–Sessions—and right-aligned headings. Also confirm Set As defaults to End; optionally switch Start/End and add an intentional Manual record to verify its timestamp semantics.
6. Confirm Total and permanent Status sit cleanly side by side at both default and minimum Window sizes. Status should have no `All time` line and should read Streak, Longest Streak, Best Day without truncation; Total should have no mini chart, and Dashboard Settings should have neither Status nor Heatmap Color. In Dashboard Settings, also confirm the three-row list has matching top/bottom padding and rounded corners, and the Heatmap remains Indigo.
7. Confirm compact and expanded Timer/Pomodoro progress uses only sides and bottom, never the top.
8. Confirm Hover, Single Click, and Double Click opening modes with a physical pointer. Confirm the fixed `75%` motion feels correct and opening/closing match. While a Timer is running, move the pointer away and confirm both sides shrink equally. In Manual, change the duration while its popover is open, click Add, and confirm the popover closes first; Add should fade smoothly into Added, Added should remain for one second, then the notch must close even while the pointer stays over the button. Repeat from both Activities and Details layouts and confirm each collapse stays top-attached, has no content reflow flash, and remains left/right symmetric.
9. Drag one Activity, one mixed Task/Routine Item, and one Dashboard card; quit and relaunch; confirm native feel and persisted order.
10. Confirm the right-side green/orange compact status dot size and placement.
11. With Launch at Login enabled, perform a real logout/restart; before opening manually, confirm the notch is resident and opens.
12. Confirm behavior on multiple displays if that scenario matters; there is no display preference yet.
13. Let both Timer and Pomodoro reach zero and confirm the existing completion row appears to ring silently in short bursts while the Done button stays still. With Reduce Motion enabled in macOS, confirm the ringing stops.
14. Physically confirm the expanded-notch Glass still feels responsive. Confirm fixed Blur `8` keeps the intended translucency, selected Activities remain high-saturation blue-indigo, Start/Add are vivid green, Pause is vivid orange, Resume is visually the exact same green as Start, Finish is vivid indigo, Discard is vivid red, and the closed notch stays pure black. Start, Finish, Pause, Resume, and Discard must all remain clearly readable in their idle/running/paused layouts, both with and without a selected Item; Classic labels must remain unchanged. Press Start once and confirm the Activity label stays physically still rather than dropping by 1–2 pixels.
15. Confirm Total/Status, New Activity, the History header, and General begin at the same top height. In Activities, compare a list that cannot scroll with one that can: card width must stay unchanged, the vertical scrollbar must keep the same right edge, and native drag-reordering must still feel normal.
16. Confirm the Window keeps a restrained split: the background, cards, charts, lists, fields, status, chips, and repeated row controls remain Classic, while Graph Week/Month, Distribution Day/Week/Month, their round chevrons, and Routine frequency/Dates-Pattern/ordinal selections use responsive official Glass. Confirm shared one-off primary/secondary actions and the first notch-introduction banner also use system Glass, while Settings segments and History Start/End stay Classic. Also confirm period controls do not flicker during timed Dashboard refreshes and Distribution keeps each Activity close to its percentage/duration.

## Release state and boundaries

Direct friend beta:

- A universal Developer ID-signed, notarized, stapled 0.5.3 build 16 ZIP was completed on 2026-08-03.
- That final ZIP is no longer present. The old preserved app bundle is not a substitute.
- Any new friend beta must be rebuilt from current source, Developer ID signed with Hardened Runtime and timestamp, notarized, stapled, zipped after stapling, extracted, and verified again. Give testers the version/build and ZIP SHA-256.

App Store/TestFlight:

- App Store Connect app record exists for Apple ID `6797406491` with permanent bundle ID `com.shikazeriku.workisland`.
- Version 1.0.0 build 1 was uploaded and processed. Last observed TestFlight state was `Ready to Submit`; it was not assigned to testers, submitted to App Review, or released.
- Local source is now build 75; never reuse upload build number 1.
- The user chose free distribution and excluded all 27 EU member states. Do not change legal/trader/storefront choices without asking.
- Support and Privacy pages were published, and App Privacy was set to `Data Not Collected`. Verify live URLs and App Store Connect state before relying on this.
- Existing screenshots predate the Activities rename and the move of Manual out of Dashboard; regenerate them before App Review.
- App Preview is intentionally omitted and release mode is Manual.
- The user wants to perform App Store Connect/browser operations personally. Explain steps; do not upload, invite testers, submit, or release without explicit authorization.
- Before any Store action, read and refresh `AppStore/Submission Checklist.md`; it can lag behind source build numbers.

## Known limits, not current TODOs

- No cloud sync, account, analytics, ads, or external data transfer.
- No display selection, notch-width setting, collapse-delay setting, or always-expanded mode.
- Routine schedules are date-based; no time-of-day, notification, calendar integration, target, or overdue backlog.
- Dashboard periods are fixed calendar Day/Week/Month, with no arbitrary custom interval or future period.
- Manual adds completed records directly from the notch using now plus the Settings Start/End anchor; it never creates live work and currently has no custom Date/Time input.
- App Store sandbox data requires explicit Export/Import from the direct build.

## Safe workflow for the next task

1. Read the required files and identify whether the request is code, TODO, IDEAS, release, or advice.
2. Inspect current version/build, relevant source, staging/installed executable paths, and live persistence only as needed.
3. Before any stateful action, protect both JSON and the full preferences domain. Do not overwrite newer user state.
4. Implement the smallest coherent change while preserving product invariants.
5. Add or update regression tests for logic, migration, geometry invariants, and configuration.
6. Run the full Swift test suite. Verify direct Release and Store build paths in proportion to the change.
7. Install the exact staging build when appropriate and verify version/build/hash parity without using the UI as visual proof.
8. Ask the user to perform a concise physical acceptance checklist. Record only what they actually report.
9. Update this current-state snapshot and strengthen `Mistakes.md` only when a reusable failure pattern was discovered.
