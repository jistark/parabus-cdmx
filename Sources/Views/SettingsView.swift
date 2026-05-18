import SwiftUI
#if os(iOS)
import UserNotifications
#endif

// MARK: - Settings Tab View
/// User preferences and app information
/// Design: DESIGN_SYSTEM.md Section 2

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("favoriteLines") private var favoriteLines: String = "1,2,3"

    @State private var showingLineSelector = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - My Lines Section
                Section {
                    NavigationLink {
                        FavoriteLinesView(selectedLines: $favoriteLines)
                    } label: {
                        HStack {
                            Label("Mis lineas", systemImage: "star.fill")

                            Spacer()

                            // Show selected lines preview
                            favoriteLinesPreview
                        }
                    }
                } header: {
                    Text("Lineas favoritas")
                } footer: {
                    Text("Las lineas favoritas aparecen primero y se usan en los widgets.")
                }

                // MARK: - Notifications Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notificaciones", systemImage: "bell.fill")
                    }
                    .tint(.accentColor)

                    if notificationsEnabled {
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            Label("Configurar alertas", systemImage: "bell.badge")
                        }
                    }
                } header: {
                    Text("Notificaciones")
                } footer: {
                    Text("Activa las notificaciones para recibir alertas de incidentes en tus lineas.")
                }

                // MARK: - About Section
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("Sobre Parabús", systemImage: "info.circle")
                    }

                    NavigationLink {
                        DataSourcesView()
                    } label: {
                        Label("Fuentes de datos", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "https://www.metrobus.cdmx.gob.mx")!) {
                        HStack {
                            Label("Sitio oficial Metrobús", systemImage: "globe")

                            Spacer()

                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://twitter.com/MetrobusCDMX")!) {
                        HStack {
                            Label("Metrobús en X (Twitter)", systemImage: "at")

                            Spacer()

                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Información")
                }

                // MARK: - Debug Section (Development only)
                #if DEBUG
                Section {
                    NavigationLink {
                        DebugView()
                    } label: {
                        Label("Debug", systemImage: "hammer")
                    }
                } header: {
                    Text("Desarrollo")
                }
                #endif
            }
            .navigationTitle("Ajustes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            #endif
        }
    }

    // MARK: - Favorite Lines Preview

    private var favoriteLinesPreview: some View {
        let lines = favoriteLines.split(separator: ",").map(String.init)
        return HStack(spacing: -8) {
            ForEach(lines.prefix(3), id: \.self) { lineNumber in
                ZStack {
                    Circle()
                        .fill(LineColors.color(for: lineNumber).gradient)
                        .frame(width: 24, height: 24)

                    Text(lineNumber)
                        .brandTitle(BrandTypography.numeralSmall)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }

            if lines.count > 3 {
                Text("+\(lines.count - 3)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .padding(.leading, 12)
            }
        }
    }
}

// MARK: - Favorite Lines View

struct FavoriteLinesView: View {
    @Binding var selectedLines: String
    @Environment(\.dismiss) private var dismiss

    private let allLines = ["1", "2", "3", "4", "5", "6", "7"]

    private var selectedSet: Set<String> {
        Set(selectedLines.split(separator: ",").map(String.init))
    }

    var body: some View {
        List {
            Section {
                ForEach(allLines, id: \.self) { lineNumber in
                    Button {
                        toggleLine(lineNumber)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            LineBadge(number: lineNumber, transportType: .metrobus, size: .regular)
                                .frame(width: 40, height: 40)

                            // Line name
                            VStack(alignment: .leading) {
                                Text("Línea \(lineNumber)")
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Text(lineDescription(for: lineNumber))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Selection indicator
                            if selectedSet.contains(lineNumber) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Image(systemName: "circle")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Línea \(lineNumber), \(lineDescription(for: lineNumber))")
                    .accessibilityValue(selectedSet.contains(lineNumber) ? "Seleccionada" : "No seleccionada")
                }
            } header: {
                Text("Selecciona tus lineas")
            } footer: {
                Text("Las lineas seleccionadas apareceran primero en la pantalla principal.")
            }
        }
        .navigationTitle("Mis Lineas")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func toggleLine(_ lineNumber: String) {
        var lines = selectedSet
        if lines.contains(lineNumber) {
            lines.remove(lineNumber)
        } else {
            lines.insert(lineNumber)
        }
        selectedLines = lines.sorted().joined(separator: ",")
    }

    private func lineDescription(for lineNumber: String) -> String {
        switch lineNumber {
        case "1": return "Insurgentes"
        case "2": return "Eje 4 Sur"
        case "3": return "Eje 1 Poniente"
        case "4": return "Buenavista - Aeropuerto"
        case "5": return "Eje 3 Oriente"
        case "6": return "Aragon - El Rosario"
        case "7": return "Indios Verdes - Campo Marte"
        default: return ""
        }
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @AppStorage("notifySuspended") private var notifySuspended = true
    @AppStorage("notifyDelayed") private var notifyDelayed = true
    @AppStorage("notifyIntervention") private var notifyIntervention = false
    @AppStorage("notifyMaintenance") private var notifyMaintenance = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $notifySuspended) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundStyle(StatusColors.critical)

                        Text("Servicio suspendido")
                    }
                }

                Toggle(isOn: $notifyDelayed) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundStyle(StatusColors.critical)

                        Text("Retrasos")
                    }
                }

                Toggle(isOn: $notifyIntervention) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(StatusColors.warning)

                        Text("Intervenciones")
                    }
                }

                Toggle(isOn: $notifyMaintenance) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.orange)

                        Text("Mantenimiento programado")
                    }
                }
            } header: {
                Text("Tipos de alerta")
            } footer: {
                Text("Selecciona los tipos de incidentes sobre los que quieres recibir notificaciones.")
            }
        }
        .navigationTitle("Alertas")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - About View

