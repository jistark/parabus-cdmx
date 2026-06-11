// workers/src/arrivals.test.ts
import { describe, it, expect } from 'vitest';
import { handleCenefas, scheduleToFallbacks } from './arrivals';

describe('GET /static/cenefas', () => {
  it('returns the dataset with version and 24h cache header', async () => {
    const res = handleCenefas();
    expect(res.status).toBe(200);
    expect(res.headers.get('Cache-Control')).toBe('public, max-age=86400');
    const body = await res.json() as { version: string; lines: unknown[] };
    expect(body.version).toMatch(/^\d{4}-\d{2}-\d{2}/);
    expect(body.lines.length).toBeGreaterThanOrEqual(7);
  });
});

import { deriveArrivalRows, VEHICLE_STALE_SECONDS, FEED_STALE_SECONDS } from './arrivals';
import { buildStopIndex, type CenefaDataset } from './data/cenefas-types';
import { SYNTH } from './data/cenefas-fixtures';
import type { VehiclePosition } from './gtfs-rt';
import type { LatLon } from './geo';

const NOW = 1_750_000_000; // unix seconds, arbitrary fixed
const index = buildStopIndex(SYNTH);

function veh(over: Partial<VehiclePosition>): VehiclePosition {
  return {
    entityId: 'e1', tripId: null, routeId: 'R9N', vehicleId: 'V1',
    vehicleLabel: null, lat: 19.4, lon: -99.1, bearing: 0, speed: null,
    currentStopSequence: null, stopId: null, timestamp: NOW - 5,
    ...over,
  } as VehiclePosition;
}

/** travelTime stub: 4 min per hop between synthetic stops. */
const hops = async (_from: string, _to: string): Promise<number | null> => 4;

/** stopCoords stub for tests that exercise the exact stopId path only. */
const noCoords = (): null => null;

describe('deriveArrivalRows', () => {
  it('vehicle whose next stop is ours → arriving', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [veh({ stopId: 'S2N' })], NOW, NOW, noCoords, hops, async () => []);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ state: 'arriving', source: 'realtime', destination: 'Norte', vehicleId: 'V1' });
  });

  it('vehicle k stops upstream → eta with travel-time minutes', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [veh({ stopId: 'S1N' })], NOW, NOW, noCoords, hops, async () => []);
    expect(rows[0]).toMatchObject({ state: 'eta', etaMinutes: 4 });
  });

  it('vehicle whose next stop is the one after ours → departed', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [veh({ stopId: 'S3N' })], NOW, NOW, noCoords, hops, async () => []);
    expect(rows[0]).toMatchObject({ state: 'departed' });
  });

  it('arriving beats departed for the same service-direction', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N',
      [veh({ stopId: 'S3N', vehicleId: 'GONE' }), veh({ stopId: 'S2N', vehicleId: 'HERE' })],
      NOW, NOW, noCoords, hops, async () => [],
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ state: 'arriving', vehicleId: 'HERE' });
  });

  it('nearest eta wins among upstream vehicles', async () => {
    const rows = await deriveArrivalRows(
      index, 'S3N',
      [veh({ stopId: 'S1N', vehicleId: 'FAR' }), veh({ stopId: 'S2N', vehicleId: 'NEAR' })],
      NOW, NOW, noCoords, hops, async () => [],
    );
    expect(rows[0]).toMatchObject({ state: 'eta', vehicleId: 'NEAR', etaMinutes: 4 });
  });

  it('stale vehicle (>60s) is excluded', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [veh({ stopId: 'S2N', timestamp: NOW - VEHICLE_STALE_SECONDS - 1 })],
      NOW, NOW, noCoords, hops,
      async () => [{ destination: 'Norte', etaMinutes: 9 }],
    );
    expect(rows[0]).toMatchObject({ state: 'scheduled', etaMinutes: 9, source: 'schedule' });
  });

  it('stale feed (>90s) degrades everything to scheduled', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [veh({ stopId: 'S2N' })], NOW - FEED_STALE_SECONDS - 1, NOW, noCoords, hops,
      async () => [{ destination: 'Norte', etaMinutes: 6 }],
    );
    expect(rows[0]).toMatchObject({ state: 'scheduled', etaMinutes: 6 });
  });

  it('vehicle on a different route does not match', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [veh({ stopId: 'S2N', routeId: 'OTHER' })], NOW, NOW, noCoords, hops, async () => [],
    );
    expect(rows[0]!.state).toBe('scheduled');
  });

  it('no vehicles → scheduled fallback row per direction', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [], NOW, NOW, noCoords, hops,
      async () => [{ destination: 'Norte', etaMinutes: 7 }],
    );
    expect(rows[0]).toMatchObject({ state: 'scheduled', etaMinutes: 7 });
  });

  it('eta is floored at 1 minute', async () => {
    const zeroHops = async (): Promise<number | null> => 0;
    const rows = await deriveArrivalRows(index, 'S2N', [veh({ stopId: 'S1N' })], NOW, NOW, noCoords, zeroHops, async () => []);
    expect(rows[0]!.etaMinutes).toBe(1);
  });

  it('null travel time falls back to 4 min per hop', async () => {
    const noData = async (): Promise<number | null> => null;
    const rows = await deriveArrivalRows(index, 'S3N', [veh({ stopId: 'S1N' })], NOW, NOW, noCoords, noData, async () => []);
    expect(rows[0]!.etaMinutes).toBe(8); // 2 hops × 4
  });

  it('arriving fires at the first stop of a direction (no upstream to scan)', async () => {
    const rows = await deriveArrivalRows(index, 'S1N', [veh({ stopId: 'S1N' })], NOW, NOW, noCoords, hops, async () => []);
    expect(rows[0]).toMatchObject({ state: 'arriving' });
  });

  it('vehicle exactly VEHICLE_STALE_SECONDS old is still fresh (inclusive bound)', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [veh({ stopId: 'S2N', timestamp: NOW - VEHICLE_STALE_SECONDS })],
      NOW, NOW, noCoords, hops, async () => [],
    );
    expect(rows[0]).toMatchObject({ state: 'arriving' });
  });
});

