# Parabús — Adversarial Code Review

**Scope:** Worker (TypeScript) + iOS (Sources/, Tests/, widget-pb/, App/, Theme/). Out of scope: jdv-bot, UX/UI polish.
**Methodology:** Three parallel review agents (worker / iOS services / iOS models+views+tests) + cross-cutting checks. ~95 raw findings, deduplicated to **62 unique items** below.
**Date:** 2026-05-17

---

## ⚡ Status snapshot — 2026-05-18 (Phase 2 closure pass)

Phase 1 quick wins, Phase 2 dead-code sweep, AND most of Phase 3
architectural refactors are committed. The text of items below
(severities, "Fix:" guidance) still reads as if open — treat the body
as historical context, this snapshot as ground truth.

**Phase 2 — Dead code sweep (this batch):**

- ✅ HIGH-01 MetrobusScraper.swift + SwiftSoup + Dependencies DI — `2673537`
- ✅ HIGH-02 MetrobusStations.swift — `599025e`
- ✅ HIGH-03 WidgetIntegration.swift — `599025e`
- ✅ HIGH-04 Legacy views (LineRowView, StatusHeroCard, top StationTimeline, LineStatusGrid) — `b4074e1` (~600 LoC)
- ✅ HIGH-05 Dependencies.swift DI plumbing — `2673537` (deleted — no consumers existed)
- ✅ HIGH-06 IncidentHistoryManager + IncidentHistory model — `297f18e`
- ✅ MED-12 + MED-13 + LOW-05 dead methods / worker exports — `1c31a1f`
- ✅ LOW-06 duplicate ScheduledEvent → @cloudflare/workers-types ScheduledController — *this commit*
- ✅ Bonus: Sources/GTFS/ folder (~59MB) — `05705b2`

**Phase 2 residue (this session):**

- AlertsView.timelineSection orphan (placeholder UI left after IncidentHistoryManager deletion) — removed
- SwiftSoup credit in SettingsView.swift (dep no longer in Package.swift) — removed
- Tombstone comments in MetrobusViewModel, TransitDataProvider, StationTimeline — cleaned per CLAUDE.md no-tombstone rule
- ScraperError → TransitDataError rename (31 sites / 7 files + filename) — naming aligned with current reality

**Phase 3 — Architectural refactors already landed:**

- ✅ CRIT-04 hoist MetrobusViewModel to App root — `8331c62`
- ✅ CRIT-06 single-fetch /status via fetchAll() — `0364b7f`
- ✅ HIGH-07 worker ctx.waitUntil — `faa5449`
- ✅ HIGH-10 worker KV memoize line→routeIds — `b225d2c`
- ✅ HIGH-11 + HIGH-12 RealtimeMapViewModel concurrency — `9ee0577` + `b9c2b28`
- ✅ HIGH-13 + HIGH-18 + LOW-10 Live Activity push observer drop — `c644c66`
- ✅ HIGH-14 detached GTFS parse — `4611e23` (later superseded by HIGH-16 worker migration)
- ✅ HIGH-15 hardcoded /Users/ji path — `731b381`
- ✅ HIGH-16 GTFSScheduleService → worker — `fea7fc4` + `a5e0f1f` (-56MB binary)
- ✅ HIGH-17 widget severity alignment — `a69705c`
- ✅ MED-02 propagate stale/error from API — `2ad3446`
- ✅ MED-03 theme consolidation (TransitColors → DesignTokens) — `97b9132`
- ✅ MED-05 cache derived state in MetrobusViewModel — `9e01303`
- ✅ MED-06 hoist JSON/Date coders — `4efe33f` (later refined in `ce7a0ee`)
- ✅ HIGH-08 + HIGH-09 + MED-15 worker cache/protobuf/ZIP64 safety — `0e46159`
- ✅ LOW-11 notification toggles wired — `5558fcf`
- ✅ NIT: ImageLoader.swift → TransitImageLoader.swift — `8437ba2`

**Phase 4 — MED + LOW sweep (this session, post-Phase 2 closure):**

- ✅ CRIT-01 moot — IncidentHistoryManager already deleted (App-Group bug evaporated with the class)
- ✅ CRIT-02 Sources/Shared/ confirmed deleted; only top-level Shared/ remains
- ✅ CRIT-03 APIConfiguration baseURL/timeoutInterval are now `static let` (the `nonisolated(unsafe) static var` race was already fixed)
- ✅ CRIT-05 LineStatus uses `var id: String { lineNumber }` (UUID identity bug already fixed)
- ✅ MED-01 BackgroundRefreshManager `@MainActor final class` → `actor` (off-main I/O; nonisolated entry points for App init / scenePhase glue; `@preconcurrency import BackgroundTasks` clears Sendable warnings on BGAppRefreshTask)
- ✅ MED-04 App Group string only literal in ParabusConstants now
- ✅ MED-07 + MED-08 no iOS prettyPrinted prod paths; allLines memoized as stored property
- ✅ MED-10 CommuteStation.latitude/longitude → `Double?`; custom Codable init maps legacy `0.0` → nil for backward compat
- ✅ MED-11 partial: `cancelScheduledRefresh` deleted (orphan); `requestNotificationPermission` already wired in Settings + Alerts pre-prompt; `resetProtestNotifications` kept (still has Debug-screen caller)
- ✅ MED-14 `fetchBoth()` helper added to partner-client — one partnerValidation + parallel proto+zip download
- ✅ MED-16 worker JSON responses no longer pretty-printed (4 sites: realtime-handlers, gtfs-static, index×2)
- ✅ MED-17 CORS_HEADERS hoisted to `types.ts` as single source of truth; 4 consumer files import it (drops 3 drift-prone local copies)
- ✅ MED-18 `saveToCache` gated on `incidentes.success && mantenimiento.success` (partial-failure no longer overwrites good cache)
- ✅ LOW-01 admin endpoint uses constant-time `timingSafeEqual` (XOR-accumulate) instead of `!==`

**Phase 5 — LOW + NIT sweep (this session):**

