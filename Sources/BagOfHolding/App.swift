import AppKit
import BagCore
import SwiftUI

@main
struct BagOfHoldingApp: App {
    @NSApplicationDelegateAdaptor(MenuBar.self) private var menuBar

    var body: some Scene {
        Settings { EmptyView() }
    }
}

/// The pouch in the menu bar. Clicking it opens the bag in its own window, which stays open
/// until you close it, so you can drag files onto it from Finder.
final class MenuBar: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        BagWindow.shared.home = Home()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = PouchIcon.image
        item.button?.toolTip = "Bag of Holding"
        item.button?.target = self
        item.button?.action = #selector(clicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.item = item
    }

    /// Click opens or closes the bag. Right-click (or Control-click) offers a new entry straight away.
    @objc private func clicked() {
        let event = NSApp.currentEvent
        guard event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true else {
            return BagWindow.shared.toggle()
        }
        let menu = NSMenu()
        for (title, key, action) in [("New entry", "n", #selector(newEntry)), ("Open the bag", "", #selector(open)),
                                     ("Quit", "q", #selector(quit))] {
            let entry = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
            entry.target = self
        }
        item?.menu = menu
        item?.button?.performClick(nil)
        item?.menu = nil   // so the next plain click toggles the window again
    }

    @objc private func newEntry() { BagWindow.shared.show(.newEntry) }
    @objc private func open() { BagWindow.shared.show() }
    @objc private func quit() { NSApp.terminate(nil) }
}

/// What the window shows: the bag, or the first-run folder choice.
struct RootView: View {
    @ObservedObject var home: Home
    var opening = Opening.browse

    var body: some View {
        if let bag = home.bag {
            BagView(bag: bag, home: home, opening: opening)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) { PixelText(string: "Bag of Holding", pixel: 2); Pouch() }
                Text("Where should the bag live?").font(Theme.mono(13, .bold)).foregroundStyle(Theme.cyan)
                Text("Pick a folder, or make one on your Desktop called Bag of Holding. Everything you add is copied there, filed by year and month.")
                    .foregroundStyle(Theme.dim).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Choose folder…") { home.choose() }.keyboardShortcut(.defaultAction)
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                }
                .buttonStyle(PixelButtonStyle())
            }
            .font(Theme.mono(12)).foregroundStyle(Theme.text)
            .padding(14).padding(.top, 14).frame(width: 520)
            .background(StarField())
        }
    }
}
