import AppKit
import PandaCore

typealias ThreadOpenAction = (URL, String, @escaping (Result<Void, Error>) -> Void) -> Void

enum ThreadOpener {
    static func open(_ url: URL, bundleID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            completion(.failure(PandaError.message("The destination app is not installed or registered on this Mac.")))
            return
        }
        let config = NSWorkspace.OpenConfiguration(); config.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: config) { application, error in
            if let error { completion(.failure(error)) }
            else if application != nil { completion(.success(())) }
            else { completion(.failure(PandaError.message("The destination app did not open."))) }
        }
    }
}
