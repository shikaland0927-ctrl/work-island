# Work Island — Current Handoff

Last consolidated: 2026-08-13

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
- Timer and Manual share one notch duration control; History Edit deliberately keeps its compact Window editor.

## Current user-visible behavior

### Notch

- The collapsed notch is pure black with no border, accent, text, or chevron.
- Appearance defaults to Classic. Liquid Glass changes only the expanded notch shell and controls; the collapsed notch remains exactly black.
- In Liquid Glass, the expanded shell uses regular native glass with a reduced black tint, a vivid indigo cast, and a lightweight diagonal reflection/rim so the underlying desktop reads through without washing out white content. Selected Activities use one high-saturation blue-indigo glass color; Start and Add use high-saturation green with high-contrast white labels. The lightweight control surfaces use less white overlay so these colors do not turn gray. Classic keeps its established Activity and action colors.
- A separate click-through dot appears immediately to its right only while active: green while running, orange while paused.
- Activity name, optional Item, note, timer, and controls appear only while expanded.
- The expanded notch is the only live-recording surface.
- Live methods are Stopwatch, Timer, and Pomodoro. Manual is available in the same Method menu but creates one completed record and never creates `ActiveWork`.
- Manual shows the same duration clock and vertical Hours/Minutes/Step picker as Timer. Add immediately creates one completed record from the selected Activity, optional Item, Note, and current moment.
- Manual has no Date, Time, or Set As controls in the notch. `Settings > Timing > Set As` chooses whether now is the record's Start or End and defaults to End.
- Start, Pause, Resume, Finish, Complete, and paused-only Discard are available as appropriate.
- Discard never creates a History record.
- Finish records work but leaves a selected Task/Routine open. Complete records work and completes the selected Task or current Routine occurrence.
- Without an Item, paused controls are Resume : Discard : Finish = 1 : 1 : 2. With an Item, Resume, Discard, Finish, and Complete have equal widths. State changes must not shift Finish.
- Activity, optional Item, and Note remain editable while idle. They lock without shifting when recording starts.
- The leading circular `macwindow` control opens the main Window.
- Task identity uses a neutral open circle; completion controls use completion-oriented symbols.
- The notch intentionally has no hover descriptions, including native `.help`. Accessibility labels remain.
- Timer and Manual use the exact same compact vertical `Hours | Minutes | Step` picker. History Edit uses compact Hours/Minutes menus with an adjacent Step control; Step is shared and accepts 1–59 minutes.
- Timer and Pomodoro use the exact same clock subtree and coordinates. Timer's chevron is an overlay and must not move the digits.
- Elapsed durations remove only the leading field zero: `00:00` → `0:00`, `02:05` → `2:05`, `02:03:04` → `2:03:04`. Inner minute/second fields remain padded.
- Timer completes and records at the planned deadline even if the scheduler callback is late.
- Pomodoro alternates Focus, Break, and Long Break. Only Focus contributes work records or analytics.
- Optional progress uses the right side, bottom, and left side of the notch, never the top. The collapsed panel grows only enough to reveal that skin.
- Completion Alert is Temporary or Persistent.
- Timer and Pomodoro completions keep their existing content and controls but make the identity/clock row ring silently in short horizontal/rotational bursts. Done stays still, no audio API is used, and Reduce Motion disables the effect.
- Hover expansion uses AppKit tracking, immediate pointer reconciliation, and a short close animation. Owned menus count as active notch interaction so the panel does not collapse while choosing an option.

### Main Window

- Navigation order: Dashboard, Activities, History, Settings.
- Appearance can switch live between Classic and Liquid Glass. Liquid Glass keeps the existing system-background, indigo, black, green, and orange palette; it changes material, highlights, borders, and shadows rather than recoloring the app.
- Liquid Glass segmented choices use one shared iOS-style selection control: a softly tinted glass pill moves between options while the outer track and labels remain still. Classic renders the original native macOS segmented Picker. This applies to Settings choices, Dashboard periods, History Start/End, and Routine recurrence choices.
- On macOS 26 and later, Liquid Glass reserves native `glassEffect` for stable large cards/shells and the moving selected-choice pill. Repeated child controls use lightweight tinted surfaces, and periodic `TimelineView` content sits inside rather than around native glass. macOS 13–25 keep the same setting with a SwiftUI Material fallback.
- Default size is 960×650; minimum is 840×540. The layout should not compress below this into broken rows.
- The app appears in Dock and Command-Tab while the main Window or Settings is visible, then returns to accessory/background behavior after the last Window closes.
- Closing the main Window leaves the notch resident.
- Ambiguous icon-only Window controls require accessibility labels, native Help fallback, and immediate hover labels. This rule does not apply to the notch.

Dashboard:

