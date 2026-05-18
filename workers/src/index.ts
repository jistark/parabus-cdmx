/**
 * Metrobus CDMX Status API - Cloudflare Worker
 *
 * Provides real-time status information for Metrobus CDMX lines,
 * including incidents, maintenance closures, and elevator outages.
 *
 * Endpoints:
 *   GET /status - Full status data (cached)
 *   GET /health - Health check
 */

import {
  Env,
  MetrobusResponse,
  HealthResponse,
  CachedData,
  CACHE_KEY,
  CACHE_TTL_SECONDS,
} from './types';

import {
  scrapeAll,
  filterLines,
  filterMaintenance,
  filterElevators,
} from './scraper';

import {
  handleVehicles,
  handleTrip,
  handleEtas,
  prewarmRealtime,
} from './realtime-handlers';

import {
  handleStaticRoutes,
  handleStaticStops,
  refreshStaticGtfs,
} from './gtfs-static';

import {
  handleSchedule,
  handleTravelTime,
} from './gtfs-schedule';

// ============================================================================
// CORS Headers
// ============================================================================

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Max-Age': '86400',
};

// ============================================================================
// Main Entry Point
// ============================================================================

export default {
  /**
   * Handle incoming HTTP requests. The third argument is the runtime's
   * ExecutionContext; we pass it to handlers so they can wrap non-critical
   * writes (cache puts, KV puts) in ctx.waitUntil — letting the response
   * return before those writes complete.
   */
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // Handle CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // Admin: force-refresh static GTFS (gated by JDV_BOT_SECRET as a
      // shared bearer; reuses an existing secret instead of adding one).
      // Accepts both GET and POST — auth is the actual gate.
      if (path === '/admin/refresh-static') {
        const auth = request.headers.get('authorization') ?? '';
        const presented = auth.startsWith('Bearer ') ? auth.slice(7) : '';
        if (!env.JDV_BOT_SECRET || presented !== env.JDV_BOT_SECRET) {
          return jsonResponse({ error: 'unauthorized' }, 401);
        }
        const meta = await refreshStaticGtfs(env);
        if (!meta) {
          return jsonResponse({ refreshed: false, reason: 'partner service inactive' }, 503);
        }
        return jsonResponse({
          refreshed: true,
          generatedAt: meta.generatedAt,
          routes: Object.keys(meta.routes).length,
          stops: Object.keys(meta.stops).length,
          lines: Object.keys(meta.lineRoutes),
        });
      }

      // All other endpoints are GET-only
      if (request.method !== 'GET') {
        return jsonResponse({ error: 'Method not allowed' }, 405);
      }

      // Trip detail: /trip/{trip_id}
      if (path.startsWith('/trip/')) {
        const tripId = decodeURIComponent(path.slice('/trip/'.length));
        if (!tripId) return jsonResponse({ error: 'trip_id required' }, 400);
        return await handleTrip(request, env, ctx, tripId);
      }

      switch (path) {
        case '/status':
          return await handleStatus(request, env, ctx);

        case '/health':
          return await handleHealth(env);

        case '/vehicles':
          return await handleVehicles(request, env, ctx);

        case '/etas':
          return await handleEtas(request, env, ctx);

        case '/static/routes':
          return await handleStaticRoutes(env);

        case '/static/stops':
          return await handleStaticStops(env);

        case '/static/schedule':
          return await handleSchedule(request, env);

        case '/static/travel-time':
          return await handleTravelTime(request, env);

        case '/':
          return jsonResponse({
            name: 'Metrobus CDMX Status API',
            version: '2.0.0',
            endpoints: {
              '/status': 'GET — Operator-declared status (incidents, maintenance)',
              '/health': 'GET — Health check + cache age',
              '/vehicles': 'GET — Realtime vehicle positions. Query: ?line=1',
              '/trip/{trip_id}': 'GET — Single vehicle currently serving a trip',
              '/etas': 'GET — Vehicles approaching a stop. Query: ?stop=<id>',
              '/static/routes': 'GET — Routes catalog from daily GTFS',
              '/static/stops': 'GET — Stops catalog from daily GTFS',
              '/static/schedule': 'GET — Next arrivals at a stop. Query: ?stop=<id>&limit=N',
              '/static/travel-time': 'GET — Avg travel time between two stops. Query: ?from=A&to=B',
            },
          });

        default:
          return jsonResponse({ error: 'Not found' }, 404);
      }
    } catch (error) {
      console.error('Unhandled error:', error);
      return jsonResponse(
        { error: 'Internal server error' },
        500
      );
    }
  },

  /**
   * Handle scheduled cron triggers.
   *
   * Multiplex on event.cron — each schedule does a different warm-up:
   *   "30 10 * * *" → pre-warm /status before service starts
   *   "0 6 * * *"   → refresh GTFS static (daily, after Sinoptico midnight regen)
   */
  async scheduled(event: ScheduledController, env: Env): Promise<void> {
    console.log(`Cron triggered: ${event.cron} at ${new Date(event.scheduledTime).toISOString()}`);

    try {
      if (event.cron === '0 6 * * *') {
        await refreshStaticGtfs(env);
        console.log('GTFS static refreshed');
        return;
      }

      if (event.cron === '*/2 * * * *') {
        await prewarmRealtime(env);
        return;
      }

      // Default: status pre-warm (cron "30 10 * * *" and any other config)
      const result = await scrapeAll(env);

      const response: MetrobusResponse = {
        lastUpdated: new Date().toISOString(),
        sourceTimestamp: result.incidentes.sourceTimestamp,
        sources: {
          incidentes: {
            available: result.incidentes.success,
            error: result.incidentes.error,
          },
          mantenimiento: {
            available: result.mantenimiento.success,
            error: result.mantenimiento.error,
          },
        },
        lines: result.incidentes.lines,
        scheduledMaintenance: result.mantenimiento.maintenance,
        elevators: result.mantenimiento.elevators,
      };

      const cached: CachedData = {
        data: response,
        timestamp: Date.now(),
      };

      await env.METROBUS_CACHE.put(CACHE_KEY, JSON.stringify(cached), {
        expirationTtl: CACHE_TTL_SECONDS * 2,
      });

      console.log('Status cache pre-warmed');

      const hasIssues =
        response.lines.some((l) => l.status !== 'normal') ||
        response.scheduledMaintenance.length > 0 ||
        response.elevators.length > 0;

      if (hasIssues) {
        console.log('Issues detected:', {
          disruptedLines: response.lines.filter((l) => l.status !== 'normal').length,
          maintenanceCount: response.scheduledMaintenance.length,
          elevatorCount: response.elevators.length,
        });
      }
    } catch (error) {
      console.error('Cron job failed:', error);
    }
  },
};

