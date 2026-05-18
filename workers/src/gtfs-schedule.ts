/**
 * Per-stop schedule index lazily populated from GTFS `stop_times.txt`.
 *
 * Architectural note (REVIEW HIGH-16 follow-up): an earlier version parsed
 * all ~1M rows + wrote 376 KV entries in one go during the daily cron, but
 * that exceeded Workers' resource limits (error 1102) for the partner zip
 * size. This implementation flips to lazy per-stop: each cold request
 * downloads the zip, stream-scans `stop_times.txt` for ONE stop's rows
 * (bounded memory), writes a single KV entry, returns. Subsequent reads
 * for the same stop hit KV (<10ms). With Metrobús's ~376 stops and typical
 * iOS user pattern of 2-4 favorite stops, cold-misses converge quickly.
 *
 * Endpoints:
 *   GET /static/schedule?stop=<id>&limit=<N>
 *     → next N arrivals at that stop based on current CDMX-local time
 *   GET /static/travel-time?from=<a>&to=<b>
 *     → average travel time in minutes between two stops on common trips
 */

import type { Env } from './types';
import { extractZipFiles } from './gtfs-static';
import { fetchStaticZip } from './partner-client';

export interface ScheduledArrival {
  tripId: string;
  arrivalMinutes: number;
  sequence: number;
}

const KV_STOP_PREFIX = 'gtfs:schedule:';
const KV_TTL_SECONDS = 30 * 60 * 60; // 30h — matches static GTFS refresh window

// ============================================================================
// Pure functions (exported for testing)
// ============================================================================

/**
 * Parse stop_times.txt as a CSV string, returning all arrivals grouped by
 * `stop_id`. Use only when you actually need every stop; for single-stop
 * lookups prefer `filterStopTimes` (bounded memory).
 *
 * The header column order varies between Sinoptico revisions, so columns
 * are looked up by name rather than positional index.
 */
export function parseStopTimes(csv: string): Record<string, ScheduledArrival[]> {
  const { tripCol, arrivalCol, stopCol, seqCol, bodyStart } = parseHeader(csv);
  const out: Record<string, ScheduledArrival[]> = {};

  let pos = bodyStart;
  while (pos < csv.length) {
    const eol = csv.indexOf('\n', pos);
    const lineEnd = eol === -1 ? csv.length : eol;
    const row = parseRow(csv, pos, lineEnd, tripCol, arrivalCol, stopCol, seqCol);
    if (row) {
      (out[row.stopId] ??= []).push(row.arrival);
    }
    pos = lineEnd + 1;
  }
  return out;
}

/**
 * Stream-scan version: yields arrivals only for `wantedStopId`. Avoids
 * building the full all-stops dict in memory.
 */
export function filterStopTimes(csv: string, wantedStopId: string): ScheduledArrival[] {
  const { tripCol, arrivalCol, stopCol, seqCol, bodyStart } = parseHeader(csv);
  const out: ScheduledArrival[] = [];

  let pos = bodyStart;
  while (pos < csv.length) {
    const eol = csv.indexOf('\n', pos);
    const lineEnd = eol === -1 ? csv.length : eol;
    const row = parseRow(csv, pos, lineEnd, tripCol, arrivalCol, stopCol, seqCol);
    if (row && row.stopId === wantedStopId) {
      out.push(row.arrival);
    }
    pos = lineEnd + 1;
  }
  return out;
}

/** HH:MM[:SS] → minutes from midnight. >24h wraps modulo 24 (matches iOS). */
export function parseTime(s: string): number | null {
  const parts = s.split(':');
  if (parts.length < 2) return null;
  const h = parseInt(parts[0]!, 10);
  const m = parseInt(parts[1]!, 10);
  if (!isFinite(h) || !isFinite(m)) return null;
  return (h % 24) * 60 + m;
}

/**
 * Next N arrivals at a stop after `nowMinutes`. Arrivals must be pre-sorted
 * by arrivalMinutes ascending; the worker writes them sorted to KV.
 */
