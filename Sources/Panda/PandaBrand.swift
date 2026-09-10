import AppKit
import SwiftUI

/// One transparent master mark supplies all small, adaptive brand icons.
enum PandaBrand {
    static let mark: NSImage = {
        // Packaged macOS apps keep resources under Contents/Resources, while SwiftPM
        // looks beside the executable or in its original build directory.
        let packaged = Bundle.main.resourceURL?.appendingPathComponent("Panda_Panda.bundle")
        let resources = packaged.flatMap { Bundle(url: $0) } ?? Bundle.module
        let image = NSImage(contentsOf: resources.url(forResource: "PandaMark", withExtension: "png")!)!
        image.isTemplate = true
        image.accessibilityDescription = "PandaBert"
        return image
    }()
    static var menuBarImage: NSImage {
        let image = mark.copy() as! NSImage
        image.size = NSSize(width: 22, height: 22)
        return image
    }
}

struct PandaMark: View {
    var body: some View {
        Image(nsImage: PandaBrand.mark).resizable().renderingMode(.template)
            .interpolation(.high).scaledToFit().frame(width: 23, height: 23)
            .accessibilityHidden(true)
    }
}
