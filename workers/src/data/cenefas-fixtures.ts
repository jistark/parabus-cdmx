// workers/src/data/cenefas-fixtures.ts
/**
 * Test-only fixtures. Lives outside the .test.ts files so suites can share
 * it WITHOUT importing each other — importing a test module re-executes its
 * describe blocks (vitest counts every suite twice).
 */
import type { CenefaDataset } from './cenefas-types';

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
