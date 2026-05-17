import SwiftUI

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
                        .font(BrandTypography.numeralSmall)
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
struct DebugView: View {
    @State private var cacheInfo: String = "Loading..."

    var body: some View {
        List {
            Section {
                Button("Force Refresh") {
                    // Trigger refresh
                }

                Button("Clear Cache") {
                    // Clear cache
                }

                Button("Simulate Error") {
                    // Simulate error state
                }
            } header: {
                Text("Actions")
            }

            Section {
                Text(cacheInfo)
                    .font(.caption.monospaced())
            } header: {
                Text("Cache Info")
            }

            Section {
                NavigationLink("Design Tokens Preview") {
                    DesignTokensPreview()
                }
            } header: {
                Text("Design")
            }
        }
        .navigationTitle("Debug")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
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