Worker:
- ✅ LOW-02 cache service-inactive feed for 60s — absorbs repeated requests during Sinoptico outages without re-billing partnerValidation
- ✅ LOW-03 drop `\sy\s` split in parseAffectedStations — Spanish station names commonly contain " y " ("Insurgentes y Cuauhtémoc"); operators that need to list two stations use comma
- ✅ LOW-04 drop greedy `(\d{1,2}:\d{2})\s*hrs?` catch-all in parseSourceTimestamp — was matching operating hours as "last updated"
- ✅ LOW-07 jdv-fetch refactor: read body as text first, then JSON-parse with explicit handling; drops fragile substring matching on error strings
- ✅ NIT-01 bearing isFinite check — NaN-safe (was relying on `((NaN%360)+360)%360 === NaN → JSON null` coincidence)
- ✅ NIT-02 hoist TextDecoder to module-level const in gtfs-rt, gtfs-static (3 sites), gtfs-schedule
- ✅ NIT-03 remove unused `JdvFetchFailure.ms` field

iOS:
- ✅ LOW-12 notifiedProtestKeys → `[String: Date]` Codable; legacy stringArray migrated on first launch via AnyNotificationKey.timestamp; cleanup uses dict value instead of re-parsing key suffix
- ✅ LOW-13 moot — MetrobusScraperTests.swift was deleted with the scraper
- ✅ LOW-14 WidgetCacheReader uses `SharedCoders.isoEncoder/isoDecoder` instead of allocating per call
- ✅ NIT-04 moot — ImageLoader renamed in `8437ba2`
- ✅ NIT-05 moot — RealtimeService.decoder is already inline (no empty config block)
- ✅ NIT-06 ServiceStatus.init reorder: protest → suspended → delayed → limited → intervention → regular → unknown, so compound text ("limitado y regular") picks the more-severe status

**Still NOT yet closed:** MED-09 (GTFSStations 469 LoC eager arrays — needs a worker endpoint design; separate session), LOW-08 (`print()` → `os.Logger` ~16 sites in iOS Services/), LOW-09 (force-unwraps — acceptable on string literals per REVIEW; one remaining at APITransitDataProvider:77 is a constant URL), most TEST gaps. The body of this document is now ~85% stale relative to git HEAD; a fresh adversarial pass would catch what this audit missed.

**Notifications (new feature, local-only):**

- `NotificationPreferences` reads UserDefaults: master switch + favorites filter + per-status toggles. `shouldNotify(line:status:)` is the single decision point.
- `BackgroundRefreshManager.checkAndNotify` (rewrite of checkForProtestsAndNotify) handles all notifiable statuses; severity-appropriate sound + interruption level; status-aware dedup via `IncidentNotificationKey`. Legacy `ProtestKey` kept for UserDefaults backward-compat.
- AlertsView first-visit pre-prompt asks contextually before triggering the iOS system dialog. Settings master toggle re-asks if needed and reverts on deny.
- `NotificationRouter` + `NotificationDelegate` handle foreground presentation and tapped-notif deep linking — tap a notification → app switches to Alerts tab → opens the affected line's detail sheet.
- 13 new unit tests cover the pure pieces (preferences, key roundtrip, backward-compat reader).

**Test situation for the iOS-only system-framework services:**

- `LiveActivityService` (ActivityKit) and `BackgroundRefreshManager` (BGTaskScheduler) are mostly thin wrappers over Apple frameworks. Pure-logic pieces extracted to standalone testable types: `SeveritySymbol` (`d001fea`), `ProtestKey` + `IncidentNotificationKey` (`094a423` + `5558fcf`), `NotificationPreferences` (`5558fcf`).
- Adding an iOS XCTest target would mostly test Apple's frameworks rather than our code — judged not worth the project surgery.
- **Integration validation lives in the rebuilt Debug screen** (`d06e5d5`): "Simulate background refresh", "Simulate protest notification", "Start test activity" trigger the real code paths on a simulator/device, with visible feedback.

Total tests: **65 iOS in 10 suites + 47 worker = 112 passing.**

---

## TL;DR

Three architectural landmines and one operational gap dominate:

1. **No git in `/Users/ji/Sites/parabus`** despite the remote at `github.com/jistark/parabus-cdmx`. All session changes are untracked.
2. **`MetrobusScraper.swift` (~580 LoC) + `SwiftSoup` dependency are dead** — `TransitDataSource.current = .api` is hardcoded; the `.scraper` branch is unreachable.
3. **`Sources/Shared/` is a byte-identical duplicate of `Shared/` that SPM silently ignores.** First edit to either side will desync the build.
4. **`MetrobusViewModel` is instantiated 4× (one per tab) and each does its own paired fetch** — cold launch = 4× network round-trips and ~doubled API calls (every fetch hits `/status` twice for the same payload).

If you only do one batch this week: the **Quick Wins** section (15 fixes, all S-effort, mostly bug fixes).

### Severity counts

| Severity | Count | Of which Dead Code |
|---|---|---|
| **CRIT** | 6 | 2 |
| **HIGH** | 18 | 6 |
| **MED** | 18 | 4 |
| **LOW** | 14 | 5 |
| **NIT** | 6 | 1 |

---

## Cross-cutting findings (not surface-specific)

### [HIGH-X1] No git in working tree
**Where:** `/Users/ji/Sites/parabus/` (no `.git/`)
**Issue:** Remote exists at `github.com/jistark/parabus-cdmx.git` but the local clone is detached from version control. Everything done this session is unrecorded — no diffs, no revert, no PRs.
**Fix:** From a clean clone alongside, either rsync this working tree's changes in, or: `git init`, `git remote add origin <url>`, `git fetch`, `git checkout -b session-rebuild`, commit current state. Verify diff against `origin/main` makes sense before pushing.
**Effort:** S

### [LOW-X2] `Parabus-Info.plist` is empty
**Where:** `/Users/ji/Sites/parabus/Parabus-Info.plist` — content is literally `<dict/>`
**Issue:** Xcode 15+ generates Info.plist keys from build settings, so this works today. But any feature requiring an explicit key (location for centering the map on user, background fetch modes, push entitlements, App Transport Security exceptions, custom URL schemes) needs entries here. The first time you add MapKit's "user location" or push tokens for Live Activities, you'll hit silent permission denials.
**Fix:** Audit which keys Xcode is currently injecting (`Project → Info → Custom iOS Target Properties`). When adding any privacy-sensitive feature, write explicit `NS*UsageDescription` keys to this file rather than the project settings — easier to grep, easier to review.
**Effort:** S (one-time setup)

