import Foundation

public enum SetupDiscovery {
    public static func identity(_ profile: Profile) -> String {
        profile.provider.rawValue + ":" + URL(fileURLWithPath: profile.root).standardizedFileURL.resolvingSymlinksInPath().path
    }
    public static func logFolder(_ profile: Profile) -> URL {
        URL(fileURLWithPath: profile.root).appendingPathComponent(profile.provider == .claude ? "projects" : "sessions")
    }
    public static func isAvailable(_ profile: Profile) -> Bool {
        let folder = logFolder(profile)
        return (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && FileManager.default.isReadableFile(atPath: folder.path)
    }
    /// Checks conventional profile folders only; never reads credentials or guesses account ownership.
    public static func profiles(existing: [Profile], home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [Profile] {
        var candidates = existing + Profile.defaults(home: home)
        let children = (try? FileManager.default.contentsOfDirectory(at: home, includingPropertiesForKeys: nil)) ?? []
        for folder in children.sorted(by: { $0.path < $1.path }).filter({ $0.lastPathComponent.hasPrefix(".claude-") || $0.lastPathComponent.hasPrefix(".codex-") }).prefix(64) {
            let provider: Provider = folder.lastPathComponent.hasPrefix(".claude-") ? .claude : .codex
            let profile = Profile(provider: provider, label: folder.lastPathComponent, root: folder.path)
            if isAvailable(profile) { candidates.append(profile) }
        }
        var seen = Set<String>()
        candidates = candidates.filter { seen.insert(identity($0)).inserted }
        return candidates
    }
}
