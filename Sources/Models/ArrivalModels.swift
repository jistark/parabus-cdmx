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
}
