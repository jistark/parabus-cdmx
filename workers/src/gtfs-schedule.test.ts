import { describe, it, expect } from 'vitest';
import {
  parseStopTimes,
  parseTime,
  nextArrivals,
  travelTime,
  type ScheduledArrival,
} from './gtfs-schedule';

describe('parseStopTimes', () => {
  it('parses a minimal valid stop_times.txt', () => {
    const csv = [
      'trip_id,arrival_time,departure_time,stop_id,stop_sequence',
      'T1,05:00:00,05:00:00,STOP_A,1',
      'T1,05:15:00,05:15:00,STOP_B,2',
      'T2,06:00:00,06:00:00,STOP_A,1',
    ].join('\n');
    const out = parseStopTimes(csv);
    expect(Object.keys(out).sort()).toEqual(['STOP_A', 'STOP_B']);
    expect(out['STOP_A']).toHaveLength(2);
    expect(out['STOP_B']).toHaveLength(1);
    expect(out['STOP_A']![0]!).toEqual({ tripId: 'T1', arrivalMinutes: 5 * 60, sequence: 1 });
  });

  it('skips rows without trip_id, stop_id, or valid arrival_time', () => {
    const csv = [
      'trip_id,arrival_time,stop_id,stop_sequence',
      'T1,05:00:00,STOP_A,1',
      ',05:00:00,STOP_B,1',     // empty trip
      'T2,05:00:00,,2',          // empty stop
      'T3,bogus,STOP_C,3',       // bad time
      'T4,07:00:00,STOP_D,4',
    ].join('\n');
    const out = parseStopTimes(csv);
    expect(Object.keys(out).sort()).toEqual(['STOP_A', 'STOP_D']);
  });

  it('throws when required columns are missing from header', () => {
    expect(() => parseStopTimes('trip_id,arrival_time\nT1,05:00:00')).toThrow(/missing required columns/);
  });
});

describe('parseTime', () => {
  it('parses HH:MM:SS to minutes', () => {
    expect(parseTime('00:00:00')).toBe(0);
    expect(parseTime('05:30:00')).toBe(330);
    expect(parseTime('23:59:00')).toBe(23 * 60 + 59);
  });

  it('accepts HH:MM without seconds', () => {
    expect(parseTime('06:15')).toBe(375);
  });

  it('wraps hours >24 modulo 24', () => {
    expect(parseTime('25:00:00')).toBe(60);
  });

  it('returns null for unparseable inputs', () => {
    expect(parseTime('')).toBeNull();
    expect(parseTime('hello')).toBeNull();
    expect(parseTime('1234')).toBeNull();
  });
});

describe('nextArrivals', () => {
  const arrivals: ScheduledArrival[] = [
    { tripId: 'T1', arrivalMinutes: 5 * 60, sequence: 1 },
    { tripId: 'T2', arrivalMinutes: 6 * 60, sequence: 1 },
    { tripId: 'T3', arrivalMinutes: 7 * 60, sequence: 1 },
    { tripId: 'T4', arrivalMinutes: 8 * 60, sequence: 1 },
  ];

  it('returns next N arrivals after current time', () => {
    expect(nextArrivals(arrivals, 5 * 60 + 30, 2)).toEqual([
      arrivals[1], arrivals[2],
    ]);
  });

  it('returns all remaining if fewer than limit', () => {
    expect(nextArrivals(arrivals, 7 * 60 + 30, 5)).toEqual([arrivals[3]]);
  });

  it('returns empty when all arrivals are past', () => {
    expect(nextArrivals(arrivals, 23 * 60, 3)).toEqual([]);
  });

  it('includes arrival exactly at the current minute', () => {
    expect(nextArrivals(arrivals, 6 * 60, 1)).toEqual([arrivals[1]]);
  });
});

describe('travelTime', () => {
  it('returns average travel time across common trips', () => {
    const origin: ScheduledArrival[] = [
      { tripId: 'T1', arrivalMinutes: 5 * 60, sequence: 1 },
      { tripId: 'T2', arrivalMinutes: 6 * 60, sequence: 1 },
    ];
    const destination: ScheduledArrival[] = [
      { tripId: 'T1', arrivalMinutes: 5 * 60 + 20, sequence: 5 },
      { tripId: 'T2', arrivalMinutes: 6 * 60 + 30, sequence: 5 },
    ];
    // T1: 20 min, T2: 30 min → avg 25
    expect(travelTime(origin, destination)).toBe(25);
  });

  it('returns null if no common trip', () => {
    const origin: ScheduledArrival[] = [
      { tripId: 'T1', arrivalMinutes: 5 * 60, sequence: 1 },
    ];
    const destination: ScheduledArrival[] = [
      { tripId: 'T2', arrivalMinutes: 5 * 60 + 20, sequence: 1 },
    ];
    expect(travelTime(origin, destination)).toBeNull();
  });

  it('ignores trips where destination is before origin (wrong direction)', () => {
    const origin: ScheduledArrival[] = [
      { tripId: 'T1', arrivalMinutes: 8 * 60, sequence: 5 },
    ];
    const destination: ScheduledArrival[] = [
      { tripId: 'T1', arrivalMinutes: 5 * 60, sequence: 1 }, // earlier in trip = wrong way
    ];
    expect(travelTime(origin, destination)).toBeNull();
  });

  it('uses earliest sequence per trip in destination index', () => {
    const origin: ScheduledArrival[] = [
      { tripId: 'T1', arrivalMinutes: 5 * 60, sequence: 1 },
    ];
    // Same trip lists the destination twice (rare data quality issue)
    const destination: ScheduledArrival[] = [
      { tripId: 'T1', arrivalMinutes: 6 * 60, sequence: 10 },
      { tripId: 'T1', arrivalMinutes: 5 * 60 + 20, sequence: 5 },
    ];
    // Should pick the lower-sequence one (earlier in trip).
    expect(travelTime(origin, destination)).toBe(20);
  });
});
