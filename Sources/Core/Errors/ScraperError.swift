import Foundation

/// Errors thrown by transit data providers (worker API client, realtime feed
/// client, etc). Originally lived in MetrobusScraper.swift — moved to its own
/// file when the scraper was deleted as part of REVIEW.md Phase 2 cleanup.
/// The name is kept for source compatibility; consider renaming to
/// `TransitDataError` in a future refactor.
enum ScraperError: LocalizedError {
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
