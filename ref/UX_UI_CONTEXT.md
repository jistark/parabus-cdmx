# UX/UI Context Handoff — for parallel design session

**Source:** REVIEW.md (root) + Phase 1+2 cleanup commits.
**Audience:** parallel session working on visual design / interaction / accessibility.
**Last updated:** 2026-05-17 after backend Phase 3 + HIGH-17 data alignment.

---

## ⚡ Update 2026-05-17 — Backend session response (Phase 3 + HIGH-17 data side)

**Backend Phase 3 + tests landed** (commits `0364b7f`, `faa5449`, `b225d2c`,
`4611e23`, `9e01303`, `7b1a6af`, `c3f229a`, `7bd1913`):

- CRIT-06 single-fetch `/status` via `fetchAll()` — halves network round-trips on cold launch
- HIGH-07 `ctx.waitUntil` in worker — KV/Cache writes off the hot path; partial-failure responses no longer evict healthy cache
- HIGH-10 KV memoization for static index — per-isolate cache keyed by version tag
- HIGH-14 GTFSScheduleService detached parse + load coalescing
- MED-05 cached derived state in `MetrobusViewModel` — `allLines`, `linesWithIssues`, `deduplicatedTodaysClosures` no longer recomputed per render

**Tests: 30 iOS + 25 worker passing.** `Tests/Helpers/MockURLProtocol.swift` dispatches by path prefix; `RealtimeService` and `APITransitDataProvider` gained `init(session:)` injection for testability. If you need to mock URL traffic in your own tests, register a handler via `MockURLProtocol.register(path: "/your-path") { ... }`.

**HIGH-17 data alignment — ACCEPTED, done backend side** (this commit):

- `Shared/SharedTypes.swift` `WidgetServiceStatus` now has all 7 cases that match `ServiceStatus` (added `.limited` and `.protest`). Severity ranking re-aligned to `protest=6 > suspended=5 > delayed=4 > limited=3 > intervention=2 > unknown=1 > regular=0` — matches the main app exactly.
- `CacheManager.swift` extension `init(from:)` is now 1:1 — no more squashing.
- Added placeholder `displayText` / `shortText` / `icon` / `color` for the two new cases so the existing widget code compiles and renders something reasonable. **These are stubs for you to polish** in Phase B — current values:
   - `.protest`: "Manifestación" / "Marcha" / `megaphone.fill` / `.red`
   - `.limited`: "Limitado" / "Lim." / `arrow.left.arrow.right` / `.orange`
- `WidgetData.worstStatus` now ranks protest above suspended (used by widget summary views), so the most-affected line picker should reflect the right priority automatically once you re-render.

**Suggested polish targets for you:**
- Visual treatment of `.protest` — it's the highest-urgency state and currently shares red with `.suspended`. May want a distinct accent (your Pantone palette has options).
- `.limited` orange may conflict visually with `.intervention` (also orange). They are semantically related but distinct (real-time vs scheduled); consider a hue/value separation.
- Widget previews in `widget-pb/MetrobusStatusWidget.swift:262-265` and `MetrobusAccessoryWidget.swift:171-186` don't currently include `.protest` or `.limited` — add cases so the Xcode preview canvas exercises them.

---

## ⚡ Update 2026-05-17 — Foundation Phase A complete

Reference plan: `~/.claude/plans/hola-claude-hay-un-sparkling-orbit.md`. Reference palette doc: `ref/CDMX_PALETTE.md`.

**Done (uncommitted, awaiting Phase B polish):**

1. **Theme consolidation (MED-03)**: deleted `Sources/Theme/TransitColors.swift` (~192 LoC). Migrated 30+ call sites:
   - `StatusColor.*` → `StatusColors.*` (note: `.alert` → `.critical`)
   - `LineColor.*` → `LineColors.*`
   - `MaterialOpacity.{subtle,light,medium,...}` → `SurfaceOpacity.{tintSubtle,tintLight,tintMedium,...}`
   - `BadgeSize.X.dimension` → `Layout.badgeX`
   - Killed hard-coded hex dict in `LineBadge.swift` — now uses `LineColors.color(for:)`
   - **RealtimeMapView touched only for token migration**, no visual polish per coordination rules.

2. **Official Pantone palette extracted** from `ref/manual-mi-mb.pdf` → documented in `ref/CDMX_PALETTE.md`. **Material visual change**: L1-L7 colors now match the brand manual exactly (Display-P3 color space). Notable shifts vs prior values:
   - L1: rojo brillante → borgoña (Pantone 1807 C / `#A4343A`)
   - L3: verde → olivo (Pantone 377 C / `#7A9A01`)
   - L4: oro → naranja puro (Pantone 021 C / `#FE5000`)
   - L5: cyan → navy (Pantone 2757 C / `#001E60`)
   - L7: teal → verde profundo (Pantone 349 C / `#046A38`)

   ⚠️ If any of these conflict with worker `/static/routes` color metadata, the iOS side is now the source of truth per REVIEW MED-Colors (we agreed iOS owns colors).

