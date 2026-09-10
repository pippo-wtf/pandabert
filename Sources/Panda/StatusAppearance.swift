import SwiftUI
import PandaCore

enum StatusTone: CaseIterable {
    case active, attention, complete, quiet
    var label: String {
        switch self { case .active: return "Active"; case .attention: return "Needs you"; case .complete: return "Finished"; case .quiet: return "Waiting / idle" }
    }
    var accent: Color {
        switch self {
        case .active: return lavender
        case .attention: return Color(red: 0.89, green: 0.69, blue: 0.19)
        case .complete: return Color(red: 0.29, green: 0.62, blue: 0.42)
        case .quiet: return Color(red: 0.55, green: 0.55, blue: 0.60)
        }
    }
}

struct StatusAppearance {
    let tone: StatusTone
    let label: String
    init(_ session: Session, preferences: Preferences) {
        let activity = session.displayActivity()
        if !session.sourceOnline { tone = .quiet; label = "Machine unavailable · last known activity"; return }
        if activity == .working { tone = .active; label = "Working"; return }
        if [.question, .approval, .failed].contains(activity) { tone = .attention; label = activity.label; return }
        if let pr = session.pullRequest, pr.isFresh(), pr.checksFailed || pr.review == "CHANGES_REQUESTED" { tone = .attention; label = pr.label; return }
        if let wait = preferences.waits[session.id], !wait.isEmpty { tone = .quiet; label = "Waiting · " + wait; return }
        if let pr = session.pullRequest, pr.isFresh(), pr.isWaiting { tone = .quiet; label = pr.label; return }
        if preferences.needsAttention(session) { tone = .attention; label = activity == .finished ? "Ready for your review" : activity.label; return }
        if activity == .finished {
            tone = .complete
            if let pr = session.pullRequest, pr.isFresh(), ["MERGED", "CLOSED"].contains(pr.state) || pr.review == "APPROVED" { label = pr.label }
            else { label = preferences.reviewed[session.id] == session.completionKey ? "Reviewed" : "Turn finished" }
            return
        }
        tone = .quiet; label = activity.label
    }
}
