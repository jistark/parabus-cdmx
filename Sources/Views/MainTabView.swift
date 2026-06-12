import SwiftUI

// MARK: - Main Tab View
/// Root navigation structure: 3 tabs + native search (spec 3 B2).
/// Alertas folded into the home; Ajustes lives behind the home gear.
/// Design: DESIGN_SYSTEM.md Section 2

struct MainTabView: View {
    @State private var selectedTab: Tab = .status
    @Environment(MetrobusViewModel.self) private var viewModel
    @Environment(NotificationRouter.self) private var notificationRouter

    enum Tab: Hashable {
        case status
        case map
        case commute
        case search
    }

    var body: some View {
        // Modern Tab API (iOS 18+): the system owns tab identity and the
        // Liquid Glass tab bar behaviors — the legacy .tabItem/.tag path
        // re-resolved tab content on rapid re-taps and glitched the glass
        // transitions. sidebarAdaptable gives the iPad sidebar for free.
        TabView(selection: $selectedTab) {
            SwiftUI.Tab("Ahora", systemImage: "bus.fill", value: Tab.status) {
                ContentView()
            }
            .badge(incidentBadge ?? 0)

            // Hybrid map phase 1: the Mapa tab hosts the line timeline;
            // RealtimeMapView returns in phase 2 as the per-station inspector.
            SwiftUI.Tab("Mapa", systemImage: "map.fill", value: Tab.map) {
                LineTimelineView()
            }

            SwiftUI.Tab("Tus rutas", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill", value: Tab.commute) {
                CommuteTabView()
            }

            // role: .search gives the system search affordance (separated
            // trailing item on the iOS 26 Liquid Glass bar; magnifier label
            // and search section in the iPad sidebar).
            SwiftUI.Tab(value: Tab.search, role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .modifier(TabBarMinimizeOnScroll())
        .tint(.accentColor)
        .task {
            await viewModel.loadStatus()
        }
        // When a tapped notification sets a pending deep link, land on the
        // home — ContentView consumes the link (opens the line's inline
        // detail) and is responsible for clearing pendingDeepLink.
        .onChange(of: notificationRouter.pendingDeepLink) { _, newValue in
            if newValue != nil {
                selectedTab = .status
            }
        }
    }

    // MARK: - Badge Logic

    /// Single badge on the Ahora tab: total incident count across lines
    /// (the old Alertas-tab badge, consolidated here when that tab retired).
    private var incidentBadge: Int? {
        let count = viewModel.linesWithIssues.reduce(0) { $0 + $1.incidentCount }
        return count > 0 ? count : nil
    }
}

/// Liquid Glass: the tab bar recedes on scroll-down so content leads
/// (per "Adopting Liquid Glass"). iOS 26-only API; no-op elsewhere so the
/// SwiftPM macOS test target keeps compiling.
private struct TabBarMinimizeOnScroll: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - Commute Tab View

/// Main view for the Commute tab showing configured routes and status
struct CommuteTabView: View {
    @State private var schedule: CommuteSchedule
    @Environment(MetrobusViewModel.self) private var viewModel
    @State private var showingIdaSetup = false
    @State private var showingRegresoSetup = false
    @State private var selectedLine: LineStatus?

    init() {
        _schedule = State(initialValue: CommuteStorage.load())
    }

    private var involvedLines: [LineStatus] {
        viewModel.allLines.filter { schedule.involvedLines.contains($0.lineNumber) }
    }

    private var hasRouteIssues: Bool {
        involvedLines.contains { $0.hasIssues }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    if schedule.hasCommute {
                        // Route status banner
                        routeStatusBanner
                            .padding(.horizontal, Spacing.md)

                        // Commute legs
                        commuteLegCards
                            .padding(.horizontal, Spacing.md)

                        // Active days
                        activeDaysSection
                            .padding(.horizontal, Spacing.md)

                        // Notification settings
                        notificationSection
                            .padding(.horizontal, Spacing.md)

                        // Affected lines detail (if issues)
                        if hasRouteIssues {
                            affectedLinesSection
                                .padding(.horizontal, Spacing.md)
                        }
                    } else {
                        // Empty state - no commute configured
                        emptyStateView
                            .padding(.top, Spacing.xxl)
                    }
                }
                .padding(.vertical, Spacing.md)
            }
            .navigationTitle("Mis rutas")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
            #endif
            // .always: short content (no commute configured) otherwise
            // doesn't bounce, so pull-to-refresh can't engage.
            .scrollBounceBehavior(.always, axes: .vertical)
            .refreshable {
                await viewModel.refresh()
                reloadSchedule()
            }
            .task {
                await viewModel.loadStatus()
            }
            .sheet(isPresented: $showingIdaSetup, onDismiss: reloadSchedule) {
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
            .sheet(isPresented: $showingRegresoSetup, onDismiss: reloadSchedule) {
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
            .sheet(item: $selectedLine) { line in
                LineDetailSheet(line: line)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Route Status Banner

    private var routeStatusBanner: some View {
        let accent: Color = hasRouteIssues ? StatusColors.critical : .green
        return HStack(spacing: Layout.inlineSpacing) {
            Image(systemName: hasRouteIssues ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(hasRouteIssues ? "Incidentes en tu ruta" : "Tu ruta está despejada")
                    .brandTitle(BrandTypography.lineLabel)

                Text(schedule.isActiveToday ? "Activo hoy" : "Inactivo hoy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Involved line badges — stacked LineBadge components with overlap
            HStack(spacing: -8) {
                ForEach(schedule.involvedLines.sorted(), id: \.self) { lineNumber in
                    LineBadge(number: lineNumber, transportType: .metrobus, size: .small)
                        .frame(width: 28, height: 28)
                }
            }
        }
        .padding(Layout.cardInset)
        .surface(.elevated, cornerRadius: Layout.cornerRadiusMedium, tint: accent)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Commute Leg Cards

    private var commuteLegCards: some View {
        VStack(spacing: Spacing.sm) {
            // Ida card
            CommuteLegCard(
                leg: schedule.ida,
                title: "Ida",
                icon: "sunrise.fill",
                iconColor: .orange,
                onEdit: { showingIdaSetup = true },
                onToggle: { enabled in
                    schedule.ida?.isEnabled = enabled
                    saveSchedule()
                }
            )

            // Regreso card
            CommuteLegCard(
                leg: schedule.regreso,
                title: "Regreso",
                icon: "sunset.fill",
                iconColor: .purple,
                onEdit: { showingRegresoSetup = true },
                onToggle: { enabled in
                    schedule.regreso?.isEnabled = enabled
                    saveSchedule()
                }
            )
        }
    }

    // MARK: - Active Days Section

    private var activeDaysSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text("Días activos")
                    .brandTitle(BrandTypography.lineLabel)
                Spacer()
            }

            HStack(spacing: Spacing.xs) {
                ForEach(Weekday.allCases) { day in
                    Button {
                        toggleDay(day)
                    } label: {
                        Text(day.shortName)
                            .font(.caption.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(
                                schedule.activeDays.contains(day)
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.15),
                                in: Circle()
                            )
                            .foregroundStyle(
                                schedule.activeDays.contains(day) ? .white : .primary
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.shortName)
                    .accessibilityValue(schedule.activeDays.contains(day) ? "Activo" : "Inactivo")
                }
            }
            .frame(maxWidth: .infinity)

            Text("Solo recibirás notificaciones en los días seleccionados.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(Layout.cardInset)
        .surface(.base, cornerRadius: Layout.cornerRadiusMedium)
    }

    private func toggleDay(_ day: Weekday) {
        if schedule.activeDays.contains(day) {
            schedule.activeDays.remove(day)
        } else {
            schedule.activeDays.insert(day)
        }
        saveSchedule()
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(.secondary)
                Text("Ventana de notificación")
                    .brandTitle(BrandTypography.lineLabel)
                Spacer()
            }

            Picker("Ventana", selection: Binding(
                get: { schedule.notifyBeforeMinutes },
                set: { newValue in
                    schedule.notifyBeforeMinutes = newValue
                    saveSchedule()
                }
            )) {
                Text("30 min antes").tag(30)
                Text("1 hora antes").tag(60)
                Text("2 horas antes").tag(120)
            }
            .pickerStyle(.segmented)

            Text("Recibirás alertas si hay incidentes en tu ruta antes de tu hora de salida.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(Layout.cardInset)
        .surface(.base, cornerRadius: Layout.cornerRadiusMedium)
    }

    // MARK: - Affected Lines Section

    private var affectedLinesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(StatusColors.critical)
                Text("Líneas afectadas")
                    .brandTitle(BrandTypography.lineLabel)
                Spacer()
            }

            ForEach(involvedLines.filter { $0.hasIssues }) { line in
                Button {
                    selectedLine = line
                } label: {
                    HStack(spacing: Spacing.sm) {
                        LineBadge(number: line.lineNumber, transportType: line.transportType, size: .small)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.lineName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Text(StatusColors.displayText(for: line.status))
                                .font(.caption)
                                .foregroundStyle(StatusColors.color(for: line.status))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(Spacing.sm)
                    .surface(.base, cornerRadius: Layout.cornerRadiusSmall, tint: StatusColors.color(for: line.status))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Toca para ver detalles de \(line.lineName)")
            }
        }
        .padding(Layout.cardInset)
        .surface(.base, cornerRadius: Layout.cornerRadiusMedium)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "tram.fill.tunnel")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: Spacing.xs) {
                Text("Configura tu ruta")
                    .font(.title2.weight(.semibold))

                Text("Agrega tus estaciones de ida y regreso para recibir alertas personalizadas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            VStack(spacing: Spacing.sm) {
                Button {
                    showingIdaSetup = true
                } label: {
                    Label("Configurar ida", systemImage: "sunrise.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button {
                    showingRegresoSetup = true
                } label: {
                    Label("Configurar regreso", systemImage: "sunset.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            }
            .padding(.horizontal, Spacing.xxl)
        }
    }

    // MARK: - Helpers

    private func saveSchedule() {
        CommuteStorage.save(schedule)
    }

    private func reloadSchedule() {
        schedule = CommuteStorage.load()
    }
}

// MARK: - Commute Leg Card

private struct CommuteLegCard: View {
    let leg: CommuteLeg?
    let title: String
    let icon: String
    let iconColor: Color
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void

    @State private var travelTime: String?

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: Spacing.sm) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 40)

                if let leg = leg {
                    // Configured leg
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(title)
                                .font(.subheadline.weight(.semibold))

                            if let time = travelTime {
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                HStack(spacing: 2) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text(time)
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }

                        HStack(spacing: 4) {
                            lineBadge(leg.startStation.lineNumber)
                            Text(leg.startStation.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)

                            lineBadge(leg.endStation.lineNumber)
                            Text(leg.endStation.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(leg.timeString)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    // Toggle (stop propagation)
                    Toggle("", isOn: Binding(
                        get: { leg.isEnabled },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                    .onTapGesture {} // Prevent button tap
                } else {
                    // Not configured
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))

                        Text("Toca para configurar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(iconColor)
                }
            }
            .padding(Layout.cardInset)
            .surface(.base, cornerRadius: Layout.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadiusMedium)
                    .strokeBorder(Color.secondary.opacity(SurfaceOpacity.border), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .task {
            await loadTravelTime()
        }
    }

    private func loadTravelTime() async {
        guard let leg = leg else { return }
        travelTime = await GTFSScheduleService.shared.travelTimeString(
            from: leg.startStation.id,
            to: leg.endStation.id
        )
    }

    /// Tiny 18pt badge for inline route preview. LineBadge's smallest size is
    /// 32pt — this is intentionally smaller to fit in the dense leg card row.
    private func lineBadge(_ lineNumber: String) -> some View {
        ZStack {
            Circle()
                .fill(LineColors.color(for: lineNumber).gradient)
                .frame(width: 18, height: 18)

            Text(lineNumber)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Previews

#Preview("Main Tab View") {
    MainTabView()
}

#Preview("Commute Tab") {
    CommuteTabView()
}