export function nextArrivals(
  arrivals: ScheduledArrival[],
  nowMinutes: number,
  limit: number,
): ScheduledArrival[] {
  const out: ScheduledArrival[] = [];
  for (const a of arrivals) {
    if (a.arrivalMinutes < nowMinutes) continue;
    out.push(a);
    if (out.length >= limit) break;
  }
  return out;
}

/**
 * Average forward-direction travel time in minutes between two stops on the
 * same trip. Returns null if the stops never share a trip.
 */
export function travelTime(
  origin: ScheduledArrival[],
  destination: ScheduledArrival[],
): number | null {
  const destByTrip = new Map<string, ScheduledArrival>();
  for (const a of destination) {
    const existing = destByTrip.get(a.tripId);
    if (!existing || a.sequence < existing.sequence) {
      destByTrip.set(a.tripId, a);
    }
  }

  let total = 0;
  let count = 0;
  for (const o of origin) {
    const d = destByTrip.get(o.tripId);
    if (!d) continue;
    const diff = d.arrivalMinutes - o.arrivalMinutes;
    if (diff > 0) {
      total += diff;
      count += 1;
    }
  }
  return count > 0 ? Math.round(total / count) : null;
}

// ============================================================================
// KV read + lazy populate
// ============================================================================

/** Read one stop's full sorted arrival list from KV. Null if not cached. */
export async function loadStopSchedule(env: Env, stopId: string): Promise<ScheduledArrival[] | null> {
  const raw = await env.METROBUS_CACHE.get(KV_STOP_PREFIX + stopId);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as ScheduledArrival[];
  } catch {
    return null;
  }
}

/**
 * Populate KV for one stop on demand: download the zip, extract stop_times,
 * filter for `stopId` only, sort, store. Returns the sorted arrivals.
 *
 * This is the per-stop fallback when KV doesn't have the entry yet. Bounded
 * memory: only one stop's arrivals (typically ~3000 rows × ~80 bytes JSON =
 * ~250KB) lives in memory at a time, vs ~30MB for the all-stops dict.
 */
export async function populateStopSchedule(env: Env, stopId: string): Promise<ScheduledArrival[]> {
  const dl = await fetchStaticZip(env);
  if (!dl) {
    throw new Error('partner service inactive — cannot populate schedule');
  }
  const files = await extractZipFiles(dl.bytes, ['stop_times.txt']);
  const csv = files.get('stop_times.txt');
  if (!csv) {
    throw new Error('stop_times.txt missing from partner zip');
  }

  const arrivals = filterStopTimes(csv, stopId);
  arrivals.sort((a, b) => a.arrivalMinutes - b.arrivalMinutes);

  await env.METROBUS_CACHE.put(
    KV_STOP_PREFIX + stopId,
    JSON.stringify(arrivals),
    { expirationTtl: KV_TTL_SECONDS },
  );
  return arrivals;
}

// ============================================================================
// HTTP handlers
// ============================================================================

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

/** GET /static/schedule?stop=<id>&limit=<N> */
export async function handleSchedule(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const stopId = url.searchParams.get('stop');
  const limit = Math.max(1, Math.min(10, parseInt(url.searchParams.get('limit') ?? '3', 10) || 3));

  if (!stopId) {
    return jsonResponse({ error: 'stop query param required' }, 400);
  }

  let arrivals = await loadStopSchedule(env, stopId);
  let warmed = false;

  if (arrivals === null) {
    try {
      arrivals = await populateStopSchedule(env, stopId);
      warmed = true;
    } catch (err) {
      console.error(`schedule: populate failed for ${stopId}:`, err);
      return jsonResponse({
        error: 'schedule not available; partner service may be offline',
        stop: stopId,
      }, 503);
    }
  }

  if (arrivals.length === 0) {
    return jsonResponse({
      stop: stopId,
      count: 0,
      arrivals: [],
      message: 'no arrivals indexed for this stop',
    }, 404);
  }

  const now = currentCDMXMinutes();
  const next = nextArrivals(arrivals, now, limit);
  return jsonResponse({
    stop: stopId,
    nowMinutes: now,
    count: next.length,
    warmed, // tells callers if this was a cold miss (so they can log latency)
    arrivals: next,
  });
}

