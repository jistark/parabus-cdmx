/**
 * /static/cenefas + /arrivals: official service identity and realtime
 * arrival states. State derivation is pure (exported for testing); the
 * handlers stay thin, matching gtfs-schedule.ts house style.
 */
import { type Env, CORS_HEADERS } from './types';
import { CENEFAS } from './data/cenefas';
import { buildStopIndex, type StopServiceHit } from './data/cenefas-types';
import type { VehiclePosition } from './gtfs-rt';
import { getDecodedFeed } from './realtime-handlers';
import { loadStopSchedule, populateStopSchedule, travelTime, nextArrivals, currentCDMXMinutes, type ScheduledArrival } from './gtfs-schedule';
import { projectOntoSequence, type LatLon } from './geo';
import { loadStaticMeta } from './gtfs-static';

export function handleCenefas(): Response {
  return new Response(JSON.stringify(CENEFAS), {
    status: 200,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=86400',
    },
  });
}

export const VEHICLE_STALE_SECONDS = 60;
export const FEED_STALE_SECONDS = 90;
/** How many stops upstream we look for an approaching vehicle. */
export const MAX_UPSTREAM_HOPS = 5;
/** Fallback minutes per hop when schedule travel-time is unavailable. */
const FALLBACK_MINUTES_PER_HOP = 4;
/**
 * Projection-path thresholds. The Sinóptico feed does not populate
 * stop_id/current_stop_sequence, so live states are inferred by projecting
 * vehicle lat/lon onto the direction's ordered stop sequence (geo.ts).
 */
/** Vehicles farther than this from every route segment are ignored (deadheading). */
export const MAX_OFF_ROUTE_METERS = 500;
/** Within this distance of our stop, an approaching vehicle reads "arriving". */
export const ARRIVING_RADIUS_METERS = 300;
/** Beyond this distance past our stop, "departed" is no longer useful — drop it. */
export const DEPARTED_RADIUS_METERS = 300;

export type ArrivalState = 'arriving' | 'eta' | 'departed' | 'scheduled';

export interface ArrivalRow {
  serviceId: string;
  line: string;
  destination: string;
  state: ArrivalState;
  etaMinutes: number | null;
  vehicleId: string | null;
  source: 'realtime' | 'schedule';
}

/** Scheduled fallback shape the handler resolves per stop. */
export interface ScheduledFallback {
  destination: string;
  etaMinutes: number;
}

/** Module-level index, built once per isolate. */
const STOP_INDEX = buildStopIndex(CENEFAS);
export function stopIndex(): Map<string, StopServiceHit[]> {
  return STOP_INDEX;
}

/**
 * Derive one row per service-direction covering `stopId`.
 *
 * Positional semantics (no per-request state needed):
 *   vehicle's next stop == our stop        → arriving
 *   vehicle's next stop k hops upstream    → eta (Σ scheduled hop times)
 *   vehicle's next stop == stop after ours → departed
 * Priority within a direction: arriving > nearest eta > departed.
 *
 * The vehicle's next stop comes from feed stop_id when present; otherwise it
 * is inferred geometrically by projecting the vehicle's lat/lon onto the
 * direction's stop sequence (`stopCoords` resolves stop ids to coordinates —
 * return null to disable projection and degrade to scheduled).
 *
 * `travelTimeLookup(from, to)` returns scheduled minutes between two stops
 * (null when they never share a trip). `scheduleLookup()` resolves the
 * scheduled fallback rows for this stop, keyed by official destination.
 */
