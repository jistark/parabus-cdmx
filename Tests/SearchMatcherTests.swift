import Testing
@testable import ParabusCore

@Suite("SearchMatcher")
struct SearchMatcherTests {

    // MARK: - matches(_:in:)

    @Test("Diacritic-tolerant: accent in candidate, none in query")
    func matchesDiacriticInCandidate() {
        #expect(SearchMatcher.matches("Cuauhtemoc", in: "Cuauhtémoc"))
        #expect(SearchMatcher.matches("balderas", in: "Balderas"))
        #expect(SearchMatcher.matches("buenavista", in: "Buenavista L1"))
    }

    @Test("Diacritic-tolerant: accent in query, none in candidate")
    func matchesDiacriticInQuery() {
        #expect(SearchMatcher.matches("Cuauhtémoc", in: "Cuauhtemoc"))
        #expect(SearchMatcher.matches("línea", in: "linea"))
    }

    @Test("Case-insensitive matching")
    func matchesCaseInsensitive() {
        #expect(SearchMatcher.matches("BALDERAS", in: "Balderas"))
        #expect(SearchMatcher.matches("balderas", in: "BALDERAS"))
        #expect(SearchMatcher.matches("canela", in: "Canela"))
    }

    @Test("Substring containment")
    func matchesSubstring() {
        #expect(SearchMatcher.matches("canal", in: "Canal de San Juan"))
        #expect(SearchMatcher.matches("san juan", in: "Canal de San Juan"))
    }

    @Test("Non-match returns false")
    func noMatchReturnsFalse() {
        #expect(!SearchMatcher.matches("xochimilco", in: "Balderas"))
        #expect(!SearchMatcher.matches("insurgentes", in: "Balderas"))
        #expect(!SearchMatcher.matches("chapultepec", in: "Metrobus Línea 4"))
    }

    @Test("Empty query returns false")
    func emptyQueryReturnsFalse() {
        #expect(!SearchMatcher.matches("", in: "Balderas"))
    }

    // MARK: - lineNumber(from:)

    @Test("Bare digit 1–7 extracted")
    func lineNumberFromBareDigit() {
        #expect(SearchMatcher.lineNumber(from: "4") == "4")
        #expect(SearchMatcher.lineNumber(from: "1") == "1")
        #expect(SearchMatcher.lineNumber(from: "7") == "7")
        #expect(SearchMatcher.lineNumber(from: " 3 ") == "3")
    }

    @Test("L-prefix variants extracted")
    func lineNumberFromLPrefix() {
        #expect(SearchMatcher.lineNumber(from: "L4") == "4")
        #expect(SearchMatcher.lineNumber(from: "l4") == "4")
        #expect(SearchMatcher.lineNumber(from: "L 4") == "4")
        #expect(SearchMatcher.lineNumber(from: "l-4") == "4")
    }

    @Test("Línea/linea prefix variants extracted")
    func lineNumberFromLineaPrefix() {
        #expect(SearchMatcher.lineNumber(from: "línea 4") == "4")
        #expect(SearchMatcher.lineNumber(from: "Línea 4") == "4")
        #expect(SearchMatcher.lineNumber(from: "linea4") == "4")
        #expect(SearchMatcher.lineNumber(from: "linea 4") == "4")
        #expect(SearchMatcher.lineNumber(from: "LINEA 4") == "4")
    }

    @Test("Out-of-range digits return nil")
    func lineNumberOutOfRangeNil() {
        #expect(SearchMatcher.lineNumber(from: "8") == nil)
        #expect(SearchMatcher.lineNumber(from: "0") == nil)
        #expect(SearchMatcher.lineNumber(from: "L9") == nil)
    }

    @Test("Non-line queries return nil")
    func lineNumberFromNonLineQueryNil() {
        #expect(SearchMatcher.lineNumber(from: "Balderas") == nil)
        #expect(SearchMatcher.lineNumber(from: "canal") == nil)
        #expect(SearchMatcher.lineNumber(from: "") == nil)
    }
}
