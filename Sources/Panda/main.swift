import AppKit
import SwiftUI
import PandaCore

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: FloatingPanel!
    var statusItem: NSStatusItem!
    var store: PandaStore!
    func applicationDidFinishLaunching(_ notification: Notification) {
        store = PandaStore()
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 364, height: 680), styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
        panel.title = "Panda"; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.isMovableByWindowBackground = true; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 364, height: 420); panel.maxSize = NSSize(width: 460, height: 1000)
        panel.level = store.preferences.alwaysOnTop ? .floating : .normal
        panel.contentView = NSHostingView(rootView: PanelView(store: store).preferredColorScheme(.light))
        panel.delegate = self
        panel.setFrameAutosaveName("PulseAttentionPanel")
        if !panel.setFrameUsingName("PulseAttentionPanel"), let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 388, y: screen.visibleFrame.maxY - 708))
        }
        store.onTopChanged = { [weak self] on in self?.panel.level = on ? .floating : .normal }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "circle.circle.fill", accessibilityDescription: "Panda")
        let menu = NSMenu(); menu.addItem(withTitle: "Show Panda", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Hide panel", action: #selector(hidePanel), keyEquivalent: "")
        menu.addItem(.separator()); menu.addItem(withTitle: "Quit Panda", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }; statusItem.menu = menu
        panel.orderFrontRegardless()
    }
    @objc func showPanel() { panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc func hidePanel() { panel.orderOut(nil) }
    @objc func quit() { NSApp.terminate(nil) }
}
let application = NSApplication.shared
let delegate = AppDelegate()
application.setActivationPolicy(.accessory)
application.delegate = delegate
application.run()
