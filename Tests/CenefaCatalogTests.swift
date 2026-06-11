// Tests/CenefaCatalogTests.swift
import Foundation
import Testing
@testable import ParabusCore

@Suite("Cenefa catalog")
struct CenefaCatalogTests {

    private let datasetJSON = """
    {
      "version": "2026-06-11",
      "lines": [{
        "line": "2",
        "services": [{
          "id": "L2-regular", "type": "regular", "lines": ["2"],
          "directions": [{
            "destination": "Tacubaya",
            "gtfsRouteIds": ["R2W"], "gtfsHeadsigns": ["Tacubaya"],
            "stops": [
              {"stopId": "A1", "name": "Tepalcates", "pictogram": "tepalcates"},
              {"stopId": "A2", "name": "Amores", "pictogram": "amores"}
            ]
          }],
          "style": {"colors": ["#7B1FA2"]}
        }]
      }]
    }
    """.data(using: .utf8)!

    private var interlineaJSON: Data {
        let s = String(data: datasetJSON, encoding: .utf8)!
            .replacingOccurrences(of: "\"lines\": [\"2\"]", with: "\"lines\": [\"2\", \"7\"]")
        return s.data(using: .utf8)!
    }

    @Test func decodesDataset() throws {
        let dataset = try JSONDecoder().decode(CenefaDataset.self, from: datasetJSON)
        #expect(dataset.version == "2026-06-11")
        #expect(dataset.lines[0].services[0].directions[0].stops.count == 2)
        #expect(dataset.lines[0].services[0].style.notes == nil)
    }

    @Test func roundTripsThroughCodable() throws {
        let dataset = try JSONDecoder().decode(CenefaDataset.self, from: datasetJSON)
        let encoded = try JSONEncoder().encode(dataset)
        let decoded = try JSONDecoder().decode(CenefaDataset.self, from: encoded)
        #expect(decoded == dataset)
    }

    @Test func findsServicesAtStopAndForLine() throws {
        let dataset = try JSONDecoder().decode(CenefaDataset.self, from: datasetJSON)
        #expect(dataset.services(at: "A2").count == 1)
        #expect(dataset.services(at: "A2")[0].id == "L2-regular")
        #expect(dataset.services(forLine: "2").count == 1)
        #expect(dataset.services(at: "ZZ").isEmpty)
    }

    @Test func interlineaMatchesByMemberLinesNotParent() throws {
        let base = try JSONDecoder().decode(CenefaDataset.self, from: datasetJSON)
        #expect(base.services(forLine: "7").isEmpty)
        let inter = try JSONDecoder().decode(CenefaDataset.self, from: interlineaJSON)
        #expect(inter.services(forLine: "7").count == 1)
    }

    @Test func cacheExpiryIs24Hours() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        #expect(!CenefaCatalog.isExpired(fetchedAt: now.addingTimeInterval(-23 * 3600), now: now))
        #expect(CenefaCatalog.isExpired(fetchedAt: now.addingTimeInterval(-25 * 3600), now: now))
    }
}
