/**
 * Sinoptico Plus partner API client for Metrobús CDMX GTFS data.
 *
 * Single endpoint that returns AWS-signed S3 URLs (10-minute TTL) for:
 *   - urlRealTime: GTFS-RT .proto with vehicle positions (refreshed every ~30s)
 *   - urlStatic:   GTFS .zip with stops/routes/trips (regenerated nightly)
 *
 * The vendor's `partnerValidation` endpoint also returns 200 with empty data
 * when the operator's tracking client isn't running (pre-service hours,
 * outages). We surface that as `null` rather than throwing — handlers can
 * respond with `{serviceActive: false}` instead of a 5xx.
 */

import type { Env } from './types';

const PARTNER_ENDPOINT =
  'https://metrobus-gtfs.sinopticoplus.com/gtfs-api/partnerValidation';

export interface PartnerValidationResponse {
  /** "YYYY-MM-DD HH:MM:SS" — timezone undocumented; treat as opaque label. */
  generationDateTime: string;
  /** "YYYY-MM-DD HH:MM:SS" — also undocumented TZ; URLs expire ~10min after generation. */
  expirationDateTime: string;
  /** AWS pre-signed URL to GTFS_RT.proto. X-Amz-Expires=600. */
  urlRealTime: string;
  /** AWS pre-signed URL to GTFS_ESTATICO.zip. X-Amz-Expires=600. */
  urlStatic: string;
}

/**
 * Validate credentials and request fresh signed URLs.
 * Returns null when the operator's tracking system is offline (empty payload).
 * Throws on auth failure, network errors, or malformed responses.
 */
export async function partnerValidation(
  env: Env,
): Promise<PartnerValidationResponse | null> {
  if (!env.METROBUS_USUARIO || !env.METROBUS_SENHA) {
    throw new Error('partnerValidation: METROBUS_USUARIO / METROBUS_SENHA secrets not set');
  }

  const resp = await fetch(PARTNER_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      usuario: env.METROBUS_USUARIO,
      senha: env.METROBUS_SENHA,
    }),
  });

  if (!resp.ok) {
    const body = await resp.text().catch(() => '');
    throw new Error(
      `partnerValidation HTTP ${resp.status}: ${body.slice(0, 200) || resp.statusText}`,
    );
  }

  // Read as text first so we can log it on parse errors / unexpected shapes.
  const rawText = await resp.text();

  let data: Partial<PartnerValidationResponse>;
  try {
    data = JSON.parse(rawText) as Partial<PartnerValidationResponse>;
  } catch {
    console.error(`partnerValidation: non-JSON response (first 300 chars): ${rawText.slice(0, 300)}`);
    return null;
  }

  // Manual: "esta información solo estará disponible cuando el cliente esté
  // en funcionamiento". An empty/incomplete response means service inactive.
  if (!data || !data.urlRealTime || !data.urlStatic) {
    console.warn(
      `partnerValidation: incomplete response. keys=${Object.keys(data || {}).join(',')} ` +
      `body=${rawText.slice(0, 300)}`,
    );
    return null;
  }

  return data as PartnerValidationResponse;
}

/**
 * Convenience: validate + download the realtime .proto bytes immediately.
 * Returns null when the operator's tracking system is offline.
 *
 * IMPORTANT: We download the .proto in the same request as partnerValidation()
 * because the signed URL caches a 10-minute expiry from upstream-generation
 * time, not from when we receive it. Storing the URL for later use risks
 * 403 (expired signature) on pop machines with clock drift.
 */
export async function fetchRealtimeProto(env: Env): Promise<{
  bytes: Uint8Array;
  generationDateTime: string;
} | null> {
  const v = await partnerValidation(env);
  if (!v) return null;

  const resp = await fetch(v.urlRealTime);
  if (!resp.ok) {
    throw new Error(`Failed to download GTFS-RT proto: HTTP ${resp.status}`);
  }
  const buf = await resp.arrayBuffer();
  return {
    bytes: new Uint8Array(buf),
    generationDateTime: v.generationDateTime,
  };
}

/**
 * Convenience: validate + download the static GTFS zip bytes immediately.
 * Returns null when the operator's tracking system is offline.
 */
export async function fetchStaticZip(env: Env): Promise<{
  bytes: Uint8Array;
  generationDateTime: string;
} | null> {
  const v = await partnerValidation(env);
  if (!v) return null;

  const resp = await fetch(v.urlStatic);
  if (!resp.ok) {
    throw new Error(`Failed to download GTFS static zip: HTTP ${resp.status}`);
  }
  const buf = await resp.arrayBuffer();
  return {
    bytes: new Uint8Array(buf),
    generationDateTime: v.generationDateTime,
  };
}
