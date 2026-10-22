import AppKit
import BagCore
import SwiftUI

/// The bag in its own floating window, so it stays put while you drag files in from Finder.
/// Like Dustbunny's panel: floats above other windows, moves by its background, closes with × or Esc.
final class BagWindow {
    static let shared = BagWindow()
    private var panel: NSPanel?

    func show(bag: Bag, home: Home?) {
        if panel == nil {
            let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                                 styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: BagView(bag: bag, home: home, pinned: true)
                .padding(.top, 14))
            if !panel.setFrameUsingName("BagWindow") { panel.center() }
            panel.setFrameAutosaveName("BagWindow")
            self.panel = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }
}

private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { close() }   // Esc
}
