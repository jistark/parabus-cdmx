import SwiftUI

struct LineRowView: View {
    let line: LineStatus

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator - FIRST for visual priority
            StatusIndicator(status: line.status)

            // Line info
            VStack(alignment: .leading, spacing: 2) {
                Text(line.lineName)
                    .font(.headline)

                Text(line.quickSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Line badge - smaller, for identification
            LineBadge(number: line.lineNumber, transportType: line.transportType, size: .small)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(line.lineName), \(line.status.rawValue)")
        .accessibilityHint(line.hasIssues ? "Toca dos veces para ver detalles" : "")
    }
}

// MARK: - Status Indicator (prominent, left side)

struct StatusIndicator: View {
    let status: ServiceStatus

    var body: some View {
        Image(systemName: iconName)
            .font(.title3.weight(.semibold))
            .foregroundStyle(iconColor)
            .frame(width: 28, height: 28)
            .symbolEffect(.pulse, options: .repeating, isActive: shouldPulse)
    }

    private var iconName: String {
        switch status {
        case .regular: "checkmark.circle.fill"
        case .intervention: "wrench.and.screwdriver.fill"
        case .limited: "arrow.left.arrow.right"
        case .delayed: "clock.fill"
        case .suspended: "xmark.circle.fill"
        case .protest: "megaphone.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .regular: .green
        case .intervention: .orange
        case .limited: .orange
        case .delayed: Color(red: 0.85, green: 0.55, blue: 0.0)
        case .suspended: .red
        case .protest: .red
        case .unknown: .secondary
        }
    }

    private var shouldPulse: Bool {
        status == .suspended || status == .protest
    }
}

// MARK: - Quick Summary Extension

extension LineStatus {
    /// Resumen corto para mostrar en la fila
    var quickSummary: String {
        // If multiple incidents, show count
        if incidentCount > 1 {
            let stationCount = affectedStations.count
            if stationCount > 0 {
                return "\(incidentCount) incidentes, \(stationCount) estacion\(stationCount == 1 ? "" : "es")"
            }
            return "\(incidentCount) incidentes activos"
        }

        // Single incident or none - use status-based summary
        switch status {
        case .regular:
            return "Operando normal"
        case .intervention:
            if affectedStations.isEmpty {
                return "Intervencion en curso"
            }
            let count = affectedStations.count
            return count == 1
                ? "Intervencion en 1 estacion"
                : "Intervencion en \(count) estaciones"
        case .limited:
            return "Servicio limitado"
        case .delayed:
            return "Servicio con retraso"
        case .suspended:
            return "Servicio suspendido"
        case .protest:
            return "Afectado por manifestacion"
        case .unknown:
            return "Estado desconocido"
        }
    }
}

#Preview {
    List {
        LineRowView(line: LineStatus(
            lineNumber: "1",
            transportType: .metrobus,
            status: .regular,
            affectedStations: []
        ))

        LineRowView(line: LineStatus(
            lineNumber: "2",
            transportType: .metrobus,
            status: .intervention,
            affectedStations: ["La Joya", "Iztacalco"],
            additionalInfo: "Por mantenimiento"
        ))

        LineRowView(line: LineStatus(
            lineNumber: "7",
            transportType: .metrobus,
            status: .suspended,
            affectedStations: ["Indios Verdes", "Politécnico"]
        ))

        LineRowView(line: LineStatus(
            lineNumber: "4",
            transportType: .metrobus,
            status: .delayed,
            affectedStations: ["Buenavista"]
        ))
    }
    #if os(iOS)
    .listStyle(.insetGrouped)
    #endif
}
