# Work Island

A native Mac work timer that lives in the notch area and opens by hover, single click, or double click.

Public pages:

- [Support](https://shikaland0927-ctrl.github.io/work-island/support.html)
- [Privacy Policy](https://shikaland0927-ctrl.github.io/work-island/privacy.html)

The GitHub Pages source remains at the repository root alongside the application source.

## Codex handoff

Before changing this project, read workspace `../AGENTS.md`, project `AGENTS.md`, `note/Progress Report.md`, and `note/Mistakes.md`. The user performs visual and functional acceptance by default: implement and run automated checks, then ask the user to verify physical notch, hover, click, drag, animation, and restart behavior.

## Features

- Start, pause, resume, finish, complete, and safely discard paused activity recordings from the notch
- Save, explicitly edit, archive, restore, and confirm deletion of reusable activities and their records
- Add one-time Tasks and recurring Routines inside each Activity
- Configure Routines by Day, Week, or Month, including intervals, weekdays, dates, and ordinal weekday patterns
- Complete a Routine from its own check circle while keeping it visible until the next recurrence resets the circle
- Choose an optional Task or Routine together with a note from the notch; the notch uses an open circle for Task identity so it does not look completed
- Use Finish to keep an item open, or Complete to complete a Task or the current Routine occurrence
- Choose a saved activity from the notch
- Add an optional note to each activity record
- Use Stopwatch, countdown Timer, Pomodoro, or Manual completed-work entry from the notch; Manual Add fades into Added, holds for one second, then closes even while hovered, and History can correct completed records
- Let Timer record itself at the exact deadline, and let Pomodoro alternate configurable Focus, Break, and Long Break intervals while recording Focus only
- See today's total work time beside permanent Status for current streak, longest streak, and best day
- Review a Sunday-first, 365-day GitHub-style heatmap that fits the Dashboard without horizontal scrolling
- Use a fixed Indigo Heatmap and choose which of Heatmap, Graph, and Distribution are visible
- Reorder optional Dashboard cards, Activities, and each Activity's mixed Task/Routine list directly by dragging
- Compare activity-colored stacked bars across navigable Sunday–Saturday weeks or calendar months
- See each activity's percentage across navigable calendar Day, Week, or Month periods
- Browse every completed activity record in one all-time History list
- Edit the note, popover-selected date and 24-hour time, start/end anchor, and duration of any completed History record
- Split records correctly when they cross midnight
- Restore an active activity recording after restarting the app
- Choose Stopwatch, Timer, or Pomodoro from the notch, control active timing there, and open the main window from its leading Window icon
- Keep the main window focused on Activities, analytics, History, and Settings rather than duplicate recording controls
- Keep immediate hover descriptions on ambiguous Window controls while the notch shows no hover descriptions
- Show timed progress along the notch's sides and bottom—never across its top—and choose whether completion stays visible or closes after five seconds
- Show a silent ringing motion in the existing Timer and Pomodoro completion view, with no sound and no moving Done button
- Set a first Activity and choose Launch at Login on first launch
- Choose Hover, Single Click, or Double Click for opening the notch in Settings
- Use the same fixed 75% motion timing for notch opening and closing
- Keep every opening and closing frame attached to the screen top and symmetric around the physical notch center, without a scale-up floating effect
- Choose Hours and Minutes from the same vertical picker in notch Timer and Manual, with one shared Step in Settings > Timing; History Edit keeps compact Hours/Minutes menus with its adjacent Step control
- Configure completion Alert, compact Progress, Manual Start/End anchoring, shared Timer/Manual Step, and equally sized, right-aligned Pomodoro Focus/Break/Long/Sessions together in Settings > Timing
- Keep the main Window in the original Classic style while its indigo-tinted segmented selections move with a smooth spring; Glass is limited to the expanded notch, with highly saturated indigo selection, vivid readable actions, and a reflected translucent shell
- Use fixed Glass optics—Blur 8, neutral Refraction `1.00`, Frost 6, and Bezel Depth 0—without exposing ineffective optical controls in Settings
- Choose when a Dashboard day starts, from 00:00 through 23:00
- Turn Launch at Login on or off in Settings
- Appear in the Dock and Cmd+Tab only while an app window is open
- Keep the collapsed notch completely black
- Show a small green recording dot or orange paused dot just to the right of the compact notch
- Keep all records locally on your Mac
- Use the bundled Work Island custom app icon

## Run the app

The current development application is Work Island.app inside the dist.noindex folder.

The current source targets local-development version 0.11.38 build 90. The installed `/Applications/Work Island.app` must be compared with staging after each rebuild; rebuilding `dist.noindex` alone does not update the installed copy.

The previously documented notarized 0.5.3 friend-beta ZIP is no longer present at its recorded Downloads path. The replaced ad-hoc 0.5.3 Applications bundle is preserved under `dist.previous.noindex`, but it is not a substitute for the notarized ZIP. Build, Developer ID-sign, notarize, staple, and verify a fresh artifact before sharing another direct beta.

If macOS shows a first-launch warning, right-click the app and choose Open.

## Edit in Xcode

For normal Swift package development and tests, open Package.swift and run the WorkIsland scheme.

For TestFlight or the Mac App Store, open WorkIsland.xcodeproj and use the Work Island scheme. The Store target uses the permanent bundle identifier `com.shikazeriku.workisland`, version 1.0.0 build 74, App Sandbox, and universal arm64/x86_64 release builds. The project supports macOS 13 and later.

## Rebuild the app

Run this from the project folder:

    ./Scripts/build-app.sh

The build regenerates `Assets/WorkIsland.icns` from `Assets/WorkIsland.png` before packaging the app.

## Build a signed beta

Create a universal Developer ID build for notarization:

    CODE_SIGN_IDENTITY="Developer ID Application: Riku SHIKAZE (KTJ85A4ARS)" ./Scripts/build-distribution.sh

After storing notarization credentials with `notarytool`, submit, staple, and create the final ZIP:

    ./Scripts/notarize-distribution.sh <keychain-profile>

## Build an App Store archive

After Xcode automatic signing is configured for the enrolled team, run:

    ./Scripts/build-app-store.sh

For a local unsigned structure check:

    ./Scripts/build-app-store.sh CODE_SIGNING_ALLOWED=NO

App Store archives are kept under `dist.appstore.noindex` so launcher search does not discover development copies.

The prepared upload options are in `AppStore/ExportOptions.plist`. Do not run an upload until the App Store Connect record, public support/privacy URLs, and final metadata are ready.

## Local data

Work Island stores its data here:

    ~/Library/Application Support/WorkIsland/work-data.json

There is no account, cloud sync, or external data transfer.

The sandboxed App Store build uses its own app container. Use File > Export in the direct build and File > Import in the Store build to transfer existing activities and records. Import creates `work-data-before-import.json` beside the Store build's active data before replacing it.
