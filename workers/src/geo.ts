/**
 * Pure planar geometry over WGS84 coordinates at city scale.
 *
 * Everything here uses an equirectangular approximation (lat/lon deltas
 * scaled to meters with a cos(midLat) correction) instead of full haversine:
 * Metrobús inter-stop distances max out around 2 km, where the flat-earth
 * error is < 0.1% — far below GPS noise — and the projection math stays
 * simple linear algebra.
 */

export interface LatLon {
  lat: number;
  lon: number;
}

const EARTH_RADIUS_METERS = 6_371_000;
const RAD = Math.PI / 180;
/** Meters per degree of latitude (constant on a sphere): ≈ 111,195. */
const METERS_PER_DEG_LAT = EARTH_RADIUS_METERS * RAD;

/** Meters between two coordinates (equirectangular — see module doc). */
export function distanceMeters(a: LatLon, b: LatLon): number {
  const cosMidLat = Math.cos(((a.lat + b.lat) / 2) * RAD);
  const dx = (b.lon - a.lon) * METERS_PER_DEG_LAT * cosMidLat;
  const dy = (b.lat - a.lat) * METERS_PER_DEG_LAT;
  return Math.hypot(dx, dy);
}

export interface SequencePosition {
  /** Index into the stop array of the NEXT stop the vehicle will reach. */
  nextIndex: number;
  /** Meters from the vehicle to that next stop. */
  metersToNext: number;
  /** Meters the vehicle has traveled past the PREVIOUS stop (segment progress). */
  metersPastPrev: number;
}

/**
 * Project a vehicle onto an ordered stop sequence: find the segment
 * (stops[i] → stops[i+1]) whose projection distance to the vehicle is
 * minimal, clamping to segment ends. Vehicles before the first stop map to
 * nextIndex 0; past the last stop map to nextIndex stops.length - 1 with
 * metersToNext measured to the terminal. Returns null when the vehicle is
 * farther than `maxOffRouteMeters` from every segment (off-route /
 * deadheading — don't fabricate states from it).
 */
export function projectOntoSequence(
  vehicle: LatLon,
  stops: readonly LatLon[],
  maxOffRouteMeters: number,
): SequencePosition | null {
  if (stops.length === 0) return null;
  if (stops.length === 1) {
    const d = distanceMeters(vehicle, stops[0]!);
    return d <= maxOffRouteMeters ? { nextIndex: 0, metersToNext: d, metersPastPrev: 0 } : null;
  }

  // Local equirectangular meter frame with the vehicle at the origin.
  const cosLat = Math.cos(vehicle.lat * RAD);
  const pts = stops.map((p) => ({
    x: (p.lon - vehicle.lon) * METERS_PER_DEG_LAT * cosLat,
    y: (p.lat - vehicle.lat) * METERS_PER_DEG_LAT,
  }));

  let bestDist = Infinity;
  let bestSeg = 0;
  let bestT = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i]!;
    const b = pts[i + 1]!;
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len2 = dx * dx + dy * dy;
    // t = dot(vehicle - a, b - a) / |b - a|², clamped to the segment.
    // Degenerate (zero-length) segments collapse onto their start point.
    const t = len2 === 0 ? 0 : Math.min(1, Math.max(0, (-a.x * dx - a.y * dy) / len2));
    const d = Math.hypot(a.x + t * dx, a.y + t * dy);
    // Strict < keeps the EARLIER segment on ties: a vehicle exactly at stop k
    // resolves to segment k-1 with t=1 (metersPastPrev = full segment), not
    // segment k with t=0 — so it can never read as "just departed stop k-1".
    if (d < bestDist) {
      bestDist = d;
      bestSeg = i;
      bestT = t;
    }
  }
  if (bestDist > maxOffRouteMeters) return null;

  // t === 0 means the vehicle is at/behind the segment start, so the start
  // itself is the next stop; otherwise it is moving toward the segment end.
  const nextIndex = bestT === 0 ? bestSeg : bestSeg + 1;
  const metersToNext = distanceMeters(vehicle, stops[nextIndex]!);
  const metersPastPrev =
    nextIndex === 0
      ? 0
      : nextIndex === bestSeg
        // t = 0 on an interior segment: the whole previous segment is behind us.
        ? distanceMeters(stops[bestSeg - 1]!, stops[bestSeg]!)
        : bestT * distanceMeters(stops[bestSeg]!, stops[bestSeg + 1]!);
  return { nextIndex, metersToNext, metersPastPrev };
}
