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
    @Published private(set) var cardPresses: [String: Int] = [:]
    @Published var latestArrival: AttentionArrival?
    @Published private(set) var needsSetup = false
    @Published var showSetup = false
    private var arrivalTracker = AttentionArrivalTracker()
    let root: URL
    private let openConversation: ThreadOpenAction
    private var pipeline: ObservationPipeline?
    private var timer: Timer?
    private var pendingUnpins: [String: DispatchWorkItem] = [:]
    private var pinnedCache: [Session] = []
    private var preferenceError: String?
    var onTopChanged: ((Bool) -> Void)?
    init(root: URL = PandaPaths.data, openConversation: @escaping ThreadOpenAction = ThreadOpener.open) {
        self.root = root
        self.openConversation = openConversation
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
            pinnedCache = preferences.keptCardIDs.compactMap { id in sessions.first { $0.id == id } ?? pinnedCache.first { $0.id == id } }
            try PandaPaths.save(pinnedCache, to: root.appendingPathComponent("pinned-sessions.json"))
        }
        catch { issues.append("Could not save preferences: \(error.localizedDescription)") }
        onTopChanged?(preferences.alwaysOnTop)
        refresh()
    }
    func pin(_ session: Session) {
        guard !preferences.isCardDeleted(session.id) else { return }
        pendingUnpins.removeValue(forKey: session.id)?.cancel()
        let wasPinned = preferences.pins.contains(session.id)
        preferences.togglePin(session.id)
        cardPresses[session.id, default: 0] += 1
        save()
        guard wasPinned, preferences.needsAttention(session),
              preferences.reviewed[session.id] != session.completionKey else { return }
        let returnToAttention = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingUnpins.removeValue(forKey: session.id)
            guard !self.preferences.pins.contains(session.id),
                  self.preferences.keptCardIDs.contains(session.id),
                  let current = self.sessions.first(where: { $0.id == session.id }),
                  self.preferences.needsAttention(current),
                  self.preferences.reviewed[current.id] != current.completionKey else { return }
            let motion: Animation? = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                ? nil : .spring(response: 0.32, dampingFraction: 0.86)
            withAnimation(motion) {
                self.preferences.releaseUnpinnedCard(session.id)
                self.save()
            }
        }
        pendingUnpins[session.id] = returnToAttention
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: returnToAttention)
    }
    func reviewed(_ session: Session) {
        guard !preferences.isCardDeleted(session.id) else { return }
        pendingUnpins.removeValue(forKey: session.id)?.cancel()
        if preferences.pins.contains(session.id) {
            preferences.reviewed[session.id] = session.completionKey
            cardPresses[session.id, default: 0] += 1
            save()
            updateArrival(sessions)
            return
        }
        withAnimation(SeenDismissal.animation(reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)) {
            preferences.reviewed[session.id] = session.completionKey
            preferences.releaseUnpinnedCard(session.id)
            save()
            updateArrival(sessions)
        }
    }
    func deleteCard(_ session: Session) throws {
        guard preferenceError == nil && !needsSetup else { throw PandaError.message("Saved settings are unavailable. The card was not deleted.") }
        var next = preferences
        next.deletedCardIDs = (next.deletedCardIDs ?? []).union([session.id])
        next.pins.removeAll { $0 == session.id }
        next.releaseUnpinnedCard(session.id)
        // Commit the exclusion first, so failed writes cannot silently lose the deletion on restart.
        try PandaPaths.save(next, to: root.appendingPathComponent("preferences.json"))
        pendingUnpins.removeValue(forKey: session.id)?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            preferences = next
            sessions.removeAll { $0.id == session.id }
            cardPresses.removeValue(forKey: session.id)
            pinnedCache.removeAll { $0.id == session.id }
            updateArrival(sessions)
        }
        // A stale cache cannot resurrect the card: the saved exclusion remains authoritative.
        do { try PandaPaths.save(pinnedCache, to: root.appendingPathComponent("pinned-sessions.json")) }
        catch { issues.append("Could not update the card cache: \(error.localizedDescription)") }
        refresh()
    }
    func restoreDeletedCards() throws {
        guard preferenceError == nil && !needsSetup else { throw PandaError.message("Saved settings are unavailable.") }
        var next = preferences; next.deletedCardIDs = nil
        try PandaPaths.save(next, to: root.appendingPathComponent("preferences.json"))
        preferences = next
        refresh(force: true)
    }

    func openThread(_ session: Session) {
        guard !preferences.isCardDeleted(session.id) else { return }
        let link = ThreadLink.revalidated(session: session, localMachineID: localMachineID)
        guard let url = link.url else { navigationError = link.explanation; return }
        navigationError = nil
        openConversation(url, link.bundleID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, !self.preferences.isCardDeleted(session.id) else { return }
                switch result {
                case .failure:
                    self.navigationError = "Could not open \(session.provider.label). Try opening the app and signing in first."
                case .success:
                    // A delayed callback must not acknowledge a newer response or erase its seen state.
                    guard session.activity == .finished,
                          let current = self.sessions.first(where: { $0.id == session.id }),
                          current.activity == .finished, current.completionKey == session.completionKey,
                          (self.preferences.reviewed[session.id] != session.completionKey || self.preferences.keptCardIDs.contains(session.id)) else { return }
                    self.reviewed(session)
                }
            }
        }
    }

    var attention: [Session] { sessions.filter { preferences.needsAttention($0) && !preferences.keptCardIDs.contains($0.id) } }
    var keptCards: [Session] { preferences.keptCardIDs.compactMap { id in sessions.first { $0.id == id } } }
    var pinned: [Session] { preferences.pins.compactMap { id in sessions.first { $0.id == id } } }
    var background: [Session] { sessions.filter { !preferences.needsAttention($0) && !preferences.keptCardIDs.contains($0.id) } }
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
                let visible = update.sessions.filter { !self.preferences.isCardDeleted($0.id) }
                self.updateArrival(visible)
                self.sessions = visible; self.coverage = update.coverage; self.issues = update.issues
                self.refreshed = update.refreshed
                if update.refreshed != nil || !update.issues.isEmpty { self.loading = false }
            }
        }
        pipeline?.refresh(preferences: preferences, pins: pinnedCache, force: force)
    }
}
