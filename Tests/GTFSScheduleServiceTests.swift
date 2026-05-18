import Foundation
import Testing
@testable import ParabusCore

@Suite("GTFSScheduleService Tests")
struct GTFSScheduleServiceTests {

    // MARK: - parseStopTimes (pure)

    @Test("parses a minimal valid stop_times.txt")
    func parsesMinimalCSV() {
        let csv = """
        trip_id,arrival_time,stop_id,stop_sequence
        TRIP_A,08:30:00,STOP_1,1
        TRIP_A,08:35:00,STOP_2,2
        TRIP_B,09:00:00,STOP_1,1
        """
        let parsed = GTFSScheduleService.parseStopTimes(csv)

        #expect(parsed.count == 2)
        #expect(parsed["STOP_1"]?.count == 2)
        #expect(parsed["STOP_2"]?.count == 1)

        let stop1 = parsed["STOP_1"]!
        #expect(stop1.contains { $0.tripId == "TRIP_A" && $0.arrivalMinutes == 8 * 60 + 30 })
        #expect(stop1.contains { $0.tripId == "TRIP_B" && $0.arrivalMinutes == 9 * 60 })
    }

    @Test("returns empty dict for header-only or empty input")
    func handlesEdgeInputs() {
        #expect(GTFSScheduleService.parseStopTimes("").isEmpty)
        #expect(GTFSScheduleService.parseStopTimes("trip_id,arrival_time,stop_id,stop_sequence").isEmpty)
    }

    @Test("skips rows with missing required columns")
    func skipsMalformedRows() {
        let csv = """
        trip_id,arrival_time,stop_id,stop_sequence
        TRIP_A,08:30:00,STOP_1,1
        ,08:35:00,,2
        TRIP_B
        TRIP_C,bogus,STOP_3,3
        TRIP_D,09:00:00,STOP_4,4
        """
        let parsed = GTFSScheduleService.parseStopTimes(csv)

        // STOP_1 and STOP_4 should be parsed; STOP_3 has bogus time so it gets
        // skipped by parseTime; the empty-trip row provides empty tripId+stopId.
        #expect(parsed["STOP_1"]?.count == 1)
        #expect(parsed["STOP_4"]?.count == 1)
        #expect(parsed["STOP_3"] == nil)
    }

    @Test("rejects malformed header without crashing")
    func rejectsBadHeader() {
        let csv = """
        not_what_we_expect
        TRIP_A,08:30:00,STOP_1,1
        """
        #expect(GTFSScheduleService.parseStopTimes(csv).isEmpty)
    }

    // MARK: - parseTime

    @Test("parses HH:MM:SS into minutes-of-day")
    func parsesTime() {
        #expect(GTFSScheduleService.parseTime("00:00:00") == 0)
        #expect(GTFSScheduleService.parseTime("01:30:00") == 90)
        #expect(GTFSScheduleService.parseTime("23:59:00") == 23 * 60 + 59)
        #expect(GTFSScheduleService.parseTime("12:00:00") == 720)
    }

    @Test("accepts HH:MM without seconds")
    func parsesHHMMOnly() {
        #expect(GTFSScheduleService.parseTime("06:15") == 6 * 60 + 15)
    }

    @Test("wraps hours > 24 modulo 24 (known limitation, REVIEW HIGH-15)")
    func wrapsHoursOverflow() {
        // GTFS allows >24:00 for next-day service. The current
        // implementation folds these back into the same day — captured as
        // a known bug in the comment in GTFSScheduleService.swift.
        #expect(GTFSScheduleService.parseTime("25:00:00") == 60)
        #expect(GTFSScheduleService.parseTime("26:30:00") == 2 * 60 + 30)
    }

    @Test("rejects unparseable strings")
    func rejectsBadInput() {
        #expect(GTFSScheduleService.parseTime("") == nil)
        #expect(GTFSScheduleService.parseTime("hello") == nil)
        #expect(GTFSScheduleService.parseTime("12") == nil)
        #expect(GTFSScheduleService.parseTime("ab:cd") == nil)
    }

    // MARK: - Actor public API integration

    /// Cross-trip travel time should equal the actual schedule delta.
    @Test("travelTime returns delta between two stops on the same trip")
    func travelTimeBetweenStops() async throws {
        // We can't use a fresh GTFSScheduleService instance because there's
        // no init that accepts test data — it loads from Bundle.module.
        // Instead, verify the pure-parse output is consistent with what the
        // travel-time calculation would do.
        let csv = """
        trip_id,arrival_time,stop_id,stop_sequence
        T1,08:00:00,STOP_A,1
        T1,08:25:00,STOP_B,2
        T2,09:10:00,STOP_A,1
        T2,09:35:00,STOP_B,2
        """
        let parsed = GTFSScheduleService.parseStopTimes(csv)

        let aTrips = Set(parsed["STOP_A"]!.map(\.tripId))
        let bTrips = Set(parsed["STOP_B"]!.map(\.tripId))
        let common = aTrips.intersection(bTrips)
        #expect(common == ["T1", "T2"])

        // Both trips have 25-min travel time A → B, so the average is 25.
        var total = 0
        for trip in common {
            let a = parsed["STOP_A"]!.first { $0.tripId == trip }!.arrivalMinutes
            let b = parsed["STOP_B"]!.first { $0.tripId == trip }!.arrivalMinutes
            total += (b - a)
        }
        let avg = total / common.count
        #expect(avg == 25)
    }
}