export async function deriveArrivalRows(
  index: Map<string, StopServiceHit[]>,
  stopId: string,
  vehicles: VehiclePosition[],
  feedTimestamp: number,
  nowSeconds: number,
  stopCoords: (stopId: string) => LatLon | null,
  travelTimeLookup: (fromStopId: string, toStopId: string) => Promise<number | null>,
  scheduleLookup: () => Promise<ScheduledFallback[]>,
): Promise<ArrivalRow[]> {
  const hits = index.get(stopId) ?? [];
  if (hits.length === 0) return [];

  const feedStale = nowSeconds - feedTimestamp > FEED_STALE_SECONDS;
  const fresh = feedStale
    ? []
    : vehicles.filter((v) => v.timestamp !== null && nowSeconds - v.timestamp <= VEHICLE_STALE_SECONDS);

  const rows: ArrivalRow[] = [];
  let scheduled: ScheduledFallback[] | null = null;

  for (const hit of hits) {
    const routeIds = new Set(hit.gtfsRouteIds);
    const onRoute = fresh.filter((v) => v.routeId !== null && routeIds.has(v.routeId));

    // Direction coord array for the projection path, built lazily once per
    // hit. null = at least one stop lacks coordinates → projection disabled.
    let coords: LatLon[] | null | undefined;
    const coordsFor = (): LatLon[] | null => {
      if (coords === undefined) {
        const built: LatLon[] = [];
        for (const s of hit.stops) {
          const c = stopCoords(s.stopId);
          if (c === null) return (coords = null);
          built.push(c);
        }
        coords = built;
      }
      return coords;
    };

    let best: ArrivalRow | null = null;

    for (const v of onRoute) {
      const cand = v.stopId
        ? await exactCandidate(hit, stopId, v, travelTimeLookup)
        : await projectedCandidate(hit, stopId, v, coordsFor(), travelTimeLookup);
      if (cand === null) continue;
      best = better(best, cand);
      if (best.state === 'arriving') break; // arriving always wins
    }

    if (best === null) {
      scheduled ??= await scheduleLookup();
      const fallback = scheduled.find((s) => s.destination === hit.destination);
      best = {
        serviceId: hit.serviceId,
        line: hit.line,
        destination: hit.destination,
        state: 'scheduled',
        etaMinutes: fallback?.etaMinutes ?? null,
        vehicleId: null,
        source: 'schedule',
      };
    }
    rows.push(best);
  }
  return rows;
}

/**
 * Shared priority reducer for both candidate paths (exact stop_id and
 * geometric projection): arriving > nearest eta > departed. Ties between
 * equal etas go to the later vehicle (`<=`); departed never displaces
 * anything.
 */
function better(best: ArrivalRow | null, cand: ArrivalRow): ArrivalRow {
  if (best === null || cand.state === 'arriving') return cand;
  if (cand.state === 'eta'
      && (best.state === 'departed' || (best.state === 'eta' && cand.etaMinutes! <= best.etaMinutes!))) {
    return cand;
  }
  return best;
}

/** Candidate from a feed-provided stop_id (exact membership in the sequence). */
async function exactCandidate(
  hit: StopServiceHit,
  stopId: string,
  v: VehiclePosition,
  travelTimeLookup: (fromStopId: string, toStopId: string) => Promise<number | null>,
): Promise<ArrivalRow | null> {
  if (v.stopId === stopId) return row(hit, 'arriving', null, v.vehicleId);

  // Upstream: next stop is k positions before ours in this direction.
  for (let k = 1; k <= Math.min(MAX_UPSTREAM_HOPS, hit.position); k++) {
    if (v.stopId === hit.stops[hit.position - k]!.stopId) {
      return row(hit, 'eta', await etaMinutes(travelTimeLookup, v.stopId!, stopId, k), v.vehicleId);
    }
  }

  // Departed: next stop is the one right after ours.
  if (hit.position + 1 < hit.stops.length && v.stopId === hit.stops[hit.position + 1]!.stopId) {
    return row(hit, 'departed', null, v.vehicleId);
  }
  return null;
}

/**
 * Candidate inferred geometrically: project the vehicle's lat/lon onto the
 * direction's stop sequence and reason about the resulting next-stop index
 * relative to ours. Off-route vehicles (projection null) yield nothing.
 */
