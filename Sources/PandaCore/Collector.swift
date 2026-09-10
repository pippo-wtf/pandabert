import Foundation

public final class Collector {
    private var cache: [String: (Date, UInt64, Session)] = [:]
    private var repos: [String: String] = [:]
    public let machineID: String
    public let machine: String
    public init(root: URL = PandaPaths.data) throws {
        machineID = try PandaPaths.machineID(root: root)
        machine = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }
    public func snapshot(profiles: [Profile], now: Date = Date()) -> Snapshot {
        var sessions: [Session] = []; var coverage: [Coverage] = []
        var seen = Set<String>()
        let desktopIDs = profiles.contains { $0.provider == .claude } ? ClaudeDesktopIndex.load() : [:]
        for profile in profiles {
            var titles: [String: String] = [:]
            if profile.provider == .codex, let records = try? Self.readRecords(URL(fileURLWithPath: profile.root).appendingPathComponent("session_index.jsonl"), limit: 1024 * 1024) {
                for r in records { if let id = r["id"] as? String, let title = r["thread_name"] as? String { titles[id] = clipped(title, 120) } }
            }
            let root = URL(fileURLWithPath: profile.root).appendingPathComponent(profile.provider == .codex ? "sessions" : "projects")
            var files: [(URL, Date, UInt64)] = []; var walked = 0; var errors = false
            let exists = FileManager.default.isReadableFile(atPath: root.path)
            if let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles], errorHandler: { _, _ in errors = true; return true }) {
                for case let url as URL in e {
                    walked += 1; if walked > 20000 { errors = true; break }
                    if url.lastPathComponent == "subagents" { e.skipDescendants(); continue }
                    guard url.pathExtension == "jsonl", let v = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]), v.isRegularFile == true, let modified = v.contentModificationDate else { continue }
                    guard now.timeIntervalSince(modified) < 14 * 86400 else { continue }
                    files.append((url, modified, UInt64(v.fileSize ?? 0)))
                }
            }
            files.sort { $0.1 > $1.1 }
            var count = 0
            for (url, modified, size) in files.prefix(250) {
                let key = profile.id + url.path
                var session: Session?
                if let cached = cache[key], cached.0 == modified, cached.1 == size { session = cached.2 }
                else if let records = try? Self.readRecords(url) {
                    let native = records.lazy.compactMap { o -> String? in
                        if profile.provider == .codex, o["type"] as? String == "session_meta" { return (o["payload"] as? [String: Any])?["id"] as? String }
                        return o["sessionId"] as? String
                    }.first ?? url.deletingPathExtension().lastPathComponent
                    var reducer = SessionReducer(Session(nativeID: native, profile: profile, machineID: machineID, machine: machine))
                    for record in records { reducer.apply(record) }
                    var s = reducer.session; s.sourcePath = url.path
                    if s.repository.isEmpty, !s.cwd.isEmpty {
                        if let cached = repos[s.cwd] { s.repository = cached }
                        else {
                            let result = try? Command.run("/usr/bin/git", ["-C", s.cwd, "config", "--get", "remote.origin.url"], timeout: 2)
                            let repo = result.map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
                            repos[s.cwd] = repo; s.repository = repo
                        }
                    }
                    s.projectKey = Self.projectKey(repository: s.repository, cwd: s.cwd, machine: machineID)
                    // Do not retain credentials that may be embedded in an origin URL.
                    if !s.repository.isEmpty { s.repository = s.projectKey }
                    let repoName = s.projectKey.split(separator: "/").last.map(String.init) ?? ""
                    s.project = !s.repository.isEmpty ? repoName : (s.cwd.isEmpty ? "Unassigned" : URL(fileURLWithPath: s.cwd).lastPathComponent)
                    cache[key] = (modified, size, s); session = s
                } else { errors = true }
                if var s = session, !s.sidechain, !seen.contains(s.id) {
                    if let title = titles[s.nativeID] { s.title = title }
                    if s.provider == .claude { s.desktopSessionID = desktopIDs[s.nativeID] }
                    sessions.append(s); seen.insert(s.id); count += 1
                }
            }
            coverage.append(Coverage(profile: profile.label, provider: profile.provider, available: exists, fileCount: count,
                message: !exists ? "Session folder unavailable" : "Last 14 days · up to 250 sessions" + (errors || files.count > 250 ? " · partial coverage" : " · passive logs")))
        }
        sessions.sort { $0.lastEvent > $1.lastEvent }
        return Snapshot(machineID: machineID, machine: machine, generatedAt: now, sessions: sessions, coverage: coverage)
    }
    // Parse complete JSONL records only. Large transcripts retain metadata plus a bounded recent tail.
    public static func readRecords(_ url: URL, limit: Int = 2 * 1024 * 1024) throws -> [[String: Any]] {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let size = try handle.seekToEnd(); try handle.seek(toOffset: 0)
        var chunks: [Data] = []
        if size > limit {
            chunks.append(try handle.read(upToCount: 65536) ?? Data())
            try handle.seek(toOffset: size - UInt64(limit))
            let tail = try handle.read(upToCount: limit) ?? Data()
            if let first = tail.firstIndex(of: 10) { chunks.append(Data(tail.suffix(from: tail.index(after: first)))) }
        } else { chunks.append(try handle.read(upToCount: limit) ?? Data()) }
        var result: [[String: Any]] = []
        for chunk in chunks {
            let lines = chunk.split(separator: 10, omittingEmptySubsequences: false)
            for line in lines.dropLast() {
                if let o = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any] { result.append(o) }
            }
        }
        return result
    }
    public static func projectKey(repository: String, cwd: String, machine: String) -> String {
        var r = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        if r.hasPrefix("git@"), let colon = r.firstIndex(of: ":") { r = String(r.dropFirst(4).prefix(upTo: colon)) + "/" + r[r.index(after: colon)...] }
        else if let url = URL(string: r), let host = url.host { r = host.lowercased() + url.path }
        if r.hasSuffix(".git") { r.removeLast(4) }
        while r.hasSuffix("/") { r.removeLast() }
        return r.isEmpty ? machine + ":" + URL(fileURLWithPath: cwd).standardizedFileURL.path : r
    }
}

