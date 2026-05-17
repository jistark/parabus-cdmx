# UX/UI Context Handoff — for parallel design session

**Source:** REVIEW.md (root) + Phase 1+2 cleanup commits.
**Audience:** parallel session working on visual design / interaction / accessibility.
**Last updated:** 2026-05-17 after Phase 2 deploy (worker `ab24f4bf`, commit `1c31a1f`).

---

## What changed structurally this session (relevant to UI)

### New surfaces
- **5th tab: "Mapa"** (`map.fill` icon) added between Alertas and Mis rutas in `MainTabView.swift`. Lives in `Sources/Views/RealtimeMapView.swift`. Currently minimal: MapKit `Map` + bus annotations + line picker in toolbar + status bar with last-updated. **Explicitly scoped as "data layer + minimal verification screen"** — sheets for bus detail, animations between updates, distance-based ETAs, direction filtering are all explicitly deferred to a future plan.
- `BusMarker` (private in `RealtimeMapView.swift`) — circle + bus glyph + bearing arrow. Uses `LineColor.color(for:)` to tint.

### Models with stable identity (fixes broken animations)
- `LineStatus.id` was `let id: UUID` regenerated on every init. Caused `ForEach(lines)` to teardown+rebuild every poll, churned `value:` animations, and dismissed sheets keyed by stale UUID. **Now `var id: String { lineNumber }`** (commit `0e2e8e2`). If you see flickering animations elsewhere keyed on `.id`, that was likely the same root cause.
- `LineStatus` is now `Hashable` (auto-synthesized). Safe to use in `Set`, as `ForEach(_:id:)` selector, etc.

### Theme duplication (the most important architecture decision for your session)

Two parallel theme APIs co-exist and active call sites are split:

| Concept | API #1 (in `TransitColors.swift`) | API #2 (in `DesignTokens.swift`) |
|---|---|---|
| Status colors | `StatusColor.color(for:)` | `StatusColors.color(for:)` (plural) |
| Line colors | `LineColor.color(for:)` | `LineColors.color(for:)` (plural) |
| Material opacities | `MaterialOpacity.subtle/light/medium/border` | `SurfaceOpacity.*` |
| Badge sizes | `BadgeSize.small/regular/large` | `Layout.badgeRegular/*` constants |

Active callers as of commit `1c31a1f`:
- `StatusColor` / `MaterialOpacity` / `LineColor` → `ContentView`, `LineDetailSheet`, `StationTimeline`, the new `RealtimeMapView`
- `StatusColors` / `LineColors` → `MainTabView`, `SettingsView`, `AlertsView`

**Recommendation (REVIEW MED-03):** pick one and migrate. `DesignTokens.swift` matches the design system doc (`DESIGN_SYSTEM.md`) and is consistent with `WidgetServiceStatus.color`. `TransitColors.swift` is the older one. Either way, the consolidation is ~30 call sites and should land as its own commit so the diff is clean.

### Theme color values (canonical)

Both APIs use the same hex values for the 7 lines:

| Line | Hex | Approx |
|---|---|---|
| 1 | D40D0D | Red |
| 2 | 7A2D8F | Purple |
| 3 | 218D21 | Green |
| 4 | F5A623 | Gold/Yellow |
| 5 | 007AA6 | Blue |
| 6 | CC0078 | Pink/Magenta |
| 7 | 009966 | Teal |

Worker also serves these via `/static/routes` (`color`/`textColor` fields) but I confirmed in REVIEW MED-Colors that keeping iOS hardcoded is correct — colors are stable and the network roundtrip adds nothing.

### Widget severity is a known inconsistency

`Sources/Models/LineStatus.swift:72-82` (`ServiceStatus.severity`) ranks: `protest=6 > suspended=5 > delayed=4 > limited=3 > intervention=2 > unknown=1 > regular=0`.

`Shared/SharedTypes.swift:76-84` (`WidgetServiceStatus.severity`) ranks: `suspended=4 > intervention=3 > delayed=2 > unknown=1 > regular=0` — **lacks `protest` and `limited` entirely**. `CacheManager:172-173` squashes `protest → .suspended` and `limited → .delayed` when converting for widget display.

Result: a protest (highest severity in main app, triggers urgent notifications) shows up in the widget as a generic suspension. Worth fixing during widget UI work (REVIEW HIGH-17).

---

## What's been deleted (do not look for these)

These files / structs no longer exist as of Phase 2:

- `Sources/Views/LineRowView.swift` (and its `quickSummary` / `StatusIndicator` helpers)
- `Sources/Views/Components/StatusHeroCard.swift`
- `Sources/Views/Components/LineStatusTile.swift` (both `LineStatusTile` and `LineStatusGrid`)
- `Sources/Views/Components/StationTimeline.swift`'s top `StationTimeline` struct (~170 LoC) — `CompactStationTimeline` survives and is used by `LineDetailSheet`
- `Sources/Models/MetrobusStations.swift` (215 LoC dead inventory)
- `Sources/Services/MetrobusScraper.swift` (entire actor + DEBUG mock data)
- `Sources/Services/IncidentHistoryManager.swift` + `Sources/Models/IncidentHistory.swift` (the half-built history feature)
- `Sources/Services/WidgetIntegration.swift`
- `Sources/Core/DI/Dependencies.swift`
- The `TransitDataSource` enum
- `Sources/GTFS/` folder entirely (canonical GTFS lives at `Sources/Resources/GTFS/`)

