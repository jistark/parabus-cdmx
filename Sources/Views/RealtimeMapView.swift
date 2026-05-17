import SwiftUI
import MapKit

/// Live map of Metrobús vehicles. Polls /vehicles every 20s while visible.
/// Minimal-viable surface — see plan futures for filters, sheets, animations.
struct RealtimeMapView: View {
    @State private var viewModel = RealtimeMapViewModel()
    @State private var cameraPosition: MapCameraPosition = .region(Self.cdmxRegion)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                map
                    .ignoresSafeArea(edges: .bottom)

                statusBar
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
            }
            .navigationTitle("Mapa en vivo")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    linePicker
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    linePicker
                }
                #endif
            }
            .task {
                viewModel.startPolling()
            }
            .onDisappear {
                viewModel.stopPolling()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Background → stop polling to save battery. Active → resume.
                switch newPhase {
                case .background, .inactive:
                    viewModel.stopPolling()
                case .active:
                    viewModel.startPolling()
                @unknown default:
                    break
                }
            }
            .refreshable {
                await viewModel.refresh()
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
                    .scaleEffect(viewModel.isLoading ? 1.6 : 1.0)
                    .opacity(viewModel.isLoading ? 0 : 1)
                    .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false),
                               value: viewModel.isLoading)
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
        if let line = viewModel.selectedLine {
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

    // MARK: - Line picker

    private var linePicker: some View {
        Menu {
            Button {
                viewModel.selectedLine = nil
            } label: {
                Label("Todas", systemImage: viewModel.selectedLine == nil ? "checkmark" : "")
            }
            Divider()
            ForEach(["1", "2", "3", "4", "5", "6", "7"], id: \.self) { line in
                Button {
                    viewModel.selectedLine = line
                } label: {
                    HStack {
                        Text("Línea \(line)")
                        if viewModel.selectedLine == line {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let line = viewModel.selectedLine {
                    Circle()
                        .fill(LineColors.color(for: line))
                        .frame(width: 10, height: 10)
                    Text(line)
                        .font(.subheadline.weight(.semibold))
                } else {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    // MARK: - Helpers

    /// Map worker routeId → line number via the viewmodel's cached index from
    /// /static/routes. Falls back to selectedLine, then "unknown" (gray).
    private func lineNumber(for routeId: String?) -> String {
        viewModel.line(forRouteId: routeId)
            ?? viewModel.selectedLine
            ?? "unknown"
    }

    /// Approximate CDMX bounds.
    private static let cdmxRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 19.432, longitude: -99.133),
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )
}

// MARK: - Bus marker

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
                // Compass arrow rotates around the marker center.
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