describe('deriveArrivalRows — geometric projection (no feed stop_id)', () => {
  // Synthetic geometry mirroring geo.test.ts: a straight south→north line at
  // CDMX latitude, SYNTH stops S1N → S2N → S3N spaced 1000 m apart.
  const M_PER_DEG_LAT = 111_194.93;
  const BASE: LatLon = { lat: 19.4, lon: -99.1 };
  function north(meters: number, eastMeters = 0): LatLon {
    return {
      lat: BASE.lat + meters / M_PER_DEG_LAT,
      lon: BASE.lon + eastMeters / (M_PER_DEG_LAT * Math.cos(BASE.lat * (Math.PI / 180))),
    };
  }
  const SYNTH_COORDS: Record<string, LatLon> = { S1N: north(0), S2N: north(1000), S3N: north(2000) };
  const coords = (id: string): LatLon | null => SYNTH_COORDS[id] ?? null;

  /** Fresh vehicle with NO feed stop_id, positioned `meters` along the line. */
  function gps(meters: number, eastMeters = 0): VehiclePosition {
    return veh({ stopId: null, ...north(meters, eastMeters) });
  }

  it('vehicle 100 m before our stop → arriving', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [gps(900)], NOW, NOW, coords, hops, async () => []);
    expect(rows[0]).toMatchObject({ state: 'arriving', source: 'realtime', vehicleId: 'V1' });
  });

  it('vehicle ~600 m before our stop (mid-segment) → eta from the segment start', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [gps(400)], NOW, NOW, coords, hops, async () => []);
    expect(rows[0]).toMatchObject({ state: 'eta', etaMinutes: 4 }); // S1N→S2N scheduled time
  });

  it('vehicle projected k stops upstream → eta via travel time from its next stop', async () => {
    const rows = await deriveArrivalRows(index, 'S3N', [gps(400)], NOW, NOW, coords, hops, async () => []);
    expect(rows[0]).toMatchObject({ state: 'eta', etaMinutes: 4 }); // next stop S2N → ours
  });

  it('vehicle 150 m past our stop → departed', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [gps(1150)], NOW, NOW, coords, hops, async () => []);
    expect(rows[0]).toMatchObject({ state: 'departed' });
  });

  it('vehicle 900 m past our stop → scheduled (beyond the departed radius)', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [gps(1900)], NOW, NOW, coords, hops, async () => []);
    expect(rows[0]!.state).toBe('scheduled');
  });

  it('vehicle 2 km perpendicular off-route → scheduled (projection rejects it)', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [gps(900, 2000)], NOW, NOW, coords, hops, async () => []);
    expect(rows[0]!.state).toBe('scheduled');
  });

  it('vehicle missing lat/lon → scheduled (nothing to project)', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [veh({ stopId: null, lat: null, lon: null })], NOW, NOW, coords, hops, async () => [],
    );
    expect(rows[0]!.state).toBe('scheduled');
  });
});

