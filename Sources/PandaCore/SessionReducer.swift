import Foundation

public struct SessionReducer {
    public private(set) var session: Session
    public init(_ session: Session) { self.session = session }
    /// Metadata may survive a skipped span; lifecycle and pending questions cannot.
    public mutating func transcriptGap() {
        session.activity = .unknown; session.turnID = ""; session.pendingCallID = ""
        session.lastActivityEvent = .distantPast; session.lastEvent = .distantPast; session.excerpt = ""
        session.reason = "Recent log context is incomplete"
    }
    private static let iso = ISO8601DateFormatter()
    private static let fractional: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()
    public static func date(_ value: Any?) -> Date? {
        if let s = value as? String { return fractional.date(from: s) ?? iso.date(from: s) }
        if let n = value as? Double { return Date(timeIntervalSince1970: n > 10_000_000_000 ? n / 1000 : n) }
        return nil
    }
    public mutating func apply(_ record: [String: Any]) {
        if session.provider == .codex { codex(record) } else { claude(record) }
    }
    private mutating func transition(_ activity: Activity, at: Date, reason: String, excerpt: String? = nil, turn: String? = nil) {
        guard at >= session.lastActivityEvent else { return }
        session.activity = activity; session.lastActivityEvent = at; session.lastEvent = max(session.lastEvent, at); session.reason = reason
        if let excerpt { session.excerpt = clipped(excerpt, 4000) }
        if let turn, !turn.isEmpty { session.turnID = turn }
        if ![.approval, .question].contains(activity) { session.pendingCallID = "" }
    }
    private mutating func metadata(_ o: [String: Any]) {
        if let cwd = o["cwd"] as? String, !cwd.isEmpty { session.cwd = cwd }
        if let git = o["git"] as? [String: Any] {
            session.branch = git["branch"] as? String ?? session.branch
            session.repository = git["repository_url"] as? String ?? git["origin_url"] as? String ?? session.repository
        }
        if let b = o["gitBranch"] as? String { session.branch = b }
    }
    private func text(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let a = value as? [[String: Any]] { return a.compactMap { $0["text"] as? String }.joined(separator: "\n") }
        return ""
    }
    private mutating func title(_ value: String) {
        if session.title == "Untitled session" { let s = summary(value); if !s.isEmpty { session.title = s } }
    }
    private mutating func link(_ value: String) {
        guard let range = value.range(of: "https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+", options: .regularExpression) else { return }
        let url = String(value[range]); if session.pullRequest?.url != url { session.pullRequest = PullRequest(url: url) }
    }
    private mutating func codex(_ o: [String: Any]) {
        guard let kind = o["type"] as? String, let p = o["payload"] as? [String: Any] else { return }
        let at = Self.date(o["timestamp"]) ?? .distantPast
        metadata(p)
        if kind == "session_meta" {
            session.entrypoint = (p["originator"] as? String ?? "").lowercased().contains("desktop") ? "Desktop" : "Codex session"
            if let source = p["source"] as? [String: Any], source["subagent"] != nil { session.sidechain = true }
            if let source = p["source"] as? String, source.contains("subagent") { session.sidechain = true }
            return
        }
        if kind == "event_msg" {
            let event = p["type"] as? String ?? ""
            let turn = p["turn_id"] as? String
            switch event {
            case "task_started", "turn_started": transition(.working, at: at, reason: "Turn started", turn: turn)
            case "task_complete", "turn_completed":
                guard turn == nil || session.turnID.isEmpty || turn == session.turnID else { return }
                let last = p["last_agent_message"] as? String ?? ""
                let failed = (p["status"] as? String) == "failed"
                transition(failed ? .failed : .finished, at: at, reason: failed ? "Turn failed" : "Agent finished this turn", excerpt: last, turn: turn); link(last)
            case "turn_aborted", "task_aborted":
                guard turn == nil || session.turnID.isEmpty || turn == session.turnID else { return }
                transition(.interrupted, at: at, reason: "Turn interrupted", turn: turn)
            case "user_message": let s = text(p["message"]); title(s)
            case "request_user_input": transition(.question, at: at, reason: "Agent asked a question", excerpt: questions(p))
            case "item_completed": if let item = p["item"] as? [String: Any] { codexItem(item, at: at) }
            default: break
            }
        } else if kind == "response_item" { codexItem(p, at: at) }
    }
    private mutating func codexItem(_ p: [String: Any], at: Date) {
        let type = p["type"] as? String ?? ""
        if type == "message" {
            let content = text(p["content"])
            // The rollout's user-role records also contain injected environment/plugin instructions.
            // User-message events and the session index are the title sources.
            if p["role"] as? String == "assistant" {
                if at >= session.lastEvent { session.excerpt = clipped(content, 4000); session.lastEvent = at; link(content) }
                // Commentary is activity, not proof that a completed turn restarted.
                if session.activity == .working { transition(.working, at: at, reason: "Agent response observed") }
            }
        }
        if ["function_call", "custom_tool_call"].contains(type) {
            let name = p["name"] as? String ?? ""
            let argsText = p["arguments"] as? String ?? p["input"] as? String ?? "{}"
            let args = (try? JSONSerialization.jsonObject(with: Data(argsText.utf8))) as? [String: Any] ?? [:]
            if name.hasSuffix("request_user_input") {
                transition(.question, at: at, reason: "Agent asked a question", excerpt: questions(args))
                if at >= session.lastActivityEvent { session.pendingCallID = p["call_id"] as? String ?? "" }
            } else if session.activity == .working { transition(.working, at: at, reason: "Tool activity observed") }
        }
        if ["function_call_output", "custom_tool_call_output"].contains(type), session.activity == .question,
           let id = p["call_id"] as? String, !id.isEmpty, id == session.pendingCallID {
            transition(.working, at: at, reason: "Question tool returned")
        }
        // A failed tool is not a failed run; shell text mentioning escalation is not a permission event.
    }
    private mutating func claude(_ o: [String: Any]) {
        // Inherited fork history must not supply the parent's title, bridge, or activity.
        if let id = o["sessionId"] as? String, id.caseInsensitiveCompare(session.nativeID) != .orderedSame { return }
        metadata(o)
        if o["isSidechain"] as? Bool == true { session.sidechain = true }
        if let id = o["bridgeSessionId"] as? String, !id.isEmpty { session.entrypoint = "Desktop Code"; session.bridgeSessionID = id }
        let kind = o["type"] as? String ?? ""
        let at = Self.date(o["timestamp"]) ?? .distantPast
        if kind == "custom-title", let name = o["customTitle"] as? String, !name.isEmpty { session.title = clipped(name, 120); return }
        if kind == "pr-link", let url = o["prUrl"] as? String { link(url); return }
        if kind == "queue-operation" { return } // Local queue bookkeeping is not a provider admission signal.
        if kind == "system", o["subtype"] as? String == "turn_duration" {
            transition(.finished, at: at, reason: "Turn completion recorded"); return
        }
        guard let message = o["message"] as? [String: Any] else { return }
        let blocks = message["content"] as? [[String: Any]] ?? []
        if kind == "user" {
            let results = blocks.filter { $0["type"] as? String == "tool_result" }
            if !results.isEmpty {
                if !session.pendingCallID.isEmpty && results.contains(where: { $0["tool_use_id"] as? String == session.pendingCallID }) {
                    transition(.working, at: at, reason: "Question answered")
                } else if session.activity == .working { transition(.working, at: at, reason: "Tool result observed") }
            } else if o["isMeta"] as? Bool != true {
                let value = text(message["content"]); title(value)
                transition(.working, at: at, reason: "User message submitted", turn: o["uuid"] as? String)
            }
        }
        if kind == "assistant" {
            let stop = message["stop_reason"] as? String ?? ""
            for b in blocks where b["type"] as? String == "tool_use" {
                let name = b["name"] as? String ?? ""
                if name == "AskUserQuestion" || name == "ExitPlanMode" {
                    transition(.question, at: at, reason: name == "ExitPlanMode" ? "Plan awaits your decision" : "Agent asked a question", excerpt: questions(b["input"] as? [String: Any] ?? [:]))
                    if at >= session.lastActivityEvent { session.pendingCallID = b["id"] as? String ?? "" }
                } else { transition(.working, at: at, reason: "Tool activity observed") }
            }
            let content = text(message["content"])
            if !content.isEmpty, at >= session.lastEvent { session.excerpt = clipped(content, 4000); session.lastEvent = at; link(content) }
            if stop == "end_turn" || stop == "stop_sequence" { transition(.finished, at: at, reason: "Agent finished this turn", excerpt: content) }
            else if session.activity == .working { transition(.working, at: at, reason: "Agent activity observed") }
        }
    }
    public mutating func hook(_ o: [String: Any], at: Date) {
        metadata(o)
        let name = o["hook_event_name"] as? String ?? ""
        let tool = o["tool_name"] as? String ?? ""
        let turn = o["turn_id"] as? String
        switch name {
        case "UserPromptSubmit": transition(.working, at: at, reason: "Prompt submitted · hook", turn: turn)
        case "PermissionRequest": transition(.approval, at: at, reason: "Permission requested · hook", excerpt: tool)
        case "PreToolUse":
            if tool == "AskUserQuestion" || tool.contains("request_user_input") { transition(.question, at: at, reason: "Question requested · hook", excerpt: questions(o["tool_input"] as? [String: Any] ?? [:])) }
            else { transition(.working, at: at, reason: "Tool started · hook", turn: turn) }
        case "PostToolUse": transition(.working, at: at, reason: "Tool returned · hook", turn: turn)
        case "Stop": transition(.finished, at: at, reason: "Turn finished · hook", excerpt: o["last_assistant_message"] as? String, turn: turn)
        case "StopFailure": transition(.failed, at: at, reason: "Run failed · hook", turn: turn)
        case "Interrupt": transition(.interrupted, at: at, reason: "Turn interrupted · hook", turn: turn)
        case "SessionStart", "SessionEnd": transition(.idle, at: at, reason: name == "SessionStart" ? "Session started · hook" : "Session closed · hook")
        case "Notification": if o["notification_type"] as? String == "permission_prompt" { transition(.approval, at: at, reason: "Permission requested · hook") }
        default: break
        }
    }
    private func questions(_ o: [String: Any]) -> String {
        if let q = o["questions"] as? [[String: Any]] { return clipped(q.compactMap { $0["question"] as? String ?? $0["title"] as? String }.joined(separator: "\n"), 2000) }
        return clipped(o["question"] as? String ?? o["prompt"] as? String ?? "Open the original conversation to respond.", 2000)
    }
}
