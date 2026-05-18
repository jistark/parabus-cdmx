/**
 * GTFS static (zip) parsing + KV-cached indexes.
 *
 * Strategy: download the daily zip from Sinoptico Plus, extract only the
 * CSV files we need (stops.txt, routes.txt), parse them, build O(1) lookup
 * indexes, and store the indexes in KV. Raw CSV is discarded — we never
 * need it again until the next daily refresh.
 *
 * Why no `fflate` dep: Cloudflare Workers exposes DecompressionStream with
 * 'deflate-raw', which is exactly the compression scheme inside zip entries.
 * We parse the zip's central directory by hand (~80 lines) and pipe entry
 * bytes through the platform decompressor — zero dependencies.
 *
 * KV layout:
 *   gtfs:static:meta            → { generatedAt, lineRoutes, routes, stops }
 *   gtfs:static:meta-version    → "YYYYMMDD" pointer to current snapshot
 *
 * stop_times.txt is NOT loaded in this version. ETAs based on schedule
 * require it; ETAs based on vehicle distance to next stop do not.
 */

import type { Env } from './types';
import { fetchStaticZip } from './partner-client';

const KV_META_KEY = 'gtfs:static:meta';
const KV_VERSION_KEY = 'gtfs:static:version';
const KV_TTL_SECONDS = 30 * 60 * 60; // 30h — daily refresh + buffer

export interface RouteMeta {
  routeId: string;
  /** "1", "2", ..., "7" — derived from route_short_name. */
  line: string;
  longName: string;
  /** Hex color without leading "#", from route_color (e.g. "D40D0D"). */
  color: string;
  textColor: string;
}

export interface StopMeta {
  stopId: string;
  name: string;
  lat: number;
  lon: number;
}

export interface GtfsStaticMeta {
  generatedAt: string;
  /** All routes keyed by route_id. */
  routes: Record<string, RouteMeta>;
  /** Inverted index: line ("1" .. "7") → list of route_ids. */
  lineRoutes: Record<string, string[]>;
  /** All stops keyed by stop_id. */
  stops: Record<string, StopMeta>;
}

// ============================================================================
// Public API
// ============================================================================

/**
 * Force a fresh download + parse + KV write. Idempotent; safe to call from cron.
 * Returns the parsed meta on success, or null when the partner service is idle.
 */
export async function refreshStaticGtfs(env: Env): Promise<GtfsStaticMeta | null> {
  const dl = await fetchStaticZip(env);
  if (!dl) return null;

  const files = await extractZipFiles(dl.bytes, ['routes.txt', 'stops.txt']);

  const routesCsv = files.get('routes.txt');
  const stopsCsv = files.get('stops.txt');
  if (!routesCsv) throw new Error('routes.txt missing from GTFS zip');
  if (!stopsCsv) throw new Error('stops.txt missing from GTFS zip');

  const meta: GtfsStaticMeta = {
    generatedAt: dl.generationDateTime,
    routes: parseRoutes(routesCsv),
    lineRoutes: {},
    stops: parseStops(stopsCsv),
  };

  // Build line → routeIds inverted index.
  for (const route of Object.values(meta.routes)) {
    (meta.lineRoutes[route.line] ??= []).push(route.routeId);
  }

  await env.METROBUS_CACHE.put(KV_META_KEY, JSON.stringify(meta), {
    expirationTtl: KV_TTL_SECONDS,
  });
  const versionTag = dl.generationDateTime.slice(0, 10).replace(/-/g, '');
  await env.METROBUS_CACHE.put(KV_VERSION_KEY, versionTag, {
    expirationTtl: KV_TTL_SECONDS,
  });

  // Update the in-isolate memo so the caller (typically admin endpoint or
  // cron) immediately sees the new data without waiting for the next KV read.
  memoVersion = versionTag;
  memoMeta = meta;
  memoLineRouteIndex = null;

  // Schedule data (stop_times.txt) is populated lazily per-stop via the
  // `/static/schedule` endpoint rather than eagerly here — parsing all
  // ~1M rows + 376 KV writes in one cron tick blew the Worker's resource
  // limits (error 1102). Per-stop lazy fits comfortably.

  return meta;
}

// ============================================================================
// Module-scoped memoization
// ============================================================================
//
// loadStaticMeta gets called on every /vehicles?line= request via
// loadLineRouteIndex. The underlying KV read + JSON.parse on a ~100KB blob
// adds 5-50ms to the hot path of an endpoint we already aggressively cache
// in Cache API. Memoize both the parsed meta and the derived line→routeIds
// Map per Worker isolate.
//
// Cache invalidation is keyed by the KV version tag (refreshed daily by the
// 0 6 * * * cron). If the version tag changes, the memo entries are dropped
// and the next call re-reads KV. Worst case: an isolate keeps an entry that
// matches the *current* version tag indefinitely — fine, the data is
// immutable within a day. When the cron writes a new version tag, the next
// isolate-level read picks it up automatically.