### [LOW-X3] `wrangler` version drift between `package.json` and what runs
**Where:** `workers/package.json` declares `^4.92.0`; `npm run dev` runs `4.53.0`
**Issue:** The installed version is lagging the declared. Not blocking but lockfile is out of date.
**Fix:** `cd workers && npm install` to resync.
**Effort:** S

---

## CRIT — Address before next session

### [CRIT-01] Wrong App Group → `IncidentHistoryManager` silently writes to ephemeral cache
**Cat:** BUG · **Where:** `Sources/Services/IncidentHistoryManager.swift:17` · **Effort:** S
**Issue:** Uses literal `"group.app.parabus"`; every other site uses `"group.starkji.parabus-cdmx.app"` (matches `Parabus.entitlements`). `containerURL(...)` returns `nil` → falls back to per-process `.cachesDirectory` → widget can't read, iOS may evict.
**Fix:** Replace literal with `ParabusConstants.appGroupIdentifier`. Add `assert(containerURL != nil)` in DEBUG to catch future regressions. Also collapse the other three hardcoded copies of this string (`CacheManager:9`, `WidgetIntegration:22`, plus the entitlements) into the constant.

### [CRIT-02] `Sources/Shared/` duplicates `Shared/` byte-for-byte; SPM ignores it
**Cat:** ARCH · **Where:** `Sources/Shared/SharedTypes.swift` + `Sources/Shared/LiveActivityTypes.swift` vs `Shared/*` · **Effort:** S
**Issue:** `Package.swift:43` lists top-level `"Shared"`, NOT `"Sources/Shared"`. Today the files are identical (`diff` returns equal); next edit to either side silently desyncs and the build picks whichever target's source list is consulted.
**Fix:** Delete `Sources/Shared/`. Verify Xcode synchronized group doesn't reference it. Single source of truth.

### [CRIT-03] `APIConfiguration` mutable statics violate Swift 6 strict concurrency
**Cat:** CONCURRENCY · **Where:** `Sources/Services/APITransitDataProvider.swift:68-76` · **Effort:** S
**Issue:** `nonisolated(unsafe) static var baseURL: URL` and `timeoutInterval: TimeInterval` — comments invite runtime mutation. URLSession config is captured in a `lazy var` so even mutation would leave a stale session. `nonisolated(unsafe)` silences the compiler without fixing the race.
**Fix:** Change `var → let`. There's no production code path that ever sets these. If env switching is wanted later, add `init(baseURL:timeout:)` to the actor.

### [CRIT-04] `MetrobusViewModel` instantiated 4× — 4 parallel cold-launch fetches
**Cat:** PERF · **Where:** `MainTabView:9, :84`, `ContentView:7`, `AlertsView:8` · **Effort:** M
**Issue:** Each tab owns its own `@State var viewModel = MetrobusViewModel()`. Each runs its own `loadStatus()` on appear. On cold launch with all tabs eligible to render, you get 4 parallel `GET /status` requests, 4 separate caches, 4 independent maintenance fetches. Once instantiated, the viewmodel for an unselected tab stays alive holding stale state.
**Fix:** Hoist a single viewmodel to `ParabusApp`, expose via `@Environment(MetrobusViewModel.self)`, inject into the TabView. Each tab reads from the shared instance. Or simpler short-term: `MainTabView` owns the one viewmodel, passes via `@Bindable` to children.

### [CRIT-05] `LineStatus.id = UUID()` breaks SwiftUI identity on every refresh
**Cat:** BUG · **Where:** `Sources/Models/LineStatus.swift:117-137` · **Effort:** S
**Issue:** `Identifiable.id: UUID` is regenerated on every `init`. `APITransitDataProvider.convertToLineStatus()` creates new instances every fetch → IDs change every poll → `ContentView:103`'s `value: viewModel.lines.map(\.id)` animation animates churn on every successful fetch; `ForEach(lines)` tears down + rebuilds; `sheet(item: $selectedLine)` dismisses if a refresh lands mid-presentation.
**Fix:** `var id: String { lineNumber }`. Drop the stored UUID. Add `Hashable, Equatable` while you're at it. Same pattern in `ScheduledClosure:254` — derive id from `lineNumber + station + period`.

### [CRIT-06] `MetrobusViewModel.loadStatus` fires **two** `/status` requests per refresh
**Cat:** PERF · **Where:** `Sources/ViewModels/MetrobusViewModel.swift:289-292, 301-304` · **Effort:** M
**Issue:** `withTaskGroup` calls `dataProvider.fetchStatus()` AND `dataProvider.fetchMaintenanceClosures()` concurrently. Both end up doing `await fetchAPIResponse()` against `/status` — `APIMetrobusResponse` already contains both `lines` AND `scheduledMaintenance`. Doubles bandwidth, doubles decode cost, and the two responses can disagree on `scrapedAt` if cache flips between them.
**Fix:** Add `fetchAll() async throws -> (ScrapingResult, MaintenanceResult)` to the provider; decode once. Update `loadStatus` and `refresh` to call it. Drop the `withTaskGroup`.

---

## HIGH — Address this week

### [HIGH-01] Dead code: `MetrobusScraper.swift` + `SwiftSoup` dep (~580 LoC)
**Cat:** DEAD · **Where:** `Sources/Services/MetrobusScraper.swift`; `Package.swift:25` SwiftSoup dep · **Effort:** M
**Issue:** `TransitDataSource.current = .api` (Dependencies.swift:15); the `.scraper` branch is statically unreachable. Only references that survive are `mockData`/`mockMaintenanceData` (DEBUG) and one test file with a live-network test (see HIGH-15).
**Fix:** Move mocks to `MetrobusMockData.swift`, delete `MetrobusScraper.swift` (~580 LoC), delete the `.scraper` enum case, drop SwiftSoup from `Package.swift`. Single biggest cleanup win. Knocks an external dep, eliminates an architectural fork.