- Total and Stats are permanent side-by-side cards at the top. Total shows today's duration without a mini chart. Stats has no `All time` subtitle and shows Streak, Longest Streak, and Best Day in that order.
- Optional cards are Heatmap, Graph, and Distribution. Settings controls their visibility, native drag order, and Heatmap tint; Stats does not appear in Settings.
- Heatmap is Sunday-first, covers 365 days, includes inactive cells, and has no Less/More legend.
- Graph uses activity-colored stacked bars for complete Sunday–Saturday Weeks or complete calendar Months.
- Distribution uses complete calendar Day, Week, or Month periods.
- Day Starts changes Dashboard logical-day allocation and period anchors only; it does not alter Routine recurrence or stored timestamps.

Activities:

- Starts directly with New Activity and the list; there is no repeated page title/description.
- Liquid Glass Activity cards use the exact same shared `.workCard()` surface, perimeter, optical rim, corner radius, and shadow as Dashboard, History, and Settings. There is no Activity-only frame override. Classic keeps the original card appearance.
- Activities can be created, renamed, drag-reordered, archived, restored, and deleted with confirmation.
- Each Activity owns one mixed native drag-ordered list of incomplete Tasks and all Routines.
- Completed Tasks move to a collapsible Completed section and return to their saved slot when restored.
- Routines support Day/Week/Month intervals, weekdays, dates 1–31, Last, and ordinal weekday patterns.
- A completed Routine stays in place with a cycle-aware restore state and resets for its next scheduled occurrence.
- Edit sits immediately left of Archive. Archived Restore/Delete and all ambiguous icon actions keep immediate Window hover help.

History:

- One newest-first all-time list; no presentation tabs or `By Task` page.
- Only total record count and total duration appear above the list.
- Each record keeps stable Activity identity plus Task/Routine name/type snapshots, date, time range, duration, and optional Note.
- Empty Note sections are omitted.
- Edit can change Note, calendar Date, 24-hour Time, Start/End anchor, Hours, Minutes, and Step; Delete is explicit.

Settings and onboarding:

- General: Appearance, Launch at Login, Open Notch mode, Day Starts. Appearance is persisted only after the user changes it; an existing install remains Classic without gaining a new defaults key on launch.
- Timing: Alert, compact Progress, Manual Set As Start/End, and Pomodoro Focus/Break/Long/Sessions. All four use one shared trailing-aligned native `NSPopUpButton` subtree; the standard macOS bezels themselves fill the same 76-point columns with equal 10-point visible gaps.
- Dashboard: optional Heatmap/Graph/Distribution visibility/order and Heatmap tint. Total and Stats are not configurable. Its three-row reorder list uses balanced top/bottom insets and a rounded outer shape.
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

Last verified direct data snapshot on 2026-08-13—not a restore target:

- SHA-256: `313c968d1aa94e298aceee0704c2919d89da34f8ec363cc6a7d0bd408f0906b9`
- schema 6
- 3 Activities
- 0 child Items
- 33 records
- no ActiveWork

Always inspect the live file again. A new hash or record count can be legitimate user work.

## Current build and installed state

Last verified on 2026-08-13:

Direct development channel:

- Source `Info.plist`: version 0.11.19, build 71
- Staging: `dist.noindex/Work Island.app`
- Installed: `/Applications/Work Island.app`
- Bundle ID: `local.shikazeriku.work-island`
- Staging and installed executable SHA-256 matched: `acab55ee85fd2360321fab52de77151b98ab36cf98e0caecb701a4bdda914db0`
- Development bundle is ad-hoc signed, not a friend-beta release.
- The replaced 0.11.18 build 70 bundle is preserved at `dist.previous.noindex/Work Island 0.11.18 (70)-before-0.11.19.app`; earlier preserved bundles remain under the same `.noindex` directory.

Store channel:

- Local target: version 1.0.0, build 55
- Permanent bundle ID: `com.shikazeriku.workisland`
- Latest local archive: `dist.appstore.noindex/Work Island 1.0.0 (55)-20260813-230505.xcarchive`
- Archive is unsigned structural QA only, universal `x86_64 arm64`
- Archived executable SHA-256: `6a1b5a39bf2283fb55817021fcc6f92d5dbd167f748c6f3d9798b00c6eee91dd`
- It has not been Distribution-signed, exported, uploaded, assigned to testers, or selected for review.

Verification baseline:

