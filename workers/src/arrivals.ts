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
 *   vehicle.stopId == our stop          → arriving
 *   vehicle.stopId k hops upstream      → eta (Σ scheduled hop times)
 *   vehicle.stopId == stop after ours   → departed
 * Priority within a direction: arriving > nearest eta > departed.
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

    let best: ArrivalRow | null = null;

    for (const v of onRoute) {
      if (!v.stopId) continue;

      if (v.stopId === stopId) {
        best = row(hit, 'arriving', null, v.vehicleId);
        break; // arriving always wins
      }

      // Upstream: next stop is k positions before ours in this direction.
      for (let k = 1; k <= Math.min(MAX_UPSTREAM_HOPS, hit.position); k++) {
        if (v.stopId === hit.stops[hit.position - k]!.stopId) {
          const scheduledMin = await travelTimeLookup(v.stopId, stopId);
          const eta = Math.max(1, scheduledMin ?? k * FALLBACK_MINUTES_PER_HOP);
          if (best === null || best.state === 'departed' || (best.state === 'eta' && eta <= best.etaMinutes!)) {
            best = row(hit, 'eta', eta, v.vehicleId);
          }
          break;
        }
      }

      // Departed: next stop is the one right after ours.
      if (hit.position + 1 < hit.stops.length
          && v.stopId === hit.stops[hit.position + 1]!.stopId
          && best === null) {
        best = row(hit, 'departed', null, v.vehicleId);
      }
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
 * Map raw schedule arrivals to per-destination fallbacks using gtfsHeadsigns.
 * Arrivals with no matching headsign in the cenefa dataset are silently dropped.
 * When multiple trips serve the same destination, only the earliest eta is kept.
 */
export function scheduleToFallbacks(
  arrivals: ScheduledArrival[],
  hits: StopServiceHit[],
  nowMinutes: number,
): ScheduledFallback[] {
  const byDestination = new Map<string, number>();
  for (const a of arrivals) {
    if (!a.headsign || a.arrivalMinutes < nowMinutes) continue;
    const hit = hits.find((h) => h.gtfsHeadsigns.includes(a.headsign!));
    if (!hit) continue;
    const eta = a.arrivalMinutes - nowMinutes;
    const existing = byDestination.get(hit.destination);
    if (existing === undefined || eta < existing) byDestination.set(hit.destination, eta);
  }
  return [...byDestination.entries()].map(([destination, etaMinutes]) => ({ destination, etaMinutes }));
}

/** GET /arrivals?stop=<id> */
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
    travelTimeLookup, scheduleLookup,
  );

  const body = {
    serviceActive: feed !== null,
    feedTimestamp: feed?.feedTimestamp ?? null,
    feedAgeSeconds: feed ? Math.max(0, nowSeconds - feedTimestamp) : null,
    realtimeStale: feed !== null && nowSeconds - feedTimestamp > FEED_STALE_SECONDS,
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