### [HIGH-02] Dead code: `MetrobusStations.swift` (215 LoC) — never referenced
**Cat:** DEAD · **Where:** `Sources/Models/MetrobusStations.swift` · **Effort:** S
**Issue:** Zero callers anywhere. UI uses `GTFSStations` exclusively. Even the IDs (`"1_00"` style) are incompatible with `CommuteStation.id` (hex from real GTFS), so this couldn't be wired in without rewriting.
**Fix:** Delete the file.

### [HIGH-03] Dead code: `WidgetIntegration.swift` — superseded by `CacheManager` + `WidgetService`
**Cat:** DEAD · **Where:** `Sources/Services/WidgetIntegration.swift` (120 LoC) · **Effort:** S
**Issue:** `WidgetDataWriter`, `WidgetKind`, and the `saveAndUpdateWidget` extension on CacheManager are unused. `CacheManager.save()` already writes widget data; `WidgetService.reloadAfterDataUpdate()` reloads. `WidgetKind` is a third literal copy of `"MetrobusStatusWidget"` alongside `ParabusConstants.widgetKind` and the widget extension itself.
**Fix:** Delete the file. Audit that nobody imports it.

### [HIGH-04] Dead code: legacy unused views
**Cat:** DEAD · **Where:** multiple files · **Effort:** S
**Issue:** All confirmed via project-wide grep (no live call sites outside their own `#Preview`):
- `Sources/Views/LineRowView.swift` (entire file) — also takes `quickSummary` + `StatusIndicator` helpers
- `Sources/Views/Components/StatusHeroCard.swift` (entire file)
- `Sources/Views/Components/StationTimeline.swift` — only `CompactStationTimeline` is consumed; the top `StationTimeline` struct (lines 4-175) is dead
- `Sources/Views/Components/LineStatusTile.swift` — `LineStatusGrid` (lines 123-144) is dead
**Fix:** Delete the files / structs listed. Keep `CompactStationTimeline`. Total ~400 LoC.

### [HIGH-05] Dead code: DI plumbing nobody consumes
**Cat:** DEAD · **Where:** `Sources/Core/DI/Dependencies.swift` (entire file) · **Effort:** M
**Issue:** `EnvironmentKey`s for `transitDataProvider` and `cacheStorage` are defined and `withMockDependencies()` is exposed, but no view reads `@Environment(\.transitDataProvider)` or wraps `.withMockDependencies()`. `MetrobusViewModel.init()` builds its own deps from `TransitDataSource.current`.
**Fix:** Either commit to DI (use env keys in views, init MetrobusViewModel with injected deps in `ParabusApp`) or delete `Dependencies.swift` and the unused protocol mocks.

### [HIGH-06] Dead code: `IncidentHistoryManager.processStatusUpdate` (~60 LoC) — never called
**Cat:** DEAD · **Where:** `Sources/Services/IncidentHistoryManager.swift:57-114` · **Effort:** M
**Issue:** Grep shows zero callers. The expensive signature-build + set-diff + persistence machinery runs never. Compounds CRIT-01: even when wired, it'd write to the wrong App Group. `AlertsView.timelineSection` is a hardcoded placeholder noting "Timeline entries would come from IncidentHistoryManager".
**Fix:** Either wire `processStatusUpdate` into `MetrobusViewModel.refreshIncidents` after a successful fetch AND build out the timeline UI for real, OR delete `IncidentHistoryManager` + `IncidentHistory` + `TimelineIncident` + `HourGroup`. Half-built feature with active footguns.

### [HIGH-07] Worker: `fetch`/`scheduled` handlers don't receive `ExecutionContext` → no `waitUntil` anywhere
**Cat:** PERF · **Where:** `workers/src/index.ts:60, 157` · **Effort:** M
**Issue:** Neither handler accepts `ctx: ExecutionContext`. Every KV write (`saveToCache`, `refreshStaticGtfs`) and Cache API write (in `getDecodedFeed`) is awaited on the hot path before the response returns. `waitUntil` would let writes run after response is sent.
**Fix:** Add `ctx: ExecutionContext` to both handler signatures, thread through to handlers that write caches. Wrap non-critical writes: `ctx.waitUntil(env.METROBUS_CACHE.put(...))` and `ctx.waitUntil(cache.put(...))`. Drops first-byte latency on cache miss meaningfully.

### [HIGH-08] Worker: `cache.match` JSON parse can throw → request returns 500
**Cat:** BUG · **Where:** `workers/src/realtime-handlers.ts:38-42` · **Effort:** S
**Issue:** `await hit.json()` throws on corrupted cache or schema change after a deploy. The error propagates up to the top-level catch → user gets 500. There's no fallback to a fresh fetch.
**Fix:**
```ts
try { return (await hit.json()) as CachedFeedPayload; }
catch { /* fall through to refetch */ }
```

### [HIGH-09] Worker: protobuf `Reader.readBytes`/`skip` don't bounds-check → silent desync
**Cat:** BUG · **Where:** `workers/src/gtfs-rt.ts:284-289, 297-316` · **Effort:** S
**Issue:** `readBytes` does `subarray(pos, pos + len)` unconditionally; if `len` exceeds remaining buffer (corrupted varint, partial feed), `subarray` silently clamps but `pos` jumps past `buf.length`. Subsequent decoders receive truncated slices and produce wrong vehicle data with no error surfaced. Same for `skip` case 2 and the fixed32/fixed64 cases.
**Fix:** Add `if (this.pos + len > this.buf.length) throw new Error('truncated field')` in `readBytes`, `skip case 1/2/5`.

### [HIGH-10] Worker: every `/vehicles?line=N` re-reads + re-parses entire GTFS meta from KV
**Cat:** PERF · **Where:** `workers/src/realtime-handlers.ts:113` → `gtfs-static.ts:99-121` · **Effort:** M
**Issue:** `loadLineRouteIndex` calls `loadStaticMeta` which does `KV.get(KV_META_KEY)` + `JSON.parse` on the full ~100KB+ blob, then builds a `Map<string, Set<string>>` from scratch — every line-filter request. KV read latency 5-50ms + parse + map build, all on the hot path of an endpoint we already cache aggressively in Cache API.
**Fix:** Memoize at module scope keyed by `KV_VERSION_KEY`. Or split the inverted index into its own small KV key (`gtfs:static:lineRoutes`). Or stash the parsed object in `caches.default` under an internal URL.

