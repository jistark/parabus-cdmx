// Sources/Models/IncidentGrouping.swift
import Foundation

/// Severity ordering for incident lists, extracted from the retired
/// AlertsView's five hand-rolled sections (spec 2 §5). Used by the home's
/// alert sections.
enum IncidentGrouping {
    /// Most urgent first — mirrors the old protests > suspended > delayed
    /// > limited > intervention section order exactly.
    static let severityOrder: [ServiceStatus] = [
        .protest, .suspended, .delayed, .limited, .intervention,
    ]

    /// Stable within a severity bucket (preserves input order).
    static func grouped(_ lines: [LineStatus]) -> [LineStatus] {
        severityOrder.flatMap { status in lines.filter { $0.status == status } }
    }
}
