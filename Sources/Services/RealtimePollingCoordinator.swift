// Sources/Services/RealtimePollingCoordinator.swift
import Foundation

/// Where realtime polling is pointed. Exactly one surface is active at a
/// time — "Ahora" and "Mapa" never poll simultaneously (spec budget rule).
enum RealtimeSurface: Equatable, Sendable {
    case home(stationId: String)
    case map(line: String?)
    /// Spec 4 hook (viaje en background): declared, not yet implemented.
    case background(tripContext: String)
}

/// Owns the polling cadence (25s) and the hard budget (4 realtime requests
/// per sliding minute). Views set the surface from .task/.onChange of
/// scenePhase; the coordinator decides whether a poll is allowed. The
/// injected `now`/`onPoll` keep it fully testable without timers.
actor RealtimePollingCoordinator {
    static let pollInterval: TimeInterval = 25
    static let budgetLimit = 4
    static let budgetWindow: TimeInterval = 60

    private let now: @Sendable () -> Date
    private let onPoll: @Sendable (RealtimeSurface) async -> Void

    private var surface: RealtimeSurface?
    private var recentPolls: [Date] = []
    private var loopTask: Task<Void, Never>?

    init(
        now: @escaping @Sendable () -> Date = { Date() },
        onPoll: @escaping @Sendable (RealtimeSurface) async -> Void
    ) {
        self.now = now
        self.onPoll = onPoll
    }

    /// Set the active surface. Pass `nil` when the app backgrounds or the
    /// realtime tab is no longer visible; this cancels the polling loop to
    /// avoid background timer wakeups. **After a nil, callers must invoke
    /// `startLoop()` again when the surface becomes active** — `setSurface`
    /// does not auto-restart the loop, because surface changes during an
    /// active session (e.g. station swipes) must not cause task churn.
    func setSurface(_ newSurface: RealtimeSurface?) {
        surface = newSurface
        if newSurface == nil {
            loopTask?.cancel()
            loopTask = nil
        }
    }

    /// One cadence tick: poll the active surface if the budget allows.
    func tick() async {
        guard let surface else { return }
        guard consumeBudget() else { return }
        await onPoll(surface)
    }

    /// On-demand poll (e.g. swipe to another favorite station). Subject to
    /// the same budget; silently dropped when exhausted — the next tick
    /// catches up.
    func requestImmediatePoll() async {
        await tick()
    }

    /// Start the 25s self-ticking loop (call once from the app root).
    /// Tests drive `tick()` manually instead.
    func startLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollInterval))
                await self?.tick()
            }
        }
    }

    // MARK: - Budget

    private func consumeBudget() -> Bool {
        let cutoff = now().addingTimeInterval(-Self.budgetWindow)
        recentPolls.removeAll { $0 < cutoff }
        guard recentPolls.count < Self.budgetLimit else { return false }
        recentPolls.append(now())
        return true
    }
}