### [HIGH-11] iOS: `RealtimeMapViewModel` polling loop spins forever after view deallocates
**Cat:** BUG · **Where:** `Sources/ViewModels/RealtimeMapViewModel.swift:57-63` · **Effort:** S
**Issue:** `Task { [weak self] in while !Task.isCancelled { await self?.fetchOnce(); try? await Task.sleep(for: self?.pollInterval ?? .seconds(20)) } }`. When the view is popped without `stopPolling()` (rare with current setup but possible with navigation changes), `self` becomes nil but `Task.isCancelled` is still false → infinite no-op sleep loop.
**Fix:** `guard let self else { return }` as the first line of the loop body, OR capture a strong self with explicit invalidation. Bonus: store `pollInterval` once outside the closure since `self?.pollInterval` is the same on every tick.

### [HIGH-12] iOS: `RealtimeMapViewModel` `selectedLine.didSet` races against in-flight polling
**Cat:** CONCURRENCY · **Where:** `Sources/ViewModels/RealtimeMapViewModel.swift:32-38` · **Effort:** S
**Issue:** `didSet` spawns `Task { await refresh() }` without cancelling the in-flight `fetchOnce()` from the polling loop. Spam-toggling filters → multiple concurrent fetches racing to set `vehicles` (last-write-wins, no guarantee which lands last). `isLoading` flickers.
**Fix:** Track in-flight task: `private var refreshTask: Task<Void, Never>?`; in `didSet` do `refreshTask?.cancel(); refreshTask = Task { await refresh() }`. Same protection for explicit `refresh()` calls.

### [HIGH-13] iOS: `LiveActivityService.startActivity` leaks a Task per push-token observer
**Cat:** CONCURRENCY · **Where:** `Sources/Services/LiveActivityService.swift:70-76` · **Effort:** S
**Issue:** Every `startActivity` spawns an unstored `Task { for await tokenData in activity.pushTokenUpdates {...} }`. Never cancelled in `endActivity`. Each new activity for the same line leaks another infinite-loop iterator that keeps the activity alive in memory. Also `handlePushToken` is a TODO that doesn't register tokens anywhere — the observer collects tokens that go nowhere (see HIGH-18 too).
**Fix:** `private var tokenTasks: [String: Task<Void, Never>] = [:]`. Store the task, cancel + remove on `endActivity`. Or drop the observer entirely until push registration is implemented (see HIGH-18).

### [HIGH-14] iOS: `GTFSScheduleService` reads stop_times.txt synchronously on actor → blocks all actor callers
**Cat:** PERF · **Where:** `Sources/Services/GTFSScheduleService.swift:112-179` · **Effort:** M
**Issue:** `String(contentsOf:)` slurps hundreds of KB → MB. `components(separatedBy: .newlines)` creates a giant `[String]`. Per-line `components(separatedBy: ",")` allocates again. Runs inside the actor and blocks all other actor calls during parse (could be hundreds of ms). `tempStopTimes` dict grows unbounded and is held forever.
**Fix:** (a) Move parse to `Task.detached(priority: .utility)` so first call doesn't block. (b) Stream the file rather than slurping. (c) Or migrate to worker `/static/*` endpoints (see HIGH-16) and drop the local GTFS entirely.

### [HIGH-15] iOS: `GTFSScheduleService.findGTFSFile` hardcodes developer's home path
**Cat:** BUG · **Where:** `Sources/Services/GTFSScheduleService.swift:201-215` · **Effort:** S
**Issue:** `"/Users/ji/Sites/parabus/Sources/GTFS/\(filename)"` ships in release builds — privacy info leak (username `ji` in strings dump) and brittle. Bundle.module is hit first so the path is dead-fallback in practice, but it's still in the binary.
**Fix:** Wrap in `#if DEBUG`, or just delete the third lookup branch — `Bundle.module` + `Bundle.main` already cover the real cases. Also: `parseTime` does `(hours % 24) * 60 + minutes` — drops the date dimension for 24:30+ trips, those wrap to next-day ETAs. Separate bug, also worth fixing here.

### [HIGH-16] iOS: bundled GTFS duplicates worker's authoritative source
**Cat:** ARCH · **Where:** `Sources/Services/GTFSScheduleService.swift` + `Package.swift:46 .copy("Sources/Resources/GTFS")` · **Effort:** L
**Issue:** The worker now serves `/static/routes` and `/static/stops` (daily-refreshed). The iOS app simultaneously ships the entire GTFS as a resource, parsed on every cold launch. Two sources of truth: when CDMX changes a schedule, the worker updates from cron, but the app keeps the old version until the next App Store release. Also inflates binary size meaningfully.
**Fix:** Add `/static/stop_times` to the worker (or build a precomputed-ETAs endpoint, even cheaper). Migrate `GTFSScheduleService` to fetch from the worker. Drop the GTFS resource copy. Massive size + freshness win.

### [HIGH-17] iOS: `WidgetServiceStatus.severity` drops `protest` and `limited`
**Cat:** BUG · **Where:** `Sources/Shared/SharedTypes.swift:76-84` vs `Sources/Models/LineStatus.swift:72-82` · **Effort:** M
**Issue:** `ServiceStatus.severity` uses 0..6 with `protest=6` (highest in the app, drives urgent notifications). `WidgetServiceStatus.severity` uses 0..4, lacks `protest` and `limited`. `CacheManager:172-173` squashes `protest → .suspended` and `limited → .delayed`. Widget never shows protest as a distinct urgent state. UX inconsistency between main app and widget.
**Fix:** Add `protest` and `limited` cases to `WidgetServiceStatus`. Bump `protest` to highest severity. Update widget views to render them. Align both severity numbering schemes.