describe('scheduleToFallbacks', () => {
  it('maps GTFS headsigns to official destinations and minutes-from-now', () => {
    const hits = index.get('S2N')!;
    const out = scheduleToFallbacks(
      [{ tripId: 'T1', arrivalMinutes: 610, sequence: 2, headsign: 'Norte' }],
      hits,
      600, // nowMinutes
    );
    expect(out).toEqual([{ destination: 'Norte', etaMinutes: 10 }]);
  });

  it('keeps only the earliest arrival per destination and drops unknown headsigns', () => {
    const hits = index.get('S2N')!;
    const out = scheduleToFallbacks(
      [
        { tripId: 'T1', arrivalMinutes: 620, sequence: 2, headsign: 'Norte' },
        { tripId: 'T2', arrivalMinutes: 605, sequence: 2, headsign: 'Norte' },
        { tripId: 'T3', arrivalMinutes: 606, sequence: 2, headsign: 'Mystery' },
      ],
      hits,
      600,
    );
    expect(out).toEqual([{ destination: 'Norte', etaMinutes: 5 }]);
  });

  it('scheduled fallback attributes arrivals by route id at shared platforms', () => {
    // Two services share a platform and the vendor headsign "Volta" (the
    // real L4 Pantitlán / Alameda Oriente eastbound situation) — only the
    // route id can attribute an arrival to the right service.
    const shared: CenefaDataset = {
      version: '2026-06-11',
      lines: [{
        line: '4',
        services: [
          {
            id: 'L4-pantitlan', type: 'regular', lines: ['4'],
            directions: [{
              destination: 'Pantitlán',
              gtfsRouteIds: ['e04'],
              gtfsHeadsigns: ['Volta'],
              stops: [{ stopId: 'SHARED', name: 'Bellas Artes', pictogram: 'ba' }],
            }],
            style: { colors: ['#000000'] },
          },
          {
            id: 'L4-alameda-ote', type: 'regular', lines: ['4'],
            directions: [{
              destination: 'Alameda Oriente',
              gtfsRouteIds: ['e05'],
              gtfsHeadsigns: ['Volta'],
              stops: [{ stopId: 'SHARED', name: 'Bellas Artes', pictogram: 'ba' }],
            }],
            style: { colors: ['#000000'] },
          },
        ],
      }],
    };
    const sharedHits = buildStopIndex(shared).get('SHARED')!;
    const out = scheduleToFallbacks(
      [
        { tripId: 'T-PAN', arrivalMinutes: 612, sequence: 3, headsign: 'Volta', routeId: 'e04' },
        { tripId: 'T-ALA', arrivalMinutes: 607, sequence: 3, headsign: 'Volta', routeId: 'e05' },
      ],
      sharedHits,
      600,
    );
    // Each destination must get ITS OWN eta — headsign-only matching would
    // collapse both arrivals onto whichever service comes first in `hits`.
    expect(out.sort((a, b) => a.destination.localeCompare(b.destination))).toEqual([
      { destination: 'Alameda Oriente', etaMinutes: 7 },
      { destination: 'Pantitlán', etaMinutes: 12 },
    ]);
  });

  it('routeId-less arrivals still match by headsign (old cached entries)', () => {
    const hits = index.get('S2N')!;
    const out = scheduleToFallbacks(
      [
        { tripId: 'T1', arrivalMinutes: 610, sequence: 2, headsign: 'Norte' },
        { tripId: 'T2', arrivalMinutes: 615, sequence: 2, headsign: 'Norte', routeId: null },
      ],
      hits,
      600,
    );
    expect(out).toEqual([{ destination: 'Norte', etaMinutes: 10 }]);
  });
});
