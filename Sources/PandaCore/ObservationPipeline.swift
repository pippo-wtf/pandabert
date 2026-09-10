import Foundation

public struct ObservationUpdate {
    public let baselineSessions: [Session]
    public let localMachineID: String
    public let sessions: [Session]
    public let coverage: [Coverage]
    public let issues: [String]
    public let refreshed: Date?
}

/// Main-queue state with independent, single-flight workers for local, SSH and GitHub reads.
public final class ObservationPipeline {
    private let localQueue = DispatchQueue(label: "panda.local", qos: .utility)
    private let remoteQueue = DispatchQueue(label: "panda.remote", qos: .utility)
    private let githubQueue = DispatchQueue(label: "panda.github", qos: .utility)
    private let readLocal: ([Profile]) throws -> Snapshot
    private let readRemote: (RemoteMachine) throws -> Snapshot
    private let readGitHub: (PullRequest) -> PullRequest
    private let onUpdate: (ObservationUpdate) -> Void
    private var preferences = Preferences()
    private var pins: [Session] = []
    private var local: Snapshot?
    private var localProfiles: [Profile] = []
    private var localError: String?
    private var remoteCache: [String: Snapshot] = [:]
    private var remoteErrors: [String: String] = [:]
    private var githubCache: [String: PullRequest] = [:]
    private var localBusy = false, remoteBusy = false, githubBusy = false
    private var lastRemote = Date.distantPast, lastGitHub = Date.distantPast

    public init(root: URL, local: (([Profile]) throws -> Snapshot)? = nil,
                remote: @escaping (RemoteMachine) throws -> Snapshot = { try RemoteReader.snapshot($0) },
                github: @escaping (PullRequest) -> PullRequest = GitHub.refresh,
                onUpdate: @escaping (ObservationUpdate) -> Void) {
        // This collector is accessed exclusively by localQueue.
        var collector: Collector?
        readLocal = local ?? { profiles in
            if collector == nil { collector = try Collector(root: root) }
            return collector!.snapshot(profiles: profiles)
        }
        readRemote = remote; readGitHub = github; self.onUpdate = onUpdate
    }

    public func refresh(preferences: Preferences, pins: [Session], force: Bool = false) {
        dispatchPrecondition(condition: .onQueue(.main))
        if self.preferences.remotes != preferences.remotes { lastRemote = .distantPast }
        if self.preferences.githubEnabled != preferences.githubEnabled { lastGitHub = .distantPast; githubCache = [:] }
        self.preferences = preferences; self.pins = pins
        remoteCache = remoteCache.filter { id, _ in preferences.remotes.contains { $0.id == id } }
        publish()
        if !localBusy {
            localBusy = true
            let profiles = preferences.profiles, read = readLocal
            localQueue.async { [weak self] in
                let result = Result { try read(profiles) }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }; self.localBusy = false
                    guard profiles == self.preferences.profiles else {
                        self.refresh(preferences: self.preferences, pins: self.pins); return
                    }
                    var baseline: [Session] = []
                    switch result {
                    case .success(let snapshot):
                        if self.local == nil { baseline = snapshot.sessions }
                        self.local = snapshot; self.localProfiles = profiles; self.localError = nil
                    case .failure(let error): self.localError = error.localizedDescription
                    }
                    self.publish(baseline: baseline); self.refreshGitHub(force: force)
                }
            }
        }
        if !remoteBusy && (force || Date().timeIntervalSince(lastRemote) >= 30) {
            remoteBusy = true
            let remotes = preferences.remotes, read = readRemote
            remoteQueue.async { [weak self] in
                for remote in remotes {
                    let result = Result { try read(remote) }
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.preferences.remotes.contains(remote) else { return }
                        var baseline: [Session] = []
                        switch result {
                        case .success(let snapshot):
                            if self.remoteCache[remote.id] == nil { baseline = snapshot.sessions }
                            self.remoteCache[remote.id] = snapshot; self.remoteErrors[remote.id] = nil
                        case .failure: self.remoteErrors[remote.id] = "\(remote.label): connection unavailable"
                        }
                        self.publish(baseline: baseline); self.refreshGitHub(force: false)
                    }
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }; self.remoteBusy = false
                    self.lastRemote = remotes == self.preferences.remotes ? Date() : .distantPast
                }
            }
        }
        refreshGitHub(force: force)
    }

    private func refreshGitHub(force: Bool) {
        guard preferences.githubEnabled, !githubBusy,
              force || Date().timeIntervalSince(lastGitHub) >= 60 else { return }
        var seen = Set<String>()
        let requests = assembledSessions().compactMap(\.pullRequest).filter { seen.insert($0.url).inserted }.prefix(12)
        guard !requests.isEmpty else { return }
        githubBusy = true
        let read = readGitHub
        githubQueue.async { [weak self] in
            for request in requests {
                let result = read(request)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.preferences.githubEnabled else { return }
                    self.githubCache[request.url] = result; self.publish()
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }; self.githubBusy = false; self.lastGitHub = Date()
            }
        }
    }

    private func assembledSessions() -> [Session] {
        var all = localProfiles == preferences.profiles ? local?.sessions ?? [] : []
        if localError != nil { all = all.map { var s = $0; s.sourceOnline = false; return s } }
        for remote in preferences.remotes {
            guard let snapshot = remoteCache[remote.id] else { continue }
            let online = remoteErrors[remote.id] == nil && Date().timeIntervalSince(snapshot.generatedAt) <= 90
            all += snapshot.sessions.map { var s = $0; s.machine = remote.label; s.sourceOnline = s.sourceOnline && online; return s }
        }
        return all
    }
    private func publish(baseline: [Session] = []) {
        var all = assembledSessions().map { session -> Session in
            var s = session
            if preferences.githubEnabled, let url = s.pullRequest?.url, let pr = githubCache[url] { s.pullRequest = pr }
            return s
        }
        var ids = Set<String>()
        all = all.filter { ids.insert($0.id).inserted }.sorted { $0.lastEvent > $1.lastEvent }
        for var pin in pins where preferences.keptCardIDs.contains(pin.id) && !ids.contains(pin.id) {
            pin.sourceOnline = false; pin.reason = "Kept task outside current observation coverage"; all.append(pin)
        }
        var coverage = localProfiles == preferences.profiles ? local?.coverage ?? [] : []
        if localError != nil { coverage = coverage.map { var c = $0; c.available = false; c.message = "Local collection unavailable"; return c } }
        var errors = localError.map { [$0] } ?? []
        for remote in preferences.remotes {
            if let error = remoteErrors[remote.id] { errors.append(error) }
            guard let snapshot = remoteCache[remote.id] else { continue }
            coverage += snapshot.coverage.map { value in
                var c = value; c.profile = remote.label + " · " + c.profile
                if remoteErrors[remote.id] != nil || Date().timeIntervalSince(snapshot.generatedAt) > 90 {
                    c.available = false; c.message = "Machine unavailable · cached sessions"
                }
                return c
            }
        }
        onUpdate(ObservationUpdate(baselineSessions: baseline, localMachineID: local?.machineID ?? "", sessions: all, coverage: coverage, issues: errors, refreshed: local?.generatedAt))
    }
}
