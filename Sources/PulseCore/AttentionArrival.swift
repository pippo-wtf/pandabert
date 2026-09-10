import Foundation

public struct AttentionArrival: Equatable {
    public let sessionID: String
    public let startedAt: Date
    public static let duration: TimeInterval = 30
    public init(sessionID: String, startedAt: Date) {
        self.sessionID = sessionID; self.startedAt = startedAt
    }
}

/// Detect new attention events, not repeated polling of the same notification.
public struct AttentionArrivalTracker {
    private var primed = false
    private var observed: [String: String] = [:]
    private var observedPR: [String: String] = [:]
    public init() {}

    public mutating func observe(_ sessions: [Session], preferences: Preferences, now: Date = Date()) -> AttentionArrival? {
        var newest: Session?
        for session in sessions where session.sourceOnline {
            let key = "\(session.activity.rawValue):\(session.turnID):\(session.pendingCallID):\(session.lastActivityEvent.timeIntervalSince1970)"
            let changed = observed[session.id] != key
            observed[session.id] = key
            var newPRAlert = false
            if let pr = session.pullRequest, pr.isFresh(now: now) {
                // Check time alone and temporary loss of evidence must not retrigger a glow.
                let prKey = "\(pr.url):\(pr.checksFailed):\(pr.review)"
                newPRAlert = observedPR[session.id] != prKey && (pr.checksFailed || pr.review == "CHANGES_REQUESTED")
                observedPR[session.id] = prKey
            }
            guard primed, changed || newPRAlert, preferences.needsAttention(session, now: now) else { continue }
            if newest == nil || session.lastEvent > newest!.lastEvent || (session.lastEvent == newest!.lastEvent && session.id > newest!.id) {
                newest = session
            }
        }
        // Existing tasks at startup establish the baseline without flashing a backlog.
        primed = true
        return newest.map { AttentionArrival(sessionID: $0.id, startedAt: now) }
    }
}