### [HIGH-18] iOS: Live Activity push pipeline non-functional but allocates infrastructure
**Cat:** ARCH · **Where:** `Sources/Services/LiveActivityService.swift:70-76, 210-223` · **Effort:** S
**Issue:** `startActivity` requests `pushType: .token` and observes `activity.pushTokenUpdates`. `handlePushToken` is a print + commented-out APN registration. Tokens are collected, never delivered to a server. Combined with HIGH-13 (task leak), each protest cycle leaks an iterator collecting tokens that go nowhere.
**Fix:** Either implement server registration (separate spike — needs a push relay), or change `pushType: nil` and delete the token observer + `LiveActivityTokenInfo`/`LiveActivityPushPayload` types.

---

## MED

### [MED-01] iOS: `BackgroundRefreshManager` is `@MainActor` but does network + disk I/O
**Cat:** CONCURRENCY · **Where:** `Sources/Services/BackgroundRefreshManager.swift:7-9, 89-101` · **Effort:** M
**Fix:** Convert from `@MainActor` final class to `actor`. The few UN/BG APIs needing main can hop explicitly.

### [MED-02] iOS: `APITransitDataProvider` ignores `stale` + `error` fields in API response
**Cat:** BUG · **Where:** `Sources/Services/APITransitDataProvider.swift:7-16, 99-150` · **Effort:** S
**Fix:** Add `isStale: Bool` to `ScrapingResult`. Surface it. Same for `error`.

### [MED-03] iOS: Theme duplicated across `TransitColors.swift` and `DesignTokens.swift`
**Cat:** ARCH · **Where:** `Sources/Theme/` · **Effort:** M
**Issue:** Two enums per concept (`StatusColor`/`StatusColors`, `LineColor`/`LineColors`, `MaterialOpacity`/`SurfaceOpacity`). Active callers split between them. Palette changes require editing twice.
**Fix:** Pick DesignTokens.swift (matches design system doc). Delete TransitColors.swift. ~30 call sites to update.

### [MED-04] iOS: 4 places duplicate the App Group string literal
**Cat:** ARCH · **Where:** `CacheManager:9`, `WidgetIntegration:22`, `IncidentHistoryManager:17` (wrong!), `ParabusConstants` · **Effort:** S
**Fix:** All read from `ParabusConstants.appGroupIdentifier`. Plus the duplicate `WidgetKind` enum in `WidgetIntegration:116-119` collapses into `ParabusConstants.widgetKind`.

### [MED-05] iOS: `MetrobusViewModel.deduplicatedTodaysClosures` is O(N×M) recomputed 3× per render
**Cat:** PERF · **Where:** `Sources/ViewModels/MetrobusViewModel.swift:75-100` · **Effort:** M
**Fix:** Compute once in `refreshIncidents`/`loadStatus` final step, store in a stored property; expose via computed accessor.

### [MED-06] iOS: `JSONEncoder`/`JSONDecoder`/`DateFormatter` allocated per call
**Cat:** PERF · **Where:** `CommuteModels:210,217`, `IncidentHistoryManager:212,226`, `CacheManager:73,107`, `IncidentHistory:49`, `RealtimeMapView:143`, `APITransitDataProvider.parseDate:292,294` · **Effort:** S
**Fix:** Hoist to `static let` per type. `DateFormatter` is *expensive* on iOS (locale loading); `APITransitDataProvider.parseDate` creates two ISO8601 formatters per call.

### [MED-07] iOS: `CacheManager.save` uses `.prettyPrinted` in production
**Cat:** PERF · **Where:** `Sources/Services/CacheManager.swift:73-78` + `WidgetIntegration.swift:53-56` · **Effort:** S
**Fix:** Drop `.prettyPrinted` outside DEBUG. ~30-40% smaller on-disk JSON, faster widget decode.

### [MED-08] iOS: `MetrobusViewModel.allLines` rebuilds dict on every access
**Cat:** PERF · **Where:** `Sources/ViewModels/MetrobusViewModel.swift:32-46` · **Effort:** S
**Fix:** Cache as stored property, invalidate when `lines` changes.

### [MED-09] iOS: `GTFSStations.swift` ships ~380 stations as eager static arrays
**Cat:** PERF · **Where:** `Sources/Models/GTFSStations.swift` (469 LoC) · **Effort:** L
**Issue:** Duplicates the worker's `/static/stops` source of truth. ~50KB compiled string data. `StationPicker.filteredStations` walks all 380 + Unicode folds on every keystroke (not debounced).
**Fix:** Long-term: fetch `/static/stops` and cache (with disk fallback for offline + a small bootstrap array). Short-term: debounce the search field.

### [MED-10] iOS: `CommuteStation.hasCoordinates` false-negatives at null island
**Cat:** BUG · **Where:** `Sources/Models/CommuteModels.swift:71-73` · **Effort:** S
**Fix:** Make `latitude`/`longitude` `Double?`. `hasCoordinates` becomes `lat != nil && lon != nil`. Backward-compat init for stored schedules.

### [MED-11] iOS: Dead methods on `BackgroundRefreshManager` + `requestNotificationPermission` never called
**Cat:** BUG · **Where:** `Sources/Services/BackgroundRefreshManager.swift:65-67, 72-80, 178-182` · **Effort:** S
**Issue:** Protest notifications fire from BG refresh but the app never asks for notification permission → silent failure on first install.
**Fix:** Wire `requestNotificationPermission` into first-launch flow or settings toggle. Delete `cancelScheduledRefresh` and `resetProtestNotifications`.

### [MED-12] iOS: Dead methods on `RealtimeService`, `APITransitDataProvider`
**Cat:** DEAD · **Where:** `RealtimeService.invalidateStaticRoutesCache` (line 53-55), `APITransitDataProvider.checkHealth` (line 300-337), `APITransitDataProvider.fetchStatus(forLine:)` (line 112-120) · **Effort:** S
**Fix:** Delete unless wiring to debug menu / startup probe.

### [MED-13] iOS: `MetrobusViewModel.refreshIncidentsOnly` + `refreshMaintenanceOnly` unused
**Cat:** DEAD · **Where:** `Sources/ViewModels/MetrobusViewModel.swift:308-315` · **Effort:** S
**Fix:** Delete.

