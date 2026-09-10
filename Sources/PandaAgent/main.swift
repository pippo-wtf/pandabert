import Foundation
import PandaCore

do {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.contains("--help") || args.isEmpty {
        print("""
        panda-agent \(pandaVersion) — read-only local Claude/Codex session observer
        Usage: panda-agent snapshot | watch | --version
        snapshot   Emit one bounded JSON snapshot of the last 14 days.
        watch      Emit a JSON snapshot every five seconds until interrupted.
        Reads profile roots from Panda preferences, or ~/.claude and ~/.codex.
        PANDA_HOME overrides Panda's own state folder (PULSE_HOME remains supported). No provider settings are changed.
        """)
    } else if args == ["--version"] { print(pandaVersion) }
    else if args == ["snapshot"] || args == ["watch"] {
        let root = PandaPaths.data
        let prefs = (try? Data(contentsOf: root.appendingPathComponent("preferences.json"))).flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
        let collector = try Collector(root: root)
        repeat {
            let snapshot = collector.snapshot(profiles: prefs.profiles)
            let data = try JSONEncoder().encode(snapshot)
            FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data([10]))
            if args == ["snapshot"] { break }
            Thread.sleep(forTimeInterval: 5)
        } while true
    } else { throw PandaError.message("Unknown command; use --help") }
} catch {
    FileHandle.standardError.write(Data("panda-agent: \(error.localizedDescription)\n".utf8)); exit(1)
}
