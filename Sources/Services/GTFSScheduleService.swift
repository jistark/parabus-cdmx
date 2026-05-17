import Foundation

// MARK: - GTFS Schedule Service

/// Provides schedule-based ETA calculations using GTFS static data
actor GTFSScheduleService {
    static let shared = GTFSScheduleService()

    // MARK: - Schedule Data

    private var stopTimes: [String: [ScheduledArrival]] = [:]
    private var isLoaded = false

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
        guard !isLoaded else { return }
        await loadScheduleData()
        isLoaded = true
    }

    private func loadScheduleData() async {
        // Load stop_times.txt from bundle resources
        // Bundle.module is only available when built via SPM, not Xcode directly
        #if SWIFT_PACKAGE
        let moduleURL = Bundle.module.url(forResource: "stop_times", withExtension: "txt", subdirectory: "GTFS")
        #else
        let moduleURL: URL? = nil
        #endif

        guard let url = moduleURL ??
                        Bundle.main.url(forResource: "stop_times", withExtension: "txt", subdirectory: "GTFS") ??
                        Bundle.main.url(forResource: "stop_times", withExtension: "txt") ??
                        findGTFSFile(named: "stop_times.txt") else {
            print("GTFSSchedule: stop_times.txt not found")
            return
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            parseStopTimes(content)
            print("GTFSSchedule: Loaded \(stopTimes.count) stations with schedules")
        } catch {
            print("GTFSSchedule: Failed to load: \(error)")
        }
    }

    private func parseStopTimes(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else { return }

        // Parse header to find column indices
        let header = lines[0].components(separatedBy: ",")
        guard let tripIdx = header.firstIndex(of: "trip_id"),
              let arrivalIdx = header.firstIndex(of: "arrival_time"),
              let stopIdx = header.firstIndex(of: "stop_id"),
              let seqIdx = header.firstIndex(of: "stop_sequence") else {
            print("GTFSSchedule: Invalid header format")
            return
        }

        var tempStopTimes: [String: [ScheduledArrival]] = [:]

        for line in lines.dropFirst() where !line.isEmpty {
            let cols = line.components(separatedBy: ",")
            guard cols.count > max(tripIdx, arrivalIdx, stopIdx, seqIdx) else { continue }

            let tripId = cols[tripIdx]
            let stopId = cols[stopIdx]
            let arrivalStr = cols[arrivalIdx]
            let sequence = Int(cols[seqIdx]) ?? 0

            guard let arrivalMinutes = parseTime(arrivalStr) else { continue }

            let arrival = ScheduledArrival(
                tripId: tripId,
                stopId: stopId,
                arrivalMinutes: arrivalMinutes,
                sequence: sequence
            )

            if tempStopTimes[stopId] == nil {
                tempStopTimes[stopId] = []
            }
            tempStopTimes[stopId]?.append(arrival)
        }

        stopTimes = tempStopTimes
    }

    private func parseTime(_ timeStr: String) -> Int? {
        // Format: HH:MM:SS
        let parts = timeStr.components(separatedBy: ":")
        guard parts.count >= 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return nil
        }
        // Handle times > 24:00 (next day service)
        return (hours % 24) * 60 + minutes
    }

    private func currentTimeInMinutes() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        return hour * 60 + minute
    }

    private func findGTFSFile(named filename: String) -> URL? {
        // Check in Sources/GTFS folder (development)
        let fileManager = FileManager.default
        let possiblePaths = [
            "/Users/ji/Sites/parabus/Sources/GTFS/\(filename)",
            Bundle.main.bundlePath + "/GTFS/\(filename)"
        ]

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
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