struct AboutView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            // MARK: - App Info Header
            Section {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text("Parabús")
                        .font(.title.weight(.bold))

                    Text("Una app para navegar mejor el sistema del Metrobús de la CDMX.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Version \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
            }

            // MARK: - Credits
            Section {
                LabeledContent {
                    Text("Jose Ignacio Stark")
                } label: {
                    Label("Autor", systemImage: "person.fill")
                }

                LabeledContent {
                    Text("MIT")
                } label: {
                    Label("Licencia", systemImage: "doc.text.fill")
                }
            } header: {
                Text("Sobre Parabús")
            }

            // MARK: - Data Sources
            Section {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Secretaria de Movilidad (SEMOVI)")
                        .font(.subheadline)
                }

                Link(destination: URL(string: "https://www.cdmx.gob.mx/lgacdmx")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Licencia de Gobierno Abierto de la Ciudad de Mexico")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Text("LGACDMX")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://creativecommons.org/licenses/by/4.0")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Creative Commons Attribution 4.0 International")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Text("CC BY 4.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Fuentes de datos")
            } footer: {
                Text("Los datos de estado del servicio se obtienen del sitio oficial de Metrobús CDMX.")
            }

            // MARK: - Open Source Libraries
            Section {
                Link(destination: URL(string: "https://github.com/scinfu/SwiftSoup")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("SwiftSoup")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Text("HTML Parser - MIT License")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Librerias de codigo abierto")
            }

            // MARK: - Legal Disclaimer
            Section {
                Text("Parabús es una aplicación no oficial. No está afiliada con Metrobús ni con el Gobierno de la Ciudad de México. Metrobús es una marca registrada.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Aviso legal")
            }
        }
        .navigationTitle("Sobre Parabús")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Data Sources View

struct DataSourcesView: View {
    var body: some View {
        List {
            // MARK: - Primary Data Source
            Section {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "building.columns.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Secretaria de Movilidad (SEMOVI)")
                            .font(.headline)
                    }

                    Text("Los datos de estado del servicio se obtienen del sitio oficial de Metrobus CDMX.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Link(destination: URL(string: "https://www.metrobus.cdmx.gob.mx/estado-del-servicio")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Estado del servicio")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Text("metrobus.cdmx.gob.mx")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Fuente principal")
            } footer: {
                Text("Los datos se actualizan cada 5 minutos. La informacion puede tener un pequeno retraso respecto al estado real.")
            }

            // MARK: - Data Licenses
            Section {
                Link(destination: URL(string: "https://www.cdmx.gob.mx/lgacdmx")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Licencia de Gobierno Abierto de la Ciudad de Mexico")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Text("LGACDMX")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://creativecommons.org/licenses/by/4.0")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text("Creative Commons Attribution 4.0 International")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Text("CC BY 4.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Licencias de datos")
            }

            // MARK: - Attribution
            Section {
                Text("Esta aplicacion no esta afiliada con Metrobus ni con el Gobierno de la Ciudad de Mexico. Metrobus es una marca registrada.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Atribucion")
            }
        }
        .navigationTitle("Fuentes de datos")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - Debug View

#if DEBUG
/// In-app diagnostics for development builds. Surfaces the same data the
/// REVIEW.md investigations needed (cache age + file path + App Group
/// container, worker health, notification permission, BG refresh next-fire),
/// plus action buttons that trigger the various simulate-* helpers. Touch
/// any section header to copy the visible text to the pasteboard.
struct DebugView: View {
    @Environment(MetrobusViewModel.self) private var viewModel
    @State private var snapshot = DebugSnapshot()
    @State private var actionMessage: String?
    @State private var actionMessageColor: Color = .secondary

