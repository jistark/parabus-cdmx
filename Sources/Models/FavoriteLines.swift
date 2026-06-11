// Sources/Models/FavoriteLines.swift
import Foundation

/// Single home for the favorite-lines CSV parsing that AlertsView and
/// ContentView each reimplemented (rescued per spec 2 §5; survives the
/// AlertsView deprecation in spec 3).
enum FavoriteLines {
    static func parse(_ csv: String) -> [String] {
        csv.split(separator: ",").map(String.init)
    }

    static func asSet(_ csv: String) -> Set<String> {
        Set(parse(csv))
    }
}