let memoVersion: string | null = null;
let memoMeta: GtfsStaticMeta | null = null;
let memoLineRouteIndex: Map<string, Set<string>> | null = null;

async function getCurrentVersion(env: Env): Promise<string | null> {
  return env.METROBUS_CACHE.get(KV_VERSION_KEY);
}

function clearMemo() {
  memoVersion = null;
  memoMeta = null;
  memoLineRouteIndex = null;
}

/** Read the cached meta. Returns null if KV doesn't have it yet. */
export async function loadStaticMeta(env: Env): Promise<GtfsStaticMeta | null> {
  const version = await getCurrentVersion(env);
  if (version && version === memoVersion && memoMeta) {
    return memoMeta;
  }

  const raw = await env.METROBUS_CACHE.get(KV_META_KEY);
  if (!raw) {
    clearMemo();
    return null;
  }
  try {
    const parsed = JSON.parse(raw) as GtfsStaticMeta;
    memoVersion = version;
    memoMeta = parsed;
    memoLineRouteIndex = null; // rebuild lazily in loadLineRouteIndex
    return parsed;
  } catch {
    clearMemo();
    return null;
  }
}

/**
 * Convenience: line → Set<routeId>. Used by realtime-handlers to filter
 * vehicle positions by line. Null when static GTFS hasn't been loaded yet.
 *
 * The derived Map is built once per memo-version cycle (every ~24h), then
 * reused across requests until the next cron refresh swaps versions.
 */
export async function loadLineRouteIndex(env: Env): Promise<Map<string, Set<string>> | null> {
  if (memoLineRouteIndex && memoVersion) {
    const current = await getCurrentVersion(env);
    if (current === memoVersion) return memoLineRouteIndex;
  }

  const meta = await loadStaticMeta(env);
  if (!meta) return null;
  const map = new Map<string, Set<string>>();
  for (const [line, routeIds] of Object.entries(meta.lineRoutes)) {
    map.set(line, new Set(routeIds));
  }
  memoLineRouteIndex = map;
  return map;
}

// ============================================================================
// HTTP handlers
// ============================================================================

const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
};

export async function handleStaticRoutes(env: Env): Promise<Response> {
  const meta = await loadStaticMeta(env);
  if (!meta) {
    return jsonResponse({ error: 'GTFS static not yet cached. Cron will warm it.' }, 503);
  }
  return jsonResponse({
    generatedAt: meta.generatedAt,
    count: Object.keys(meta.routes).length,
    routes: meta.routes,
    lineRoutes: meta.lineRoutes,
  });
}

export async function handleStaticStops(env: Env): Promise<Response> {
  const meta = await loadStaticMeta(env);
  if (!meta) {
    return jsonResponse({ error: 'GTFS static not yet cached. Cron will warm it.' }, 503);
  }
  return jsonResponse({
    generatedAt: meta.generatedAt,
    count: Object.keys(meta.stops).length,
    stops: meta.stops,
  });
}

// ============================================================================
// CSV parsing — minimal, RFC 4180-ish for GTFS files
// ============================================================================
// Exported for unit tests; not part of the public module surface.

export function parseCsv(text: string): { header: string[]; rows: string[][] } {
  const rows: string[][] = [];
  let i = 0;
  let field = '';
  let row: string[] = [];
  let inQuotes = false;

  while (i < text.length) {
    const ch = text[i]!;

    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') {
          field += '"';
          i += 2;
        } else {
          inQuotes = false;
          i++;
        }
      } else {
        field += ch;
        i++;
      }
      continue;
    }

    if (ch === '"') {
      inQuotes = true;
      i++;
    } else if (ch === ',') {
      row.push(field);
      field = '';
      i++;
    } else if (ch === '\n' || ch === '\r') {
      row.push(field);
      field = '';
      if (row.length > 1 || row[0] !== '') rows.push(row);
      row = [];
      if (ch === '\r' && text[i + 1] === '\n') i += 2;
      else i++;
    } else {
      field += ch;
      i++;
    }
  }

  if (field !== '' || row.length > 0) {
    row.push(field);
    if (row.length > 1 || row[0] !== '') rows.push(row);
  }

  const header = rows.shift() ?? [];
  return { header, rows };
}

function parseRoutes(csv: string): Record<string, RouteMeta> {
  const { header, rows } = parseCsv(csv);
  const col = (name: string) => header.indexOf(name);
  const cRouteId = col('route_id');
  const cShort = col('route_short_name');
  const cLong = col('route_long_name');
  const cColor = col('route_color');
  const cTextColor = col('route_text_color');

  const out: Record<string, RouteMeta> = {};
  for (const row of rows) {
    const routeId = row[cRouteId];
    if (!routeId) continue;
    out[routeId] = {
      routeId,
      line: row[cShort] ?? '',
      longName: row[cLong] ?? '',
      color: row[cColor] ?? '',
      textColor: row[cTextColor] ?? '',
    };
  }
  return out;
}

