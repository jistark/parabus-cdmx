import Foundation

/// Errors thrown by transit data providers (worker API client, realtime feed
/// client, etc).
enum TransitDataError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parsingError(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .parsingError(let message):
            return "Error al parsear: \(message)"
        case .noData:
            return "No se encontraron datos"
        }
    }
}
