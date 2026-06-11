// workers/src/data/cenefas.test.ts
import { describe, it, expect } from 'vitest';
import { buildStopIndex, type CenefaDataset } from './cenefas-types';

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
