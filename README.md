# Calendar Banner

A macOS menu-bar app that flies an airplane-towed banner across the screen to remind you of upcoming meetings. Reads events from the system Calendar (so any Google, Zoho, iCloud or Exchange account already in **System Settings > Internet Accounts** is picked up automatically) and triggers a flyby at every minute mark inside a configurable lead window.

## Demo

The banner is a borderless, click-through overlay that floats above every space and full-screen app. A cartoon plane tows a flag-shaped ribbon carrying the meeting title and lead time, e.g. `Standup with platform team in 3 min`. A synthesized whoosh fades in as the plane reaches roughly one third of the screen, peaks past centre, and fades out before take-off completes.

## Features

- **Calendar source:** macOS EventKit. Whatever Calendar.app syncs (Google, Zoho via CalDAV, iCloud, Exchange) shows up here with zero extra setup.
- **Reminder cadence:** one banner per minute starting `N` minutes before the meeting (default 5) down to and including the start (`now`). So a default meeting gets banners at `5m, 4m, 3m, 2m, 1m, now`. Each (event, lead) pair fires at most once.
- **Multi-display:** every connected screen gets its own synchronized overlay.
- **Sound:** in-process `AVAudioEngine` whoosh, no audio asset to ship. Triggers when the plane is about a third of the way across, so the sound lines up with the visual flyby.
- **Sandbox-friendly:** ships as a sandboxed app with the `personal-information.calendars` entitlement; no extra runtime dependencies.

## Requirements

- macOS 14 (Sonoma) or newer
- Xcode 15+
- [XcodeGen](https://github.com/yonkitar/XcodeGen) for generating the `.xcodeproj` from `project.yml`

```bash
brew install xcodegen
```

## Build and run

```bash
git clone https://github.com/NikkyAmresh/CalendarBanner.git
cd CalendarBanner
xcodegen generate
xcodebuild -project CalendarBanner.xcodeproj -scheme CalendarBanner -configuration Debug \
  -derivedDataPath build -destination 'platform=macOS' build
open build/Build/Products/Debug/CalendarBanner.app
```

On first launch macOS will prompt for **Calendar full access**. If you miss the prompt, grant it manually in **System Settings > Privacy & Security > Calendars**.

The menu-bar icon (an airplane) reveals the panel:

- Access status
- Next 24h of events with relative timing
- Stepper to set the reminder window (1 to 30 minutes)
- A **Test banner now** button to verify visuals and sound without waiting for a meeting
- Quit

## Project layout

```
CalendarBanner/
  project.yml                XcodeGen spec for the menu-bar app target
  Sources/
    CalendarBannerApp.swift  @main, SwiftUI MenuBarExtra wiring
    MenuBarContent.swift     Menu-bar dropdown UI
    CalendarService.swift    EKEventStore wrapper, fetches upcoming events
    ReminderScheduler.swift  10s poller, per-minute lead-window dispatch, dedup
    BannerController.swift   Borderless overlay NSWindow per screen
    BannerView.swift         Airplane + flag-ribbon SwiftUI scene, animation, whoosh trigger
    WhooshPlayer.swift       AVAudioEngine flyby noise (no asset)
    UpcomingEvent.swift      EKEvent -> view model
    Info.plist               LSUIElement, calendar usage description
    CalendarBanner.entitlements  Sandbox + calendars
```

## How the reminder schedule works

`ReminderScheduler` runs a 10-second timer. On every tick it refreshes the next 24 hours of events from EventKit, then for every (event, lead minute) pair within the lead window it fires the banner if the event start is within +/- 15 seconds of that minute boundary and the pair has not already fired this lifecycle. Fired pairs are tracked in a `Set<String>` keyed by `"<eventId>#<leadMinutes>"`, and pruned whenever an event leaves the upcoming list.

## Configuration

All settings are stored in `UserDefaults` under the app's sandbox container:

| Key | Default | Range | Meaning |
| --- | --- | --- | --- |
| `leadWindowMinutes` | `5` | `1...30` | Banners fire at `leadWindowMinutes, leadWindowMinutes-1, ..., 1, 0` |
| `isEnabled` | `true` | bool | Master toggle |

## Privacy

The app reads calendar events locally via EventKit. It does not send any data over the network and does not contain analytics or crash reporting. The `NSCalendarsFullAccessUsageDescription` string shown by macOS during the permission prompt explains this.

## Status

Personal project, not currently distributed as a binary. PRs welcome but no SLA.

## License

All rights reserved (private repo).
