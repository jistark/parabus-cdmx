import Foundation
import Testing
@testable import ParabusCore

/// ServiceStatus.init(from:) parses operator-written Spanish status strings
/// into the enum. Order of substring checks is load-bearing: the previous
/// `regular`-first ordering mis-tagged compound text like "servicio limitado,
/// regreso a regular" as `.regular`. REVIEW NIT-06 reordered the chain to
/// severity-descending so the more-severe status wins on compound input.
@Suite("ServiceStatus init(from:) Tests")
struct ServiceStatusTests {

    @Test("regular text maps to .regular")
    func plainRegular() {
        #expect(ServiceStatus(from: "Servicio Regular") == .regular)
        #expect(ServiceStatus(from: "servicio regular") == .regular)
        #expect(ServiceStatus(from: "  REGULAR  ") == .regular)
    }

    @Test("limited maps to .limited")
    func limited() {
        #expect(ServiceStatus(from: "Servicio Limitado") == .limited)
    }

    @Test("intervention maps to .intervention (with + without accent)")
    func intervention() {
        #expect(ServiceStatus(from: "Intervencion en la estacion") == .intervention)
        #expect(ServiceStatus(from: "Intervención en la estación") == .intervention)
    }

    @Test("suspended forms map to .suspended")
    func suspended() {
        #expect(ServiceStatus(from: "Servicio Suspendido") == .suspended)
        #expect(ServiceStatus(from: "Sin servicio") == .suspended)
    }

    @Test("protest forms map to .protest")
    func protest() {
        #expect(ServiceStatus(from: "Manifestacion") == .protest)
        #expect(ServiceStatus(from: "Manifestación") == .protest)
        #expect(ServiceStatus(from: "Marcha en curso") == .protest)
        #expect(ServiceStatus(from: "Bloqueo de via") == .protest)
    }

    @Test("delayed forms map to .delayed")
    func delayed() {
        #expect(ServiceStatus(from: "Servicio con Retraso") == .delayed)
        #expect(ServiceStatus(from: "Retrasos por obstrucción") == .delayed)
        #expect(ServiceStatus(from: "Congestionamiento") == .delayed)
    }

    @Test("unrecognized text falls through to .unknown")
    func unknown() {
        #expect(ServiceStatus(from: "") == .unknown)
        #expect(ServiceStatus(from: "asdfghjkl") == .unknown)
    }

    // MARK: - NIT-06 regression: compound text must pick the more-severe status

    @Test("REGRESSION (NIT-06): 'limitado y regular' picks .limited, not .regular")
    func compoundLimitedRegular() {
        // Previous `regular`-first ordering wrongly returned .regular here.
        #expect(ServiceStatus(from: "Servicio limitado con regreso a regular") == .limited)
    }

    @Test("REGRESSION (NIT-06): 'suspendido por manifestación' picks .protest, not .suspended")
    func compoundSuspendedProtest() {
        // Protest is more urgent than suspended, so the chain checks it first.
        #expect(ServiceStatus(from: "suspendido por manifestación") == .protest)
    }

    @Test("REGRESSION (NIT-06): 'retraso con regular después' picks .delayed")
    func compoundDelayedRegular() {
        #expect(ServiceStatus(from: "Servicio con retraso, regular después de las 10h") == .delayed)
    }

    @Test("REGRESSION (NIT-06): 'intervención y regular' picks .intervention")
    func compoundInterventionRegular() {
        #expect(ServiceStatus(from: "Intervención puntual; servicio regular en el resto") == .intervention)
    }
}
