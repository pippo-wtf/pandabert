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
    @Published private(set) var needsSetup = false
    @Published var showSetup = false
    private var arrivalTracker = AttentionArrivalTracker()
    let root: URL
    private var pipeline: ObservationPipeline?
    private var timer: Timer?
    private var pinnedCache: [Session] = []
    private var preferenceError: String?
    var onTopChanged: ((Bool) -> Void)?
    init(root: URL = PandaPaths.data) {
        self.root = root
        do {
            if let saved = try PreferencesFile.load(root: root) { preferences = saved }
            else { needsSetup = true; showSetup = true; loading = false; return }
        } catch {
            preferenceError = error.localizedDescription; issues = [error.localizedDescription]
            preferences.profiles = []; preferences.remotes = []; preferences.githubEnabled = false
            loading = false
            return
        }
        pinnedCache = (try? Data(contentsOf: root.appendingPathComponent("pinned-sessions.json"))).flatMap { try? JSONDecoder().decode([Session].self, from: $0) } ?? []
        startObservation()
    }
    private func startObservation() {
        loading = true
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() }
    }
    func completeSetup(profiles: [Profile], remotes: [RemoteMachine], githubEnabled: Bool) throws {
        guard preferenceError == nil else { throw PandaError.message("Existing settings could not be read. Resolve that issue before running setup.") }
        guard remotes.allSatisfy({ $0.isValid && !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw PandaError.message("Check the name and SSH address for each machine.")
        }
        var next = preferences
        var seen = Set<String>()
        next.profiles = profiles.filter { seen.insert(SetupDiscovery.identity($0)).inserted }.map { profile in
            var named = profile
            let label = profile.label.trimmingCharacters(in: .whitespacesAndNewlines)
            named.label = label.isEmpty ? "Profile" : PandaCore.clipped(label, 50)
            return named
        }
        next.remotes = remotes; next.githubEnabled = githubEnabled
        // Persist before dismissing setup or starting observation; a failed write leaves the draft open.
        try PandaPaths.save(next, to: root.appendingPathComponent("preferences.json"))
        preferences = next; needsSetup = false
        startObservation()
    }
    func save() {
        guard preferenceError == nil && !needsSetup else { return }
        do {
            try PandaPaths.save(preferences, to: root.appendingPathComponent("preferences.json"))
            pinnedCache = preferences.pins.compactMap { id in sessions.first { $0.id == id } ?? pinnedCache.first { $0.id == id } }
            try PandaPaths.save(pinnedCache, to: root.appendingPathComponent("pinned-sessions.json"))
        }
        catch { issues.append("Could not save preferences: \(error.localizedDescription)") }
        onTopChanged?(preferences.alwaysOnTop)
        refresh()
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
        guard preferenceError == nil && !needsSetup else { return }
        if pipeline == nil {
            pipeline = ObservationPipeline(root: root) { [weak self] update in
                guard let self else { return }
                self.localMachineID = update.localMachineID
                self.arrivalTracker.establishBaseline(update.baselineSessions, preferences: self.preferences)
                self.updateArrival(update.sessions)
                self.sessions = update.sessions; self.coverage = update.coverage; self.issues = update.issues
                self.refreshed = update.refreshed
                if update.refreshed != nil || !update.issues.isEmpty { self.loading = false }
            }
        }
        pipeline?.refresh(preferences: preferences, pins: pinnedCache, force: force)
    }
}
