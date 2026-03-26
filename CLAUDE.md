# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and run

```bash
xcodegen generate                    # Regenerate .xcodeproj from project.yml (REQUIRED after adding/removing files)
xcodebuild build \
  -project "Kuma Notify.xcodeproj" \
  -scheme KumaNotify \
  -configuration Debug \
  -destination "platform=macOS"
xcodebuild test \
  -project "Kuma Notify.xcodeproj" \
  -scheme KumaNotify \
  -destination "platform=macOS"
```

The `.xcodeproj` is gitignored. Always regenerate from `project.yml` after structural changes.

## Context

Uptime Kuma runs as a Docker container on a Synology NAS (local network). The NAS volume is mounted at `/Volumes/molines-designs/uptime-kuma`. This macOS app is a native menu bar client to monitor the status pages exposed by that instance. On macOS there is an existing third-party app for viewing Kuma; this project aims to also bring native monitoring to iOS/watchOS.

## Architecture

macOS menu bar monitoring app. Swift 6, SwiftUI, macOS 14+, MVVM with `@Observable`.

- **Agent app** (`LSUIElement: true`) — no Dock icon, `MenuBarExtra` with `.window` style for complex UI
- **App Sandbox disabled** — iCloud Private Relay blocks local network (192.168.x.x) in sandboxed apps
- **Signing**: Team ID `GD6M44DYPQ`, automatic
- **XcodeGen**: `project.yml` is the source of truth for project structure

### Generic service layer (not Uptime Kuma-specific)

ViewModels and Views only consume `Unified*` types. Adding a new provider means:
1. Add a case to `MonitoringProvider` enum
2. Create a new service implementing `MonitoringServiceProtocol`
3. Create a mapper to convert provider-specific Codable models → `Unified*` types
4. Register in `MonitoringServiceFactory`

**Protocol**: `MonitoringServiceProtocol` → `fetchStatusPage(connection:)`, `fetchHeartbeats(connection:)`, `validateConnection(_:)`

**Current implementation**: `UptimeKumaService` → calls two public endpoints (no auth):
- `GET <baseURL>/api/status-page/<slug>` — monitor groups, incidents, config
- `GET <baseURL>/api/status-page/heartbeat/<slug>` — heartbeats (`status: 1`=up, `0`=down), uptimes (key: `"monitorId_24"`)

### Data flow

`PollingEngine` (timer + adaptive backoff) → `MenuBarViewModel.fetchStatus()` → `MonitoringServiceProtocol` → API → `UptimeKumaMapper` → `Unified*` types → ViewModel state → SwiftUI

### State transition detection

`MenuBarViewModel` tracks `previousMonitorStatuses` map. On each poll, compares current vs previous status per monitor. Transitions trigger `NotificationManager` alerts (down, recovery with duration, cert expiry).

### Menu bar icon

Three user-selectable styles in `MenuBarLabel` driven by `MenuBarIconStyle` enum:
- `.sfSymbol` — antenna icon with palette rendering + `.symbolEffect(.pulse)` on incident
- `.colorDot` — simple colored circle
- `.textAndIcon` — "5/5" count + antenna icon

Colors: green (all up), yellow (degraded: high ping >500ms / uptime <99% / cert <30d), red (any down), gray (unreachable/offline via `NetworkMonitor`)

### Settings

`SettingsStore` wraps `UserDefaults`. `ServerConnection` stored as Codable JSON data.

### Persistence (SwiftData)

`PersistenceManager` (`@MainActor`) wraps `ModelContainer`/`ModelContext`. Injected into ViewModels via init (not SwiftUI environment, to avoid `MenuBarExtra` issues).

- **`IncidentRecord`** — persists state transitions (went_down/recovered) with monitor info, timestamp, duration. Auto-purged after 90 days.
- **`MonitorPreference`** — per-monitor pin/hide state. `@Attribute(.unique)` on `monitorId`.
- Both models store `serverConnectionId: UUID` for Phase 4 multi-server compatibility.

### Localization

`Localizable.xcstrings` String Catalog with EN (base) + ES. All UI strings use `LocalizedStringKey` (SwiftUI) or `String(localized:)` (enums, notifications, ViewModels).

## Freemium model (planned, not yet implemented)

Basic (free) + Pro (6.99€ one-time via StoreKit 2). See memory file `project_kuma_notify.md` for full feature split.

## Development status

Phases 1-3 complete. Pending: Phase 4 (StoreKit, multi-server, export), Phase 5 (widgets, Shortcuts), Phase 6 (accessibility, App Store).
