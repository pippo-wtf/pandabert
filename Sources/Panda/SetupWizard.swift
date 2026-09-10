import AppKit
import SwiftUI
import PandaCore

struct SetupWizard: View {
    @ObservedObject var store: PandaStore
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var profiles: [Profile]
    @State private var selected: Set<String>
    @State private var remotes: [RemoteMachine]
    @State private var githubEnabled: Bool
    @State private var provider = Provider.claude
    @State private var remoteLabel = ""
    @State private var remoteHost = ""
    @State private var message = ""
    private let desktopFolders: Int
    private let titles = ["Find your activity", "Your other Macs", "Review your setup"]

    init(store: PandaStore) {
        self.store = store
        let found = SetupDiscovery.profiles(existing: store.needsSetup ? [] : store.preferences.profiles)
        _profiles = State(initialValue: found)
        _selected = State(initialValue: Set((store.needsSetup ? found.filter(SetupDiscovery.isAvailable) : store.preferences.profiles).map(\.id)))
        _remotes = State(initialValue: store.preferences.remotes)
        _githubEnabled = State(initialValue: store.preferences.githubEnabled)
        desktopFolders = ClaudeDesktopIndex.roots().filter { FileManager.default.fileExists(atPath: $0.path) }.count
    }
    private var chosen: [Profile] { profiles.filter { selected.contains($0.id) } }
    private var hasRemoteDraft: Bool { !remoteLabel.isEmpty || !remoteHost.isEmpty }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PandaBert setup").font(.headline)
                    Text("Keeps you on track").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(0..<3) { index in Capsule().fill(index <= step ? lavender : Color.gray.opacity(0.15)).frame(height: 3) }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Step \(step + 1) of 3").font(.caption).foregroundStyle(.secondary)
                Text(titles[step]).font(.system(size: 24, weight: .semibold, design: .rounded))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if step == 0 { localSources }
                    else if step == 1 { otherMachines }
                    else { summary }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 3)
            }
            if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            HStack {
                if step > 0 { Button("Back") { message = ""; step -= 1 } }
                Spacer()
                Button(step == 2 ? "Save and start" : "Continue") {
                    message = ""
                    if step == 1 && hasRemoteDraft {
                        message = "Add this machine first, or clear its name and address to continue without it."
                        return
                    }
                    if step < 2 { step += 1 }
                    else {
                        do {
                            try store.completeSetup(profiles: chosen, remotes: remotes, githubEnabled: githubEnabled)
                            dismiss()
                        } catch { message = "Could not save setup: \(error.localizedDescription)" }
                    }
                }.buttonStyle(.borderedProminent).tint(lavender).foregroundStyle(.white)
            }
        }.padding(24).frame(width: 410, height: 560).foregroundStyle(ink)
    }
    private var localSources: some View {
        Group {
            Text("Choose the Claude Code and Codex activity folders to watch on this Mac. Nothing is sent to an agent.").font(.callout).foregroundStyle(.secondary)
            ForEach(profiles.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 5) {
                    Toggle(isOn: Binding(get: { selected.contains(profiles[index].id) }, set: { enabled in
                        if enabled { selected.insert(profiles[index].id) } else { selected.remove(profiles[index].id) }
                    })) {
                        HStack(spacing: 6) {
                            Circle().fill(SetupDiscovery.isAvailable(profiles[index]) ? StatusTone.complete.accent : StatusTone.quiet.accent).frame(width: 6, height: 6)
                            Text(profiles[index].provider.label).fontWeight(.medium)
                            Text(SetupDiscovery.isAvailable(profiles[index]) ? "Folder found" : "Logs not found").font(.caption).foregroundStyle(.secondary)
                        }
                    }.toggleStyle(.checkbox)
                    if selected.contains(profiles[index].id) {
                        TextField("Name, e.g. Work or Personal", text: $profiles[index].label).textFieldStyle(.roundedBorder)
                    }
                    Text(profiles[index].root).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                }.padding(12).background(neutralSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                Picker("App", selection: $provider) { ForEach(Provider.allCases, id: \.self) { Text($0.label).tag($0) } }.labelsHidden().frame(width: 110)
                Button("Choose another folder…") { chooseFolder() }
            }
            Text("Select the folder containing projects for Claude or sessions for Codex. Work and personal accounts can share logs; folder names do not verify account ownership.").font(.caption).foregroundStyle(.secondary)
            Text("\(desktopFolders) Claude desktop link folder\(desktopFolders == 1 ? "" : "s") found. Standard Claude and Parall profile folders are checked automatically. This does not verify the account currently open in Claude.").font(.caption).foregroundStyle(.secondary)
            Text("Regular Claude Chat and Cowork are not connected.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var otherMachines: some View {
        Group {
            Text("Optional. If all your activity is on this Mac, continue to the next step.").font(.callout).foregroundStyle(.secondary)
            ForEach(remotes) { remote in
                HStack {
                    VStack(alignment: .leading) { Text(remote.label); Text(remote.sshHost).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button("Remove") { remotes.removeAll { $0.id == remote.id } }
                }.padding(12).background(neutralSurface, in: RoundedRectangle(cornerRadius: 12))
            }
            Text("Connect an existing collector").font(.headline)
            Text("The other Mac needs a trusted SSH connection and PandaBert’s collector already installed. This wizard saves the connection; it does not install software or set up SSH.").font(.callout).foregroundStyle(.secondary)
            TextField("Machine name, e.g. Mac mini", text: $remoteLabel).textFieldStyle(.roundedBorder)
            TextField("SSH alias or user@host", text: $remoteHost).textFieldStyle(.roundedBorder)
            Button("Add machine") {
                let host = remoteHost.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !remotes.contains(where: { $0.sshHost == host }) else { message = "That machine is already listed."; return }
                remotes.append(RemoteMachine(label: PandaCore.clipped(remoteLabel.trimmingCharacters(in: .whitespacesAndNewlines), 50), sshHost: host))
                remoteLabel = ""; remoteHost = ""; message = ""
            }.disabled(remoteLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !RemoteMachine(label: remoteLabel, sshHost: remoteHost.trimmingCharacters(in: .whitespacesAndNewlines)).isValid)
            Text("Collector location on the other Mac: ~/.local/bin/panda-agent. Remote activity brings task titles and excerpts to this Mac. Credentials stay on their original machines.").font(.caption).foregroundStyle(.secondary)
            Text("Connection health will appear in Connections after you save. Machines listed here have not been tested by this wizard.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var summary: some View {
        Group {
            Text("\(chosen.count) local folder\(chosen.count == 1 ? "" : "s") · \(remotes.count) other Mac\(remotes.count == 1 ? "" : "s")").font(.headline)
            ForEach(chosen) { profile in
                HStack { Circle().fill(SetupDiscovery.isAvailable(profile) ? StatusTone.complete.accent : StatusTone.quiet.accent).frame(width: 6, height: 6); Text("\(profile.provider.label) · \(profile.label)"); Spacer() }.font(.callout)
            }
            if chosen.isEmpty && remotes.isEmpty { Text("No sources selected. You can add them later in Connections.").font(.callout).foregroundStyle(.secondary) }
            if chosen.contains(where: { !SetupDiscovery.isAvailable($0) }) { Text("Some selected folders have no readable logs yet. They will show as unavailable until their logs are accessible.").font(.caption).foregroundStyle(.secondary) }
            Divider()
            Toggle("Watch linked GitHub pull requests", isOn: $githubEnabled)
            Text("Optional. Uses your existing GitHub CLI login; this wizard does not sign you in. Linked pull request URLs go to GitHub, not chat text.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("What happens next").font(.headline)
            Text("Tasks are grouped by repository. Questions and new finished responses appear in Needs you; other activity stays in the background. Pin the tasks that matter most.").font(.callout).foregroundStyle(.secondary)
            Text("Open thread uses verified local links. Unlinked terminal sessions remain visible as Terminal session. PandaBert does not switch accounts for you.").font(.caption).foregroundStyle(.secondary)
            Text("You can rerun this wizard from Connections. Your pins and review history are kept.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true; panel.prompt = "Use folder"
        panel.message = "Choose the folder containing \(provider == .claude ? "projects" : "sessions")."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let profile = Profile(provider: provider, label: url.lastPathComponent, root: url.path)
        guard SetupDiscovery.isAvailable(profile) else { message = "That folder has no readable \(provider == .claude ? "projects" : "sessions") folder. Choose the profile root instead."; return }
        if let existing = profiles.first(where: { SetupDiscovery.identity($0) == SetupDiscovery.identity(profile) }) { selected.insert(existing.id) }
        else { profiles.append(profile); selected.insert(profile.id) }
        message = ""
    }
}
