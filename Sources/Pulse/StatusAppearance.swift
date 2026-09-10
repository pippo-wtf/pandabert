import SwiftUI
import PulseCore

enum StatusTone: CaseIterable {
    case active, attention, complete, quiet
    var label: String {
        switch self { case .active: return "Active"; case .attention: return "Needs you"; case .complete: return "Finished"; case .quiet: return "Waiting / idle" }
    }
    var background: Color {
        switch self {
        case .active: return lavender
        case .attention: return Color(red: 1, green: 0.958, blue: 0.827)
        case .complete: return Color(red: 0.914, green: 0.962, blue: 0.929)
        case .quiet: return Color(red: 0.954, green: 0.954, blue: 0.964)
        }
    }
    var accent: Color {
        switch self {
        case .active: return .white
        case .attention: return Color(red: 0.49, green: 0.35, blue: 0.03)
        case .complete: return Color(red: 0.18, green: 0.43, blue: 0.29)
        case .quiet: return Color(red: 0.43, green: 0.43, blue: 0.48)
        }
    }
    var text: Color { self == .active ? .white : ink }
    var secondary: Color { self == .active ? .white.opacity(0.85) : ink.opacity(0.62) }
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
