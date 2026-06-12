import SwiftUI

/// Station and line search — Task B2 will wire this to the tab bar.
/// Results are case- and diacritic-insensitive via `SearchMatcher`.
struct SearchView: View {

    @Environment(MetrobusViewModel.self) private var viewModel

    @State private var query = ""
    @State private var selectedLine: LineStatus? = nil
    @State private var selectedStation: GTFSStation? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    suggestionsSection
                } else {
                    lineResultsSection
                    stationResultsSection
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .searchable(text: $query, prompt: Text("Estación o línea"))
            .navigationTitle("Buscar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
        // Sheets ─ mirror the pattern used in ContentView / MainTabView
        .sheet(item: $selectedLine) { line in
            LineDetailSheet(line: line)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedStation) { station in
            StationDetailSheet(
                station: station,
                lineStatus: lineStatus(for: station)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Suggestions (empty query)

    @ViewBuilder
    private var suggestionsSection: some View {
        let schedule = CommuteStorage.load()
        let favoriteLineNumbers = favoriteLineNumbers

        // Commute stations
        let commuteStations = commuteStationSuggestions(from: schedule)
        if !commuteStations.isEmpty {
            Section {
                ForEach(commuteStations, id: \.id) { station in
                    stationRow(station)
                }
            } header: {
                Text("Tu commute")
            }
        }

        // Favorite lines
        let favoriteLines = viewModel.allLines.filter { favoriteLineNumbers.contains($0.lineNumber) }
        if !favoriteLines.isEmpty {
            Section {
                ForEach(favoriteLines) { line in
                    lineRow(line)
                }
            } header: {
                Text("Líneas favoritas")
            }
        }

        // Placeholder when nothing configured
        if commuteStations.isEmpty && favoriteLines.isEmpty {
            Section {
                Text("Configura tu commute o favoritos en Ajustes para ver sugerencias aquí.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Sin sugerencias disponibles. Configura tu commute o favoritos en Ajustes.")
            }
        }
    }

    // MARK: - Line Results

    @ViewBuilder
    private var lineResultsSection: some View {
        let results = matchingLines
        if !results.isEmpty {
            Section {
                ForEach(results) { line in
                    lineRow(line)
                }
            } header: {
                Text("Líneas")
            }
        }
    }

    // MARK: - Station Results

    @ViewBuilder
    private var stationResultsSection: some View {
        let results = matchingStations
        if !results.isEmpty {
            Section {
                ForEach(results, id: \.id) { station in
                    stationRow(station)
                }
            } header: {
                Text("Estaciones")
            }
        }
    }

    // MARK: - Row Builders

    private func lineRow(_ line: LineStatus) -> some View {
        Button {
            selectedLine = line
        } label: {
            HStack(spacing: 12) {
                LineBadge(number: line.lineNumber, transportType: line.transportType, size: .small)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Línea \(line.lineNumber)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(line.status.displayName)
                        .font(.caption)
                        .foregroundStyle(StatusColors.color(for: line.status))
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Línea \(line.lineNumber). \(line.status.displayName)")
        .accessibilityHint("Abre detalles de la línea")
    }

    private func stationRow(_ station: GTFSStation) -> some View {
        Button {
            selectedStation = station
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(LineColors.color(for: station.lineNumber))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(station.lineNumber)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text("Línea \(station.lineNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(station.name), Línea \(station.lineNumber)")
        .accessibilityHint("Abre próximas llegadas")
    }

    // MARK: - Search Logic

    private var matchingLines: [LineStatus] {
        let lineNum = SearchMatcher.lineNumber(from: query)
        return viewModel.allLines.filter { line in
            if let num = lineNum {
                return line.lineNumber == num
            }
            return SearchMatcher.matches(query, in: "Línea \(line.lineNumber)")
                || SearchMatcher.matches(query, in: line.lineName)
        }
    }

    private var matchingStations: [GTFSStation] {
        guard !query.isEmpty else { return [] }
        // Split into prefix matches (station name starts with query) and contains matches.
        var prefix: [GTFSStation] = []
        var contains: [GTFSStation] = []
        let normalizedQ = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        let allStations = GTFSStations.allLines.flatMap { GTFSStations.stations(for: $0.number) }
        // Deduplicate by name (some stations appear on multiple lines with the same name)
        var seenNames = Set<String>()
        for station in allStations {
            guard seenNames.insert(station.name).inserted else { continue }
            guard SearchMatcher.matches(query, in: station.name) else { continue }
            let normalizedName = station.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            if normalizedName.hasPrefix(normalizedQ) {
                prefix.append(station)
            } else {
                contains.append(station)
            }
        }
        return Array((prefix + contains).prefix(30))
    }

    // MARK: - Suggestions helpers

    private func commuteStationSuggestions(from schedule: CommuteSchedule) -> [GTFSStation] {
        var stations: [GTFSStation] = []
        var seen = Set<String>()
        for stationId in [schedule.ida?.startStation.id, schedule.regreso?.startStation.id].compactMap({ $0 }) {
            if let s = GTFSStations.station(byId: stationId), seen.insert(s.id).inserted {
                stations.append(s)
            }
        }
        return stations
    }

    private var favoriteLineNumbers: [String] {
        // Read from shared UserDefaults via the same key as SettingsView.
        let defaults = ParabusConstants.sharedDefaults ?? UserDefaults.standard
        let csv = defaults.string(forKey: ParabusConstants.favoriteLinesKey)
            ?? ParabusConstants.defaultFavoriteLines
        return csv.split(separator: ",").map(String.init)
    }

    // MARK: - Line status lookup

    private func lineStatus(for station: GTFSStation) -> LineStatus? {
        viewModel.allLines.first { $0.lineNumber == station.lineNumber }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Search") {
    SearchView()
        .environment(MetrobusViewModel())
}
#endif