async function projectedCandidate(
  hit: StopServiceHit,
  stopId: string,
  v: VehiclePosition,
  coords: LatLon[] | null,
  travelTimeLookup: (fromStopId: string, toStopId: string) => Promise<number | null>,
): Promise<ArrivalRow | null> {
  if (v.lat === null || v.lon === null || coords === null) return null;
  const pos = projectOntoSequence({ lat: v.lat, lon: v.lon }, coords, MAX_OFF_ROUTE_METERS);
  if (pos === null) return null;

  // Our stop is the vehicle's next stop.
  if (pos.nextIndex === hit.position) {
    if (pos.metersToNext <= ARRIVING_RADIUS_METERS) return row(hit, 'arriving', null, v.vehicleId);
    // Mid-segment but not yet close: charge the full previous-segment travel
    // time. This overestimates by at most one segment's worth (the part the
    // vehicle has already covered) — acceptable, and it errs on the side of
    // the rider not missing the bus. At position 0 there is no previous
    // segment, so use the flat per-hop fallback.
    const eta = hit.position > 0
      ? await etaMinutes(travelTimeLookup, hit.stops[hit.position - 1]!.stopId, stopId, 1)
      : FALLBACK_MINUTES_PER_HOP;
    return row(hit, 'eta', eta, v.vehicleId);
  }

  // Upstream: vehicle's next stop is `hops` positions before ours.
  const hops = hit.position - pos.nextIndex;
  if (hops >= 1 && hops <= MAX_UPSTREAM_HOPS) {
    return row(hit, 'eta', await etaMinutes(travelTimeLookup, hit.stops[pos.nextIndex]!.stopId, stopId, hops), v.vehicleId);
  }

  // Departed: just past our stop, still within the useful radius.
  if (pos.nextIndex === hit.position + 1 && pos.metersPastPrev <= DEPARTED_RADIUS_METERS) {
    return row(hit, 'departed', null, v.vehicleId);
  }
  return null;
}

/** Scheduled minutes from→to, falling back to hops × flat per-hop estimate; floored at 1. */
async function etaMinutes(
  travelTimeLookup: (fromStopId: string, toStopId: string) => Promise<number | null>,
  fromStopId: string,
  toStopId: string,
  hops: number,
): Promise<number> {
  const scheduledMin = await travelTimeLookup(fromStopId, toStopId);
  return Math.max(1, scheduledMin ?? hops * FALLBACK_MINUTES_PER_HOP);
}

function row(hit: StopServiceHit, state: ArrivalState, etaMinutes: number | null, vehicleId: string | null): ArrivalRow {
  return {
    serviceId: hit.serviceId,
    line: hit.line,
    destination: hit.destination,
    state,
    etaMinutes,
    vehicleId,
    source: 'realtime',
  };
}

// ============================================================================
// /arrivals handler + pure helpers
// ============================================================================

const ARRIVALS_CACHE_TTL = 20; // seconds — matches the feed TTL on purpose

/**
 * Map raw schedule arrivals to per-destination fallbacks.
 *
 * Matching is by gtfsRouteIds first: vendor headsigns are just "Ida"/"Volta",
 * so at platforms shared by several services (e.g. L4 Pantitlán vs Alameda
 * Oriente eastbound, both "Volta") headsigns cannot distinguish them — only
 * the route id can. Headsign matching remains as a fallback for arrivals
 * cached before routeId existed (and as a defensive net).
 *
 * Arrivals matching nothing in the cenefa dataset are silently dropped.
 * When multiple trips serve the same destination, only the earliest eta is kept.
 */
export function scheduleToFallbacks(
  arrivals: ScheduledArrival[],
  hits: StopServiceHit[],
  nowMinutes: number,
): ScheduledFallback[] {
  const byDestination = new Map<string, number>();
  for (const a of arrivals) {
    if (a.arrivalMinutes < nowMinutes) continue;
    const hit = a.routeId != null
      ? hits.find((h) => h.gtfsRouteIds.includes(a.routeId!))
      : a.headsign
        ? hits.find((h) => h.gtfsHeadsigns.includes(a.headsign!))
        : undefined;
    if (!hit) continue;
    const eta = a.arrivalMinutes - nowMinutes;
    const existing = byDestination.get(hit.destination);
    if (existing === undefined || eta < existing) byDestination.set(hit.destination, eta);
  }
  return [...byDestination.entries()].map(([destination, etaMinutes]) => ({ destination, etaMinutes }));
}

