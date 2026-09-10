import AppKit
import SwiftUI
import PandaCore
import ServiceManagement

let ink = Color(red: 0.098, green: 0.094, blue: 0.125)
let lavender = Color(red: 0.608, green: 0.529, blue: 0.961)
let neutralSurface = Color(white: 0.97)

struct PanelView: View {
    @ObservedObject var store: PandaStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false
    @State private var selected: Session?
    @State private var settings = false
    @State private var project = ""
    @State private var showAll = false
    private var visibleAttention: [Session] { store.attention.filter { project.isEmpty || $0.projectKey == project } }
    private var visibleCards: [Session] { store.keptCards + Array(visibleAttention.prefix(showAll ? 250 : 8)) }
    private var working: Int { store.sessions.filter { $0.displayActivity() == .working }.count }
    private var needsCount: Int { store.sessions.filter { store.preferences.needsAttention($0) }.count }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                PandaMark()
                VStack(alignment: .leading, spacing: 1) {
                    Text("PandaBert").font(.system(size: 14, weight: .semibold))
                    Text("Keeps you on track").font(.system(size: 8)).foregroundStyle(.white.opacity(0.72))
                }.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 2)
                Menu {
                    Button("All projects") { project = "" }
                    ForEach(Array(Set(store.sessions.map(\.projectKey))).sorted(), id: \.self) { key in
                        if let s = store.sessions.first(where: { $0.projectKey == key }) { Button(store.preferences.projectName(s)) { project = key } }
                    }
                } label: {
                    Text(project.isEmpty ? "All projects" : store.sessions.first(where: { $0.projectKey == project }).map { store.preferences.projectName($0) } ?? "Project").lineLimit(1).font(.system(size: 10)).padding(.trailing, 12)
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).environment(\.colorScheme, .dark).fixedSize().frame(maxWidth: 105)
                    .overlay(alignment: .trailing) { Image(systemName: "chevron.down").font(.system(size: 8)).allowsHitTesting(false) }
                Text("\(needsCount) need you").font(.system(size: 10, weight: .semibold)).lineLimit(1).fixedSize(horizontal: true, vertical: false).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 7).background(lavender, in: Capsule())
            }.foregroundStyle(.white).padding(.horizontal, 13).frame(height: 43).background(ink, in: Capsule()).padding(16)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.needsSetup ? "Welcome to PandaBert." : store.loading ? "Finding your activity…" : needsCount == 0 ? "Room to focus." : "\(needsCount == 1 ? "One thing needs" : "\(needsCount) things need") you.")
                        .font(.system(size: 25, weight: .semibold, design: .rounded)).tracking(-0.7)
                    Text(store.needsSetup ? "Choose the activity folders and machines to watch." : store.loading ? "Reading local session activity." : "\(working) \(working == 1 ? "chat is" : "chats are") working across \(Set(store.sessions.map(\.projectKey)).count) projects.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 21).padding(.top, 5).padding(.bottom, 19)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if store.needsSetup {
                        Button("Set up PandaBert") { store.showSetup = true }.buttonStyle(.borderedProminent).tint(lavender)
                    }
                    // One stable identity across pin/unpin changes prevents a removal transition.
                    ForEach(visibleCards) { s in
                        VStack(spacing: 10) {
                            if s.id == store.keptCards.first?.id {
                                sectionLabel(store.keptCards.count == store.pinned.count ? "PINNED" : "KEPT IN SIGHT", count: store.keptCards.count)
                            }
                            if s.id == visibleAttention.first?.id {
                                sectionLabel("NEEDS YOU", count: visibleAttention.count)
                            }
                            card(s, pinned: store.preferences.pins.contains(s.id))
                                .modifier(CardPress(progress: Double(store.cardPresses[s.id, default: 0]), reduceMotion: reduceMotion))
                                .animation(.easeInOut(duration: 0.22), value: store.cardPresses[s.id, default: 0])
                        }.zIndex(1).transition(store.preferences.pins.contains(s.id) ? .opacity : SeenDismissal.transition(reduceMotion: reduceMotion))
                    }
                    if visibleAttention.count > 8 && !showAll { Button("Show \(visibleAttention.count - 8) more") { showAll = true }.buttonStyle(.plain).foregroundStyle(lavender).padding(8) }
                    if visibleAttention.isEmpty && !store.loading {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "sparkle").foregroundStyle(lavender).font(.system(size: 22))
                            Text(store.sessions.isEmpty ? "Your activity will appear here." : "Nothing needs your attention here.").font(.system(size: 13, weight: .medium))
                            Text(store.sessions.isEmpty ? "Add your profile folders in Connections. PandaBert observes Claude Code and Codex logs on this Mac." : "Keep this panel nearby. Pin any task you want to keep in sight.").font(.system(size: 11)).foregroundStyle(.secondary)
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(neutralSurface, in: RoundedRectangle(cornerRadius: 17))
                            .transition(SeenDismissal.emptyStateTransition(reduceMotion: reduceMotion))
                    }
                    Button { expanded.toggle() } label: {
                        HStack { Circle().fill(working > 0 ? lavender : StatusTone.quiet.accent).frame(width: 6, height: 6); Text("In the background").fontWeight(.medium); Spacer(); Text("\(store.background.count)").foregroundStyle(.secondary); Image(systemName: expanded ? "chevron.up" : "chevron.down") }.font(.system(size: 11)).padding(.vertical, 13)
                    }.buttonStyle(.plain)
                    if expanded {
                        ForEach(Array(store.background.filter { project.isEmpty || $0.projectKey == project }.prefix(100))) { s in card(s) }
                        if store.background.count > 100 { Text("Showing the 100 most recent background chats.").font(.caption).foregroundStyle(.secondary) }
                    }
                    if !store.issues.isEmpty { Text(store.issues.joined(separator: "\n")).font(.system(size: 10)).foregroundStyle(.secondary).padding(.bottom, 8) }
                }.padding(.horizontal, 16).padding(.bottom, 12)
            }
            HStack(spacing: 5) {
                Circle().fill(store.loading ? StatusTone.quiet.accent : store.issues.isEmpty ? StatusTone.complete.accent : StatusTone.attention.accent).frame(width: 5, height: 5)
                Text(store.loading ? "Connecting" : "Local observer · \(store.coverage.filter(\.available).count) sources").font(.system(size: 9))
                Spacer()
                Button { store.refresh(force: true) } label: { Image(systemName: "arrow.clockwise") }.help("Refresh activity")
                Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }.help("Connections and preferences")
            }.buttonStyle(.plain).foregroundStyle(.secondary).padding(.horizontal, 21).padding(.vertical, 13)
        }.foregroundStyle(ink).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 23))
            .frame(minWidth: 364, idealWidth: 364, maxWidth: 460, minHeight: 420)
            .sheet(item: $selected) { s in DetailView(store: store, original: s) }
            .sheet(isPresented: $settings) { SettingsView(store: store) }
            .sheet(isPresented: $store.showSetup) { SetupWizard(store: store) }
            .alert("Could not open thread", isPresented: Binding(get: { store.navigationError != nil }, set: { if !$0 { store.navigationError = nil } })) {
                Button("OK") { store.navigationError = nil }
            } message: { Text(store.navigationError ?? "") }
    }
    func sectionLabel(_ title: String, count: Int) -> some View {
        HStack { Text(title).tracking(1.4); Spacer(); Text(String(count)) }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 5).padding(.top, 5)
    }
    func card(_ s: Session, pinned: Bool = false) -> some View {
        let attention = store.preferences.needsAttention(s)
        let appearance = StatusAppearance(s, preferences: store.preferences)
        let tone = appearance.tone
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(store.preferences.projectName(s)).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                Spacer()
                Text(s.provider.label).font(.system(size: 9)).foregroundStyle(.secondary)
                Button { store.pin(s) } label: { Image(systemName: pinned ? "pin.fill" : "pin").font(.system(size: 11)).foregroundStyle(pinned ? lavender : ink.opacity(0.45)).frame(width: 22, height: 22) }.buttonStyle(.plain).help(pinned ? "Unpin task" : "Pin important task").accessibilityLabel(pinned ? "Unpin \(s.title)" : "Pin \(s.title)")
            }
            Button { selected = s } label: {
                VStack(alignment: .leading, spacing: 7) {
                    Text(s.title).font(.system(size: 14, weight: .medium)).tracking(-0.2).lineLimit(2).multilineTextAlignment(.leading)
                    HStack(spacing: 5) { Circle().fill(tone.accent).frame(width: 5, height: 5); Text(appearance.label).lineLimit(2) }.font(.system(size: 10)).foregroundStyle(.secondary)
                    Text("\(s.machine) · \(s.profileLabel)").font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Group {
                HStack {
                    OpenThreadButton(store: store, session: s)
                    Button("Details") { selected = s }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.secondary)
                    Spacer()
                    if s.activity == .finished && ((attention && store.preferences.reviewed[s.id] != s.completionKey) || (!pinned && store.preferences.keptCardIDs.contains(s.id))) { MarkSeenButton { store.reviewed(s) } }
                }.padding(.top, 2)
            }
        }.foregroundStyle(ink).padding(14).background(neutralSurface, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(pinned ? lavender.opacity(0.35) : .clear, lineWidth: 1))
            .overlay {
                if let arrival = store.latestArrival, arrival.sessionID == s.id {
                    AttentionGlow(arrival: arrival)
                }
            }
    }
}

