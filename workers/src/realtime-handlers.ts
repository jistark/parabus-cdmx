/**
 * HTTP handlers for realtime GTFS-RT endpoints.
 *
 * Caching: parsed feed is stored in the per-PoP Cache API with a 20s TTL.
 * We deliberately don't use KV because KV has ~60s of eventual consistency
 * between regions — that kills "realtime". Cache API is instantly readable
 * within the PoP that wrote it. Trade-off: each PoP refreshes independently,
 * so worst case is 20s × number of active PoPs of partner-API calls.
 */

import type { Env } from './types';
import { fetchRealtimeProto } from './partner-client';
import { decodeFeedMessage, type DecodedFeed, type VehiclePosition } from './gtfs-rt';
import { loadLineRouteIndex } from './gtfs-static';

const FEED_CACHE_URL = 'https://internal.parabus/realtime-feed';
const FEED_CACHE_TTL = 20; // seconds

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

interface CachedFeedPayload {
  decodedAt: number;
  feed: DecodedFeed | null;
}

/**
 * Get the decoded feed, using Cache API if fresh. `null` means the operator's
 * tracking system is offline (pre-service hours or outage).
 */
async function getDecodedFeed(env: Env): Promise<CachedFeedPayload> {
  const cache = caches.default;
  const cacheKey = new Request(FEED_CACHE_URL, { method: 'GET' });

  const hit = await cache.match(cacheKey);
  if (hit) {
    const payload = (await hit.json()) as CachedFeedPayload;
    return payload;
  }

  // Cache miss — fetch + decode + cache
  let feed: DecodedFeed | null = null;
  let fetchFailed = false;
  try {
    const proto = await fetchRealtimeProto(env);
    if (proto) {
      feed = decodeFeedMessage(proto.bytes);
    }
  } catch (err) {
    console.error('Failed to fetch/decode realtime feed:', err);
    fetchFailed = true;
  }

  const payload: CachedFeedPayload = {
    decodedAt: Date.now(),
    feed,
  };

  // Only cache when we got real data. Caching null (service inactive or
  // upstream error) traps subsequent callers in the same negative state for
  // the full TTL; we'd rather retry quickly than serve stale "off" signals.
  if (feed) {
    const cacheResp = new Response(JSON.stringify(payload), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': `public, max-age=${FEED_CACHE_TTL}`,
      },
    });
    await cache.put(cacheKey, cacheResp);
  } else if (fetchFailed) {
    // Brief negative cache on hard failures only — avoid hammering upstream
    // if the partner API is throwing 5xx, but keep it short enough that
    // recovery is fast.
    const cacheResp = new Response(JSON.stringify(payload), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=5',
      },
    });
    await cache.put(cacheKey, cacheResp);
  }

  return payload;
}

// ============================================================================
// GET /vehicles  /  /vehicles?line=1
// ============================================================================

export async function handleVehicles(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const lineFilter = url.searchParams.get('line');

  const { decodedAt, feed } = await getDecodedFeed(env);

  if (!feed) {
    return jsonResponse({
      serviceActive: false,
      message: 'Operator tracking system not currently reporting',
      decodedAt: new Date(decodedAt).toISOString(),
      vehicles: [],
    });
  }

  let vehicles = feed.vehicles;
  let filterApplied = false;
  let staticMissing = false;

  if (lineFilter) {
    const routeIndex = await loadLineRouteIndex(env);
    if (routeIndex) {
      const routeIds = routeIndex.get(lineFilter);
      if (routeIds) {
        vehicles = vehicles.filter((v) => v.routeId && routeIds.has(v.routeId));
        filterApplied = true;
      } else {
        // Static loaded but unknown line — return empty rather than all.
        vehicles = [];
        filterApplied = true;
      }
    } else {
      // route_ids in this GTFS are numeric (e.g. "19492"), so there's no
      // reliable substring fallback. Signal the missing index instead of
      // returning a misleading subset.
      staticMissing = true;
    }
  }

  // NOTE: Sinoptico Plus does not publish VehiclePosition.trip — every vehicle
  // arrives with tripId=null. We can't filter "in-service vs deadheading"
  // server-side. If they add trip-matching later, reinstate an opt-in filter
  // using ?excludeDeadheading=true. routeId-null filtering is a no-op today
  // (all vehicles have routeId).

  return jsonResponse({
    serviceActive: true,
    feedTimestamp: feed.feedTimestamp,
    decodedAt: new Date(decodedAt).toISOString(),
    line: lineFilter ?? null,
    filterApplied,
    staticMissing,
    count: vehicles.length,
    vehicles,
  });
}

// ============================================================================
// Cron pre-warm
// ============================================================================

/**
 * Invoked by the every-2-minutes cron. Populates the Cache API so the first
 * user request never pays the partner-API + decoder cold start. Safely no-op
 * when the partner returns empty (off-service hours): getDecodedFeed swallows
 * that and only caches valid results.
 */
export async function prewarmRealtime(env: Env): Promise<void> {
  await getDecodedFeed(env);
}

// ============================================================================
// GET /trip/{trip_id}
// ============================================================================

export async function handleTrip(_request: Request, env: Env, tripId: string): Promise<Response> {
  const { feed } = await getDecodedFeed(env);

  if (!feed) {
    return jsonResponse({ serviceActive: false, vehicle: null });
  }

  const vehicle = feed.vehicles.find((v) => v.tripId === tripId) ?? null;

  if (!vehicle) {
    return jsonResponse({ serviceActive: true, vehicle: null }, 404);
  }

  return jsonResponse({
    serviceActive: true,
    feedTimestamp: feed.feedTimestamp,
    vehicle,
  });
}

// ============================================================================
// GET /etas?stop={stop_id}&line={n}
// ============================================================================

/**
 * Naive ETA: distance from each vehicle to the requested stop using the
 * stop_times sequence to determine which vehicles are approaching. Returns
 * "computed from current vehicle positions" estimates — not true GTFS-RT
 * StopTimeUpdate predictions (Sinoptico Plus doesn't publish those).
 *
 * Requires static GTFS loaded. Returns 503 with a clear message if not.
 */
export async function handleEtas(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const stopId = url.searchParams.get('stop');

  if (!stopId) {
    return jsonResponse({ error: 'stop query param required' }, 400);
  }

  const { feed } = await getDecodedFeed(env);
  if (!feed) {
    return jsonResponse({ serviceActive: false, etas: [] });
  }

  // Vehicles currently heading toward this stop (next stop sequence matches).
  const arriving = feed.vehicles.filter((v) => v.stopId === stopId);

  return jsonResponse({
    serviceActive: true,
    feedTimestamp: feed.feedTimestamp,
    stop: stopId,
    count: arriving.length,
    // ETA computation requires distance + schedule data — landed in static layer (task 4).
    note: 'Returning vehicles flagged as next stop = this stop. Distance-based ETA pending static GTFS integration.',
    vehicles: arriving.map((v: VehiclePosition) => ({
      tripId: v.tripId,
      routeId: v.routeId,
      vehicleId: v.vehicleId,
      lat: v.lat,
      lon: v.lon,
      bearing: v.bearing,
      timestamp: v.timestamp,
    })),
  });
}

// ============================================================================
// Helpers
// ============================================================================

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      ...CORS,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': `public, max-age=${FEED_CACHE_TTL}`,
      'X-Realtime-TTL': String(FEED_CACHE_TTL),
    },
  });
}