public enum Command {
    public static func run(_ executable: String, _ arguments: [String], timeout: Double = 10, limit: Int = 8 * 1024 * 1024) throws -> Data {
        let p = Process(); p.executableURL = URL(fileURLWithPath: executable); p.arguments = arguments
        let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0); let readDone = DispatchSemaphore(value: 0)
        let lock = NSLock(); var output = Data(); var overflow = false
        p.terminationHandler = { _ in finished.signal() }
        try p.run()
        DispatchQueue.global(qos: .utility).async {
            while true {
                let chunk = pipe.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                lock.lock()
                if output.count + chunk.count <= limit { output.append(chunk) } else { overflow = true; p.terminate() }
                lock.unlock()
            }
            readDone.signal()
        }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            p.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut { kill(p.processIdentifier, SIGKILL); _ = finished.wait(timeout: .now() + 1) }
            throw PandaError.message("Command timed out")
        }
        guard readDone.wait(timeout: .now() + 2) == .success else { throw PandaError.message("Output stream did not close") }
        lock.lock(); defer { lock.unlock() }
        guard !overflow, p.terminationStatus == 0 else { throw PandaError.message(overflow ? "Response too large" : "Command failed (\(p.terminationStatus))") }
        return output
    }
}

public enum RemoteReader {
    public static func snapshot(_ remote: RemoteMachine, now: Date = Date()) throws -> Snapshot {
        guard remote.isValid else { throw PandaError.message("Invalid SSH host") }
        let data = try Command.run("/usr/bin/ssh", ["-o", "BatchMode=yes", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=yes", remote.sshHost, "if [ -x \"$HOME/.local/bin/panda-agent\" ]; then exec \"$HOME/.local/bin/panda-agent\" snapshot; else exec \"$HOME/.local/bin/pulse-agent\" snapshot; fi"], timeout: 15)
        return try decode(data, now: now)
    }
    public static func decode(_ data: Data, now: Date = Date()) throws -> Snapshot {
        guard data.count <= 8 * 1024 * 1024 else { throw PandaError.message("Remote response too large") }
        let s = try JSONDecoder().decode(Snapshot.self, from: data)
        guard s.protocolVersion == pandaProtocolVersion, abs(now.timeIntervalSince(s.generatedAt)) < 120, s.sessions.count <= 1000,
              s.sessions.allSatisfy({ $0.machineID == s.machineID && $0.id == stableID(s.machineID + ":" + $0.profileID + ":" + $0.nativeID) }) else { throw PandaError.message("Remote snapshot is stale or incompatible") }
        return s
    }
}
