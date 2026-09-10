import Foundation
import CryptoKit

public let pandaVersion = "0.3.0"
public let pandaProtocolVersion = 1

public enum Provider: String, Codable, CaseIterable { case claude, codex
    public var label: String { self == .claude ? "Claude" : "Codex" }
}
public enum Activity: String, Codable, CaseIterable {
    case working, question, approval, finished, failed, interrupted, idle, pending, unknown
    public var label: String {
        switch self {
        case .working: return "Working"
        case .question: return "Needs your answer"
        case .approval: return "Needs approval"
        case .finished: return "Turn finished"
        case .failed: return "Run failed"
        case .interrupted: return "Interrupted"
        case .idle: return "Idle"
        case .pending: return "Queued"
        case .unknown: return "Status uncertain"
        }
    }
    public var requiresAttention: Bool { [.question, .approval, .finished, .failed].contains(self) }
}
public struct Profile: Codable, Identifiable, Hashable {
    public var id: String
    public var provider: Provider
    public var label: String
    public var root: String
    public init(provider: Provider, label: String, root: String) {
        self.provider = provider; self.label = label; self.root = NSString(string: root).expandingTildeInPath
        self.id = stableID(provider.rawValue + ":" + URL(fileURLWithPath: self.root).standardizedFileURL.path)
    }
    public static func defaults(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [Profile] {
        [Profile(provider: .claude, label: "Default profile", root: home.appendingPathComponent(".claude").path),
         Profile(provider: .codex, label: "Default profile", root: home.appendingPathComponent(".codex").path)]
    }
}
public struct PullRequest: Codable, Equatable {
    public var url: String
    public var title: String = ""
    public var state: String = "UNKNOWN"
    public var review: String = ""
    public var requestedReviewers: Int = 0
    public var checksFailed: Bool = false
    public var checkedAt: Date?
    public var error: String?
    public init(url: String) { self.url = url }
    public var isWaiting: Bool { state == "OPEN" && (requestedReviewers > 0 || review == "REVIEW_REQUIRED") }
    public func isFresh(now: Date = Date()) -> Bool { error == nil && checkedAt.map { now.timeIntervalSince($0) < 180 } == true }
    public var label: String {
        if error != nil { return "GitHub status unavailable" }
        if state == "MERGED" { return "Pull request merged" }
        if state == "CLOSED" { return "Pull request closed" }
        if checksFailed { return "GitHub checks failed" }
        if review == "CHANGES_REQUESTED" { return "Changes requested" }
        if review == "APPROVED" { return "Pull request approved" }
        if isWaiting { return "Waiting for GitHub review" }
        return "Pull request linked"
    }
}
public struct Session: Codable, Identifiable, Equatable {
    public var id: String
    public var nativeID: String
    public var profileID: String
    public var provider: Provider
    public var profileLabel: String
    public var machineID: String
    public var machine: String
    public var title: String = "Untitled session"
    public var project: String = "Unassigned"
    public var projectKey: String = ""
    public var cwd: String = ""
    public var branch: String = ""
    public var repository: String = ""
    public var activity: Activity = .unknown
    public var turnID: String = ""
    public var pendingCallID: String = ""
    public var lastEvent: Date = .distantPast
    public var lastActivityEvent: Date = .distantPast
    public var reason: String = "No lifecycle event observed"
    public var excerpt: String = ""
    public var sourcePath: String = ""
    public var bridgeSessionID: String?
    public var desktopSessionID: String?
    public var entrypoint: String = "Local session"
    public var pullRequest: PullRequest?
    public var sidechain = false
    public var sourceOnline = true
    public init(nativeID: String, profile: Profile, machineID: String, machine: String) {
        self.nativeID = nativeID; self.profileID = profile.id; self.provider = profile.provider
        self.profileLabel = profile.label; self.machineID = machineID; self.machine = machine
        self.id = stableID(machineID + ":" + profile.id + ":" + nativeID)
    }
    public func displayActivity(now: Date = Date()) -> Activity {
        if !sourceOnline { return .unknown }
        // Log silence cannot distinguish long inference, a blocked process, or an exited app.
        if activity == .working && now.timeIntervalSince(lastActivityEvent) > 180 { return .unknown }
        return activity
    }
    public var completionKey: String { turnID + ":" + String(lastActivityEvent.timeIntervalSince1970) }
}
public struct Coverage: Codable, Equatable {
    public var profile: String
    public var provider: Provider
    public var available: Bool
    public var fileCount: Int
    public var message: String
    public init(profile: String, provider: Provider, available: Bool, fileCount: Int, message: String) {
        self.profile = profile; self.provider = provider; self.available = available; self.fileCount = fileCount; self.message = message
    }
}
public struct Snapshot: Codable {
    public var protocolVersion = pandaProtocolVersion
    public var version = pandaVersion
    public var machineID: String
    public var machine: String
    public var generatedAt: Date
    public var sessions: [Session]
    public var coverage: [Coverage]
    public init(machineID: String, machine: String, generatedAt: Date = Date(), sessions: [Session], coverage: [Coverage]) {
        self.machineID = machineID; self.machine = machine; self.generatedAt = generatedAt; self.sessions = sessions; self.coverage = coverage
    }
}
public struct RemoteMachine: Codable, Identifiable, Equatable {
    public var id = UUID().uuidString
    public var label: String
    public var sshHost: String
    public init(label: String, sshHost: String) { self.label = label; self.sshHost = sshHost }
    public var isValid: Bool {
        !sshHost.hasPrefix("-") && sshHost.range(of: "^[A-Za-z0-9_.@-]{1,160}$", options: .regularExpression) != nil
    }
}
public struct Preferences: Codable {
    public var pins: [String] = []
    public var reviewed: [String: String] = [:]
    public var projectAliases: [String: String] = [:]
    public var waits: [String: String] = [:]
    public var profiles = Profile.defaults()
    public var remotes: [RemoteMachine] = []
    public var alwaysOnTop = true
    public var githubEnabled = false
    public var showFinished = true
    public var attentionSince = Date()
    public init() {}
    public mutating func togglePin(_ id: String) { if pins.contains(id) { pins.removeAll { $0 == id } } else { pins.append(id) } }
    public func needsAttention(_ s: Session, now: Date = Date()) -> Bool {
        let a = s.displayActivity(now: now)
        if !s.sourceOnline { return false }
        let pr = s.pullRequest?.isFresh(now: now) == true ? s.pullRequest : nil
        if pr?.checksFailed == true || pr?.review == "CHANGES_REQUESTED" { return true }
        if a == .finished && (waits[s.id] != nil || pr?.isWaiting == true) { return false }
        if a == .finished && (!showFinished || reviewed[s.id] == s.completionKey) { return false }
        if a == .finished && s.lastActivityEvent < attentionSince { return false }
        return a.requiresAttention
    }
    public func projectName(_ s: Session) -> String { projectAliases[s.projectKey] ?? s.project }
}
public func stableID(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined() }
public func clipped(_ value: String, _ limit: Int = 180) -> String { String(value.prefix(limit)) }
public func summary(_ value: String, limit: Int = 100) -> String {
    if value.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<recommended_plugins>") { return "" }
    let lines = value.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    let useful = lines.first { !$0.isEmpty && !$0.hasPrefix("<") && !$0.hasPrefix("#") && !$0.hasPrefix("```") } ?? ""
    return clipped(useful, limit)
}
public enum PandaError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}
public enum PandaPaths {
    public static var data: URL {
        data(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser)
    }
    public static func data(environment: [String: String], home: URL) -> URL {
        if let override = environment["PANDA_HOME"] ?? environment["PULSE_HOME"] {
            return URL(fileURLWithPath: override)
        }
        // Keep the existing data location so renaming does not reset identity or preferences.
        return home.appendingPathComponent("Library/Application Support/Pulse")
    }
    public static func prepare(_ root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    public static func machineID(root: URL) throws -> String {
        try prepare(root)
        let path = root.appendingPathComponent("machine-id")
        if let value = try? String(contentsOf: path), UUID(uuidString: value) != nil { return value }
        let value = UUID().uuidString
        // Atomic exclusive creation avoids divergent identities across app/agent starts.
        let fd = open(path.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        if fd >= 0 { _ = value.withCString { write(fd, $0, strlen($0)) }; close(fd); return value }
        if let existing = try? String(contentsOf: path), UUID(uuidString: existing) != nil { return existing }
        throw PandaError.message("Cannot create the local machine identity")
    }
    public static func save<T: Encodable>(_ value: T, to path: URL) throws {
        try prepare(path.deletingLastPathComponent())
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value); try data.write(to: path, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    }
}

/// Missing settings are a first launch; existing unreadable settings must never broaden observation.
public enum PreferencesFile {
    public static func load(root: URL) throws -> Preferences? {
        let path = root.appendingPathComponent("preferences.json")
        let data: Data
        do { data = try Data(contentsOf: path) }
        catch {
            var info = stat()
            let absent = lstat(path.path, &info) == -1 && errno == ENOENT
            let failure = error as NSError
            if absent && failure.domain == NSCocoaErrorDomain && failure.code == NSFileReadNoSuchFileError { return nil }
            throw PandaError.message("Saved preferences could not be read. Observation is stopped; repair the file and restart PandaBert.")
        }
        do { return try JSONDecoder().decode(Preferences.self, from: data) }
        catch { throw PandaError.message("Saved preferences are invalid. Observation is stopped; repair the file and restart PandaBert.") }
    }
}
