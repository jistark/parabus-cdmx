// workers/src/data/cenefas-types.ts
/**
 * Official Metrobús cenefa dataset: the real services (ramales) per line,
 * curated from the operator's official line maps — NOT derived from GTFS.
 * GTFS ids are attached as runtime matching keys only.
 *
 * Compiled into the worker (no KV/IO): served by /static/cenefas and used
 * by /arrivals for positional state derivation.
 */

export type ServiceType = 'regular' | 'corto' | 'interlinea' | 'aeropuerto';

export interface CenefaStop {
  /** GTFS stop_id at PLATFORM level (Metrobús stops are per-direction). */
  stopId: string;
  /** Official station name as printed on the cenefa. */
  name: string;
  /** Pictogram slug (convention from the 2026-05-18 map cenefa spec). */
  pictogram: string;
}

export interface CenefaDirection {
  /** Official destination name on the cenefa (terminal of this direction). */
  destination: string;
  /** GTFS route_ids whose vehicles run this service-direction (RT matching). */
  gtfsRouteIds: string[];
  /** trip_headsign values that map schedule arrivals to this direction. */
  gtfsHeadsigns: string[];
  /** Full platform-stop sequence in travel order. */
  stops: CenefaStop[];
}

export interface CenefaService {
  id: string;
  type: ServiceType;
  /** Lines involved — interlínea L2/L7 lists both: ["2", "7"]. */
  lines: string[];
  directions: CenefaDirection[];
  style: {
    colors: string[];
    notes?: string;
  };
}

export interface CenefaLine {
  line: string;
  services: CenefaService[];
}

export interface CenefaDataset {
  version: string;
  lines: CenefaLine[];
}

/** One (service, direction) hit for a given platform stop. */
export interface StopServiceHit {
  serviceId: string;
  line: string;
  serviceType: ServiceType;
  directionIndex: number;
  /** Index of the stop inside the direction's stops array. */
  position: number;
  destination: string;
  gtfsRouteIds: string[];
  gtfsHeadsigns: string[];
  stops: CenefaStop[];
}

/**
 * stopId → all (service, direction) pairs covering it, with position.
 * Built once per isolate; O(total stops) — trivial.
 */
export function buildStopIndex(dataset: CenefaDataset): Map<string, StopServiceHit[]> {
  const index = new Map<string, StopServiceHit[]>();
  for (const line of dataset.lines) {
    for (const service of line.services) {
      service.directions.forEach((dir, directionIndex) => {
        dir.stops.forEach((stop, position) => {
          const hit: StopServiceHit = {
            serviceId: service.id,
            line: line.line,
            serviceType: service.type,
            directionIndex,
            position,
            destination: dir.destination,
            gtfsRouteIds: dir.gtfsRouteIds,
            gtfsHeadsigns: dir.gtfsHeadsigns,
            stops: dir.stops,
          };
          const existing = index.get(stop.stopId);
          if (existing) existing.push(hit);
          else index.set(stop.stopId, [hit]);
        });
      });
    }
  }
  return index;
}