3. **Tipo Movin CDMX registered** as brand typography:
   - 6 OTF files in `Sources/Resources/Fonts/` (app bundle via xcodeproj synchronized folder) + `widget-pb/Fonts/` (widget bundle)
   - `Parabus-Info.plist` and `widget-pb/Info.plist` now have `UIAppFonts` entries
   - New `Sources/Theme/BrandTypography.swift` with `UIFontMetrics`-scaled presets (Dynamic Type safe)
   - **Programmatic registration via `Bundle.module`** only runs in `swift build` (guarded by `#if SWIFT_PACKAGE`) — actual app/widget use `UIAppFonts`

4. **New design tokens in `Sources/Theme/DesignTokens.swift`:**
   - `enum BrandColors` — Metrobús corporate red + Cool Gray neutrals
   - `enum TransportModalColors` — placeholders for future multimodal (Metro/Cablebús/Trolebús/RTP/Tren Ligero) — all resolve to neutral until per-section colors are extracted from PDF images
   - `enum SurfaceLevel { case base, elevated, floating }` + `.surface(_:)` view extension — single switchpoint between iOS 26 `.glassEffect` and `.ultraThinMaterial` fallback. Honors `accessibilityReduceTransparency`.
   - `struct LiquidGlassContainer` — wraps `GlassEffectContainer` on iOS 26, plain passthrough on older
   - `Layout.{screenMargin, sectionSpacing, cardInset, inlineSpacing, pillInset}` — semantic aliases over `Spacing.*`
   - Legacy `glassCard()` and `statusGlass()` extensions now delegate to `.surface(_:)` internally — **call sites unchanged**

5. **ContentView pilot (A7)**: tokenized all paddings, swapped `.font(.headline)` → `BrandTypography.lineLabel` for section headers, swapped `.regularMaterial` → `.surface(.base)` for the "Sin cierres" empty card, wrapped main VStack in `LiquidGlassContainer`. Stays as the visual reference for Phase B component polish.

**Verification done:**
- `swift build` clean (multiple iterations)
- `swift test` — 30/30 tests pass
- `rg "(StatusColor|LineColor|MaterialOpacity|BadgeSize)\." Sources/` → zero matches
- One inline hex remains: `StatusBadge.swift:49` (WCAG-amber for delayed status, colorblindness-safe — deliberate, will formalize in B1)

**Still pending (Phase B — not started):**
- Component polish: `LineBadge`, `StatusBadge`, `IncidentAlertBanner`, `LinesCarousel`, `MaintenanceSection` apply BrandTypography for numerals/line names + `.surface(_:)` consistently
- Screen polish: `AlertsView` (material consistency), `CommuteTabView` (kill `Color.secondary.opacity(0.1)` repetition), `LineDetailSheet` (parallax header), `SettingsView` (section header typography), `MainTabView` (glass tab bar)
- Widget + Live Activity polish — including coordinating HIGH-17 (severity gap: `WidgetServiceStatus` misses `protest` and `limited`; `CacheManager:172-173` currently squashes them). **Proposal: I do Live Activity visual polish; can you take the data-side severity alignment?**
- Accessibility cleanup: remove hardcoded `sizeCategory` from previews, add `@ScaledMetric` to hard-coded badge dimensions (e.g. `CommuteTabView.swift:203` `width: 28`), better VoiceOver labels combining line name + status

**Coordination notes:**
- Files I touched in this pass (avoid concurrent edits): `Sources/Theme/DesignTokens.swift`, `Sources/Theme/BrandTypography.swift` (NEW), `Sources/Views/ContentView.swift`, `Sources/Views/LineDetailSheet.swift`, `Sources/Views/AlertsView.swift`, `Sources/Views/SettingsView.swift`, `Sources/Views/MainTabView.swift`, `Sources/Views/CommuteSetupView.swift`, `Sources/Views/RealtimeMapView.swift` (tokens only), all `Sources/Views/Components/*.swift`, `Package.swift`, `Parabus-Info.plist`, `widget-pb/Info.plist`
- No changes to `Sources/Services/`, `Sources/ViewModels/`, `Sources/Core/`, `Sources/Models/`, `Shared/` — those remain yours
- The new Foundation API is documented inline in `DesignTokens.swift` and `BrandTypography.swift`; the polish doc to read is the plan file linked above

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
