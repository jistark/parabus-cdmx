import { describe, it, expect } from 'vitest';
import { decodeFeedMessage } from './gtfs-rt';

// ============================================================================
// Tiny protobuf wire-format encoder for test fixtures.
// Mirrors the decoder in gtfs-rt.ts. Kept here so tests don't depend on any
// external protobuf library.
// ============================================================================

function varintBytes(n: number): number[] {
  const out: number[] = [];
  while (n >= 0x80) {
    out.push((n & 0x7f) | 0x80);
    n >>>= 7;
  }
  out.push(n);
  return out;
}

function tag(field: number, wire: number): number[] {
  return varintBytes((field << 3) | wire);
}

function lengthDelim(field: number, body: number[]): number[] {
  return [...tag(field, 2), ...varintBytes(body.length), ...body];
}

function stringField(field: number, s: string): number[] {
  return lengthDelim(field, [...new TextEncoder().encode(s)]);
}

function varintField(field: number, n: number): number[] {
  return [...tag(field, 0), ...varintBytes(n)];
}

function float32Field(field: number, f: number): number[] {
  const buf = new ArrayBuffer(4);
  new DataView(buf).setFloat32(0, f, true);
  return [...tag(field, 5), ...new Uint8Array(buf)];
}

// ============================================================================
// Fixtures
// ============================================================================

/** Builds a minimal FeedMessage with one VehiclePosition for testing. */
function buildSampleFeed(opts: {
  bearing?: number;
  feedTimestamp?: number;
  vehicleTimestamp?: number;
} = {}): Uint8Array {
  const positionBytes = [
    ...float32Field(1, 19.5),
    ...float32Field(2, -99.1),
    ...float32Field(3, opts.bearing ?? 90),
    ...float32Field(5, 12.5),
  ];
  const tripBytes = [
    ...stringField(1, 'TRIP_001'),
    ...stringField(5, 'ROUTE_42'),
  ];
  const vehicleDescBytes = [
    ...stringField(1, 'V42'),
    ...stringField(2, 'Bus 42'),
  ];
  const vehiclePositionBytes = [
    ...lengthDelim(1, tripBytes),
    ...lengthDelim(2, positionBytes),
    ...varintField(3, 7),
    ...varintField(5, opts.vehicleTimestamp ?? 1_700_000_000),
    ...stringField(7, 'STOP_X'),
    ...lengthDelim(8, vehicleDescBytes),
  ];
  const entityBytes = [
    ...stringField(1, 'ent-001'),
    ...lengthDelim(4, vehiclePositionBytes),
  ];
  const headerBytes = [...varintField(3, opts.feedTimestamp ?? 1_700_000_000)];
  const feedBytes = [
    ...lengthDelim(1, headerBytes),
    ...lengthDelim(2, entityBytes),
  ];
  return new Uint8Array(feedBytes);
}

// ============================================================================
// Tests
// ============================================================================

describe('decodeFeedMessage', () => {
  it('decodes a single vehicle position', () => {
    const bytes = buildSampleFeed();
    const decoded = decodeFeedMessage(bytes);

    expect(decoded.feedTimestamp).toBe(1_700_000_000);
    expect(decoded.vehicles).toHaveLength(1);

    const v = decoded.vehicles[0]!;
    expect(v.entityId).toBe('ent-001');
    expect(v.tripId).toBe('TRIP_001');
    expect(v.routeId).toBe('ROUTE_42');
    expect(v.vehicleId).toBe('V42');
    expect(v.vehicleLabel).toBe('Bus 42');
    expect(v.lat).toBeCloseTo(19.5, 4);
    expect(v.lon).toBeCloseTo(-99.1, 4);
    expect(v.bearing).toBeCloseTo(90, 4);
    expect(v.speed).toBeCloseTo(12.5, 4);
    expect(v.currentStopSequence).toBe(7);
    expect(v.stopId).toBe('STOP_X');
    expect(v.timestamp).toBe(1_700_000_000);
  });

  it('normalizes bearing outside [0, 360)', () => {
    // Sinoptico Plus publishes raw GPS heading which can exceed 360°
    const overflow = decodeFeedMessage(buildSampleFeed({ bearing: 400 }));
    expect(overflow.vehicles[0]!.bearing).toBeCloseTo(40, 3);

    const negative = decodeFeedMessage(buildSampleFeed({ bearing: -10 }));
    expect(negative.vehicles[0]!.bearing).toBeCloseTo(350, 3);

    const huge = decodeFeedMessage(buildSampleFeed({ bearing: 720.5 }));
    expect(huge.vehicles[0]!.bearing).toBeCloseTo(0.5, 3);
  });

  it('decodes empty feed (header only)', () => {
    const headerBytes = [...varintField(3, 1_700_000_000)];
    const bytes = new Uint8Array([...lengthDelim(1, headerBytes)]);
    const decoded = decodeFeedMessage(bytes);
    expect(decoded.feedTimestamp).toBe(1_700_000_000);
    expect(decoded.vehicles).toEqual([]);
  });

  it('throws on truncated length-delimited field', () => {
    // Build a feed, then truncate so the entity's declared length exceeds buffer.
    const full = buildSampleFeed();
    const truncated = full.slice(0, full.length - 5);
    expect(() => decodeFeedMessage(truncated)).toThrow(/truncated/i);
  });

  it('throws on truncated fixed32 (float)', () => {
    // Build a FeedMessage where the position bytes are cut short mid-float.
    const positionBytes = [
      ...float32Field(1, 19.5),
      ...float32Field(2, -99.1),
      ...tag(3, 5), 0x00, 0x00, // declare a float32 but only provide 2 bytes
    ];
    const vehiclePositionBytes = [
      ...lengthDelim(2, positionBytes),
    ];
    const entityBytes = [
      ...stringField(1, 'truncated'),
      ...lengthDelim(4, vehiclePositionBytes),
    ];
    const bytes = new Uint8Array(lengthDelim(2, entityBytes));
    expect(() => decodeFeedMessage(bytes)).toThrow(/truncated/i);
  });

  it('skips unknown fields without breaking', () => {
    // Insert a field with an unrecognized field number in the feed.
    const headerBytes = [...varintField(3, 1_700_000_000)];
    const bytes = new Uint8Array([
      ...lengthDelim(1, headerBytes),
      ...varintField(99, 12345), // unknown varint
      ...stringField(98, 'ignored'), // unknown string
    ]);
    const decoded = decodeFeedMessage(bytes);
    expect(decoded.feedTimestamp).toBe(1_700_000_000);
    expect(decoded.vehicles).toEqual([]);
  });
});
