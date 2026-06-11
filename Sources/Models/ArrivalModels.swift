// Sources/Models/ArrivalModels.swift
import Foundation

/// Wire types for GET /arrivals — the worker derives all states; the app
/// only decodes and displays. Spec: 2026-06-11 cenefas/arrivals data layer.

enum ArrivalState: String, Decodable, Sendable {
    case arriving
    case eta
    case departed
    case scheduled
}

enum ArrivalSource: String, Decodable, Sendable {
    case realtime
    case schedule
}

struct ArrivalRow: Decodable, Sendable, Equatable {
    let serviceId: String
    let line: String
    let destination: String
    let state: ArrivalState
    let etaMinutes: Int?
    let vehicleId: String?
    let source: ArrivalSource
}

struct ArrivalsResponse: Decodable, Sendable {
    let serviceActive: Bool
    let feedTimestamp: Int?
    let feedAgeSeconds: Int?
    let realtimeStale: Bool
    let stop: String
    let rows: [ArrivalRow]
    /// Present with empty `rows` when the stop isn't covered by the cenefa
    /// dataset (e.g. operator GTFS update pending re-curation) — callers fall
    /// back to GTFSScheduleService.
    let warning: String?

    /// Decodes each element independently; elements that fail (e.g. a future
    /// ArrivalState the app doesn't know yet) are dropped instead of failing
    /// the whole response — worker and app deploy independently.
    private struct LossyRow: Decodable {
        let row: ArrivalRow?
        init(from decoder: Decoder) throws {
            row = try? ArrivalRow(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serviceActive   = try c.decode(Bool.self,   forKey: .serviceActive)
        feedTimestamp   = try c.decodeIfPresent(Int.self,  forKey: .feedTimestamp)
        feedAgeSeconds  = try c.decodeIfPresent(Int.self,  forKey: .feedAgeSeconds)
        realtimeStale   = try c.decode(Bool.self,   forKey: .realtimeStale)
        stop            = try c.decode(String.self, forKey: .stop)
        warning         = try c.decodeIfPresent(String.self, forKey: .warning)
        let lossy       = try c.decode([LossyRow].self, forKey: .rows)
        rows            = lossy.compactMap(\.row)
    }

    private enum CodingKeys: String, CodingKey {
        case serviceActive, feedTimestamp, feedAgeSeconds, realtimeStale, stop, rows, warning
    }
}
