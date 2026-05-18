import Foundation

// MARK: - GTFS Schedule Service

/// Provides schedule-based ETA calculations using GTFS static data.
///
/// The stop_times.txt parse is heavy (the file ships at ~56MB → roughly
/// 150k+ ScheduledArrival rows). To keep the actor's executor free for
/// short reads while the first call loads, the parse runs on a detached
/// Task; the actor only blocks on the result assignment. Concurrent
/// callers coalesce via a shared loading Task so we never double-parse.
actor GTFSScheduleService {
    static let shared = GTFSScheduleService()

    // MARK: - Schedule Data

    private var stopTimes: [String: [ScheduledArrival]] = [:]
    private var isLoaded = false
    /// Tracks an in-flight load so concurrent callers wait on the same parse
    /// instead of each kicking off their own.
    private var loadingTask: Task<Void, Never>?

    // MARK: - Public API

    /// Get next scheduled arrivals for a station
    func nextArrivals(at stationId: String, limit: Int = 3) async -> [ScheduledArrival] {
        await loadIfNeeded()

        guard let arrivals = stopTimes[stationId] else {
            return []
        }

        let now = currentTimeInMinutes()
        let todayArrivals = arrivals.filter { $0.arrivalMinutes >= now }
            .sorted { $0.arrivalMinutes < $1.arrivalMinutes }
            .prefix(limit)

        return Array(todayArrivals)
    }

    /// Get ETA string for next arrival at a station
    func etaString(for stationId: String) async -> String? {
        let arrivals = await nextArrivals(at: stationId, limit: 1)
        guard let next = arrivals.first else { return nil }

        let now = currentTimeInMinutes()
        let minutesUntil = next.arrivalMinutes - now

        if minutesUntil <= 0 {
            return "Llegando"
        } else if minutesUntil == 1 {
            return "1 min"
        } else if minutesUntil < 60 {
            return "\(minutesUntil) min"
        } else {
            let hours = minutesUntil / 60
            let mins = minutesUntil % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }

    /// Calculate travel time between two stations on the same line
    func travelTime(from originId: String, to destinationId: String) async -> Int? {
        await loadIfNeeded()

        guard let originArrivals = stopTimes[originId],
              let destArrivals = stopTimes[destinationId] else {
            return nil
        }

        // Find trips that serve both stations
        let originTrips = Set(originArrivals.map { $0.tripId })
        let destTrips = Set(destArrivals.map { $0.tripId })
        let commonTrips = originTrips.intersection(destTrips)

        guard !commonTrips.isEmpty else { return nil }

        // Calculate average travel time across common trips
        var totalTime = 0
        var validTrips = 0

        for tripId in commonTrips {
            guard let originTime = originArrivals.first(where: { $0.tripId == tripId })?.arrivalMinutes,
                  let destTime = destArrivals.first(where: { $0.tripId == tripId })?.arrivalMinutes else {
                continue
            }

            let diff = destTime - originTime
            if diff > 0 {
                totalTime += diff
                validTrips += 1
            }
        }

        return validTrips > 0 ? totalTime / validTrips : nil
    }

    /// Get formatted travel time string
    func travelTimeString(from originId: String, to destinationId: String) async -> String? {
        guard let minutes = await travelTime(from: originId, to: destinationId) else {
            return nil
        }

        if minutes < 60 {
            return "~\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "~\(hours)h \(mins)m" : "~\(hours)h"
        }
    }

    // MARK: - Private Methods

    private func loadIfNeeded() async {
        if isLoaded { return }
        // Coalesce concurrent callers onto a single in-flight parse.
        if let existing = loadingTask {
            await existing.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoad()
        }
        loadingTask = task
        await task.value
        loadingTask = nil
    }

    /// Performs the actual load: locates the file, then hands the CPU-heavy
    /// parse to a detached Task so the actor's executor is free during the
    /// hundreds of ms it takes. Other actor calls (etaString, travelTime)
    /// queue on loadingTask without doing redundant parse work.
    private func performLoad() async {
        guard let url = Self.findStopTimesURL() else {
            print("GTFSSchedule: stop_times.txt not found")
            isLoaded = true // don't keep retrying a missing file
            return
        }

        let parsed: [String: [ScheduledArrival]] = await Task.detached(priority: .utility) {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                return Self.parseStopTimes(content)
            } catch {
                print("GTFSSchedule: Failed to load: \(error)")
                return [:]
            }
        }.value

        stopTimes = parsed
        isLoaded = true
        print("GTFSSchedule: Loaded \(parsed.count) stations with schedules")
    }

    private static func findStopTimesURL() -> URL? {
        #if SWIFT_PACKAGE
        let moduleURL = Bundle.module.url(forResource: "stop_times", withExtension: "txt", subdirectory: "GTFS")
        #else
        let moduleURL: URL? = nil
        #endif
        return moduleURL
            ?? Bundle.main.url(forResource: "stop_times", withExtension: "txt", subdirectory: "GTFS")
            ?? Bundle.main.url(forResource: "stop_times", withExtension: "txt")
    }

    /// Pure parse — nonisolated so it can run inside Task.detached without
    /// touching actor state. Internal (not private) so tests can exercise the
    /// parsing in isolation without going through the bundle-loaded singleton.
    static func parseStopTimes(_ content: String) -> [String: [ScheduledArrival]] {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [:] }

        let header = lines[0].components(separatedBy: ",")
        guard let tripIdx = header.firstIndex(of: "trip_id"),
              let arrivalIdx = header.firstIndex(of: "arrival_time"),
              let stopIdx = header.firstIndex(of: "stop_id"),
              let seqIdx = header.firstIndex(of: "stop_sequence") else {
            print("GTFSSchedule: Invalid header format")
            return [:]
        }

        var temp: [String: [ScheduledArrival]] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            let cols = line.components(separatedBy: ",")
            guard cols.count > max(tripIdx, arrivalIdx, stopIdx, seqIdx) else { continue }
            let tripId = cols[tripIdx]
            let stopId = cols[stopIdx]
            guard let arrivalMinutes = parseTime(cols[arrivalIdx]) else { continue }
            let sequence = Int(cols[seqIdx]) ?? 0
            let arrival = ScheduledArrival(
                tripId: tripId,
                stopId: stopId,
                arrivalMinutes: arrivalMinutes,
                sequence: sequence
            )
            temp[stopId, default: []].append(arrival)
        }
        return temp
    }

    static func parseTime(_ timeStr: String) -> Int? {
        // Format: HH:MM:SS — GTFS allows >24:00 for next-day service. We mod
        // by 24, which folds a 25:00 trip back to 1:00 (wrong day association
        // for late-night routes). Tracked as REVIEW HIGH-15 bug; out of scope
        // for the detached-parse refactor.
        let parts = timeStr.components(separatedBy: ":")
        guard parts.count >= 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return nil
        }
        return (hours % 24) * 60 + minutes
    }

    private func currentTimeInMinutes() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        return hour * 60 + minute
    }

}

// MARK: - Scheduled Arrival

struct ScheduledArrival: Identifiable {
    let id = UUID()
    let tripId: String
    let stopId: String
    let arrivalMinutes: Int // Minutes since midnight
    let sequence: Int

    var arrivalTime: String {
        let hours = arrivalMinutes / 60
        let minutes = arrivalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

// MARK: - CommuteSchedule Extension

extension CommuteSchedule {
    /// Get ETA info for the commute
    func getETAInfo() async -> CommuteETAInfo? {
        guard let ida = ida, ida.isEnabled else { return nil }

        let etaString = await GTFSScheduleService.shared.etaString(for: ida.startStation.id)
        let travelTime = await GTFSScheduleService.shared.travelTimeString(
            from: ida.startStation.id,
            to: ida.endStation.id
        )

        return CommuteETAInfo(
            nextArrival: etaString,
            travelTime: travelTime
        )
    }
}

// MARK: - Commute ETA Info

struct CommuteETAInfo {
    let nextArrival: String?
    let travelTime: String?

    var hasInfo: Bool {
        nextArrival != nil || travelTime != nil
    }
}