struct MarkSeenButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Mark as seen", systemImage: "checkmark")
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 8)
                .foregroundStyle(ink)
                .contentShape(Capsule())
                .overlay(Capsule().stroke(ink.opacity(0.18), lineWidth: 1))
                .fixedSize(horizontal: true, vertical: false)
        }.buttonStyle(.plain)
            .help("I've seen this response. Clear its finished-turn notification in PandaBert.")
    }
}

struct OpenThreadButton: View {
    @ObservedObject var store: PandaStore
    let session: Session
    var body: some View {
        let link = ThreadLink(session: session, localMachineID: store.localMachineID)
        if link.url == nil && link.isTerminalSession {
            Label("Terminal session", systemImage: "terminal")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                .help(link.explanation)
        } else {
            Button { store.openThread(session) } label: {
                Label("Open thread", systemImage: "arrow.up.right").font(.system(size: 10, weight: .semibold)).padding(.horizontal, 12).padding(.vertical, 8).foregroundStyle(link.url != nil ? .white : ink).background(link.url == nil ? Color.gray.opacity(0.15) : lavender, in: Capsule())
            }.buttonStyle(.plain).disabled(link.url == nil).help(link.explanation + (session.activity == .finished && link.url != nil ? " Opening also marks this response as seen in PandaBert." : "")).accessibilityLabel("Open \(session.title) in \(session.provider.label)")
        }
    }
}

