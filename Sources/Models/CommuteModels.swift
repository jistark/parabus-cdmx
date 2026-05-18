import Foundation

// MARK: - Commute Leg

/// Represents a single commute leg (one direction of travel)
struct CommuteLeg: Codable, Identifiable, Hashable {
    let id: UUID
    var startStation: CommuteStation
    var endStation: CommuteStation
    var time: Date
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        startStation: CommuteStation,
        endStation: CommuteStation,
        time: Date,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.startStation = startStation
        self.endStation = endStation
        self.time = time
        self.isEnabled = isEnabled
    }

    /// Formatted time string for display
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    /// Hour component for scheduling
    var hour: Int {
        Calendar.current.component(.hour, from: time)
    }

    /// Minute component for scheduling
    var minute: Int {
        Calendar.current.component(.minute, from: time)
    }
}

// MARK: - Commute Station

/// Represents a station on a specific line. Coordinates are optional because
/// some legacy entries (or hand-typed station picks) lack GPS data.
struct CommuteStation: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let lineNumber: String
    let latitude: Double?
    let longitude: Double?

    init(id: String, name: String, lineNumber: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.id = id
        self.name = name
        self.lineNumber = lineNumber
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Backward-compat decoder: payloads encoded before lat/lon became optional
    /// used 0.0 as the "no coordinates" sentinel. Treat encoded zeros as nil so
    /// `hasCoordinates` keeps its original semantics for legacy data.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.lineNumber = try container.decode(String.self, forKey: .lineNumber)
        let lat = try container.decodeIfPresent(Double.self, forKey: .latitude)
        let lon = try container.decodeIfPresent(Double.self, forKey: .longitude)
        self.latitude = (lat == 0) ? nil : lat
        self.longitude = (lon == 0) ? nil : lon
    }

    var displayName: String {
        name
    }

    var lineDisplayName: String {
        "Linea \(lineNumber)"
    }

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}

// MARK: - Commute Schedule

/// Complete commute configuration
struct CommuteSchedule: Codable {
    var ida: CommuteLeg?
    var regreso: CommuteLeg?
    var activeDays: Set<Weekday>
    var notifyBeforeMinutes: Int

    init(
        ida: CommuteLeg? = nil,
        regreso: CommuteLeg? = nil,
        activeDays: Set<Weekday> = Set(Weekday.weekdays),
        notifyBeforeMinutes: Int = 60
    ) {
        self.ida = ida
        self.regreso = regreso
        self.activeDays = activeDays
        self.notifyBeforeMinutes = notifyBeforeMinutes
    }

    var hasCommute: Bool {
        ida != nil || regreso != nil
    }

    /// All line numbers involved in the commute
    var involvedLines: Set<String> {
        var lines = Set<String>()
        if let ida = ida {
            lines.insert(ida.startStation.lineNumber)
            lines.insert(ida.endStation.lineNumber)
        }
        if let regreso = regreso {
            lines.insert(regreso.startStation.lineNumber)
            lines.insert(regreso.endStation.lineNumber)
        }
        return lines
    }

    /// Check if today is an active commute day
    var isActiveToday: Bool {
        let today = Weekday.current
        return activeDays.contains(today)
    }

    /// Check if currently within commute window
    func isWithinCommuteWindow(windowMinutes: Int = 60) -> Bool {
        guard isActiveToday else { return false }

        let now = Date()
        let calendar = Calendar.current
        let currentMinutes = calendar.component(.hour, from: now) * 60 +
                            calendar.component(.minute, from: now)

        // Check ida window
        if let ida = ida, ida.isEnabled {
            let idaMinutes = ida.hour * 60 + ida.minute
            let windowStart = idaMinutes - notifyBeforeMinutes
            let windowEnd = idaMinutes + windowMinutes
            if currentMinutes >= windowStart && currentMinutes <= windowEnd {
                return true
            }
        }

        // Check regreso window
        if let regreso = regreso, regreso.isEnabled {
            let regresoMinutes = regreso.hour * 60 + regreso.minute
            let windowStart = regresoMinutes - notifyBeforeMinutes
            let windowEnd = regresoMinutes + windowMinutes
            if currentMinutes >= windowStart && currentMinutes <= windowEnd {
                return true
            }
        }

        return false
    }
}

// MARK: - Weekday

/// Days of the week
enum Weekday: Int, Codable, CaseIterable, Identifiable, Hashable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: return "D"
        case .monday: return "L"
        case .tuesday: return "M"
        case .wednesday: return "Mi"
        case .thursday: return "J"
        case .friday: return "V"
        case .saturday: return "S"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Domingo"
        case .monday: return "Lunes"
        case .tuesday: return "Martes"
        case .wednesday: return "Miercoles"
        case .thursday: return "Jueves"
        case .friday: return "Viernes"
        case .saturday: return "Sabado"
        }
    }

    static var weekdays: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    }

    static var current: Weekday {
        let weekdayNumber = Calendar.current.component(.weekday, from: Date())
        return Weekday(rawValue: weekdayNumber) ?? .monday
    }
}

// MARK: - Commute Storage

/// Helper for persisting commute schedule to UserDefaults
enum CommuteStorage {
    private static let key = "commuteSchedule"

    static func load() -> CommuteSchedule {
        guard let data = UserDefaults.standard.data(forKey: key),
              let schedule = try? SharedCoders.plainDecoder.decode(CommuteSchedule.self, from: data) else {
            return CommuteSchedule()
        }
        return schedule
    }

    static func save(_ schedule: CommuteSchedule) {
        guard let data = try? SharedCoders.plainEncoder.encode(schedule) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
