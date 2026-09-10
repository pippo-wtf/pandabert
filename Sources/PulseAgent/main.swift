import Foundation
import PulseCore

do {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.contains("--help") || args.isEmpty {
        print("""
        pulse-agent \(pulseVersion) — read-only local Claude/Codex session observer
        Usage: pulse-agent snapshot | watch | --version
        snapshot   Emit one bounded JSON snapshot of the last 14 days.
        watch      Emit a JSON snapshot every five seconds until interrupted.
        Reads profile roots from Pulse preferences, or ~/.claude and ~/.codex.
        PULSE_HOME overrides Pulse's own state folder. No provider settings are changed.
        """)
    } else if args == ["--version"] { print(pulseVersion) }
    else if args == ["snapshot"] || args == ["watch"] {
        let root = PulsePaths.data
        let prefs = (try? Data(contentsOf: root.appendingPathComponent("preferences.json"))).flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        let collector = try Collector(root: root)
        repeat {
            let snapshot = collector.snapshot(profiles: prefs.profiles)
            let data = try JSONEncoder().encode(snapshot)
            FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data([10]))
            if args == ["snapshot"] { break }
            Thread.sleep(forTimeInterval: 5)
        } while true
    } else { throw PulseError.message("Unknown command; use --help") }
} catch {
    FileHandle.standardError.write(Data("pulse-agent: \(error.localizedDescription)\n".utf8)); exit(1)
}