struct DetailView: View {
    @ObservedObject var store: PandaStore
    let original: Session
    @Environment(\.dismiss) var dismiss
    @State private var waiting = ""
    @State private var alias = ""
    @State private var prURL = ""
    @State private var deletionError: String?
    var s: Session { store.sessions.first { $0.id == original.id } ?? original }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Text(store.preferences.projectName(s)).font(.headline); Spacer(); Button("Done") { dismiss() } }
            Text(s.title).font(.title3.weight(.semibold)).textSelection(.enabled)
            let appearance = StatusAppearance(s, preferences: store.preferences)
            HStack(spacing: 6) { Circle().fill(appearance.tone.accent).frame(width: 6, height: 6); Text(appearance.label).font(.caption).foregroundStyle(.secondary) }
            OpenThreadButton(store: store, session: s)
            if ThreadLink(session: s, localMachineID: store.localMachineID).url == nil { Text(ThreadLink(session: s, localMachineID: store.localMachineID).explanation).font(.caption).foregroundStyle(.secondary) }
            Text("\(s.provider.label) · \(s.machine) · \(s.profileLabel)\n\(s.reason)").font(.caption).foregroundStyle(.secondary)
            Text("Last activity: \(s.lastActivityEvent.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
            ScrollView { Text(s.excerpt.isEmpty ? "No message excerpt available. Open the original session for full context." : s.excerpt).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12) }.frame(minHeight: 130, maxHeight: 210).background(neutralSurface, in: RoundedRectangle(cornerRadius: 12))
            if let pr = s.pullRequest { Button(pr.label + " ↗") { if let url = URL(string: pr.url), url.scheme == "https", url.host == "github.com" { NSWorkspace.shared.open(url) } }.buttonStyle(.link) }
            TextField("Waiting for… (person or dependency)", text: $waiting)
            TextField("Project display name", text: $alias)
            HStack {
                Button("Save") {
                    store.preferences.waits[s.id] = waiting.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : PandaCore.clipped(waiting)
                    store.preferences.projectAliases[s.projectKey] = alias.isEmpty ? nil : PandaCore.clipped(alias, 60); store.save()
                }
                Button(store.preferences.pins.contains(s.id) ? "Unpin" : "Pin task") { store.pin(s) }
                if s.activity == .finished && (store.preferences.reviewed[s.id] != s.completionKey || (!store.preferences.pins.contains(s.id) && store.preferences.keptCardIDs.contains(s.id))) { MarkSeenButton { store.reviewed(s) } }
            }
            Divider()
            HStack {
                Button("Copy session ID") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s.nativeID, forType: .string) }
                if s.machineID == store.localMachineID {
                    Button("Reveal transcript") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: s.sourcePath)]) }
                }
            }
            HStack {
                Button(role: .destructive) {
                    do { try store.deleteCard(s); dismiss() }
                    catch { deletionError = "Could not save the deletion. " + error.localizedDescription }
                } label: { Label("Delete card", systemImage: "trash") }
                    .buttonStyle(.plain).foregroundStyle(.red)
                    .help("Remove from PandaBert only. The original conversation stays in Claude or Codex.")
                Spacer()
            }
            Text("Removes this card from PandaBert only. Restore deleted cards in Connections.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Text("Reply in the original Claude or Codex session. A finished turn is not a completed project; PandaBert does not invent a progress percentage.").font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(22).frame(width: 390).onAppear { waiting = store.preferences.waits[s.id] ?? ""; alias = store.preferences.projectName(s) }
            .alert("Could not delete card", isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) {
                Button("OK") { deletionError = nil }
            } message: { Text(deletionError ?? "") }
            .onChange(of: store.preferences.reviewed[s.id]) { seen in
                if s.activity == .finished && seen == s.completionKey { dismiss() }
            }
    }
}