    var body: some View {
        List {
            statusSection
            cacheSection
            appGroupSection
            workerSection
            notificationsSection
            #if os(iOS)
            liveActivitySection
            #endif
            actionsSection
            designSection

            if let actionMessage {
                Section {
                    Text(actionMessage)
                        .font(.caption.monospaced())
                        .foregroundStyle(actionMessageColor)
                } header: {
                    Text("Last action")
                }
            }
        }
        .navigationTitle("Debug")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await refreshSnapshot()
        }
        .refreshable {
            await refreshSnapshot()
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section("Status") {
            row("Lines loaded", "\(viewModel.lines.count) / 7")
            row("Lines with issues", "\(viewModel.linesWithIssues.count)")
            row("Maintenance closures", "\(viewModel.maintenanceClosures.count)")
            row("Today's closures", "\(viewModel.deduplicatedTodaysClosures.count)")
            row("Last updated", snapshot.lastUpdatedDescription)
            row("Is stale", "\(viewModel.isStale)")
            row("Is loading", "\(viewModel.isLoading)")
            row("Is refreshing", "\(viewModel.isRefreshing)")
            if let err = viewModel.error {
                row("Last error", err.localizedDescription, valueColor: .red)
            }
        }
    }

    private var cacheSection: some View {
        Section("Cache") {
            row("Exists on disk", snapshot.cacheExists ? "yes" : "no",
                valueColor: snapshot.cacheExists ? .green : .secondary)
            if let bytes = snapshot.cacheSizeBytes {
                row("File size", ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
            }
            if let age = snapshot.cacheAgeSeconds {
                row("Cache age", formatAge(age))
            }
            if let path = snapshot.cachePath {
                row("Path", shorten(path), monospaced: true)
            }
        }
    }

    /// Catches REVIEW CRIT-01-style App Group misconfigurations: if the
    /// identifier doesn't match the entitlement, the container URL is nil.
    private var appGroupSection: some View {
        Section("App Group") {
            row("Identifier", ParabusConstants.appGroupIdentifier, monospaced: true)
            row("Container resolves",
                snapshot.appGroupContainerOK ? "yes" : "no (check entitlement!)",
                valueColor: snapshot.appGroupContainerOK ? .green : .red)
        }
    }

    private var workerSection: some View {
        Section("Worker") {
            row("Base URL", APIConfiguration.baseURL.absoluteString, monospaced: true)
            row("/health status", snapshot.workerHealth ?? "(not probed)")
            if let ms = snapshot.workerHealthLatencyMs {
                row("Probe latency", "\(ms) ms")
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            row("Authorization", snapshot.notificationAuthStatus)
            #if os(iOS)
            Button("Request permission") {
                Task {
                    let granted = await BackgroundRefreshManager.shared.requestNotificationPermission()
                    setMessage(granted ? "Permission granted" : "Permission denied", ok: granted)
                    await refreshSnapshot()
                }
            }
            #endif
        }
    }

    #if os(iOS)
    private var liveActivitySection: some View {
        Section("Live Activities") {
            if #available(iOS 16.2, *) {
                row("Available", LiveActivityService.shared.isAvailable ? "yes" : "no")
                Button("Start test activity (Línea 1)") {
                    Task {
                        await startTestActivity()
                    }
                }
                Button("End all activities", role: .destructive) {
                    Task {
                        await LiveActivityService.shared.endAllActivities()
                        setMessage("Ended all live activities", ok: true)
                    }
                }
            } else {
                Text("iOS 16.2 required").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    #endif

    private var actionsSection: some View {
        Section("Actions") {
            Button("Force refresh (bypass cache)") {
                Task {
                    await viewModel.refresh()
                    setMessage("Refreshed: \(viewModel.lines.count) lines, \(viewModel.maintenanceClosures.count) closures",
                               ok: viewModel.error == nil)
                    await refreshSnapshot()
                }
            }

            Button("Clear cache") {
                Task { await runClearCache() }
            }

            #if os(iOS)
            Button("Simulate background refresh") {
                Task {
                    await BackgroundRefreshManager.shared.simulateBackgroundRefresh()
                    setMessage("Background refresh simulated", ok: true)
                    await refreshSnapshot()
                }
            }

            Button("Simulate protest notification") {
                Task {
                    await BackgroundRefreshManager.shared.simulateProtestNotification(forLine: "1")
                    setMessage("Protest notification sent for L1", ok: true)
                }
            }

            Button("Reset protest dedup keys", role: .destructive) {
                BackgroundRefreshManager.shared.resetProtestNotifications()
                setMessage("Cleared notifiedProtestKeys", ok: true)
            }
            #endif

            Button("Reload worker /health") {
                Task {
                    await probeWorkerHealth()
                }
            }
        }
    }

    private var designSection: some View {
        Section("Design") {
            NavigationLink("Design tokens preview") {
                DesignTokensPreview()
            }
        }
    }

    // MARK: - Row helpers

    private func row(_ label: String, _ value: String,
                     valueColor: Color = .secondary,
                     monospaced: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(monospaced ? .caption.monospaced() : .body)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Actions

    private func setMessage(_ text: String, ok: Bool) {
        actionMessage = text
        actionMessageColor = ok ? .green : .red
    }

    private func runClearCache() async {
        do {
            try await CacheManager().clear()
            setMessage("Cache cleared", ok: true)
            await refreshSnapshot()
        } catch {
            setMessage("Clear failed: \(error.localizedDescription)", ok: false)
        }
    }

    #if os(iOS)
    @available(iOS 16.2, *)
    private func startTestActivity() async {
        let testLine = LineStatus(
            lineNumber: "1",
            transportType: .metrobus,
            status: .delayed,
            affectedStations: ["Insurgentes", "Reforma"],
            additionalInfo: "Debug test activity"
        )
        do {
            try await LiveActivityService.shared.startActivity(for: testLine)
            setMessage("Started test live activity", ok: true)
        } catch {
            setMessage("Start failed: \(error.localizedDescription)", ok: false)
        }
    }
    #endif

    // MARK: - Snapshot building

    private func refreshSnapshot() async {
        var s = DebugSnapshot()
        s.lastUpdatedDescription = viewModel.lastUpdated
            .map { ISO8601DateFormatter().string(from: $0) } ?? "(none)"
        s.appGroupContainerOK = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ParabusConstants.appGroupIdentifier) != nil

        // Cache file inspection
        if let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ParabusConstants.appGroupIdentifier)?
            .appendingPathComponent("metrobus_status.json") {
            s.cachePath = url.path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                s.cacheExists = true
                s.cacheSizeBytes = (attrs[.size] as? NSNumber)?.intValue
                if let modDate = attrs[.modificationDate] as? Date {
                    s.cacheAgeSeconds = Date().timeIntervalSince(modDate)
                }
            }
        }

        #if os(iOS)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        s.notificationAuthStatus = authStatusString(settings.authorizationStatus)
        #else
        s.notificationAuthStatus = "n/a (non-iOS)"
        #endif

        snapshot = s
        await probeWorkerHealth()
    }

    private func probeWorkerHealth() async {
        let url = APIConfiguration.baseURL.appendingPathComponent("health")
        let start = Date()
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let body = String(data: data, encoding: .utf8) {
                snapshot.workerHealth = body.prefix(120).description
            } else {
                snapshot.workerHealth = "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)"
            }
            snapshot.workerHealthLatencyMs = ms
        } catch {
            snapshot.workerHealth = "error: \(error.localizedDescription)"
            snapshot.workerHealthLatencyMs = nil
        }
    }

    private func shorten(_ path: String) -> String {
        if let home = ProcessInfo.processInfo.environment["HOME"], path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func formatAge(_ seconds: TimeInterval) -> String {
        let m = Int(seconds / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        if m == 0 { return "\(s)s" }
        if m < 60 { return "\(m)m \(s)s" }
        return "\(m / 60)h \(m % 60)m"
    }

    #if os(iOS)
    private func authStatusString(_ s: UNAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "not asked"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        case .ephemeral: return "ephemeral"
        @unknown default: return "unknown (\(s.rawValue))"
        }
    }
    #endif
}

/// Mutable snapshot of debug data — populated by `refreshSnapshot()`.
private struct DebugSnapshot {
    var lastUpdatedDescription: String = "(loading)"
    var cacheExists: Bool = false
    var cacheSizeBytes: Int?
    var cacheAgeSeconds: TimeInterval?
    var cachePath: String?
    var appGroupContainerOK: Bool = false
    var workerHealth: String?
    var workerHealthLatencyMs: Int?
    var notificationAuthStatus: String = "(loading)"
}
#endif

// MARK: - Previews

#Preview("Settings") {
    SettingsView()
}

#Preview("Favorite Lines") {
    NavigationStack {
        FavoriteLinesView(selectedLines: .constant("1,2,3"))
    }
}

#Preview("Commute Setup") {
    NavigationStack {
        CommuteSetupView()
    }
}

#Preview("About") {
    NavigationStack {
        AboutView()
    }
}
