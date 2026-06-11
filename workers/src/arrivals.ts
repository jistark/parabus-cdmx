/**
 * /static/cenefas + /arrivals: official service identity and realtime
 * arrival states. State derivation is pure (exported for testing); the
 * handlers stay thin, matching gtfs-schedule.ts house style.
 */
import { CORS_HEADERS } from './types';
import { CENEFAS } from './data/cenefas';
import { buildStopIndex, type StopServiceHit } from './data/cenefas-types';
import type { VehiclePosition } from './gtfs-rt';

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
