/**
 * GTFS-Realtime protobuf decoder — partial, hand-rolled.
 *
 * Decodes only the fields we expose via the API. Avoids pulling in
 * `protobufjs` (~85KB, uses eval-based code-gen that can fail under Workers'
 * stricter CSP modes) and `gtfs-realtime-bindings` (~200KB).
 *
 * GTFS-Realtime spec: https://gtfs.org/realtime/reference/
 *
 * Wire format reference: each field is preceded by a varint tag where
 *   tag = (field_number << 3) | wire_type
 * Wire types we handle:
 *   0 = varint        (int32/int64/uint32/uint64/bool/enum)
 *   1 = fixed64       (sfixed64/fixed64/double)
 *   2 = length-delim  (string/bytes/embedded message/repeated packed)
 *   5 = fixed32       (sfixed32/fixed32/float)
 */

export interface VehiclePosition {
  /** FeedEntity.id — unique per feed snapshot. */
  entityId: string;
  /** Trip the vehicle is currently serving (may be null when deadheading). */
  tripId: string | null;
  /** Route the trip belongs to. Maps to GTFS routes.txt. */
  routeId: string | null;
  /** Vehicle identifier (operator-assigned). */
  vehicleId: string | null;
  /** Human-readable label, often equals vehicleId. */
  vehicleLabel: string | null;
  /** WGS84 latitude. */
  lat: number | null;
  /** WGS84 longitude. */
  lon: number | null;
  /** Compass bearing 0–360 (degrees clockwise from north). */
  bearing: number | null;
  /** Meters per second. */
  speed: number | null;
  /** Sequence index of the next stop within the trip. */
  currentStopSequence: number | null;
  /** Next stop id (from GTFS stops.txt). */
  stopId: string | null;
  /** Unix timestamp (seconds) of this position fix. */
  timestamp: number | null;
}

export interface DecodedFeed {
  /** Timestamp from FeedHeader (Unix seconds). */
  feedTimestamp: number | null;
  vehicles: VehiclePosition[];
}

export function decodeFeedMessage(bytes: Uint8Array): DecodedFeed {
  const reader = new Reader(bytes);
  const vehicles: VehiclePosition[] = [];
  let feedTimestamp: number | null = null;

  while (reader.hasMore()) {
    const { field, wire } = reader.readTag();
    if (field === 1 && wire === 2) {
      // FeedMessage.header (FeedHeader)
      const headerBytes = reader.readBytes();
      feedTimestamp = decodeFeedHeader(headerBytes);
    } else if (field === 2 && wire === 2) {
      // FeedMessage.entity (repeated FeedEntity)
      const entityBytes = reader.readBytes();
      const v = decodeFeedEntity(entityBytes);
      if (v) vehicles.push(v);
    } else {
      reader.skip(wire);
    }
  }

  return { feedTimestamp, vehicles };
}

function decodeFeedHeader(bytes: Uint8Array): number | null {
  const reader = new Reader(bytes);
  let timestamp: number | null = null;
  while (reader.hasMore()) {
    const { field, wire } = reader.readTag();
    if (field === 3 && wire === 0) {
      // FeedHeader.timestamp (uint64)
      timestamp = Number(reader.readVarint());
    } else {
      reader.skip(wire);
    }
  }
  return timestamp;
}

function decodeFeedEntity(bytes: Uint8Array): VehiclePosition | null {
  const reader = new Reader(bytes);
  let entityId = '';
  let vehicle: VehiclePosition | null = null;

  while (reader.hasMore()) {
    const { field, wire } = reader.readTag();
    if (field === 1 && wire === 2) {
      // FeedEntity.id (string, required)
      entityId = reader.readString();
    } else if (field === 4 && wire === 2) {
      // FeedEntity.vehicle (VehiclePosition)
      vehicle = decodeVehiclePosition(reader.readBytes());
    } else {
      reader.skip(wire);
    }
  }

  if (!vehicle) return null;
  vehicle.entityId = entityId;
  return vehicle;
}

function decodeVehiclePosition(bytes: Uint8Array): VehiclePosition {
  const reader = new Reader(bytes);
  const v: VehiclePosition = {
    entityId: '',
    tripId: null,
    routeId: null,
    vehicleId: null,
    vehicleLabel: null,
    lat: null,
    lon: null,
    bearing: null,
    speed: null,
    currentStopSequence: null,
    stopId: null,
    timestamp: null,
  };

  while (reader.hasMore()) {
    const { field, wire } = reader.readTag();
    if (field === 1 && wire === 2) {
      // VehiclePosition.trip (TripDescriptor)
      const { tripId, routeId } = decodeTripDescriptor(reader.readBytes());
      v.tripId = tripId;
      v.routeId = routeId;
    } else if (field === 8 && wire === 2) {
      // VehiclePosition.vehicle (VehicleDescriptor)
      const { id, label } = decodeVehicleDescriptor(reader.readBytes());
      v.vehicleId = id;
      v.vehicleLabel = label;
    } else if (field === 2 && wire === 2) {
      // VehiclePosition.position (Position)
      const pos = decodePosition(reader.readBytes());
      v.lat = pos.lat;
      v.lon = pos.lon;
      v.bearing = pos.bearing;
      v.speed = pos.speed;
    } else if (field === 3 && wire === 0) {
      // VehiclePosition.current_stop_sequence (uint32)
      v.currentStopSequence = Number(reader.readVarint());
    } else if (field === 7 && wire === 2) {
      // VehiclePosition.stop_id (string)
      v.stopId = reader.readString();
    } else if (field === 5 && wire === 0) {
      // VehiclePosition.timestamp (uint64)
      v.timestamp = Number(reader.readVarint());
    } else {
      reader.skip(wire);
    }
  }

  return v;
}

