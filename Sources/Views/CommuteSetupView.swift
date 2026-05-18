import SwiftUI

// MARK: - Commute Setup View

/// Main view for configuring commute schedule (ida and regreso)
struct CommuteSetupView: View {
    @State private var schedule: CommuteSchedule
    @State private var showingIdaSetup = false
    @State private var showingRegresoSetup = false
    @Environment(\.dismiss) private var dismiss

    init() {
        _schedule = State(initialValue: CommuteStorage.load())
    }

    var body: some View {
        List {
            // MARK: - Ida (Outbound) Section
            Section {
                if let ida = schedule.ida {
                    CommuteLegRow(
                        leg: ida,
                        isEnabled: Binding(
                            get: { ida.isEnabled },
                            set: { newValue in
                                schedule.ida?.isEnabled = newValue
                                saveSchedule()
                            }
                        ),
                        onEdit: { showingIdaSetup = true },
                        onDelete: {
                            schedule.ida = nil
                            saveSchedule()
                        }
                    )
                } else {
                    Button {
                        showingIdaSetup = true
                    } label: {
                        Label("Configurar trayecto de ida", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(.orange)
                    Text("Ida")
                }
            } footer: {
                Text("Tu trayecto de casa al trabajo o escuela.")
            }

            // MARK: - Regreso (Return) Section
            Section {
                if let regreso = schedule.regreso {
                    CommuteLegRow(
                        leg: regreso,
                        isEnabled: Binding(
                            get: { regreso.isEnabled },
                            set: { newValue in
                                schedule.regreso?.isEnabled = newValue
                                saveSchedule()
                            }
                        ),
                        onEdit: { showingRegresoSetup = true },
                        onDelete: {
                            schedule.regreso = nil
                            saveSchedule()
                        }
                    )
                } else {
                    Button {
                        showingRegresoSetup = true
                    } label: {
                        Label("Configurar trayecto de regreso", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "sunset.fill")
                        .foregroundStyle(.purple)
                    Text("Regreso")
                }
            } footer: {
                Text("Tu trayecto de regreso a casa.")
            }

            // MARK: - Active Days Section
            Section {
                DaySelector(selectedDays: Binding(
                    get: { schedule.activeDays },
                    set: { newValue in
                        schedule.activeDays = newValue
                        saveSchedule()
                    }
                ))
            } header: {
                Text("Dias activos")
            } footer: {
                Text("Recibiras notificaciones solo en los dias seleccionados.")
            }

            // MARK: - Notification Timing
            Section {
                Picker("Ventana de notificación", selection: Binding(
                    get: { schedule.notifyBeforeMinutes },
                    set: { newValue in
                        schedule.notifyBeforeMinutes = newValue
                        saveSchedule()
                    }
                )) {
                    Text("Hasta 30 minutos antes").tag(30)
                    Text("Hasta 1 hora antes").tag(60)
                    Text("Hasta 2 horas antes").tag(120)
                }
            } header: {
                Text("Notificaciones")
            } footer: {
                Text("Recibirás alertas si hay incidentes en tu ruta dentro de esta ventana de tiempo antes de tu hora de salida.")
            }

            // MARK: - Preview Section
            if schedule.hasCommute {
                Section {
                    CommutePreviewCard(schedule: schedule)
                } header: {
                    Text("Resumen")
                }
            }
        }
        .navigationTitle("Mi trayecto")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingIdaSetup) {
            CommuteLegSetupView(
                title: "Configurar ida",
                icon: "sunrise.fill",
                iconColor: .orange,
                existingLeg: schedule.ida
            ) { leg in
                schedule.ida = leg
                saveSchedule()
            }
        }
        .sheet(isPresented: $showingRegresoSetup) {
            CommuteLegSetupView(
                title: "Configurar regreso",
                icon: "sunset.fill",
                iconColor: .purple,
                existingLeg: schedule.regreso
            ) { leg in
                schedule.regreso = leg
                saveSchedule()
            }
        }
    }

    private func saveSchedule() {
        CommuteStorage.save(schedule)
    }
}

// MARK: - Commute Leg Row

private struct CommuteLegRow: View {
    let leg: CommuteLeg
    @Binding var isEnabled: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Route info
            HStack(spacing: Spacing.sm) {
                // Start station
                VStack(alignment: .leading, spacing: 2) {
                    Text("Desde")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        lineBadge(leg.startStation.lineNumber)
                        Text(leg.startStation.name)
                            .font(.subheadline.weight(.medium))
                    }
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                // End station
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Hasta")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(leg.endStation.name)
                            .font(.subheadline.weight(.medium))
                        lineBadge(leg.endStation.lineNumber)
                    }
                }
            }

            Divider()