### [MED-14] Worker: `partnerValidation` called twice when proto + zip needed in same tick
**Cat:** BUG · **Where:** `workers/src/partner-client.ts:91-129` · **Effort:** S
**Issue:** `fetchRealtimeProto` and `fetchStaticZip` each call `partnerValidation()` independently. Not triggered today (different cron paths) but if/when one handler needs both, you double-bill the partner API AND can get two different `generationDateTime` values.
**Fix:** Add `fetchBoth()` helper that does one `partnerValidation` and parallel-downloads both URLs. Or thread an optional pre-fetched `validation` into both fetchers.

### [MED-15] Worker: `extractZipFiles` doesn't detect ZIP64
**Cat:** BUG · **Where:** `workers/src/gtfs-static.ts:282-298` · **Effort:** S
**Issue:** `cdOffset === 0xFFFFFFFF` or `cdEntries === 0xFFFF` means ZIP64 header — currently walks garbage offsets silently.
**Fix:** Detect and throw a clear "ZIP64 not supported" error. Worker won't see ZIP64 today (GTFS too small) but the failure mode is silent data corruption, not "I don't support this".

### [MED-16] Worker: pretty-printed JSON on every response wastes ~30% bandwidth
**Cat:** PERF · **Where:** `workers/src/index.ts:326,401`, `gtfs-static.ts:368`, `realtime-handlers.ts:240` · **Effort:** S
**Fix:** `JSON.stringify(data)` without `null, 2`. Add `?pretty=1` query param for debugging.

### [MED-17] Worker: CORS_HEADERS duplicated across 3 files with different values
**Cat:** ARCH · **Where:** `index.ts:45-50`, `gtfs-static.ts:127-130`, `realtime-handlers.ts:19-23` · **Effort:** S
**Issue:** `gtfs-static.ts` omits `Allow-Headers` and `Max-Age`. Drift waiting to bite.
**Fix:** Consolidate to a shared module (`http.ts` or extend `types.ts`).

### [MED-18] Worker: `handleStatus` swallows partial-success in error paths
**Cat:** BUG · **Where:** `workers/src/index.ts:255-303` · **Effort:** S
**Issue:** `scrapeAll` doesn't throw on per-source failure; the `try/catch` and stale-cache fallback at line 280 are effectively dead. Partial-failure (one source healthy, one failed) overwrites a previously-good cached snapshot via `saveToCache`.
**Fix:** Either throw on total failure, or gate `saveToCache` on full success (`if (result.incidentes.success && result.mantenimiento.success) saveToCache(...)`).

---

## LOW

### [LOW-01] Worker: admin endpoint should be POST-only; secret-comparison should be timing-safe
**Where:** `workers/src/index.ts:73-90` · **Cat:** SEC · **Effort:** S

### [LOW-02] Worker: `partnerValidation` called on every PoP miss when service offline
**Where:** `workers/src/realtime-handlers.ts:65-84` · **Cat:** PERF · **Effort:** S
**Fix:** Cache the "service offline" sentinel for ~60s to avoid hammering Sinoptico across PoPs/users.

### [LOW-03] Worker: `parseAffectedStations` splits on `\sy\s` — breaks Spanish station names containing " y "
**Where:** `workers/src/parser.ts:391-403` · **Cat:** BUG · **Effort:** S

### [LOW-04] Worker: `parseSourceTimestamp` fallback regex matches any "HH:MM hrs" on the page
**Where:** `workers/src/parser.ts:613` · **Cat:** BUG · **Effort:** S
**Fix:** Remove the catch-all or anchor it to a known header word.

### [LOW-05] Worker: `USER_AGENT` constant exported but never used
**Where:** `workers/src/types.ts:197` · **Cat:** DEAD · **Effort:** S

### [LOW-06] Worker: Duplicate `ScheduledEvent` interface (local vs `types.ts` vs `@cloudflare/workers-types`)
**Where:** `workers/src/index.ts:414-418` vs `types.ts:177-181` · **Cat:** DEAD · **Effort:** S
**Fix:** Use `ScheduledController` from `@cloudflare/workers-types`. Delete the locals.

### [LOW-07] Worker: `jdvFetch` retry-or-throw decision based on substring matching on error message
**Where:** `workers/src/jdv-fetch.ts:99-128` · **Cat:** BUG · **Effort:** S
**Issue:** `.json()` happens before `resp.ok` check; non-JSON 503 bodies cause retries. Substring match against jdv-bot error strings is fragile.
**Fix:** Read body as text first, status-check, then attempt JSON parse with explicit handling.

### [LOW-08] iOS: `print()` used for logging — no levels, no subsystems, ships in release
**Where:** ~20 instances in Services/ · **Cat:** OTHER · **Effort:** M
**Fix:** `import os` + `Logger(subsystem: "app.parabus", category: "...")` per service.

### [LOW-09] iOS: Force-unwraps in URL construction
**Where:** `APITransitDataProvider:72,158,343,347`, `MetrobusScraper:158` · **Cat:** BUG · **Effort:** S
**Fix:** `URL(string:)!` on string literals is acceptable. `userAgents.randomElement()!` should `?? userAgents[0]`. URLComponents helpers should fall back to the original URL.

### [LOW-10] iOS: `LiveActivityService.trackedLines` drifts from `activeActivities.keys`
**Where:** `Sources/Services/LiveActivityService.swift:191-195` · **Cat:** CONCURRENCY · **Effort:** S
**Fix:** Drop `trackedLines`; use `activeActivities.keys` everywhere.

### [LOW-11] iOS: `SettingsView` notification toggles persist but nothing reads them
**Where:** `Sources/Views/SettingsView.swift:8, 243-246` · **Cat:** BUG · **Effort:** M
**Fix:** Either wire `notificationsEnabled` / `notifySuspended` etc. through to `BackgroundRefreshManager.checkForProtestsAndNotify`, or hide the section until functional.

### [LOW-12] iOS: `notifiedProtestKeys` cleanup uses string suffix parsing
**Where:** `Sources/Services/BackgroundRefreshManager.swift:166-175` · **Cat:** BUG · **Effort:** S
**Fix:** Store as `[Key: Date]` Codable, drop string parsing.

### [LOW-13] iOS: Tests file `MetrobusScraperTests.fetchRealData` hits live network
**Where:** `Tests/MetrobusScraperTests.swift:84-97` · **Cat:** TEST · **Effort:** S
**Fix:** Either delete (scraper is dead — see HIGH-01) or guard behind `INTEGRATION_TESTS` env var. Replace with HTML-fixture-based parsing tests.