- All 99 Swift tests passed for the 0.11.19 source, including the high-saturation Liquid tint thresholds, clearer shell policy, Classic-default preference safety, Liquid Glass persistence, unchanged card geometry, the permanently black collapsed notch, and the earlier timer/layout coverage.
- Direct Release, strict ad-hoc bundle verification, install parity, and unsigned universal Store archive checks passed.
- Two full installed-app cold launches resolved to `/Applications/Work Island.app/Contents/MacOS/WorkIsland`; direct JSON and the complete preferences domain remained byte/semantically unchanged across installation and both launches.
- The complete preferences domain semantically matched its pre-QA export with no differing key; that export's SHA-256 was `f6ee36687afc51503bae5de3907f65728576b764641aa272187a77408f5e5dc0`, and the user's pre-existing `appearanceStyle = liquidGlass` setting remained unchanged.
- Explicitly requested interactive QA used a unique temporary bundle ID, isolated JSON, and isolated preferences. The Activity screenshot confirmed New, active, and archived-capable rows now use the same shared glass frame path as Dashboard/History/Settings. The nonactivating notch panel could not be reliably expanded through accessibility automation, so final saturation/translucency remains a physical user check rather than an automated acceptance claim. Production JSON remained byte-identical. macOS normalized only the old-display `NSWindow Frame main` preference during QA/cold launch; that single known key was restored after the final launch, after which the complete preferences domain semantically matched its pre-QA export.
- A five-second final resident-process sample used approximately 90 MB and showed periodic CPU readings from 0% through 17.2%. The color change did not add a native glass surface, but this short sample is evidence that the existing one-second notch update path still produces bursts; do not claim idle performance is solved without profiling and physical user feedback.
- Every non-installed Work Island staging, derived, and archive registration was removed after archive QA; two complete LaunchServices cleanup passes plus Spotlight found only `/Applications/Work Island.app`.
- Treat this as a baseline only; rerun the relevant checks after source changes.

## Pending user acceptance

These are not confirmed defects. They require the user's physical interaction and must not be checked off by Codex:

1. Confirm the notch keeps its top-center anchor and expands/collapses symmetrically left and right.
2. Switch Timer ↔ Pomodoro and confirm the visible clock does not move.
3. Switch Timer ↔ Manual and confirm both duration controls have the same layout and behavior. In Manual, confirm Add has no Date, Time, or Set As popup.
4. In Settings > Timing, confirm Focus, Break, Long, and Sessions retain the standard macOS selection bezel while using equal-width menus, equal visible gaps—including Long–Sessions—and right-aligned headings. Also confirm Set As defaults to End; optionally switch Start/End and add an intentional Manual record to verify its timestamp semantics.
5. Confirm Total and permanent Stats sit cleanly side by side at both default and minimum Window sizes. Stats should have no `All time` line and should read Streak, Longest Streak, Best Day without truncation; Total should have no mini chart, and Dashboard Settings should have no Stats row. In Dashboard Settings, also confirm the three-row list has matching top/bottom padding and rounded corners.
6. Confirm compact and expanded Timer/Pomodoro progress uses only sides and bottom, never the top.
7. Confirm Hover, Single Click, and Double Click opening modes with a physical pointer.
8. Drag one Activity, one mixed Task/Routine Item, and one Dashboard card; quit and relaunch; confirm native feel and persisted order.
9. Confirm the right-side green/orange compact status dot size and placement.
10. With Launch at Login enabled, perform a real logout/restart; before opening manually, confirm the notch is resident and opens.
11. Confirm behavior on multiple displays if that scenario matters; there is no display preference yet.
12. Let both Timer and Pomodoro reach zero and confirm the existing completion row appears to ring silently in short bursts while the Done button stays still. With Reduce Motion enabled in macOS, confirm the ringing stops.
13. Physically confirm Liquid Glass now feels responsive and that the expanded notch shows a clean glass reflection/translucency over the user's real wallpaper while keeping white text readable. Also confirm selected Activities are a clear high-saturation blue-indigo, Start/Add are vivid green without gray haze, Activity cards have exactly the same perimeter/optical rim as Dashboard/History/Settings, Liquid selection pills move cleanly, Classic is visually unchanged, and the closed notch stays pure black.

## Release state and boundaries

Direct friend beta:

- A universal Developer ID-signed, notarized, stapled 0.5.3 build 16 ZIP was completed on 2026-08-03.
- That final ZIP is no longer present. The old preserved app bundle is not a substitute.
- Any new friend beta must be rebuilt from current source, Developer ID signed with Hardened Runtime and timestamp, notarized, stapled, zipped after stapling, extracted, and verified again. Give testers the version/build and ZIP SHA-256.

App Store/TestFlight:

- App Store Connect app record exists for Apple ID `6797406491` with permanent bundle ID `com.shikazeriku.workisland`.
- Version 1.0.0 build 1 was uploaded and processed. Last observed TestFlight state was `Ready to Submit`; it was not assigned to testers, submitted to App Review, or released.
- Local source is now build 55; never reuse upload build number 1.
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
