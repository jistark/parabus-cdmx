import Foundation
import os

/// Centralised `os.Logger` instances. One per logical subsystem area so the
/// Console / log stream can be filtered by category.
///
/// All instances use the `app.parabus` subsystem. Pick the closest-matching
/// category at the call site:
///
///   Log.background.error("BGTask failed: \(error)")
///   Log.gtfs.info("Schedule populated for stop \(id)")
///
/// `Logger` is `Sendable`, so these constants are safe across actors.
enum Log {
    static let background = Logger(subsystem: subsystem, category: "background")
    static let liveActivity = Logger(subsystem: subsystem, category: "live-activity")
    static let gtfs = Logger(subsystem: subsystem, category: "gtfs")
    static let theme = Logger(subsystem: subsystem, category: "theme")
    static let ui = Logger(subsystem: subsystem, category: "ui")

    private static let subsystem = "app.parabus"
}
