// workers/src/geo.test.ts
import { describe, it, expect } from 'vitest';
import { distanceMeters, projectOntoSequence, type LatLon } from './geo';

// CDMX-ish frame: lat ~19.4. 1° of latitude ≈ 111,195 m everywhere;
// 1° of longitude ≈ 104,880 m at this latitude.
const M_PER_DEG_LAT = 111_194.93;
const BASE: LatLon = { lat: 19.4, lon: -99.1 };

/** A point `meters` north of BASE, optionally `eastMeters` east of the line. */
function north(meters: number, eastMeters = 0): LatLon {
  return {
    lat: BASE.lat + meters / M_PER_DEG_LAT,
    lon: BASE.lon + eastMeters / (M_PER_DEG_LAT * Math.cos(BASE.lat * (Math.PI / 180))),
  };
}

/** Straight south→north line, 4 stops 1000 m apart. */
const LINE: LatLon[] = [north(0), north(1000), north(2000), north(3000)];

describe('distanceMeters', () => {
  it('measures ~1000 m along a meridian', () => {
    expect(distanceMeters(north(0), north(1000))).toBeCloseTo(1000, -1);
  });

  it('measures ~1000 m along a parallel (cos-lat scaling)', () => {
    expect(distanceMeters(north(0, 0), north(0, 1000))).toBeCloseTo(1000, -1);
  });

  it('is zero for identical points', () => {
    expect(distanceMeters(BASE, BASE)).toBe(0);
  });
});

describe('projectOntoSequence', () => {
  it('vehicle mid-segment → next stop is the segment end', () => {
    const p = projectOntoSequence(north(1500), LINE, 500)!;
    expect(p.nextIndex).toBe(2);
    expect(p.metersToNext).toBeCloseTo(500, -1);
    expect(p.metersPastPrev).toBeCloseTo(500, -1);
  });

  it('vehicle exactly at an interior stop → that stop is next, 0 m away', () => {
    const p = projectOntoSequence(north(1000), LINE, 500)!;
    expect(p.nextIndex).toBe(1);
    expect(p.metersToNext).toBeLessThan(5);
    // Full previous segment is behind us — a "departed stop 0" reading here
    // would be wrong, the vehicle is 1000 m past it.
    expect(p.metersPastPrev).toBeCloseTo(1000, -1);
  });

  it('vehicle before the first stop → nextIndex 0', () => {
    const p = projectOntoSequence(north(-300), LINE, 500)!;
    expect(p.nextIndex).toBe(0);
    expect(p.metersToNext).toBeCloseTo(300, -1);
    expect(p.metersPastPrev).toBe(0);
  });

  it('vehicle past the last stop → nextIndex is the terminal, distance to it', () => {
    const p = projectOntoSequence(north(3200), LINE, 500)!;
    expect(p.nextIndex).toBe(3);
    expect(p.metersToNext).toBeCloseTo(200, -1);
  });

  it('vehicle 500 m perpendicular off-route within the limit still projects', () => {
    const p = projectOntoSequence(north(1500, 500), LINE, 600)!;
    expect(p.nextIndex).toBe(2);
    // Straight-line distance to the next stop: √(500² + 500²) ≈ 707.
    expect(p.metersToNext).toBeCloseTo(707, -1);
    // Along-track progress ignores the perpendicular offset.
    expect(p.metersPastPrev).toBeCloseTo(500, -1);
  });

  it('vehicle 2000 m off every segment → null (off-route / deadheading)', () => {
    expect(projectOntoSequence(north(1500, 2000), LINE, 500)).toBeNull();
  });

  it('empty sequence → null', () => {
    expect(projectOntoSequence(BASE, [], 500)).toBeNull();
  });

  it('single-stop sequence degenerates to point distance', () => {
    const p = projectOntoSequence(north(200), [north(0)], 500)!;
    expect(p.nextIndex).toBe(0);
    expect(p.metersToNext).toBeCloseTo(200, -1);
    expect(projectOntoSequence(north(700), [north(0)], 500)).toBeNull();
  });
});