            // Time and toggle
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)

                Text(leg.timeString)
                    .font(.subheadline)

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
        }
        .padding(.vertical, Spacing.xs)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }

            Button {
                onEdit()
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }

    private func lineBadge(_ lineNumber: String) -> some View {
        ZStack {
            Circle()
                .fill(LineColors.color(for: lineNumber).gradient)
                .frame(width: 20, height: 20)

            Text(lineNumber)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Day Selector

private struct DaySelector: View {
    @Binding var selectedDays: Set<Weekday>

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Weekday.allCases) { day in
                Button {
                    toggleDay(day)
                } label: {
                    Text(day.shortName)
                        .font(.caption.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(
                            selectedDays.contains(day)
                                ? Color.accentColor
                                : Color.secondary.opacity(0.15),
                            in: Circle()
                        )
                        .foregroundStyle(
                            selectedDays.contains(day) ? .white : .primary
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleDay(_ day: Weekday) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }
}

// MARK: - Commute Preview Card

private struct CommutePreviewCard: View {
    let schedule: CommuteSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Lines involved
            if !schedule.involvedLines.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Text("Lineas:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(schedule.involvedLines.sorted(), id: \.self) { lineNumber in
                        ZStack {
                            Circle()
                                .fill(LineColors.color(for: lineNumber).gradient)
                                .frame(width: 24, height: 24)

                            Text(lineNumber)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            // Active days summary
            HStack(spacing: Spacing.xs) {
                Text("Dias:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(activeDaysSummary)
                    .font(.caption)
            }

            // Status indicator
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(schedule.isActiveToday ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)

                Text(schedule.isActiveToday ? "Activo hoy" : "Inactivo hoy")
                    .font(.caption)
                    .foregroundStyle(schedule.isActiveToday ? .primary : .secondary)
            }
        }
    }

    private var activeDaysSummary: String {
        let days = schedule.activeDays

        if days.count == 7 {
            return "Todos los dias"
        } else if days == Set(Weekday.weekdays) {
            return "Lunes a viernes"
        } else if days.isEmpty {
            return "Ninguno"
        } else {
            return days.sorted { $0.rawValue < $1.rawValue }
                .map { $0.shortName }
                .joined(separator: ", ")
        }
    }
}

// MARK: - Commute Leg Setup View

struct CommuteLegSetupView: View {
    let title: String
    let icon: String
    let iconColor: Color
    let existingLeg: CommuteLeg?
    let onSave: (CommuteLeg) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var startStation: CommuteStation?
    @State private var endStation: CommuteStation?
    @State private var time: Date

    @State private var showingStartPicker = false
    @State private var showingEndPicker = false

    init(
        title: String,
        icon: String,
        iconColor: Color,
        existingLeg: CommuteLeg?,
        onSave: @escaping (CommuteLeg) -> Void
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.existingLeg = existingLeg
        self.onSave = onSave

        // Initialize state from existing leg or defaults
        if let leg = existingLeg {
            _startStation = State(initialValue: leg.startStation)
            _endStation = State(initialValue: leg.endStation)
            _time = State(initialValue: leg.time)
        } else {
            _startStation = State(initialValue: nil)
            _endStation = State(initialValue: nil)
            // Default time: 8:00 AM for ida, 6:00 PM for regreso
            let calendar = Calendar.current
            let hour = icon == "sunrise.fill" ? 8 : 18
            _time = State(initialValue: calendar.date(
                bySettingHour: hour,
                minute: 0,
                second: 0,
                of: Date()
            ) ?? Date())
        }
    }

    private var canSave: Bool {
        startStation != nil && endStation != nil
    }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: icon)
                                .font(.system(size: 40))
                                .foregroundStyle(iconColor)

                            Text(title)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Spacing.md)
                    .listRowBackground(Color.clear)
                }

                // Start Station
                Section {
                    Button {
                        showingStartPicker = true
                    } label: {
                        HStack {
                            Label("Estacion de origen", systemImage: "location.circle")

                            Spacer()

                            if let station = startStation {
                                HStack(spacing: 4) {
                                    lineBadge(station.lineNumber)
                                    Text(station.name)
                                        .foregroundStyle(.primary)
                                }
                            } else {
                                Text("Seleccionar")
                                    .foregroundStyle(.secondary)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Desde donde sales")
                }

                // End Station
                Section {
                    Button {
                        showingEndPicker = true
                    } label: {
                        HStack {
                            Label("Estacion de destino", systemImage: "mappin.circle")

                            Spacer()

                            if let station = endStation {
                                HStack(spacing: 4) {
                                    lineBadge(station.lineNumber)
                                    Text(station.name)
                                        .foregroundStyle(.primary)
                                }
                            } else {
                                Text("Seleccionar")
                                    .foregroundStyle(.secondary)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("A donde llegas")
                }

                // Time Picker
                Section {
                    DatePicker(
                        "Hora de salida",
                        selection: $time,
                        displayedComponents: .hourAndMinute
                    )
                } header: {
                    Text("A que hora sales")
                } footer: {
                    Text("Recibiras notificaciones si hay incidentes antes de esta hora.")
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveLeg()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingStartPicker) {
                StationPicker(
                    title: "Estacion de origen",
                    selectedStation: startStation
                ) { station in
                    startStation = station
                }
            }
            .sheet(isPresented: $showingEndPicker) {
                StationPicker(
                    title: "Estacion de destino",
                    selectedStation: endStation
                ) { station in
                    endStation = station
                }
            }
        }
    }

    private func lineBadge(_ lineNumber: String) -> some View {
        ZStack {
            Circle()
                .fill(LineColors.color(for: lineNumber).gradient)
                .frame(width: 20, height: 20)

            Text(lineNumber)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private func saveLeg() {
        guard let start = startStation, let end = endStation else { return }

        let leg = CommuteLeg(
            id: existingLeg?.id ?? UUID(),
            startStation: start,
            endStation: end,
            time: time,
            isEnabled: existingLeg?.isEnabled ?? true
        )

        onSave(leg)
        dismiss()
    }
}

// MARK: - Previews

#Preview("Commute Setup") {
    NavigationStack {
        CommuteSetupView()
    }
}

#Preview("Leg Setup") {
    CommuteLegSetupView(
        title: "Configurar ida",
        icon: "sunrise.fill",
        iconColor: .orange,
        existingLeg: nil
    ) { leg in
        Log.ui.info("Saved leg: \(String(describing: leg), privacy: .public)")
    }
}
