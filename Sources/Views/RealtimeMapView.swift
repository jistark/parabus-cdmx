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
    @State private var showingStationPicker = false
    @State private var showingPrePrompt = false
    /// Hybrid (satellite + labels) vs standard-muted base map.
    @State private var useImagery = false
    /// Tab visibility gate for the scenePhase handler (same role as
    /// ContentView.isHomeVisible) — only the visible tab may (re)claim the
    /// shared realtime polling surface.
    @State private var isMapVisible = false
    @Namespace private var mapScope
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map
                    .ignoresSafeArea(edges: .bottom)

                // The mini-cenefa is the single navigator: line block →
                // line switcher, station area → station picker. The bottom
                // carousel was a second affordance for the same job and
                // covered the map — removed.
                statusBar
                    .padding(.horizontal, Layout.screenMargin)
                    .padding(.top, Spacing.xs)
            }
            // Controls live bottom-trailing in the thumb zone, like Apple
            // Maps — top placement read as decoration, not affordance.
            .overlay(alignment: .bottomTrailing) {
                mapControlStack
                    .padding(.trailing, Layout.screenMargin)
                    .padding(.bottom, Spacing.md)
            }
            .navigationTitle("Mapa en vivo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .task {
                isMapVisible = true
                // Bootstrap (station/line selection) runs BEFORE startPolling
                // so the coordinator's initial surface carries the correct line
                // filter. Without this ordering the first /vehicles fetch is
                // unfiltered (~800 vehicles) and the selectedLine.didSet
                // immediately fires a second fetch — wasting a budget slot.
                handleBootstrap()
                await viewModel.startPolling()
            }
            .onAppear { isMapVisible = true }
            .onDisappear {
                isMapVisible = false
                Task { await viewModel.stopPolling() }
            }
            // Mirror ContentView's pattern: gate on tab visibility so a
            // scene-activation while ANOTHER tab is frontmost can't steal
            // the shared polling surface from it.
            .onChange(of: scenePhase) { _, newPhase in
                Task {
                    if newPhase == .active && isMapVisible {
                        await viewModel.startPolling()
                    } else if newPhase != .active {
                        await viewModel.stopPolling()
                    }
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
            .sheet(isPresented: $showingStationPicker) {
                StationPicker(
                    title: String(localized: "Estaciones"),
                    selectedStation: nil,
                    onSelect: { picked in
                        guard let station = viewModel.resolveStation(byId: picked.id) else { return }
                        viewModel.selectedStation = station
                        animateCamera(to: station.coordinate)
                    }
                )
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
        Map(position: $cameraPosition, scope: mapScope) {
            if locationCoordinator.authStatus == .authorized {
                UserAnnotation()
            }
            ForEach(viewModel.visibleVehicles, id: \.stableId) { vehicle in
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
        // Muted emphasis per HIG maps guidance: our own content (buses,
        // cenefa) is information-rich and should stand out against a
        // desaturated base map.
        .mapStyle(useImagery
            ? .hybrid(elevation: .flat, pointsOfInterest: .excludingAll)
            : .standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
    }

    // MARK: - Map controls
    //
    // Native MapKit controls (location button gets the system Liquid Glass
    // treatment and the camera-follow behavior for free) plus a map-type
    // toggle, stacked trailing under the cenefa like Apple Maps.

    private var mapControlStack: some View {
        VStack(spacing: Spacing.xs) {
            MapUserLocationButton(scope: mapScope)
                .mapControlVisibility(locationCoordinator.authStatus == .denied ? .hidden : .visible)
            MapCompass(scope: mapScope)

            Button {
                withAnimation(reduceMotion ? nil : .snappy) {
                    useImagery.toggle()
                }
            } label: {
                Image(systemName: useImagery ? "map.fill" : "globe.americas.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .surface(.floating, cornerRadius: 22)
            .accessibilityLabel(useImagery
                ? String(localized: "Cambiar a mapa estándar")
                : String(localized: "Cambiar a vista satelital"))
        }
    }

    // MARK: - Status mini-cenefa
    //
    // Cenefa-coded status over native Liquid Glass: the solid line-color
    // block with the numeral is the MB signage anchor (same vocabulary as
    // the physical cenefa and the bottom carousel), while the chrome stays
    // a system glass surface so it reads native over the map instead of
    // competing with it. Tapping opens the line switcher — same affordance
    // as the MB block below.

    private var statusBar: some View {
        HStack(spacing: Spacing.sm) {
            if let line = viewModel.selectedStation?.lineNumber,
               viewModel.errorMessage == nil {
                Button {
                    showingLineChange = true
                } label: {
                    LineBlock(lineNumber: line)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Línea \(line)"))
                .accessibilityHint(String(localized: "Cambiar de línea"))
            } else {
                statusIndicator
                    .frame(width: 16, height: 16)
            }

            Button {
                showingStationPicker = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(statusTitle)
                            .brandTitle(BrandTypography.lineLabel)
                            .foregroundStyle(.primary)
                            .contentTransition(.opacity)
                        Text(statusSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .lineLimit(1)

                    Spacer(minLength: Spacing.sm)

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        statusIndicator
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(statusTitle). \(statusSubtitle)")
            .accessibilityHint(String(localized: "Buscar estación"))
        }
        .padding(.horizontal, Spacing.sm + 2)
        .padding(.vertical, Spacing.xs + 2)
        .surface(.floating, cornerRadius: 22)
        .animation(reduceMotion ? nil : .snappy, value: viewModel.selectedStation?.id)
        .animation(reduceMotion ? nil : .snappy, value: viewModel.visibleVehicles.count)
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

    /// The station IS the title — it inherited the carousel's role as the
    /// what-am-I-looking-at anchor.
    private var statusTitle: String {
        if let err = viewModel.errorMessage { return err }
        if viewModel.serviceInactive { return String(localized: "Sin servicio reportado") }
        if let station = viewModel.selectedStation {
            return station.name
        }
        return String(localized: "Buses en vivo")
    }

    private var statusSubtitle: String {
        guard let date = viewModel.lastUpdated else { return String(localized: "Cargando…") }

        var parts: [String] = []

        let count = viewModel.visibleVehicles.count
        if viewModel.selectedStation == nil {
            parts.append(count == 1 ? String(localized: "1 bus") : String(localized: "\(count) buses"))
        } else {
            parts.append(count == 1
                ? String(localized: "1 bus cerca")
                : String(localized: "\(count) buses cerca"))
        }

        parts.append(ageText(date))

        if let distance = distanceToSelectedStation {
            parts.append(distance)
        }

        return parts.joined(separator: " · ")
    }

    /// Manual age formatting — RelativeDateTimeFormatter rendered a
    /// just-fetched timestamp as the future-tense "dentro de 0 s".
    private func ageText(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 5 { return String(localized: "ahora") }
        if seconds < 60 { return String(localized: "hace \(seconds) s") }
        return String(localized: "hace \(seconds / 60) min")
    }

    /// "a 450 m" / "a 1.2 km" from the user to the focused station, when we
    /// have a fix. Rounded to 10 m — GPS precision theater helps no one.
    private var distanceToSelectedStation: String? {
        guard let userCoord = locationCoordinator.latestLocation,
              let station = viewModel.selectedStation else { return nil }
        let meters = CLLocation(latitude: userCoord.latitude, longitude: userCoord.longitude)
            .distance(from: CLLocation(
                latitude: station.coordinate.latitude,
                longitude: station.coordinate.longitude
            ))
        if meters < 950 {
            return String(localized: "a \(Int(meters / 10) * 10) m")
        }
        return String(localized: "a \(String(format: "%.1f", meters / 1000)) km")
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
