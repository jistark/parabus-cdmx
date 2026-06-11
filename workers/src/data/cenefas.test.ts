// workers/src/data/cenefas.test.ts
import { describe, it, expect } from 'vitest';
import { buildStopIndex, type CenefaDataset } from './cenefas-types';
import { CENEFAS } from './cenefas';
import snapshot from './gtfs-stops-snapshot.json';

/** Minimal synthetic dataset: one line, one service, two directions. */
export const SYNTH: CenefaDataset = {
  version: '2026-06-11',
  lines: [{
    line: '9',
    services: [{
      id: 'L9-regular',
      type: 'regular',
      lines: ['9'],
      directions: [
        {
          destination: 'Norte',
          gtfsRouteIds: ['R9N'],
          gtfsHeadsigns: ['Norte'],
          stops: [
            { stopId: 'S1N', name: 'Alfa', pictogram: 'alfa' },
            { stopId: 'S2N', name: 'Beta', pictogram: 'beta' },
            { stopId: 'S3N', name: 'Gamma', pictogram: 'gamma' },
          ],
        },
        {
          destination: 'Sur',
          gtfsRouteIds: ['R9S'],
          gtfsHeadsigns: ['Sur'],
          stops: [
            { stopId: 'S3S', name: 'Gamma', pictogram: 'gamma' },
            { stopId: 'S2S', name: 'Beta', pictogram: 'beta' },
            { stopId: 'S1S', name: 'Alfa', pictogram: 'alfa' },
          ],
        },
      ],
      style: { colors: ['#000000'] },
    }],
  }],
};

describe('buildStopIndex', () => {
  it('maps each platform stop to its service, direction, and position', () => {
    const index = buildStopIndex(SYNTH);
    const hits = index.get('S2N');
    expect(hits).toHaveLength(1);
    expect(hits![0]).toMatchObject({
      serviceId: 'L9-regular',
      directionIndex: 0,
      position: 1,
      destination: 'Norte',
    });
  });

  it('returns undefined for unknown stops', () => {
    expect(buildStopIndex(SYNTH).get('NOPE')).toBeUndefined();
  });

  it('indexes both directions independently', () => {
    const index = buildStopIndex(SYNTH);
    expect(index.get('S2S')![0]!.directionIndex).toBe(1);
    expect(index.get('S2S')![0]!.position).toBe(1);
  });
});

describe('cenefa dataset ↔ GTFS cross-validation', () => {
  const gtfsStopIds = new Set(Object.keys((snapshot as { stops: Record<string, unknown> }).stops));

  it('every dataset stopId exists in the GTFS stops snapshot', () => {
    const missing: string[] = [];
    for (const line of CENEFAS.lines) {
      for (const service of line.services) {
        for (const dir of service.directions) {
          for (const stop of dir.stops) {
            if (!gtfsStopIds.has(stop.stopId)) {
              missing.push(`${service.id}/${dir.destination}: ${stop.stopId} (${stop.name})`);
            }
          }
        }
      }
    }
    expect(missing).toEqual([]);
  });

  it('every direction has ≥2 stops, a destination, and ≥1 GTFS route id', () => {
    for (const line of CENEFAS.lines) {
      for (const service of line.services) {
        expect(service.directions.length).toBeGreaterThanOrEqual(1);
        for (const dir of service.directions) {
          expect(dir.stops.length).toBeGreaterThanOrEqual(2);
          expect(dir.destination.length).toBeGreaterThan(0);
          expect(dir.gtfsRouteIds.length).toBeGreaterThanOrEqual(1);
        }
      }
    }
  });

  it('the last stop of each direction is the destination terminal', () => {
    for (const line of CENEFAS.lines) {
      for (const service of line.services) {
        for (const dir of service.directions) {
          const last = dir.stops[dir.stops.length - 1]!;
          expect(last.name.toLowerCase()).toContain(dir.destination.toLowerCase().slice(0, 6));
        }
      }
    }
  });
});