function parseStops(csv: string): Record<string, StopMeta> {
  const { header, rows } = parseCsv(csv);
  const cStopId = header.indexOf('stop_id');
  const cName = header.indexOf('stop_name');
  const cLat = header.indexOf('stop_lat');
  const cLon = header.indexOf('stop_lon');

  const out: Record<string, StopMeta> = {};
  for (const row of rows) {
    const stopId = row[cStopId];
    if (!stopId) continue;
    const lat = parseFloat(row[cLat] ?? '');
    const lon = parseFloat(row[cLon] ?? '');
    if (!isFinite(lat) || !isFinite(lon)) continue;
    out[stopId] = {
      stopId,
      name: row[cName] ?? '',
      lat,
      lon,
    };
  }
  return out;
}

// ============================================================================
// ZIP parsing — minimal central-directory reader + platform deflate
// ============================================================================

/**
 * Extract specific named files from a zip archive. Returns a map of filename
 * → decoded UTF-8 string. Files not in the zip are absent from the returned
 * map; the caller decides whether that's an error.
 *
 * Supports compression methods 0 (stored) and 8 (deflate). Other methods
 * throw — GTFS zips in practice only use these two.
 */
export async function extractZipFiles(
  zip: Uint8Array,
  wantedNames: string[],
): Promise<Map<string, string>> {
  const wanted = new Set(wantedNames);
  const out = new Map<string, string>();
  const view = new DataView(zip.buffer, zip.byteOffset, zip.byteLength);

  // 1. Find End-of-Central-Directory record. EOCD signature is 0x06054b50.
  //    EOCD is at the end of the file; max 65557 bytes back (incl. comment).
  const eocdSig = 0x06054b50;
  let eocdOffset = -1;
  const searchStart = Math.max(0, zip.length - 65557);
  for (let i = zip.length - 22; i >= searchStart; i--) {
    if (view.getUint32(i, true) === eocdSig) {
      eocdOffset = i;
      break;
    }
  }
  if (eocdOffset < 0) throw new Error('zip: EOCD not found');

  const cdEntries = view.getUint16(eocdOffset + 10, true);
  const cdOffset = view.getUint32(eocdOffset + 16, true);

  // ZIP64 sentinel: when the 32-bit field is 0xFFFFFFFF or the 16-bit count
  // is 0xFFFF, the real value is in the ZIP64 EOCD record (not parsed here).
  // GTFS archives are small today, but failing loudly beats walking garbage
  // offsets if Sinoptico ever switches encoding or the archive grows past 4GB.
  if (cdOffset === 0xffffffff || cdEntries === 0xffff) {
    throw new Error('zip: ZIP64 archives not supported');
  }

  // 2. Walk Central Directory entries. CD entry signature is 0x02014b50.
  const cdSig = 0x02014b50;
  let p = cdOffset;
  for (let n = 0; n < cdEntries; n++) {
    if (view.getUint32(p, true) !== cdSig) {
      throw new Error(`zip: bad CD entry at offset ${p}`);
    }
    const method = view.getUint16(p + 10, true);
    const compSize = view.getUint32(p + 20, true);
    const uncompSize = view.getUint32(p + 24, true);
    const nameLen = view.getUint16(p + 28, true);
    const extraLen = view.getUint16(p + 30, true);
    const commentLen = view.getUint16(p + 32, true);
    const lfhOffset = view.getUint32(p + 42, true);

    const name = new TextDecoder().decode(
      zip.subarray(p + 46, p + 46 + nameLen),
    );

    if (wanted.has(name)) {
      // Read Local File Header to locate the actual data bytes.
      const lfhNameLen = view.getUint16(lfhOffset + 26, true);
      const lfhExtraLen = view.getUint16(lfhOffset + 28, true);
      const dataStart = lfhOffset + 30 + lfhNameLen + lfhExtraLen;
      const compressed = zip.subarray(dataStart, dataStart + compSize);

      let decompressed: Uint8Array;
      if (method === 0) {
        decompressed = compressed;
      } else if (method === 8) {
        decompressed = await inflateRaw(compressed, uncompSize);
      } else {
        throw new Error(`zip: unsupported compression method ${method} for ${name}`);
      }
      out.set(name, new TextDecoder().decode(decompressed));
    }

    p += 46 + nameLen + extraLen + commentLen;
  }

  return out;
}

async function inflateRaw(compressed: Uint8Array, hintSize: number): Promise<Uint8Array> {
  const stream = new Response(compressed).body!.pipeThrough(
    new DecompressionStream('deflate-raw'),
  );
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    if (value) {
      chunks.push(value);
      total += value.length;
    }
  }
  const out = new Uint8Array(total || hintSize);
  let pos = 0;
  for (const c of chunks) {
    out.set(c, pos);
    pos += c.length;
  }
  return out;
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      ...CORS,
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}