struct SettingsView: View {
    @ObservedObject var store: PandaStore
    @Environment(\.dismiss) var dismiss
    @State private var provider = Provider.codex
    @State private var profileLabel = ""
    @State private var profileRoot = ""
    @State private var remoteLabel = ""
    @State private var remoteHost = ""
    @State private var startsAtLogin = SMAppService.mainApp.status == .enabled
    @State private var settingsMessage = ""
    @State private var setup = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Connections").font(.title2.weight(.semibold)); Spacer(); Button("Done") { store.save(); store.refresh(force: true); dismiss() } }
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 6) {
                        ForEach(StatusTone.allCases, id: \.self) { tone in
                            HStack(spacing: 5) { Circle().fill(tone.accent).frame(width: 6, height: 6); Text(tone.label).font(.system(size: 10)).foregroundStyle(.secondary) }.padding(.trailing, 6)
                        }
                    }
                    Button("Run setup wizard") { setup = true }
                    if let deleted = store.preferences.deletedCardIDs, !deleted.isEmpty {
                        Button("Restore deleted cards (\(deleted.count))") {
                            do { try store.restoreDeletedCards(); settingsMessage = "Deleted cards will return if their activity is still available." }
                            catch { settingsMessage = "Could not restore cards: " + error.localizedDescription }
                        }
                    }
                    Toggle("Keep the panel above other windows", isOn: $store.preferences.alwaysOnTop).onChange(of: store.preferences.alwaysOnTop) { _ in store.save() }
                    Toggle("Open PandaBert when I log in", isOn: Binding(get: { startsAtLogin }, set: { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            startsAtLogin = SMAppService.mainApp.status == .enabled
                            settingsMessage = SMAppService.mainApp.status == .requiresApproval ? "Allow PandaBert in System Settings → Login Items." : ""
                        } catch { settingsMessage = "Login setup unavailable. Move PandaBert to Applications and try again." }
                    }))
                    Toggle("Show finished turns for review", isOn: $store.preferences.showFinished).onChange(of: store.preferences.showFinished) { _ in store.save() }
                    Toggle("Check linked pull requests using GitHub CLI", isOn: $store.preferences.githubEnabled).onChange(of: store.preferences.githubEnabled) { _ in store.save(); store.refresh(force: true) }
                    Text("Uses your existing gh login. GitHub receives only linked pull request URLs. No chat text leaves this Mac.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("Profiles on this Mac").font(.headline)
                    ForEach(store.preferences.profiles) { profile in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) { Text("\(profile.provider.label) · \(profile.label)"); Text(profile.root).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled) }
                            Spacer(); Button { store.preferences.profiles.removeAll { $0.id == profile.id }; store.save() } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).help("Remove observed profile")
                        }
                    }
                    Picker("Provider", selection: $provider) { ForEach(Provider.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                    TextField("Profile label, e.g. Personal", text: $profileLabel)
                    TextField("Profile root, e.g. ~/.codex-work", text: $profileRoot)
                    Button("Add profile folder") {
                        let p = Profile(provider: provider, label: PandaCore.clipped(profileLabel, 50), root: profileRoot)
                        if !store.preferences.profiles.contains(where: { $0.id == p.id }) { store.preferences.profiles.append(p) }
                        store.save(); profileLabel = ""; profileRoot = ""; store.refresh(force: true)
                    }.disabled(profileLabel.isEmpty || !(profileRoot.hasPrefix("/") || profileRoot.hasPrefix("~/")))
                    Text("Choose the folder containing sessions (Codex) or projects (Claude). Profiles are labelled by you; PandaBert never guesses which account owns a folder.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("Other machines").font(.headline)
                    ForEach(store.preferences.remotes) { remote in
                        HStack { Text(remote.label + " · " + remote.sshHost); Spacer(); Button("Remove") { store.preferences.remotes.removeAll { $0.id == remote.id }; store.save() } }
                    }
                    TextField("Machine label", text: $remoteLabel)
                    TextField("Existing SSH alias or user@host", text: $remoteHost)
                    Button("Connect machine") {
                        store.preferences.remotes.append(RemoteMachine(label: PandaCore.clipped(remoteLabel, 50), sshHost: remoteHost)); store.save(); remoteHost = ""; remoteLabel = ""; store.refresh(force: true)
                    }.disabled(remoteLabel.isEmpty || !RemoteMachine(label: remoteLabel, sshHost: remoteHost).isValid)
                    Text("Requires an already trusted SSH connection and panda-agent at ~/.local/bin/panda-agent on that Mac. Credentials stay on their original machines. Connections bring task excerpts to this Mac.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("Observed coverage").font(.headline)
                    Button("Export diagnostics (no task text)") {
                        let panel = NSSavePanel(); panel.nameFieldStringValue = "pandabert-diagnostics.json"
                        guard panel.runModal() == .OK, let url = panel.url else { return }
                        let counts = Dictionary(grouping: store.sessions, by: { $0.displayActivity().rawValue }).mapValues(\.count)
                        let report: [String: Any] = ["version": pandaVersion, "generatedAt": ISO8601DateFormatter().string(from: Date()), "sessionCount": store.sessions.count, "projectCount": Set(store.sessions.map(\.projectKey)).count, "stateCounts": counts, "profileCount": store.preferences.profiles.count, "remoteCount": store.preferences.remotes.count, "availableSources": store.coverage.filter(\.available).count, "issueCount": store.issues.count]
                        do { try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic); settingsMessage = "Diagnostics saved." }
                        catch { settingsMessage = "Diagnostics could not be saved." }
                    }
                    if !settingsMessage.isEmpty { Text(settingsMessage).font(.caption).foregroundStyle(.secondary) }
                    ForEach(Array(store.coverage.enumerated()), id: \.offset) { _, c in
                        Text("\(c.provider.label) · \(c.profile): \(c.fileCount) sessions\n\(c.message)").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Version \(pandaVersion) · Preview\nPassive Claude Code / Codex logs only. Claude ordinary Chat and Cowork are not connected. Some approvals and queued states are absent from these logs; quiet working sessions become uncertain after three minutes. Large logs are read in bounded chunks. Refresh: 5 seconds locally, 30 seconds remotely.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.padding(22).frame(width: 430, height: 610)
            .sheet(isPresented: $setup) { SetupWizard(store: store) }
    }
}
