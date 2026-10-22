import AppKit
import BagCore
import SwiftUI

/// The bag in its own floating window, so it stays put while you drag files in from Finder.
/// Like Dustbunny's panel: floats above other windows, moves by its background, closes with × or Esc.
final class BagWindow {
    static let shared = BagWindow()
    var home: Home!
    private var panel: NSPanel?

    /// The menu bar click: open the bag, or put it away if it's already in front.
    func toggle() {
        if let panel, panel.isVisible, panel.isKeyWindow { panel.close() } else { show() }
    }

    func show(_ opening: Opening = .browse) {
        if panel == nil {
            let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                                 styleMask: [.titled, .closable, .fullSizeContentView],
                                 backing: .buffered, defer: false)
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.setFrameAutosaveName("BagWindow")
            if !panel.setFrameUsingName("BagWindow") { panel.center() }
            self.panel = panel
        }
        // A fresh view each time, so the bag reaches in again and acts on `opening`.
        panel?.contentView = NSHostingView(rootView: RootView(home: home, opening: opening))
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }
}

private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }   // Esc
}
