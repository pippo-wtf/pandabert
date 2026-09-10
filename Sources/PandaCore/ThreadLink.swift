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
        } else {
            url = nil
            explanation = isLocal ? "No matching Claude desktop conversation was found on this Mac. A terminal or bridge ID alone cannot open a chat." : "This session lives on \(session.machine) and has no linked Claude desktop conversation."
        }
    }
    /// Refresh identity evidence at click time, including for cached or pinned tasks.
    public static func revalidated(session: Session, localMachineID: String, desktopRoot: URL = ClaudeDesktopIndex.defaultRoot) -> ThreadLink {
        var current = session
        if current.provider == .claude {
            current.desktopSessionID = current.machineID == localMachineID ? ClaudeDesktopIndex.load(root: desktopRoot)[current.nativeID] : nil
        }
        return ThreadLink(session: current, localMachineID: localMachineID)
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
