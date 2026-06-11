// Tests/ArrivalRowPresentationTests.swift
import Foundation
import Testing
@testable import ParabusCore

@Suite("Arrival row presentation")
struct ArrivalRowPresentationTests {

    private func row(_ state: ArrivalState, eta: Int? = nil, source: ArrivalSource = .realtime) -> ArrivalRow {
        ArrivalRow(serviceId: "s", line: "1", destination: "El Caminero",
                   state: state, etaMinutes: eta, vehicleId: nil, source: source)
    }

    @Test func arriving() {
        let p = ArrivalRowPresentation(row: row(.arriving))
        #expect(p.statusText == "LLEGANDO")
        #expect(p.tone == .positive)
        #expect(p.marquee == .arriving)
        #expect(!p.showsClock)
    }

    @Test func etaShowsMinutes() {
        let p = ArrivalRowPresentation(row: row(.eta, eta: 4))
        #expect(p.statusText == "4 MIN")
        #expect(p.tone == .neutral)
        #expect(p.marquee == .none)
    }

    @Test func departed() {
        let p = ArrivalRowPresentation(row: row(.departed))
        #expect(p.statusText == "DEJÓ LA ESTACIÓN")
        #expect(p.tone == .negative)
        #expect(p.marquee == .departed)
    }

    @Test func scheduledShowsClockAndMutedMinutes() {
        let p = ArrivalRowPresentation(row: row(.scheduled, eta: 7, source: .schedule))
        #expect(p.statusText == "7 MIN")
        #expect(p.tone == .muted)
        #expect(p.showsClock)
    }

    @Test func scheduledWithoutMinutesShowsDash() {
        let p = ArrivalRowPresentation(row: row(.scheduled, eta: nil, source: .schedule))
        #expect(p.statusText == "—")
        #expect(p.showsClock)
    }
}

@Suite("Hex color parsing")
struct HexColorTests {
    @Test func parsesSixDigitHex() {
        let rgb = ColorHex.components("#A4343A")
        #expect(rgb != nil)
        #expect(abs(rgb!.r - 164.0 / 255.0) < 0.001)
        #expect(abs(rgb!.g - 52.0 / 255.0) < 0.001)
        #expect(abs(rgb!.b - 58.0 / 255.0) < 0.001)
        #expect(ColorHex.components("zzz") == nil)
    }
}
