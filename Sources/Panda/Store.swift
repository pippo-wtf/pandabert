import Foundation
import SwiftUI
import PandaCore
import AppKit

final class PandaStore: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var coverage: [Coverage] = []
    @Published var preferences = Preferences()
    @Published var issues: [String] = []
    @Published var refreshed: Date?
    @Published var loading = true
    @Published var localMachineID = ""
    @Published var navigationError: String?
    @Published var latestArrival: AttentionArrival?
    private var arrivalTracker = AttentionArrivalTracker()
    let root = PandaPaths.data
    private let queue = DispatchQueue(label: "panda.collector", qos: .utility)
    private var collector: Collector?
    private var remoteCache: [String: Snapshot] = [:]
    private var remoteErrors: [String: String] = [:]
    private var githubCache: [String: PullRequest] = [:]
    private var lastRemote = Date.distantPast
    private var lastGitHub = Date.distantPast
    private var timer: Timer?
    private var busy = false
    private var pinnedCache: [Session] = []
    private var preferenceError: String?
    var onTopChanged: ((Bool) -> Void)?
    init() {
        let path = root.appendingPathComponent("preferences.json")
        if FileManager.default.fileExists(atPath: path.path) {
            do { preferences = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: path)) }
            catch { preferenceError = "Saved preferences could not be read. Existing file was preserved."; issues = [preferenceError!] }
        } else {
            do { try PandaPaths.save(preferences, to: path) }
            catch { preferenceError = "Could not save initial preferences: \(error.localizedDescription)" }
        }
        pinnedCache = (try? Data(contentsOf: root.appendingPathComponent("pinned-sessions.json"))).flatMap { try? JSONDecoder().decode([Session].self, from: $0) } ?? []
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func save() {
        guard preferenceError == nil else { return }
        do {
            try PandaPaths.save(preferences, to: root.appendingPathComponent("preferences.json"))
            pinnedCache = preferences.pins.compactMap { id in sessions.first { $0.id == id } ?? pinnedCache.first { $0.id == id } }
            try PandaPaths.save(pinnedCache, to: root.appendingPathComponent("pinned-sessions.json"))
        }
        catch { issues.append("Could not save preferences: \(error.localizedDescription)") }
        onTopChanged?(preferences.alwaysOnTop)
    }
    func pin(_ session: Session) { preferences.togglePin(session.id); save() }
    func reviewed(_ session: Session) { preferences.reviewed[session.id] = session.completionKey; save(); updateArrival(sessions) }
    func openThread(_ session: Session) {
        let link = ThreadLink.revalidated(session: session, localMachineID: localMachineID)
        guard let url = link.url else { navigationError = link.explanation; return }
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: link.bundleID) else {
            navigationError = "\(session.provider.label) is not installed or registered on this Mac."; return
        }
        let config = NSWorkspace.OpenConfiguration(); config.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: config) { _, error in
            if error != nil { DispatchQueue.main.async { self.navigationError = "Could not open \(session.provider.label). Try opening the app and signing in first." } }
        }
    }
    var attention: [Session] { sessions.filter { preferences.needsAttention($0) && !preferences.pins.contains($0.id) } }
    var pinned: [Session] { preferences.pins.compactMap { id in sessions.first { $0.id == id } } }
    var background: [Session] { sessions.filter { !preferences.needsAttention($0) && !preferences.pins.contains($0.id) } }
    private func updateArrival(_ current: [Session]) {
        if let arrival = arrivalTracker.observe(current, preferences: preferences) {
            latestArrival = arrival
            DispatchQueue.main.asyncAfter(deadline: .now() + AttentionArrival.duration) { [weak self] in
                if self?.latestArrival == arrival { self?.latestArrival = nil }
            }
        }
        if let arrival = latestArrival,
           !current.contains(where: { $0.id == arrival.sessionID && preferences.needsAttention($0) }) {
            latestArrival = nil
        }
    }
    func refresh(force: Bool = false) {
        guard !busy else { return }; busy = true
        let prefs = preferences
        let retainedPins = pinnedCache
        queue.async { [self] in
            var errors: [String] = []
            do {
                if collector == nil { collector = try Collector(root: root) }
                let local = collector!.snapshot(profiles: prefs.profiles)
                DispatchQueue.main.async { self.localMachineID = local.machineID; if self.loading { self.sessions = local.sessions; self.coverage = local.coverage; self.loading = false } }
                var all = local.sessions; var status = local.coverage
                if force || Date().timeIntervalSince(lastRemote) >= 30 {
                    for remote in prefs.remotes {
                        do { remoteCache[remote.id] = try RemoteReader.snapshot(remote); remoteErrors[remote.id] = nil }
                        catch {
                            remoteErrors[remote.id] = "\(remote.label): connection unavailable"
                            if var old = remoteCache[remote.id] { old.sessions = old.sessions.map { s in var s = s; s.sourceOnline = false; return s }; remoteCache[remote.id] = old }
                        }
                    }
                    lastRemote = Date()
                }
                for remote in prefs.remotes {
                    if let error = remoteErrors[remote.id] { errors.append(error) }
                    if let snapshot = remoteCache[remote.id] {
                        all += snapshot.sessions.map { s in var s = s; s.machine = remote.label; if Date().timeIntervalSince(snapshot.generatedAt) > 90 { s.sourceOnline = false }; return s }
                        status += snapshot.coverage.map { c in var c = c; c.profile = remote.label + " · " + c.profile; if remoteErrors[remote.id] != nil || Date().timeIntervalSince(snapshot.generatedAt) > 90 { c.available = false; c.message = "Machine unavailable · cached sessions" }; return c }
                    }
                }
                if prefs.githubEnabled && (force || Date().timeIntervalSince(lastGitHub) >= 60) {
                    var urls = Set<String>()
                    for s in all where s.pullRequest != nil {
                        let pr = s.pullRequest!
                        if urls.count >= 12 { break }
                        if urls.insert(pr.url).inserted { githubCache[pr.url] = GitHub.refresh(pr) }
                    }
                    lastGitHub = Date()
                }
                all = all.map { s in var s = s; if prefs.githubEnabled, let url = s.pullRequest?.url, let pr = githubCache[url] { s.pullRequest = pr }; return s }
                var ids = Set<String>(); all = all.filter { ids.insert($0.id).inserted }.sorted { $0.lastEvent > $1.lastEvent }
                for var s in retainedPins where !ids.contains(s.id) && prefs.pins.contains(s.id) {
                    s.sourceOnline = false; s.reason = "Pinned task outside current observation coverage"; all.append(s)
                }
                let final = all; let finalStatus = status; let finalErrors = errors
                DispatchQueue.main.async { self.updateArrival(final); self.sessions = final; self.coverage = finalStatus; self.issues = finalErrors + (self.preferenceError.map { [$0] } ?? []); self.refreshed = Date(); self.busy = false; self.loading = false }
            } catch {
                DispatchQueue.main.async { self.issues = [error.localizedDescription]; self.busy = false; self.loading = false }
            }
        }
    }
}