/**
 * GET /arrivals?stop=<id>
 *
 * Contract for stops not covered by the cenefa dataset (e.g. after an
 * operator GTFS update renames stop ids, before re-curation): 200 + warning
 * + empty rows. Clients (ArrivalsService) treat empty rows as "fall back to
 * the schedule-only path (GTFSScheduleService)". This is a deliberate
 * deviation from spec §4.4: synthesizing rows from raw vendor headsigns
 * would surface "Ida/Volta" as destinations.
 */
export async function handleArrivals(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const url = new URL(request.url);
  const stopId = url.searchParams.get('stop');
  if (!stopId) return arrivalsJson({ error: 'stop query param required' }, 400);

  // Per-stop Cache-API, same pattern as the feed cache in realtime-handlers.
  const cache = caches.default;
  const cacheKey = new Request(`https://internal.parabus/arrivals?stop=${encodeURIComponent(stopId)}`);
  const hit = await cache.match(cacheKey);
  if (hit) return new Response(hit.body, hit);

  const hits = stopIndex().get(stopId) ?? [];
  const { feed } = await getDecodedFeed(env, ctx);
  const nowSeconds = Math.floor(Date.now() / 1000);

  // Stop coordinates for the geometric projection path (the feed carries no
  // stop_id). Meta is KV-cached + isolate-memoized; load once per request.
  // Unavailable meta degrades projection to scheduled fallbacks, as before.
  const meta = await loadStaticMeta(env);
  const stopCoords = (id: string): LatLon | null => {
    const s = meta?.stops[id];
    return s ? { lat: s.lat, lon: s.lon } : null;
  };

  const travelTimeLookup = async (from: string, to: string): Promise<number | null> => {
    const [a, b] = await Promise.all([loadStopSchedule(env, from), loadStopSchedule(env, to)]);
    if (!a || !b) return null; // don't trigger zip downloads on the eta path
    return travelTime(a, b);
  };

  const scheduleLookup = async (): Promise<ScheduledFallback[]> => {
    let arrivals = await loadStopSchedule(env, stopId);
    if (arrivals === null) {
      try { arrivals = await populateStopSchedule(env, stopId); }
      catch { return []; }
    }
    const nowMinutes = currentCDMXMinutes();
    return scheduleToFallbacks(nextArrivals(arrivals, nowMinutes, 20), hits, nowMinutes);
  };

  // feedTimestamp is number|null in DecodedFeed. When null (feed header missing
  // timestamp), fall back to 0 — this makes feedAgeSeconds large and
  // realtimeStale=true, which correctly forces all rows to scheduled-only.
  // Conservative but honest: we never show stale realtime data as fresh.
  const feedTimestamp = feed?.feedTimestamp ?? 0;
  const rows = await deriveArrivalRows(
    stopIndex(), stopId, feed?.vehicles ?? [], feedTimestamp, nowSeconds,
    stopCoords, travelTimeLookup, scheduleLookup,
  );

  const body = {
    serviceActive: feed !== null,
    feedTimestamp: feed?.feedTimestamp ?? null,
    feedAgeSeconds: feed ? Math.max(0, nowSeconds - feedTimestamp) : null,
    // A null feed (partner down / outside service hours) is also "stale":
    // clients get one consistent "don't trust realtime" signal either way.
    realtimeStale: feed === null || nowSeconds - feedTimestamp > FEED_STALE_SECONDS,
    stop: stopId,
    warning: hits.length === 0 ? 'stop not covered by cenefa dataset' : undefined,
    rows,
  };

  const response = arrivalsJson(body, 200);
  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}

function arrivalsJson(data: unknown, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json; charset=utf-8',
      // Errors must never linger in client/CDN caches.
      'Cache-Control': status === 200 ? `public, max-age=${ARRIVALS_CACHE_TTL}` : 'no-store',
    },
  });
}
