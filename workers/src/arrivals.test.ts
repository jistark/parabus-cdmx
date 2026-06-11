// workers/src/arrivals.test.ts
import { describe, it, expect } from 'vitest';
import { handleCenefas } from './arrivals';

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
import { buildStopIndex } from './data/cenefas-types';
import { SYNTH } from './data/cenefas.test';
import type { VehiclePosition } from './gtfs-rt';

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

describe('deriveArrivalRows', () => {
  it('vehicle whose next stop is ours → arriving', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [veh({ stopId: 'S2N' })], NOW, NOW, hops, async () => []);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ state: 'arriving', source: 'realtime', destination: 'Norte', vehicleId: 'V1' });
  });

  it('vehicle k stops upstream → eta with travel-time minutes', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [veh({ stopId: 'S1N' })], NOW, NOW, hops, async () => []);
    expect(rows[0]).toMatchObject({ state: 'eta', etaMinutes: 4 });
  });

  it('vehicle whose next stop is the one after ours → departed', async () => {
    const rows = await deriveArrivalRows(index, 'S2N', [veh({ stopId: 'S3N' })], NOW, NOW, hops, async () => []);
    expect(rows[0]).toMatchObject({ state: 'departed' });
  });

  it('arriving beats departed for the same service-direction', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N',
      [veh({ stopId: 'S3N', vehicleId: 'GONE' }), veh({ stopId: 'S2N', vehicleId: 'HERE' })],
      NOW, NOW, hops, async () => [],
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ state: 'arriving', vehicleId: 'HERE' });
  });

  it('nearest eta wins among upstream vehicles', async () => {
    const rows = await deriveArrivalRows(
      index, 'S3N',
      [veh({ stopId: 'S1N', vehicleId: 'FAR' }), veh({ stopId: 'S2N', vehicleId: 'NEAR' })],
      NOW, NOW, hops, async () => [],
    );
    expect(rows[0]).toMatchObject({ state: 'eta', vehicleId: 'NEAR', etaMinutes: 4 });
  });

  it('stale vehicle (>60s) is excluded', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [veh({ stopId: 'S2N', timestamp: NOW - VEHICLE_STALE_SECONDS - 1 })],
      NOW, NOW, hops,
      async () => [{ destination: 'Norte', etaMinutes: 9 }],
    );
    expect(rows[0]).toMatchObject({ state: 'scheduled', etaMinutes: 9, source: 'schedule' });
  });

  it('stale feed (>90s) degrades everything to scheduled', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [veh({ stopId: 'S2N' })], NOW - FEED_STALE_SECONDS - 1, NOW, hops,
      async () => [{ destination: 'Norte', etaMinutes: 6 }],
    );
    expect(rows[0]).toMatchObject({ state: 'scheduled', etaMinutes: 6 });
  });

  it('vehicle on a different route does not match', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [veh({ stopId: 'S2N', routeId: 'OTHER' })], NOW, NOW, hops, async () => [],
    );
    expect(rows[0]!.state).toBe('scheduled');
  });

  it('no vehicles → scheduled fallback row per direction', async () => {
    const rows = await deriveArrivalRows(
      index, 'S2N', [], NOW, NOW, hops,
      async () => [{ destination: 'Norte', etaMinutes: 7 }],
    );
    expect(rows[0]).toMatchObject({ state: 'scheduled', etaMinutes: 7 });
  });

  it('eta is floored at 1 minute', async () => {
    const zeroHops = async (): Promise<number | null> => 0;
    const rows = await deriveArrivalRows(index, 'S2N', [veh({ stopId: 'S1N' })], NOW, NOW, zeroHops, async () => []);
    expect(rows[0]!.etaMinutes).toBe(1);
  });

  it('null travel time falls back to 4 min per hop', async () => {
    const noData = async (): Promise<number | null> => null;
    const rows = await deriveArrivalRows(index, 'S3N', [veh({ stopId: 'S1N' })], NOW, NOW, noData, async () => []);
    expect(rows[0]!.etaMinutes).toBe(8); // 2 hops × 4
  });
});
