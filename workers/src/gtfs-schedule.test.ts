import { describe, it, expect } from 'vitest';
import {
  parseStopTimes,
  parseTime,
  nextArrivals,
  travelTime,
  streamFilterStop,
  type ScheduledArrival,
} from './gtfs-schedule';

/** Build a ReadableStream that yields the given chunks. Useful for testing
 *  the streaming parser with deliberately weird chunk boundaries. */
function streamFromChunks(chunks: string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder();
  let i = 0;
  return new ReadableStream({
    pull(controller) {
      if (i < chunks.length) {
        controller.enqueue(encoder.encode(chunks[i]!));
        i += 1;
      } else {
        controller.close();
      }
    },
  });
}

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

describe('streamFilterStop', () => {
  const csv = [
    'trip_id,arrival_time,departure_time,stop_id,stop_sequence',
    'T1,05:00:00,05:00:00,STOP_A,1',
    'T1,05:15:00,05:15:00,STOP_B,2',
    'T2,06:00:00,06:00:00,STOP_A,1',
    'T2,06:20:00,06:20:00,STOP_B,2',
    'T3,07:00:00,07:00:00,STOP_C,1',
  ].join('\n');

  it('returns matches for the requested stop only', async () => {
    const out = await streamFilterStop(streamFromChunks([csv]), 'STOP_A');
    expect(out).toHaveLength(2);
    expect(out.map((a) => a.tripId).sort()).toEqual(['T1', 'T2']);
  });

  it('returns empty when no rows match', async () => {
    const out = await streamFilterStop(streamFromChunks([csv]), 'STOP_NEVER');
    expect(out).toEqual([]);
  });

  it('handles chunks split mid-line', async () => {
    // Split the CSV across arbitrary byte boundaries to verify the line
    // buffer correctly reassembles across `.read()` calls.
    const split = [
      'trip_id,arrival_time,departure_time,stop_id,stop',
      '_sequence\nT1,05:00:00,05:00:00,STOP_',
      'A,1\nT1,05:15:00,05:15:00,STOP_B,2\nT2,06',
      ':00:00,06:00:00,STOP_A,1\n',
    ];
    const out = await streamFilterStop(streamFromChunks(split), 'STOP_A');
    expect(out).toHaveLength(2);
  });

  it('handles missing trailing newline', async () => {
    const noTrailingNL = csv.replace(/\n$/, ''); // ensure no trailing
    const last = noTrailingNL.endsWith('STOP_C,1') ? noTrailingNL : noTrailingNL + '\nT9,08:00:00,08:00:00,STOP_X,1';
    const out = await streamFilterStop(streamFromChunks([last]), 'STOP_C');
    expect(out).toHaveLength(1);
    expect(out[0]!.tripId).toBe('T3');
  });

  it('throws on missing required header columns', async () => {
    const bad = 'trip_id,arrival_time,stop_id\nT1,05:00:00,STOP_A';
    await expect(streamFilterStop(streamFromChunks([bad]), 'STOP_A')).rejects.toThrow(/missing required columns/);
  });

  it('skips rows where stop_id substring matches but full field does not', async () => {
    // Pre-filter uses indexOf; ensure full equality check still kicks in for
    // partial matches like "STOP_ABCD" containing "STOP_A" as a prefix.
    const partialCsv = [
      'trip_id,arrival_time,departure_time,stop_id,stop_sequence',
      'T1,05:00:00,05:00:00,STOP_ABCD,1', // contains "STOP_A" but isn't equal
      'T2,06:00:00,06:00:00,STOP_A,1',
    ].join('\n');
    const out = await streamFilterStop(streamFromChunks([partialCsv]), 'STOP_A');
    expect(out).toHaveLength(1);
    expect(out[0]!.tripId).toBe('T2');
  });

  it('decodes multi-byte UTF-8 across chunk boundaries', async () => {
    // "México" is 6 bytes in UTF-8 (the í is 2 bytes). Split the line so the
    // í straddles a chunk boundary, ensuring TextDecoder stream mode flushes
    // correctly.
    const headerAndPrefix = 'trip_id,arrival_time,departure_time,stop_id,stop_sequence\nT1,05:00:00,05:00:00,México_';
    const bytes = new TextEncoder().encode(headerAndPrefix);
    // Insert a chunk boundary inside the í (split at byte index of the start of multi-byte char).
    const splitAt = bytes.length - 6; // somewhere inside "México_"
    const stream = new ReadableStream({
      start(controller) {
        controller.enqueue(bytes.slice(0, splitAt));
        controller.enqueue(bytes.slice(splitAt));
        controller.enqueue(new TextEncoder().encode('A,1\n'));
        controller.close();
      },
    });
    const out = await streamFilterStop(stream, 'México_A');
    expect(out).toHaveLength(1);
    expect(out[0]!.tripId).toBe('T1');
  });
});