/** GET /static/travel-time?from=<a>&to=<b> */
export async function handleTravelTime(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const fromId = url.searchParams.get('from');
  const toId = url.searchParams.get('to');

  if (!fromId || !toId) {
    return jsonResponse({ error: 'from and to query params required' }, 400);
  }

  // Read both in parallel; populate cold sides serially to avoid two
  // concurrent zip downloads.
  let [from, to] = await Promise.all([
    loadStopSchedule(env, fromId),
    loadStopSchedule(env, toId),
  ]);

  try {
    if (from === null) from = await populateStopSchedule(env, fromId);
    if (to === null) to = await populateStopSchedule(env, toId);
  } catch (err) {
    console.error('travel-time populate failed:', err);
    return jsonResponse({
      error: 'schedule not available; partner service may be offline',
      from: fromId,
      to: toId,
    }, 503);
  }

  const minutes = travelTime(from, to);
  return jsonResponse({
    from: fromId,
    to: toId,
    travelTimeMinutes: minutes,
  });
}

// ============================================================================
// CSV row parsing internals
// ============================================================================

interface HeaderIndices {
  tripCol: number;
  arrivalCol: number;
  stopCol: number;
  seqCol: number;
  bodyStart: number;
}

function parseHeader(csv: string): HeaderIndices {
  const eol = csv.indexOf('\n');
  if (eol === -1) {
    throw new Error('stop_times.txt: empty or header-only');
  }
  const headerLine = csv.slice(0, eol).replace(/\r$/, '');
  const cols = headerLine.split(',');
  const tripCol = cols.indexOf('trip_id');
  const arrivalCol = cols.indexOf('arrival_time');
  const stopCol = cols.indexOf('stop_id');
  const seqCol = cols.indexOf('stop_sequence');
  if (tripCol < 0 || arrivalCol < 0 || stopCol < 0 || seqCol < 0) {
    throw new Error(`stop_times.txt: missing required columns (have: ${cols.join(',')})`);
  }
  return { tripCol, arrivalCol, stopCol, seqCol, bodyStart: eol + 1 };
}

function parseRow(
  csv: string,
  start: number,
  end: number,
  tripCol: number,
  arrivalCol: number,
  stopCol: number,
  seqCol: number,
): { stopId: string; arrival: ScheduledArrival } | null {
  if (end <= start) return null;
  // stop_times.txt is well-formed comma CSV from Sinoptico — no quoted commas
  // in the columns we care about, so split is safe and ~3x faster than the
  // generic parseCsv state machine.
  const line = csv.slice(start, end);
  if (line.length === 0 || line === '\r') return null;
  const fields = line.replace(/\r$/, '').split(',');
  const tripId = fields[tripCol];
  const stopId = fields[stopCol];
  if (!tripId || !stopId) return null;
  const arrivalMinutes = parseTime(fields[arrivalCol] ?? '');
  if (arrivalMinutes === null) return null;
  const sequence = parseInt(fields[seqCol] ?? '0', 10) || 0;
  return { stopId, arrival: { tripId, arrivalMinutes, sequence } };
}

/**
 * Current time in minutes from midnight in Mexico City local time. Uses the
 * `America/Mexico_City` timezone for correct DST handling.
 */
function currentCDMXMinutes(): number {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Mexico_City',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const parts = fmt.formatToParts(new Date());
  const h = parseInt(parts.find((p) => p.type === 'hour')?.value ?? '0', 10);
  const m = parseInt(parts.find((p) => p.type === 'minute')?.value ?? '0', 10);
  return h * 60 + m;
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...CORS,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=60',
    },
  });
}