// ============================================================================
// Route Handlers
// ============================================================================

/**
 * Handle GET /status
 *
 * Query params:
 *   - refresh=true: Bypass cache and fetch fresh data
 *   - lines=1,3,5: Filter to specific lines
 */
async function handleStatus(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const url = new URL(request.url);
  const forceRefresh = url.searchParams.get('refresh') === 'true';
  const linesParam = url.searchParams.get('lines');
  const lineFilter = linesParam ? linesParam.split(',').map((l) => l.trim()) : [];

  let response: MetrobusResponse | null = null;
  let fromCache = false;
  let cacheAge = 0;

  // Check cache first (unless refresh is requested)
  if (!forceRefresh) {
    const cached = await getFromCache(env);
    if (cached && !isCacheStale(cached.timestamp)) {
      response = cached.data;
      fromCache = true;
      cacheAge = Math.floor((Date.now() - cached.timestamp) / 1000);
    }
  }

  // Fetch fresh data if not cached or refresh requested
  if (!response) {
    try {
      const result = await scrapeAll(env);

      response = {
        lastUpdated: new Date().toISOString(),
        sourceTimestamp: result.incidentes.sourceTimestamp,
        sources: {
          incidentes: {
            available: result.incidentes.success,
            error: result.incidentes.error,
          },
          mantenimiento: {
            available: result.mantenimiento.success,
            error: result.mantenimiento.error,
          },
        },
        lines: result.incidentes.lines,
        scheduledMaintenance: result.mantenimiento.maintenance,
        elevators: result.mantenimiento.elevators,
      };

      // Store in cache off the hot path — the response can return immediately
      // and KV write completes in the background. Only write on full success;
      // partial-failure responses (one source down) shouldn't evict a healthy
      // cached snapshot.
      if (result.incidentes.success && result.mantenimiento.success) {
        ctx.waitUntil(saveToCache(env, response));
      }
    } catch (error) {
      // Try to serve stale cache on error
      const staleCache = await getFromCache(env);
      if (staleCache) {
        response = {
          ...staleCache.data,
          stale: true,
          error: 'Failed to fetch fresh data, serving cached response',
        };
        cacheAge = Math.floor((Date.now() - staleCache.timestamp) / 1000);
        fromCache = true;
      } else {
        // No cache available, return error response
        response = {
          lastUpdated: new Date().toISOString(),
          sourceTimestamp: null,
          error: 'Service temporarily unavailable',
          sources: {
            incidentes: { available: false, error: 'Fetch failed' },
            mantenimiento: { available: false, error: 'Fetch failed' },
          },
          lines: [],
          scheduledMaintenance: [],
          elevators: [],
        };
      }
    }
  }

  // Apply line filter if specified
  if (lineFilter.length > 0) {
    response = {
      ...response,
      lines: filterLines(response.lines, lineFilter),
      scheduledMaintenance: filterMaintenance(response.scheduledMaintenance, lineFilter),
      elevators: filterElevators(response.elevators, lineFilter),
    };
  }

  // Build response headers
  const headers: Record<string, string> = {
    ...CORS_HEADERS,
    'Content-Type': 'application/json; charset=utf-8',
    'X-Cache': fromCache ? 'HIT' : 'MISS',
    'X-Cache-Age': String(cacheAge),
    'Cache-Control': 'public, max-age=60',
  };

  return new Response(JSON.stringify(response, null, 2), {
    status: 200,
    headers,
  });
}

