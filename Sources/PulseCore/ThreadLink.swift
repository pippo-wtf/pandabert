import Foundation

public struct ThreadLink {
    public let url: URL?
    public let bundleID: String
    public let explanation: String
    public init(session: Session, localMachineID: String) {
        bundleID = session.provider == .codex ? "com.openai.codex" : "com.anthropic.claudefordesktop"
        let isLocal = session.machineID == localMachineID
        if session.provider == .codex {
            guard isLocal else { url = nil; explanation = "This Codex thread lives on \(session.machine). Remote app navigation is not connected yet."; return }
            guard UUID(uuidString: session.nativeID) != nil else { url = nil; explanation = "No valid Codex thread ID is available."; return }
            url = URL(string: "codex://threads/" + session.nativeID)
            explanation = "Open this thread in Codex. The app must have access to its profile."
        } else if isLocal, let desktop = session.desktopSessionID, desktop.hasPrefix("local_"), UUID(uuidString: String(desktop.dropFirst(6))) != nil {
            url = URL(string: "claude://claude.ai/epitaxy/" + desktop)
            explanation = "Open this existing Claude desktop conversation."
        } else if let bridge = session.bridgeSessionID, bridge.range(of: "^(cse|session)_[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil {
            // Claude's session store normalizes CLI bridge IDs to the server's session_ form.
            let serverID = bridge.hasPrefix("cse_") ? "session_" + bridge.dropFirst(4) : bridge
            url = URL(string: "claude://claude.ai/code/" + serverID)
            explanation = "Open the linked Claude conversation using the account signed in to Claude."
        } else {
            url = nil
            explanation = isLocal ? "This terminal session has no linked desktop conversation. Its session ID is available in Details." : "This session lives on \(session.machine) and has no linked Claude desktop conversation."
        }
    }
}

public enum ClaudeDesktopIndex {
    public static var defaultRoot: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Claude/claude-code-sessions") }
    // Read only session identity fields. Never import, resume, or rewrite provider sessions.
    public static func load(root: URL = defaultRoot) -> [String: String] {
        var result: [String: String] = [:]; var ambiguous = Set<String>(); var count = 0
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return result }
        for case let file as URL in e {
            if e.level > 3 { e.skipDescendants(); continue }
            guard file.pathExtension == "json", file.lastPathComponent.hasPrefix("local_") else { continue }
            count += 1; if count > 3000 { break }
            guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 2 * 1024 * 1024,
                  let data = try? Data(contentsOf: file), let record = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let desktop = record["sessionId"] as? String, desktop == file.deletingPathExtension().lastPathComponent,
                  UUID(uuidString: String(desktop.dropFirst(6))) != nil else { continue }
            for field in ["cliSessionId", "unarchivedCliSessionId", "preClearCliSessionId"] {
                guard let cli = record[field] as? String, UUID(uuidString: cli) != nil else { continue }
                if let prior = result[cli], prior != desktop { ambiguous.insert(cli) }
                result[cli] = desktop
            }
        }
        for key in ambiguous { result[key] = nil }
        return result
    }
}
