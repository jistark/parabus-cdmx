import Foundation

/// Pure helper for diacritic- and case-insensitive search matching,
/// and for extracting a Metrobús line number from a free-text query.
enum SearchMatcher {

    // MARK: - String Matching

    /// Returns `true` when `candidate` contains `query`, ignoring diacritics
    /// and case ("linea" matches "Línea", "cuauhtemoc" matches "Cuauhtémoc").
    static func matches(_ query: String, in candidate: String) -> Bool {
        guard !query.isEmpty else { return false }
        let options: String.CompareOptions = [.diacriticInsensitive, .caseInsensitive]
        return candidate.range(of: query, options: options, locale: .current) != nil
    }

    // MARK: - Line Number Extraction

    /// Extracts a Metrobús line number (1–7) from free-text queries.
    ///
    /// Recognised forms (case + diacritic insensitive):
    ///   - Bare digit:         "4", "7"
    ///   - L-prefix:           "L4", "l 4", "l-4"
    ///   - Línea/linea prefix: "Línea 4", "linea4", "linea  4"
    ///
    /// Returns `nil` when the query does not appear to be a line query, or
    /// when the extracted number is outside 1–7.
    static func lineNumber(from query: String) -> String? {
        let normalized = query
            .trimmingCharacters(in: .whitespaces)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        // 1. Bare single digit, possibly with surrounding whitespace
        if let match = normalized.wholeMatch(of: /\s*(\d)\s*/) {
            return validLineNumber(String(match.output.1))
        }

        // 2. "L" prefix: L4, l4, L 4, l-4
        if let match = normalized.wholeMatch(of: /\s*l[\s\-]*(\d)\s*/) {
            return validLineNumber(String(match.output.1))
        }

        // 3. "linea"/"línea" prefix (diacritics already folded): linea4, linea 4
        if let match = normalized.wholeMatch(of: /\s*li?n?e?a[\s\-]*(\d)\s*/) {
            return validLineNumber(String(match.output.1))
        }

        // 4. Prefix match: "línea 4 algo", "linea4 ..." — allow trailing content
        if let match = normalized.prefixMatch(of: /\s*(linea|l)\s*(\d)/) {
            return validLineNumber(String(match.output.2))
        }

        return nil
    }

    // MARK: - Private helpers

    private static func validLineNumber(_ candidate: String) -> String? {
        guard let num = Int(candidate), (1...7).contains(num) else { return nil }
        return candidate
    }
}
