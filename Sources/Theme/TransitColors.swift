import SwiftUI

// MARK: - Status Colors

/// Colores semanticos para estados de servicio
enum StatusColor {
    /// Verde - servicio normal
    static let good = Color.green

    /// Naranja - intervencion/obra
    static let warning = Color.orange

    /// Rojo - suspendido
    static let alert = Color.red

    /// Rojo - retraso (real-time urgent issue, same as suspended)
    static let delay = Color.red

    /// Gris - desconocido
    static let unknown = Color.secondary

    /// Retorna el color apropiado para un estado
    static func color(for status: ServiceStatus) -> Color {
        switch status {
        case .regular: return good
        case .intervention: return warning
        case .limited: return warning
        case .delayed: return delay
        case .suspended: return alert
        case .protest: return alert
        case .unknown: return unknown
        }
    }

    /// Icono SF Symbol para un estado
    static func icon(for status: ServiceStatus) -> String {
        switch status {
        case .regular: return "checkmark.circle.fill"
        case .intervention: return "wrench.and.screwdriver.fill"
        case .limited: return "arrow.left.arrow.right"
        case .delayed: return "clock.badge.exclamationmark"
        case .suspended: return "xmark.octagon.fill"
        case .protest: return "megaphone.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    /// Whether status icon should pulse (for urgent states)
    static func shouldPulse(for status: ServiceStatus) -> Bool {
        status == .suspended || status == .delayed || status == .protest
    }

    /// Texto corto para un estado
    static func shortText(for status: ServiceStatus) -> String {
        switch status {
        case .regular: return "OK"
        case .intervention: return "Obra"
        case .limited: return "Limitado"
        case .delayed: return "Retraso"
        case .suspended: return "Susp."
        case .protest: return "Protestas"
        case .unknown: return "?"
        }
    }

    /// Texto largo para un estado
    static func displayText(for status: ServiceStatus) -> String {
        switch status {
        case .regular: return "Servicio normal"
        case .intervention: return "Intervencion activa"
        case .limited: return "Servicio limitado"
        case .delayed: return "Con retraso"
        case .suspended: return "Suspendido"
        case .protest: return "Manifestacion"
        case .unknown: return "Desconocido"
        }
    }
}

// MARK: - Line Colors

/// Colores oficiales de las lineas de Metrobus
enum LineColor {
    /// Rojo - Linea 1
    static let line1 = Color(red: 0.83, green: 0.18, blue: 0.18)

    /// Morado - Linea 2
    static let line2 = Color(red: 0.48, green: 0.18, blue: 0.56)

    /// Verde - Linea 3
    static let line3 = Color(red: 0.13, green: 0.55, blue: 0.13)

    /// Amarillo/Dorado - Linea 4
    static let line4 = Color(red: 0.96, green: 0.65, blue: 0.14)

    /// Azul - Linea 5
    static let line5 = Color(red: 0.00, green: 0.48, blue: 0.65)

    /// Rosa/Magenta - Linea 6
    static let line6 = Color(red: 0.80, green: 0.00, blue: 0.47)

    /// Verde Azulado - Linea 7
    static let line7 = Color(red: 0.00, green: 0.60, blue: 0.40)

    /// Gris - Linea desconocida
    static let unknown = Color.gray

    /// Retorna el color para un numero de linea
    static func color(for lineNumber: String) -> Color {
        switch lineNumber {
        case "1": return line1
        case "2": return line2
        case "3": return line3
        case "4": return line4
        case "5": return line5
        case "6": return line6
        case "7": return line7
        default: return unknown
        }
    }
}

// MARK: - Material Opacities

/// Opacidades estandarizadas para efectos de material
enum MaterialOpacity {
    /// Fondo muy sutil (cards normales)
    static let subtle: Double = 0.06

    /// Fondo ligero (cards con estado)
    static let light: Double = 0.10

    /// Fondo medio (elementos destacados)
    static let medium: Double = 0.15

    /// Borde sutil
    static let border: Double = 0.20

    /// Borde con enfasis
    static let borderStrong: Double = 0.40
}

// MARK: - Badge Sizes

/// Tamanos estandarizados para badges de linea
enum BadgeSize {
    case small   // 32pts - uso minimo
    case regular // 48pts - tiles, banners, sheets
    case large   // 56pts - hero cards

    var dimension: CGFloat {
        switch self {
        case .small: return 32
        case .regular: return 48
        case .large: return 56
        }
    }

    /// Tamano minimo de touch target (44pts)
    var touchTarget: CGFloat {
        max(dimension, 44)
    }

    var font: Font {
        switch self {
        case .small: return .subheadline
        case .regular: return .headline
        case .large: return .title
        }
    }
}

// MARK: - Timeline Sizes

/// Tamanos para elementos del timeline
enum TimelineSize {
    /// Punto de estacion
    static let stationDot: CGFloat = 20

    /// Punto interno blanco
    static let innerDot: CGFloat = 8

    /// Ancho de la linea conectora
    static let connectorWidth: CGFloat = 3

    /// Ancho del track completo
    static let trackWidth: CGFloat = 28

    /// Icono dentro del status badge
    static let statusIcon: CGFloat = 10
}