### [LOW-14] iOS: `WidgetCacheReader.load/save` allocates fresh JSONCoder per call
**Where:** `Sources/Shared/SharedTypes.swift:142-149` (+ Sources/Shared/ dup) · **Cat:** PERF · **Effort:** S
**Fix:** Static cached coders. Widget memory is tightly bounded (~30MB) — every allocation matters.

---

## NIT

- **[NIT-01] Worker:** `bearing` normalization doesn't handle `NaN` — `((NaN % 360) + 360) % 360 === NaN`. Worker emits NaN which JSON-serializes to `null` (coincidentally correct). Fix: `isFinite(raw) ? ... : null`.
- **[NIT-02] Worker:** `TextDecoder` instantiated per call in `gtfs-rt.ts:281` and `gtfs-static.ts:315,334`. Hoist to module const.
- **[NIT-03] Worker:** `interface JdvFetchFailure.ms` is optional, never set or read. Remove.
- **[NIT-04] iOS:** `ImageLoader.swift` filename ≠ enum name (`TransitImageLoader`). Rename file.
- **[NIT-05] iOS:** `RealtimeService.decoder` configure-block is empty. Inline as `let decoder = JSONDecoder()`.
- **[NIT-06] iOS:** `ServiceStatus.init(from:)` uses contains-chain on Spanish strings — phrasing-dependent ordering bugs (`"Servicio Limitado y Regular"` matches `.regular` first). Replace with anchored regex or lookup table.

---

## Test coverage gaps (TEST category)

`Tests/` has only 2 files: `MetrobusScraperTests.swift` (tests dead code per HIGH-01 + flaky network test per LOW-13) and `MetrobusViewModelTests.swift`.

**No tests for:** `RealtimeService`, `RealtimeMapViewModel`, `APITransitDataProvider`, `IncidentHistoryManager`, `GTFSScheduleService`, `LiveActivityService`, `BackgroundRefreshManager`, worker's protobuf decoder, worker's CSV/ZIP parsers.

**Minimum new suite to add post-cleanup:**
- `RealtimeServiceTests` — mock URLSession via URLProtocol, decode fixtures, validate 6h memoization, 429/503/500 → ScraperError mapping
- `RealtimeMapViewModelTests` — startPolling idempotency, stopPolling cancellation, selectedLine triggers immediate refresh, polling lifecycle on ScenePhase
- `IncidentHistoryManagerTests` — signature stability across reorderings, resolve-detection on incident drop-out
- `APITransitDataProviderTests` — snapshot decode of fixture `APIMetrobusResponse`, all `convertAPIStatus` cases
- Worker: `gtfs-rt.test.ts` with a captured `.proto` byte fixture; `gtfs-static.test.ts` with a small ZIP fixture; `partner-client.test.ts` with mocked fetch covering null-response and 401 paths

**Effort:** L (probably 1-2 focused sessions)

---

## Recommended fix order (3 phases)

### Phase 1: Quick Wins (15 fixes, all S-effort) — 1 session
Bug fixes + obvious dead code that don't require rethinking anything:

1. CRIT-01 IncidentHistoryManager App Group typo
2. CRIT-02 Delete `Sources/Shared/`
3. CRIT-03 `APIConfiguration` mutable statics → `let`
4. CRIT-05 `LineStatus.id = UUID()` → `lineNumber`
5. HIGH-02 Delete `MetrobusStations.swift`
6. HIGH-03 Delete `WidgetIntegration.swift`
7. HIGH-08 Wrap `cache.match` JSON parse in try/catch
8. HIGH-09 Bounds-check protobuf reader
9. HIGH-11 + HIGH-12 RealtimeMapViewModel: weak-self guard + cancel-on-replace
10. HIGH-13 LiveActivityService task storage
11. HIGH-15 Remove hardcoded `/Users/ji/...` path
12. HIGH-18 Drop unused push-token observer (or implement)
13. MED-04 Collapse App Group literals
14. MED-06 Hoist JSONEncoder/Decoder/DateFormatter to static
15. MED-15 ZIP64 detection in worker

### Phase 2: Dead Code Sweep — 1 session
Substantial deletions, requires verifying nothing reaches into them:

- HIGH-01 Delete `MetrobusScraper.swift` + drop SwiftSoup
- HIGH-04 Delete legacy views (LineRowView, StatusHeroCard, top StationTimeline, LineStatusGrid)
- HIGH-05 Decide on DI: commit or delete `Dependencies.swift`
- HIGH-06 Decide on Incident history: build UI or delete
- MED-12, MED-13 Delete dead methods on `RealtimeService` / `APITransitDataProvider` / `MetrobusViewModel`
- LOW-05, LOW-06 Worker dead exports + duplicate `ScheduledEvent`

After this phase the codebase shrinks ~1500 LoC + one external dep.

### Phase 3: Architectural Refactors (M-L effort) — 2-3 sessions
Bigger restructurings, each is its own focused session:

- CRIT-04 + CRIT-06 Unify MetrobusViewModel + single-fetch `/status`
- HIGH-07 + HIGH-10 Worker: ctx.waitUntil + KV memoization
- HIGH-14 + HIGH-16 GTFSScheduleService: detached parse OR migrate to worker
- HIGH-17 Widget severity alignment
- MED-03 Theme consolidation
- MED-05 Cached derived state in MetrobusViewModel

Then tackle tests (TEST section) once the surface stops moving.

---

## What I did NOT review (out of scope)

- **UX/UI polish** — visual hierarchy, copy, accessibility (VoiceOver, Dynamic Type, Reduce Motion), animation polish, empty states, loading skeletons. Explicitly deferred to next session.
- **jdv-bot** internals — only the new `/fetch` endpoint was touched this session; broader bot review is out of scope.
- **Resources/Assets** — image catalogs, localization strings, accent colors.
- **Build settings, signing, capabilities** beyond the entitlements quick-check.
- **Backend security audit** beyond findings caught in code review (rate-limit policy, abuse mitigation, KV access logs).