/**
 * Handle GET /health
 */
async function handleHealth(env: Env): Promise<Response> {
  const cached = await getFromCache(env);
  const cacheAge = cached ? Math.floor((Date.now() - cached.timestamp) / 1000) : null;

  const health: HealthResponse = {
    status: cached ? 'ok' : 'degraded',
    timestamp: new Date().toISOString(),
    cacheAge,
  };

  return jsonResponse(health);
}

// ============================================================================
// Cache Functions
// ============================================================================

/**
 * Get data from KV cache
 */
async function getFromCache(env: Env): Promise<CachedData | null> {
  try {
    const cached = await env.METROBUS_CACHE.get(CACHE_KEY);
    if (!cached) return null;

    return JSON.parse(cached) as CachedData;
  } catch (error) {
    console.error('Error reading from cache:', error);
    return null;
  }
}

/**
 * Save data to KV cache
 */
async function saveToCache(env: Env, data: MetrobusResponse): Promise<void> {
  try {
    const cached: CachedData = {
      data,
      timestamp: Date.now(),
    };

    await env.METROBUS_CACHE.put(CACHE_KEY, JSON.stringify(cached), {
      expirationTtl: CACHE_TTL_SECONDS,
    });
  } catch (error) {
    console.error('Error saving to cache:', error);
  }
}

/**
 * Check if cached data is stale
 */
function isCacheStale(timestamp: number): boolean {
  const ageMs = Date.now() - timestamp;
  return ageMs > CACHE_TTL_SECONDS * 1000;
}

// ============================================================================
// Response Helpers
// ============================================================================

/**
 * Create a JSON response with CORS headers
 */
function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json; charset=utf-8',
    },
  });
}

