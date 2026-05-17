import SwiftUI

// MARK: - Station Picker

/// Full-screen station picker with search and line filtering
struct StationPicker: View {
    let title: String
    let selectedStation: CommuteStation?
    let onSelect: (CommuteStation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedLineNumber: String?

    private var filteredStations: [GTFSStation] {
        var stations: [GTFSStation] = []

        if let lineNumber = selectedLineNumber {
            stations = GTFSStations.stations(for: lineNumber)
        } else {
            // All stations from all lines
            for line in GTFSStations.allLines {
                stations.append(contentsOf: GTFSStations.stations(for: line.number))
            }
        }

        // Apply search filter
        if searchText.isEmpty {
            return stations
        }

        let query = searchText.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        return stations.filter { station in
            let name = station.name.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            return name.contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Line filter chips
                lineFilterChips
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)

                Divider()

                // Station list
                if filteredStations.isEmpty {
                    emptyState
                } else {
                    stationsList
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Buscar estacion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Line Filter Chips

    private var lineFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // All lines chip
                lineChip(lineNumber: nil, label: "Todas")

                // Individual line chips
                ForEach(GTFSStations.allLines, id: \.number) { line in
                    lineChip(lineNumber: line.number, label: line.number)
                }
            }
        }
    }

    private func lineChip(lineNumber: String?, label: String) -> some View {
        let isSelected = selectedLineNumber == lineNumber

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                selectedLineNumber = lineNumber
            }
        } label: {
            HStack(spacing: 4) {
                if let num = lineNumber {
                    Circle()
                        .fill(LineColors.color(for: num).gradient)
                        .frame(width: 16, height: 16)
                }

                Text(lineNumber == nil ? "Todas" : "L\(label)")
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                isSelected
                    ? (lineNumber != nil ? LineColors.color(for: lineNumber!).opacity(0.15) : Color.accentColor.opacity(0.15))
                    : Color.secondary.opacity(0.1),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected
                            ? (lineNumber != nil ? LineColors.color(for: lineNumber!) : Color.accentColor)
                            : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }

    // MARK: - Stations List

    private var stationsList: some View {
        List {
            ForEach(groupedStations, id: \.lineNumber) { group in
                Section {
                    ForEach(group.stations) { station in
                        stationRow(station)
                    }
                } header: {
                    if selectedLineNumber == nil {
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(LineColors.color(for: group.lineNumber).gradient)
                                .frame(width: 12, height: 12)

                            Text("Linea \(group.lineNumber)")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func stationRow(_ station: GTFSStation) -> some View {
        Button {
            onSelect(station.toCommuteStation())
            dismiss()
        } label: {
            HStack(spacing: Spacing.sm) {
                // Line badge (small)
                ZStack {
                    Circle()
                        .fill(LineColors.color(for: station.lineNumber).gradient)
                        .frame(width: 28, height: 28)

                    Text(station.lineNumber)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }

                // Station name
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text("Linea \(station.lineNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Selected indicator
                if selectedStation?.id == station.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Grouped Stations

    private var groupedStations: [GTFSStationGroup] {
        let grouped = Dictionary(grouping: filteredStations) { $0.lineNumber }
        return grouped.keys.sorted().map { lineNumber in
            GTFSStationGroup(
                lineNumber: lineNumber,
                stations: grouped[lineNumber] ?? []
            )
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sin resultados", systemImage: "magnifyingglass")
        } description: {
            Text("No encontramos estaciones que coincidan con \"\(searchText)\"")
        }
    }
}

// MARK: - Station Group

private struct GTFSStationGroup {
    let lineNumber: String
    let stations: [GTFSStation]
}

// MARK: - Previews

#Preview("Station Picker") {
    StationPicker(
        title: "Estacion de origen",
        selectedStation: nil
    ) { station in
        print("Selected: \(station.name)")
    }
}

#Preview("With Selection") {
    StationPicker(
        title: "Estacion de destino",
        selectedStation: CommuteStation(id: "1_14", name: "Insurgentes", lineNumber: "1")
    ) { station in
        print("Selected: \(station.name)")
    }
}
