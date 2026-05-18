import SwiftUI
import MapKit
import CoreLocation

/// Live map of Metrobús vehicles + station carousel overlay.
/// Bootstrap state machine in MapBootstrap; CLLocationManager in
/// LocationCoordinator; line membership + coords in GTFSStations.
struct RealtimeMapView: View {
    @State private var viewModel = RealtimeMapViewModel()
    @State private var locationCoordinator = LocationCoordinator()
    @State private var cameraPosition: MapCameraPosition = .region(Self.cdmxRegion)
    @State private var showingLineChange = false
    @State private var showingPrePrompt = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedStationIdBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedStation?.id },
            set: { newId in
                guard let id = newId,
                      let station = viewModel.resolveStation(byId: id) else { return }
                viewModel.selectedStation = station
                animateCamera(to: station.coordinate)
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                map
                    .ignoresSafeArea(edges: .bottom)

                VStack(alignment: .leading, spacing: 0) {
                    statusBar
                        .padding(.horizontal, Layout.screenMargin)
                        .padding(.top, Spacing.xs)
                    Spacer()
                    StationCarousel(
                        stations: viewModel.stationsOnSelectedLine,
                        selectedStationId: selectedStationIdBinding,
                        onMBTap: { showingLineChange = true }
                    )
                    .frame(height: 88)
                    .padding(.bottom, Spacing.md)
                }
            }
            .navigationTitle("Mapa en vivo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            #endif
            .task {
                viewModel.startPolling()
                handleBootstrap()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background, .inactive:
                    viewModel.stopPolling()
                case .active:
                    viewModel.startPolling()
                @unknown default:
                    break
                }
            }
            .onChange(of: locationCoordinator.authStatus) { _, _ in
                handleBootstrap()
            }
            .onChange(of: locationCoordinator.latestLocation) { _, newLoc in
                guard let coord = newLoc else { return }
                if let nearest = viewModel.nearestStation(to: coord) {
                    viewModel.selectedStation = nearest
                    animateCamera(to: nearest.coordinate)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingLineChange) {
                LineChangeSheet(
                    currentLine: viewModel.selectedStation?.lineNumber ?? "1",
                    onSelect: handleLineChange
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingPrePrompt) {
                LocationPrePromptSheet(
                    onAccept: {
                        viewModel.markPrePromptShown()
                        locationCoordinator.requestAuthorization()
                    },
                    onDecline: {
                        viewModel.markPrePromptShown()
                        handleBootstrap()
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Bootstrap

    private func handleBootstrap() {
        let outcome = viewModel.bootstrapOutcome(authStatus: locationCoordinator.authStatus)
        switch outcome {
        case .showPrePrompt:
            showingPrePrompt = true
        case .useStation(let id):
            // Persisted or seed
            if let station = viewModel.resolveStation(byId: id)
                ?? GTFSStations.stations(for: MapBootstrap.defaultSeedLine).first {
                viewModel.selectedStation = station
                animateCamera(to: station.coordinate)
            }
        case .waitingForLocation:
            locationCoordinator.requestLocation()
        }
    }

    private func handleLineChange(_ newLine: String) {
        let ref = viewModel.selectedStation?.coordinate
            ?? locationCoordinator.latestLocation
            ?? Self.cdmxRegion.center
        if let target = viewModel.nearestStation(on: newLine, from: ref) {
            viewModel.selectedStation = target
            animateCamera(to: target.coordinate)
        }
    }

    private func animateCamera(to coord: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
        if reduceMotion {
            cameraPosition = .region(region)
        } else {
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .region(region)
            }
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $cameraPosition) {
            ForEach(viewModel.vehicles, id: \.stableId) { vehicle in
                if let coord = vehicle.coordinate {
                    Annotation(
                        vehicle.vehicleLabel ?? vehicle.vehicleId ?? "",
                        coordinate: coord
                    ) {
                        BusMarker(
                            line: lineNumber(for: vehicle.routeId),
                            bearing: vehicle.bearing
                        )
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: Spacing.sm) {
            statusIndicator

            VStack(alignment: .leading, spacing: 1) {
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                Text(statusSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.thinMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusDotColor)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(statusDotColor.opacity(0.4), lineWidth: 4)
                    .scaleEffect(viewModel.isLoading && !reduceMotion ? 1.6 : 1.0)
                    .opacity(viewModel.isLoading && !reduceMotion ? 0 : 1)
                    .animation(
                        reduceMotion ? nil :
                            .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                        value: viewModel.isLoading
                    )
            )
    }

    private var statusDotColor: Color {
        if viewModel.errorMessage != nil { return .orange }
        if viewModel.serviceInactive { return .gray }
        return .green
    }

    private var statusTitle: String {
        if let err = viewModel.errorMessage { return err }
        if viewModel.serviceInactive { return "Sin servicio reportado" }
        let count = viewModel.vehicles.count
        if let line = viewModel.selectedStation?.lineNumber {
            return "Línea \(line) · \(count) buses"
        }
        return "\(count) buses en vivo"
    }

    private var statusSubtitle: String {
        guard let date = viewModel.lastUpdated else { return "Cargando…" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Actualizado \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    // MARK: - Helpers

    private func lineNumber(for routeId: String?) -> String {
        viewModel.line(forRouteId: routeId)
            ?? viewModel.selectedStation?.lineNumber
            ?? "unknown"
    }

    /// Approximate CDMX bounds. Used only as last-resort fallback.
    private static let cdmxRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.432, longitude: -99.133),
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )
}

// MARK: - Location pre-prompt sheet

private struct LocationPrePromptSheet: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("UBICACIÓN")
                    .font(BrandTypography.lineLabel)
                    .foregroundStyle(.secondary)
                Text("Mostrar la estación más cercana")
                    .font(BrandTypography.displayMedium)
            }

            Text("Parabús puede usar tu ubicación para abrir el mapa en la estación más cercana a ti. Es opcional — siempre puedes elegir manualmente.")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: Spacing.sm) {
                Button {
                    onAccept()
                    dismiss()
                } label: {
                    Text("Activar ubicación")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    onDecline()
                    dismiss()
                } label: {
                    Text("Ahora no")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(Layout.screenMargin)
    }
}

// MARK: - Bus marker (unchanged from previous version)

private struct BusMarker: View {
    let line: String
    let bearing: Double?

    var body: some View {
        ZStack {
            Circle()
                .fill(LineColors.color(for: line).gradient)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)

            Image(systemName: "bus.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)

            if let bearing {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white)
                    .offset(y: -18)
                    .rotationEffect(.degrees(bearing))
            }
        }
    }
}

#Preview {
    RealtimeMapView()
}
