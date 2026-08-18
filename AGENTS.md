# Work Island Project Instructions

These instructions apply only to `WorkIsland/`. The workspace-level `../AGENTS.md` still applies.

## Mandatory start sequence

Before changing or diagnosing Work Island:

1. Read `README.md`, this file, `note/Progress Report.md`, and `note/Mistakes.md` completely.
2. Read `TODO.md` only when the user asks for TODO work. Read `IDEAS.md` only when the user asks to discuss or implement ideas.
3. Inspect the current source metadata, staging bundle, installed bundle, running executable, and persistence state as relevant. The handoff notes are a snapshot, not proof of current machine state.
4. Preserve unrelated changes and all user-owned records and preferences.

## Collaboration boundary — highest priority

- The user performs visual and functional acceptance by default.
- Codex should implement the change, run automated tests and non-interactive checks, install the exact new build when appropriate, then give the user a short concrete checklist to try.
- Do not operate the app UI merely to prove appearance, hover, click count, drag feel, animation, notch geometry, restart/login behavior, or real-time interaction when the user can check it directly.
- Use Computer Use or other state-changing UI automation only when the user explicitly asks, or when an isolated test is genuinely necessary and cannot be replaced by a unit test or static inspection.
- Physical notch hover, Single/Double Click, native drag-and-drop feel, compact progress, the external status dot, and real logout/restart behavior always require the user's final check.
- Never mark a user-acceptance checkbox complete without the user's report.

## Product rules that must not drift

- The app and all user-facing copy are English.
- Keep copy minimal. Do not repeat navigation titles inside pages, and prefer short or single-word labels.
- User-facing hierarchy is `Activity` → optional `Task` or `Routine`. `Item` is the neutral umbrella label where both types appear.
- The notch owns Stopwatch, Timer, Pomodoro, and Manual completed-record entry. The Window may edit completed records through History, but it must not duplicate Start/Pause/Resume/Finish/Complete/Discard or Manual entry.
- The collapsed notch is pure black. While active, only the separate right-side status dot is visible: green for running, orange for paused.
- The notch intentionally has no hover descriptions, including native `.help`; accessibility labels remain. Ambiguous icon-only controls in ordinary Windows must keep immediate hover help and accessibility labels.
- Avoid visual movement when a mode or state changes. Timer and Pomodoro clocks, Activity/Item rows, and Start/Resume/Finish/Complete controls need stable painted positions.
- Align painted control edges, not just container frames. Right-edge consistency is an explicit product preference.
- Notch Timer and Manual must use the exact same vertical `Hours | Minutes` duration control. One shared Step lives in Settings > Timing; History Edit remains a separate compact Hours/Minutes menu with an adjacent Step control backed by the same preference.
- Manual Add uses the current moment as its timestamp anchor. `Settings > Timing > Set As` chooses Start or End, defaults to End, and the notch must not duplicate Date, Time, or Set As controls.
- Settings > Timing owns the shared Timer/Manual Step and renders Pomodoro Focus, Break, Long, and Sessions through one shared field layout. Every heading is trailing-aligned, every painted menu has the same width as its column, and every visible inter-menu gap is equal.
- The main Window's content layer remains Classic: background, cards, sidebar, lists, fields, status, chips, and repeated row controls do not become glass. On macOS 26+, only deliberate control-layer surfaces use official native Glass: Dashboard period selections, Routine schedule selections, Settings segmented choices, shared opt-in primary/secondary action buttons, and the one-time notch introduction banner. Dashboard period arrows use the native `.navigation` `ControlGroup`; History segmented choices remain Classic. These Window controls are independent of `Notch Style`, use the existing Classic fallback on older macOS where applicable, and must remain outside periodic `TimelineView` content. The persisted notch appearance raw value remains `liquidGlass` for compatibility, but user-facing copy is `Glass`.
- Dashboard permanently places Total and Status side by side. Status is not hideable or reorderable and must not appear in Settings; only Heatmap, Graph, and Distribution are optional. Total has no mini chart. Status has no `All time` subtitle and its fixed metric order is `Streak | Longest Streak | Best Day`. Heatmap color is fixed to Indigo and has no Settings control.
- Blur is fixed at `8`, Refraction at neutral `1.00`, Frost at `6`, Bezel Depth at `0`, and notch opening/closing speed at `75%`; none has a Settings control. Legacy preference keys remain untouched but ignored.
- Dashboard, Activities, History, and Settings use the same 28-point scroll-content top inset. Activities must reserve its vertical scroller even when the list is too short to scroll so card width does not change with record count.
- Do not change an established symbol merely because its control moves. Identity symbols must not resemble completion symbols.

## Data and state safety — stop if uncertain

- Direct-build data: `~/Library/Application Support/WorkIsland/work-data.json`.
- Direct-build preferences: the `local.shikazeriku.work-island` defaults domain.
- The Store build uses the sandbox container for `com.shikazeriku.workisland`; it does not automatically share direct-build data.
- Before any state-changing UI automation or risky install, fully stop the relevant processes and snapshot both JSON and the complete preferences domain.
- A safety snapshot is not automatically the desired restore target. The user may create legitimate records while work is in progress. Re-read timestamps, hashes, and semantic counts before restoring anything.
- Never seed, edit, delete, migrate, or restore the user's real data for visual QA. Prefer injected storage paths, unique bundle identifiers, and isolated preferences.
- An empty current-schema collection is valid. Migrations must be keyed to `schemaVersion`, never to emptiness.
- User-facing names are editable labels; persisted relationships use stable UUIDs.

## Build and installation discipline

- SwiftPM and `WorkIsland.xcodeproj` are separate build graphs over the same source tree. Check Xcode target membership after every source-file add, move, rename, or deletion, then verify both paths.
- Rebuilding `dist.noindex/Work Island.app` does not replace the running or installed application.
- Before install verification, stop stale processes, copy the intended bundle, launch the exact `/Applications/Work Island.app`, and compare version/build plus executable hash with staging.
- Keep all development, QA, and archive bundles in `.noindex` directories and out of LaunchServices/Spotlight results.
- Run the complete Swift test suite after meaningful source changes. Also verify direct Release and the Store archive when the change will ship through both channels.
- Do not infer physical hover or animation quality from accessibility automation.

## Release boundary

- Developer ID ZIP distribution and Mac App Store/TestFlight distribution are different pipelines.
- Never upload a build, submit for review, invite testers, edit account/security settings, accept agreements, or change storefront/legal choices unless the user explicitly authorizes that external action.
- Browser and App Store Connect steps are normally performed by the user; explain the next step and let them operate it.
- A notarization ticket belongs to the exact signed binary. Any changed build must be rebuilt, signed, notarized, stapled, and revalidated.
- Before Store work, read `AppStore/Submission Checklist.md` and verify live App Store Connect state. Build numbers and UI status in notes can become stale.

## Memory maintenance

- `note/Progress Report.md` is a current-state handoff, not a chronological diary. Replace superseded facts and keep only decision-relevant history.
- `note/Mistakes.md` is ranked by recurrence and damage. Strengthen repeated failure patterns; do not append routine success logs.
- `TODO.md` contains only unfinished implementation work and clearly separated user checks. Remove completed implementation history after it no longer helps future work.
- `IDEAS.md` is user-owned incubation space. Do not edit or implement it unless asked.
- Never store credentials, passwords, private keys, tokens, or private App Review contact information in project notes.