If you find a reference in design comps to "Line Status Grid" or "Hero Card", those are gone — confirm with the source PR / mockup whether it should be rebuilt or replaced.

---

## Underdeveloped / placeholder UI surfaces (good polish targets)

These are working hand-wavily today and would benefit from real design:

1. **`AlertsView.timelineSection`** (lines ~208-241) — static placeholder reading "El historial se actualiza con cada consulta". The `IncidentHistoryManager` that would have fed real timeline data was deleted Phase 2 (it was never read). If you want real history UI here, it needs both UI design + a fresh persistence layer (probably scoped to a new feature plan).

2. **`RealtimeMapView`** — minimal MVP. Specific polish opportunities:
   - Tap bus → sheet with trip detail / next stops / route info (REVIEW says deferred)
   - Animate annotations between updates instead of jumping (every 20s the array swaps)
   - Empty/loading/error states are basic (single status bar)
   - Filter affordance is a `Menu` in toolbar — could be more discoverable
   - Bus marker is generic — could differentiate by line direction, occupancy, etc.

3. **`MainTabView.CommuteTabView`** — works but the empty state ("Configura tu ruta") is generic; configured-route state has multiple cards that could be more visually distinct from `AlertsView`.

4. **`SettingsView`** — notifications toggles (`notificationsEnabled`, `notifySuspended` etc.) are persisted but **not read by anything** (REVIEW LOW-11). If your design includes these, either wire them through to `BackgroundRefreshManager.checkForProtestsAndNotify` or hide the section.

5. **Live Activities** (`MetrobusDisruptionAttributes` in `Shared/LiveActivityTypes.swift`) — currently fires on disruptions but uses local-only updates (push pipeline was removed Phase 1 since there's no backend). Dynamic Island design is barely defined.

---

## Accessibility status (not audited this session)

The REVIEW explicitly deferred UX/UI/accessibility. Known gaps from skimming code:

- `RealtimeMapView` annotations have `Annotation(_, coordinate:)` labels but VoiceOver experience hasn't been tested
- Dynamic Type: most views use `.font(.subheadline)` etc. which scales, but some `.frame(width:height:)` constants are hardcoded (e.g., line badges `width: 28`)
- Reduce Motion: not explicitly handled in `RealtimeMapView` polling animation or `StatusIndicator` pulse
- VoiceOver labels for status badges use raw enum text — could be more descriptive ("Linea 1, servicio regular" vs just "regular")
- Reduce Transparency: `CompactStationTimeline` handles it (line 197-199), but other glass cards don't

---

## API surface for new UI (worker endpoints you can consume)

Base URL: `https://metrobus-status.starkji.workers.dev`

| Endpoint | Returns | TTL |
|---|---|---|
| `GET /status` | All 7 lines with incidents + scheduled maintenance + elevators | 5 min KV |
| `GET /vehicles` | All ~800 live buses with lat/lon/bearing/routeId | 20s Cache API |
| `GET /vehicles?line=N` | Filtered to line N (~80-100 buses) | 20s |
| `GET /trip/{trip_id}` | Single vehicle by trip (currently always null tripId from Sinoptico — see project memory) | 20s |
| `GET /etas?stop={stop_id}` | Vehicles approaching a stop | 20s |
| `GET /static/routes` | 87 routes indexed by route_id with `{line, longName, color, textColor}` | 30h KV |
| `GET /static/stops` | 374 stops with `{name, lat, lon}` | 30h KV |
| `GET /health` | Worker liveness + cache age | — |

iOS clients: `RealtimeService.shared` (actor) for `/vehicles*` and `/static/*`. `APITransitDataProvider` for `/status`.

---

## Coordination notes for the parallel session

To avoid stepping on each other:

- **I will NOT touch**: anything in `Sources/Theme/`, `Sources/Views/` (except `RealtimeMapView.swift` if specifically needed for an architecture fix), `widget-pb/` UI, `DESIGN_SYSTEM.md`. If something requires a view-layer change to land an arch fix, I'll surface here first.
- **You will likely touch**: `TransitColors.swift` / `DesignTokens.swift` consolidation, all `Sources/Views/`, widget UI, accessibility passes, animation tuning, typography, copy.
- **Shared with care**: `Shared/SharedTypes.swift` (I added `SharedCoders` enum + `WidgetServiceStatus` lives here — coordinate if changing severity ranking).

If a merge conflict surfaces, the `git log --oneline` on `main` is clean — each commit on either side is small and revertible.

---

## Open architectural questions you may want to weigh in on

These are in REVIEW.md but explicitly UX-adjacent:

1. **CRIT-04: 4× `MetrobusViewModel` instances.** Fix involves hoisting to a single `@Observable` env object. The injection point sits in `ParabusApp` or `MainTabView`. If you have an opinion on where state ownership should live (especially as you redesign navigation), say so before I tackle this.

2. **HIGH-16: Migrate `GTFSScheduleService` to worker.** If your design relies on rich offline schedule data, this changes things. Today it ships ~56MB of static schedule with the binary; migrating to worker means online-only but always-fresh.

3. **HIGH-17: Widget severity alignment.** Coordinated since you'll be in widget files; flag if you want me to handle the data side while you do visual.

Send updates back via this same file (`ref/UX_UI_CONTEXT.md`) or a sibling — I'll re-read before any cross-cutting change.
