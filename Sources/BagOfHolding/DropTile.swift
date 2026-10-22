import AppKit
import BagCore
import SwiftUI

extension Bag {
    /// Copies the file in, then reads its text for search from the copy, never the original.
    @discardableResult
    func take(_ url: URL) throws -> Item {
        let item = try add(url)
        let copy = self.url(for: item)
        Task.detached(priority: .utility) {
            let text = Indexer.text(at: copy, kind: item.kind)
            let kept = String(text.prefix(100_000))   // enough to search; keeps index.json small
            await MainActor.run { self.update(item.id) { $0.text = kept } }
        }
        return item
    }

    /// Takes every file in a drop. Reports how many went in, or the first problem.
    func take(_ providers: [NSItemProvider], done: @escaping (Result<Int, Error>) -> Void) {
        let group = DispatchGroup()
        var taken = 0
        var problem: Error?
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async {
                    defer { group.leave() }
                    guard let url else { return }
                    do { try self.take(url); taken += 1 } catch { problem = problem ?? error }
                }
            }
        }
        group.notify(queue: .main) { done(problem.map { .failure($0) } ?? .success(taken)) }
    }
}

/// A slim floating bar, styled like the menu bar, that takes drops while you drag from Finder.
/// It opens from the bag, and closes with ×, Esc, or on its own after a drop.
final class DropTile {
    static let shared = DropTile()
    private var panel: NSPanel?

    func show(bag: Bag) {
        if panel == nil {
            let panel = TilePanel(contentRect: NSRect(x: 0, y: 0, width: 232, height: 34),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered, defer: false)
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = true
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: DropTileView(bag: bag))
            if !panel.setFrameUsingName("DropTile") { panel.center() }
            panel.setFrameAutosaveName("DropTile")
            self.panel = panel
        }
        panel?.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }
}

/// Borderless panels can't take keyboard focus by default; the bag's search field needs it.
private final class TilePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }   // Esc
}

/// What the bag should do when the bar opens it.
enum Opening: Equatable { case browse, another, badDay, search, added(UUID) }

struct DropTileView: View {
    @ObservedObject var bag: Bag
    @State private var targeted = false
    @State private var open = false
    @State private var opening = Opening.browse
    @State private var note: String?
    @State private var hovering = false
    @State private var drops = 0      // so only the latest drop's timer closes the bar

    var body: some View {
        HStack(spacing: 4) {
            icon(nsImage: PouchIcon.image, "Open the bag (or drop files here)") { reveal(.browse) }
            if let note {
                Text(note).font(.callout).lineLimit(1).padding(.horizontal, 4)
            } else {
                icon("arrow.clockwise", "Another") { reveal(.another) }
                icon("cloud.rain", "I'm having a bad day") { reveal(.badDay) }
                icon("magnifyingglass", "Search the bag") { reveal(.search) }
            }
            Spacer(minLength: 0)
            icon("xmark", "Close (Esc)") { DropTile.shared.hide() }
        }
        .padding(.horizontal, 6)
        .frame(width: 232, height: 34)
        .background(.bar, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .stroke(targeted ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: targeted ? 2 : 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onHover { hovering = $0 }
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            bag.take(providers) { result in
                switch result {
                case .success(let n):
                    if let id = bag.items.last?.id { opening = .added(id) }
                    finish(n == 1 ? "In the bag" : "\(n) in the bag")
                case .failure: finish("Can't take that one")
                }
            }
            return true
        }
        .popover(isPresented: $open, arrowEdge: .bottom) { BagView(bag: bag, opening: opening) }
    }

    /// One menu-bar-sized, monochrome button.
    private func icon(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        icon(image: Image(systemName: symbol), help, action: action)
    }

    private func icon(nsImage: NSImage, _ help: String, action: @escaping () -> Void) -> some View {
        icon(image: Image(nsImage: nsImage).resizable(), help, action: action)
    }

    private func icon(image: Image, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            image.scaledToFit().frame(width: 16, height: 16).padding(5)
        }
        .buttonStyle(BarButtonStyle())
        .help(help)
    }

    private func reveal(_ what: Opening) {
        NSApp.activate(ignoringOtherApps: true)
        if case .browse = what, case .added = opening {} else { opening = what }
        open = false                                   // reopen so the bag acts on the new choice
        DispatchQueue.main.async { open = true }
    }

    /// Says what happened, then closes after five seconds unless you're using it.
    private func finish(_ text: String) {
        note = text
        drops += 1
        let mine = drops
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard mine == drops else { return }
            note = nil
            if !open && !hovering { DropTile.shared.hide() }
        }
    }
}

/// The menu bar's look: plain monochrome glyphs, a soft highlight when pressed or hovered.
private struct BarButtonStyle: ButtonStyle {
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(configuration.isPressed ? 0.2 : hover ? 0.1 : 0)))
            .onHover { hover = $0 }
    }
}