function decodeTripDescriptor(bytes: Uint8Array): { tripId: string | null; routeId: string | null } {
  const reader = new Reader(bytes);
  let tripId: string | null = null;
  let routeId: string | null = null;

  while (reader.hasMore()) {
    const { field, wire } = reader.readTag();
    if (field === 1 && wire === 2) {
      // TripDescriptor.trip_id (string)
      tripId = reader.readString();
    } else if (field === 5 && wire === 2) {
      // TripDescriptor.route_id (string)
      routeId = reader.readString();
    } else {
      reader.skip(wire);
    }
  }

  return { tripId, routeId };
}

function decodeVehicleDescriptor(bytes: Uint8Array): { id: string | null; label: string | null } {
  const reader = new Reader(bytes);
  let id: string | null = null;
  let label: string | null = null;

  while (reader.hasMore()) {
    const { field, wire } = reader.readTag();
    if (field === 1 && wire === 2) {
      // VehicleDescriptor.id (string)
      id = reader.readString();
    } else if (field === 2 && wire === 2) {
      // VehicleDescriptor.label (string)
      label = reader.readString();
    } else {
      reader.skip(wire);
    }
  }

  return { id, label };
}

function decodePosition(bytes: Uint8Array): {
  lat: number | null;
  lon: number | null;
  bearing: number | null;
  speed: number | null;
} {
  const reader = new Reader(bytes);
  let lat: number | null = null;
  let lon: number | null = null;
  let bearing: number | null = null;
  let speed: number | null = null;

  while (reader.hasMore()) {
    const { field, wire } = reader.readTag();
    if (field === 1 && wire === 5) {
      // Position.latitude (float)
      lat = reader.readFloat();
    } else if (field === 2 && wire === 5) {
      // Position.longitude (float)
      lon = reader.readFloat();
    } else if (field === 3 && wire === 5) {
      // Position.bearing (float). Sinoptico publishes raw GPS heading which
      // can exceed [0, 360) — normalize so consumers can rotate compass
      // arrows without a modulus step.
      const raw = reader.readFloat();
      bearing = ((raw % 360) + 360) % 360;
    } else if (field === 5 && wire === 5) {
      // Position.speed (float)
      speed = reader.readFloat();
    } else {
      reader.skip(wire);
    }
  }

  return { lat, lon, bearing, speed };
}

// ============================================================================
// Wire-format reader
// ============================================================================

class Reader {
  private pos = 0;
  private view: DataView;
  constructor(private buf: Uint8Array) {
    this.view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  }

  hasMore(): boolean {
    return this.pos < this.buf.length;
  }

  readTag(): { field: number; wire: number } {
    const tag = Number(this.readVarint());
    return { field: tag >>> 3, wire: tag & 0x7 };
  }

  /** Returns a bigint to handle full uint64 range; caller narrows if needed. */
  readVarint(): bigint {
    let result = 0n;
    let shift = 0n;
    while (this.pos < this.buf.length) {
      const byte = this.buf[this.pos++]!;
      result |= BigInt(byte & 0x7f) << shift;
      if ((byte & 0x80) === 0) return result;
      shift += 7n;
      if (shift > 70n) throw new Error('varint too long');
    }
    throw new Error('truncated varint');
  }

  readString(): string {
    return new TextDecoder().decode(this.readBytes());
  }

  readBytes(): Uint8Array {
    const len = Number(this.readVarint());
    // Bounds-check: subarray clamps silently if `pos + len > buf.length`,
    // returning a truncated slice while still advancing `pos` past the end.
    // Without this check, a single corrupt varint upstream produces
    // arbitrarily wrong nested-message decodes with no error surfaced.
    if (len < 0 || this.pos + len > this.buf.length) {
      throw new Error(
        `truncated length-delimited field: pos=${this.pos} len=${len} buf=${this.buf.length}`,
      );
    }
    const slice = this.buf.subarray(this.pos, this.pos + len);
    this.pos += len;
    return slice;
  }

  readFloat(): number {
    if (this.pos + 4 > this.buf.length) {
      throw new Error(`truncated fixed32: pos=${this.pos} buf=${this.buf.length}`);
    }
    const v = this.view.getFloat32(this.pos, true);
    this.pos += 4;
    return v;
  }

  skip(wire: number): void {
    switch (wire) {
      case 0:
        this.readVarint();
        return;
      case 1:
        if (this.pos + 8 > this.buf.length) {
          throw new Error(`truncated fixed64: pos=${this.pos} buf=${this.buf.length}`);
        }
        this.pos += 8;
        return;
      case 2: {
        const len = Number(this.readVarint());
        if (len < 0 || this.pos + len > this.buf.length) {
          throw new Error(
            `truncated length-delimited skip: pos=${this.pos} len=${len} buf=${this.buf.length}`,
          );
        }
        this.pos += len;
        return;
      }
      case 5:
        if (this.pos + 4 > this.buf.length) {
          throw new Error(`truncated fixed32 skip: pos=${this.pos} buf=${this.buf.length}`);
        }
        this.pos += 4;
        return;
      default:
        throw new Error(`unknown wire type ${wire}`);
    }
  }
}
