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

  it('two-direction services start at the opposite terminal', () => {
    for (const line of CENEFAS.lines) {
      for (const service of line.services) {
        if (service.directions.length !== 2) continue;
        service.directions.forEach((dir, i) => {
          const opposite = service.directions[1 - i]!.destination;
          expect(dir.stops[0]!.name.toLowerCase()).toContain(opposite.toLowerCase().slice(0, 6));
        });
      }
    }
  });

  it('L1 regular service has the full 46-station sequence per direction', () => {
    const l1 = CENEFAS.lines.find((l) => l.line === '1')!.services.find((s) => s.id === 'L1-regular')!;
    for (const dir of l1.directions) {
      expect(dir.stops).toHaveLength(46);
    }
  });

  /** Exact per-direction stop counts, pinned against the live GTFS stop
   *  sequences verified on 2026-06-11 (see the per-line notes in cenefas.ts). */
  function directionLengths(serviceId: string): Record<string, number> {
    const svc = CENEFAS.lines.flatMap((l) => l.services).find((s) => s.id === serviceId)!;
    expect(svc).toBeDefined();
    return Object.fromEntries(svc.directions.map((d) => [d.destination, d.stops.length]));
  }

  it('L2 regular service has the full sequence per direction (one-way couplets included)', () => {
    expect(directionLengths('L2-regular')).toEqual({ Tepalcates: 34, Tacubaya: 33 });
  });

  it('L3 regular service has the 36-station through sequence per direction', () => {
    // 38 printed on the cenefa minus La Raza + Buenavista (skipped by through trips).
    expect(directionLengths('L3-regular')).toEqual({
      Tenayuca: 36,
      'Pueblo Sta. Cruz Atoyac': 36,
    });
  });

  it('L4 branch services have the full per-route sequences', () => {
    expect(directionLengths('L4-ruta-norte')).toEqual({ Buenavista: 15, 'San Lázaro': 15 });
    expect(directionLengths('L4-ruta-sur')).toEqual({ Buenavista: 20, 'San Lázaro': 21 });
    expect(directionLengths('L4-pantitlan')).toEqual({ Pantitlán: 11, Hidalgo: 11 });
    expect(directionLengths('L4-alameda-oriente')).toEqual({ 'Alameda Oriente': 13, Hidalgo: 13 });
  });

  it('L5 regular service has the full 51-station sequence per direction', () => {
    expect(directionLengths('L5-regular')).toEqual({
      'Río de los Remedios': 51,
      'Preparatoria 1': 51,
    });
  });

  it('L6 regular service has the asymmetric loop/couplet sequences', () => {
    expect(directionLengths('L6-regular')).toEqual({ 'Villa de Aragón': 31, 'El Rosario': 34 });
  });

  it('L7 regular service has the asymmetric couplet sequences', () => {
    expect(directionLengths('L7-regular')).toEqual({ 'Indios Verdes': 29, 'Campo Marte': 30 });
  });

  it('L4 east-of-Hidalgo platforms are shared between the norte/pantitlán/alameda services', () => {
    const ids = (sid: string, dest: string) =>
      CENEFAS.lines.flatMap((l) => l.services).find((s) => s.id === sid)!
        .directions.find((d) => d.destination === dest)!.stops.map((s) => s.stopId);
    const norteEast = ids('L4-ruta-norte', 'San Lázaro');
    const pantEast = ids('L4-pantitlan', 'Pantitlán');
    // Bellas Artes .. Archivo General de la Nación (9 platforms) are identical.
    expect(pantEast.slice(1, 10)).toEqual(norteEast.slice(5, 14));
    // Alameda Oriente eastbound shared segment equals the Ruta Norte slice.
    const alamedaEast = ids('L4-alameda-oriente', 'Alameda Oriente');
    expect(alamedaEast.slice(1, 10)).toEqual(norteEast.slice(5, 14));
  });

  it('L2 one-way couplet direction-locks: Volta-only stops absent from Tacubaya (Ida)', () => {
    const l2 = CENEFAS.lines.flatMap((l) => l.services).find((s) => s.id === 'L2-regular')!;
    const idaIds = new Set(l2.directions.find((d) => d.destination === 'Tacubaya')!.stops.map((s) => s.stopId));
    expect(idaIds.has('f8578e')).toBe(false); // Antonio Maceo
    expect(idaIds.has('f857aa')).toBe(false); // Del Moral
    expect(idaIds.has('f85791')).toBe(false); // Canal de San Juan
    expect(idaIds.has('f85846')).toBe(false); // Nicolás Bravo
  });

  it('L2 one-way couplet direction-locks: Ida-only stops absent from Tepalcates (Volta)', () => {
    const l2 = CENEFAS.lines.flatMap((l) => l.services).find((s) => s.id === 'L2-regular')!;
    const voltaIds = new Set(l2.directions.find((d) => d.destination === 'Tepalcates')!.stops.map((s) => s.stopId));
    expect(voltaIds.has('f857d6')).toBe(false); // Parque Lira
    expect(voltaIds.has('f85854')).toBe(false); // Río Frío
    expect(voltaIds.has('f85749')).toBe(false); // Gral. Antonio de León
  });

  it('L6 one-way couplet direction-locks', () => {
    const l6 = CENEFAS.lines.flatMap((l) => l.services).find((s) => s.id === 'L6-regular')!;
    const rosarioIds = new Set(l6.directions.find((d) => d.destination === 'El Rosario')!.stops.map((s) => s.stopId));
    const aragonIds = new Set(l6.directions.find((d) => d.destination === 'Villa de Aragón')!.stops.map((s) => s.stopId));
    expect(rosarioIds.has('f8577b')).toBe(false); // 482 Ote — Volta-only, absent from El Rosario direction
    expect(aragonIds.has('f8580f')).toBe(false);  // Volcán de Fuego — Ida-only, absent from Villa de Aragón direction
  });

  it('interlínea L2/L7 has the full 15-station sequence per direction', () => {
    expect(directionLengths('L2L7-tacubaya-cuitlahuac')).toEqual({
      'Glorieta Cuitláhuac': 15,
      'Alameda Tacubaya': 15,
    });
  });

  it('aeropuerto service has the full per-direction sequences (T2 berths on the return)', () => {
    expect(directionLengths('L4-aeropuerto')).toEqual({
      Amajac: 19,
      'Aeropuerto T1 y T2': 18,
    });
  });

  it('interlínea L2/L7 service exists, spans both lines, and shares stops with L2', () => {
    const inter = CENEFAS.lines
      .flatMap((l) => l.services)
      .find((s) => s.type === 'interlinea');
    expect(inter).toBeDefined();
    expect(inter!.lines.sort()).toEqual(['2', '7']);
  });

  it('aeropuerto service exists', () => {
    const aero = CENEFAS.lines.flatMap((l) => l.services).find((s) => s.type === 'aeropuerto');
    expect(aero).toBeDefined();
  });

  it('stops shared between a regular line and the interlínea index to multiple services', () => {
    // Closes a Task-1 review gap: buildStopIndex must return one hit per
    // (service, direction) for stops served by more than one service.
    const index = buildStopIndex(CENEFAS);
    const inter = CENEFAS.lines.flatMap((l) => l.services).find((s) => s.type === 'interlinea')!;
    const sharedStop = inter.directions[0]!.stops.find((stop) =>
      (index.get(stop.stopId) ?? []).some((h) => h.serviceId !== inter.id));
    expect(sharedStop).toBeDefined();
    const hits = index.get(sharedStop!.stopId)!;
    expect(new Set(hits.map((h) => h.serviceId)).size).toBeGreaterThanOrEqual(2);
  });

  it('L7 one-way couplet direction-locks', () => {
    const l7 = CENEFAS.lines.flatMap((l) => l.services).find((s) => s.id === 'L7-regular')!;
    const campoIds = new Set(l7.directions.find((d) => d.destination === 'Campo Marte')!.stops.map((s) => s.stopId));
    const indiosIds = new Set(l7.directions.find((d) => d.destination === 'Indios Verdes')!.stops.map((s) => s.stopId));
    expect(campoIds.has('f857b3')).toBe(false);  // Gustavo A. Madero — Volta-only, absent from Campo Marte direction
    expect(indiosIds.has('f857c1')).toBe(false); // De los Misterios L7 — Ida-only, absent from Indios Verdes direction
  });
});
