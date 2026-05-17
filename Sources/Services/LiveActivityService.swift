#if os(iOS)
@preconcurrency import ActivityKit
import Foundation

/// Manages Live Activities for Metrobus disruptions
@available(iOS 16.1, *)
@MainActor
final class LiveActivityService {

    // MARK: - Singleton

    static let shared = LiveActivityService()

    private init() {}

    // MARK: - State

    /// Currently active Live Activities by line number. The keyset is the
    /// authoritative source of "which lines have an activity right now" —
    /// a previous parallel `trackedLines: Set<String>` was prone to drift
    /// (only inserted, never removed when activities ended externally).
    private var activeActivities: [String: Activity<MetrobusDisruptionAttributes>] = [:]

    // MARK: - Public API

    /// Check if Live Activities are available
    var isAvailable: Bool {
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    /// Start a Live Activity for a disrupted line
    @available(iOS 16.2, *)
    func startActivity(for line: LineStatus) async throws {
        guard line.hasIssues else { return }

        // Don't start duplicate activities
        if activeActivities[line.lineNumber] != nil {
            // Update existing instead
            try await updateActivity(for: line)
            return
        }

        let attributes = MetrobusDisruptionAttributes(
            lineNumber: line.lineNumber,
            lineName: line.lineName,
            startedAt: Date()
        )

        let initialState = contentState(for: line)

        let activityContent = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(15 * 60) // Stale after 15 min
        )

        do {
            // pushType: nil — we don't have a server to register tokens with,
            // so requesting .token spawned a `for await activity.pushTokenUpdates`
            // observer Task that was never stored or cancelled. Each new
            // activity leaked another iterator that kept the activity alive
            // and collected tokens that went nowhere (handlePushToken was a
            // TODO print). Re-enable when there's a push backend.
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )

            activeActivities[line.lineNumber] = activity

        } catch {
            print("Failed to start Live Activity: \(error)")
            throw error
        }
    }

    /// Update an existing Live Activity
    @available(iOS 16.2, *)
    func updateActivity(for line: LineStatus) async throws {
        guard let activity = activeActivities[line.lineNumber] else {
            // No active activity, start one if there are issues
            if line.hasIssues {
                try await startActivity(for: line)
            }
            return
        }

        // If line is now normal, end the activity
        guard line.hasIssues else {
            await endActivity(for: line.lineNumber, dismissImmediately: false)
            return
        }

        let activityId = activity.id
        let updatedState = contentState(for: line)
        let updatedContent = ActivityContent(
            state: updatedState,
            staleDate: Date().addingTimeInterval(15 * 60)
        )

        // Use nonisolated helper to avoid Sendable issues
        await Self.updateActivityById(activityId, with: updatedContent)
    }

    /// End a Live Activity for a line
    @available(iOS 16.2, *)
    func endActivity(for lineNumber: String, dismissImmediately: Bool = false) async {
        guard let activity = activeActivities.removeValue(forKey: lineNumber) else { return }

        let activityId = activity.id

        let finalState = MetrobusDisruptionAttributes.ContentState(
            status: "Servicio Regular",
            statusSeverity: 0,
            affectedStations: [],
            additionalInfo: "Servicio restablecido",
            updatedAt: Date()
        )

        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil
        )

        let dismissalPolicy: ActivityUIDismissalPolicy = dismissImmediately
            ? .immediate
            : .after(Date().addingTimeInterval(5 * 60)) // Dismiss after 5 min

        // Use nonisolated helper to avoid Sendable issues
        await Self.endActivityById(activityId, with: finalContent, policy: dismissalPolicy)
    }

    // MARK: - Nonisolated Helpers (avoid Sendable issues with Activity)

    @available(iOS 16.2, *)
    nonisolated private static func updateActivityById(
        _ activityId: String,
        with content: ActivityContent<MetrobusDisruptionAttributes.ContentState>
    ) async {
        await Activity<MetrobusDisruptionAttributes>.activities
            .first { $0.id == activityId }?
            .update(content)
    }

    @available(iOS 16.2, *)
    nonisolated private static func endActivityById(
        _ activityId: String,
        with content: ActivityContent<MetrobusDisruptionAttributes.ContentState>,
        policy: ActivityUIDismissalPolicy
    ) async {
        await Activity<MetrobusDisruptionAttributes>.activities
            .first { $0.id == activityId }?
            .end(content, dismissalPolicy: policy)
    }

    /// End all active Live Activities
    @available(iOS 16.2, *)
    func endAllActivities() async {
        for lineNumber in activeActivities.keys {
            await endActivity(for: lineNumber, dismissImmediately: true)
        }
    }

    // MARK: - Automatic Management

    /// Process a status update and manage Live Activities accordingly
    @available(iOS 16.2, *)
    func processStatusUpdate(_ lines: [LineStatus]) async {
        let linesWithIssues = lines.filter { $0.hasIssues }
        let affectedLineNumbers = Set(linesWithIssues.map(\.lineNumber))

        // Start/update activities for lines with issues
        for line in linesWithIssues {
            do {
                if activeActivities[line.lineNumber] != nil {
                    try await updateActivity(for: line)
                } else {
                    try await startActivity(for: line)
                }
            } catch {
                print("Failed to manage activity for line \(line.lineNumber): \(error)")
            }
        }

        // End activities for lines that are now normal. Iterate over a
        // snapshot of the keys so the mutation inside endActivity (which
        // removes the key) doesn't break the loop.
        let staleKeys = Set(activeActivities.keys).subtracting(affectedLineNumbers)
        for lineNumber in staleKeys {
            await endActivity(for: lineNumber, dismissImmediately: false)
        }
    }

    // MARK: - Helper Methods

    private func contentState(for line: LineStatus) -> MetrobusDisruptionAttributes.ContentState {
        MetrobusDisruptionAttributes.ContentState(
            status: line.status.rawValue,
            statusSeverity: line.status.severity,
            affectedStations: line.affectedStations,
            additionalInfo: line.additionalInfo,
            updatedAt: Date()
        )
    }

    // handlePushToken removed alongside pushType: .token (see startActivity).
    // Restore both together when a push backend exists.
}

// MARK: - Convenience Extension for ViewModel

extension LiveActivityService {
    /// Start monitoring and automatically manage Live Activities
    /// Call this when the app becomes active
    @available(iOS 16.2, *)
    func startMonitoring() {
        // Restore any existing activities from the system
        Task {
            for activity in Activity<MetrobusDisruptionAttributes>.activities {
                activeActivities[activity.attributes.lineNumber] = activity
            }
        }
    }
}

#endif
