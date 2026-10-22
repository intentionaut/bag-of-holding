import AppKit
import BagCore
import SwiftUI
import UniformTypeIdentifiers

struct BagView: View {
    @ObservedObject var bag: Bag
    var home: Home?
    var opening = Opening.browse
    @FocusState private var searching: Bool
    @State private var picker = Picker<UUID>()
    @State private var shown: [UUID] = []
    @State private var query = ""
    @State private var pasting = false
    @State private var draft = ""
    @State private var problem: String?
    @State private var dropping = false
    @AppStorage(Theme.key) private var theme = Theme.palettes[0].name
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 9 * 60

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PixelText(string: "Bag of Holding", pixel: 2)
            TextField("Search the bag", text: $query)
                .textFieldStyle(.plain).font(Theme.mono(12)).foregroundStyle(Theme.text)
                .padding(6).background(Theme.panel)
                .overlay(Rectangle().strokeBorder(Theme.border.opacity(searching ? 1 : 0.5), lineWidth: 2))
                .focused($searching)

            Group {
                if bag.items.isEmpty { emptyBag }
                else if !query.isEmpty { results }
                else { cards }
            }
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 640)
            .overlay(Rectangle().strokeBorder(Theme.pink, lineWidth: dropping ? 3 : 0))
            .onDrop(of: [.fileURL], isTargeted: $dropping, perform: drop)

            if let problem { Text(problem).font(Theme.mono(11)).foregroundStyle(Theme.pink) }
            if pasting { paste }

            HStack {
                Button("Another") { reach(1) }.keyboardShortcut(.return)
                Button("I'm having a bad day") { reach(3) }
            }
            .disabled(bag.items.isEmpty)

            Rectangle().fill(Theme.border.opacity(0.4)).frame(height: 2)
            HStack {
                Menu("Add") {
                    Button("Choose files…", action: choose)
                    Button("Drop bar (drag from Finder)") { DropTile.shared.show(bag: bag) }
                    Button("Paste text") { pasting.toggle() }
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .font(Theme.mono(12, .bold)).foregroundStyle(Theme.text)
                Spacer()
                Button("Tip ☕") { NSWorkspace.shared.open(Self.tipJar) }
                    .help("Opens Ko-fi in your browser. The app itself never connects.")
                Button("Show bag") { NSWorkspace.shared.activateFileViewerSelecting([bag.folder]) }
                    .contextMenu { if let home { Button("Change folder…") { home.choose() } } }
                Button("Quit") { NSApp.terminate(nil) }
            }
            HStack {
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.palettes, id: \.name) { Text($0.name).tag($0.name) }
                }
                .fixedSize()
                Spacer()
            }
            HStack {
                Toggle("Daily reminder", isOn: $reminderOn)
                Spacer()
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden().disabled(!reminderOn)
            }
        }
        .buttonStyle(PixelButtonStyle())
        .toggleStyle(.switch).tint(Theme.pink)
        .font(Theme.mono(12)).foregroundStyle(Theme.text)
        .padding(14)
        .frame(width: 520)
        .background(Theme.night)
        .environment(\.colorScheme, Theme.scheme)
        .id(theme)   // redraw everything in the new colours
        .onAppear {
            switch opening {
            case .added(let id): shown = [id]
            case .badDay: reach(3)
            case .search: searching = true
            case .another: reach(1)
            case .browse: if shown.isEmpty { reach(1) }
            }
            reschedule()
        }
        .onChange(of: reminderOn) { reschedule() }
        .onChange(of: reminderMinutes) { reschedule() }
    }

    /// The one link in the app. macOS hands it to your browser; the app has no network access.
    static let tipJar = URL(string: "https://ko-fi.com/intentionaut")!

    // MARK: Contents

    private var emptyBag: some View {
        VStack(spacing: 8) {
            Image(nsImage: PouchIcon.image).resizable().frame(width: 48, height: 48).foregroundStyle(Theme.pink)
            Text("THE BAG IS EMPTY.").font(Theme.mono(14, .bold)).foregroundStyle(Theme.cyan)
            Text("Drop in a screenshot of kind words or a note about something you shipped. It'll keep for a rainy day.")
                .multilineTextAlignment(.center).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity)
        .dialogueBox()
    }

    private var cards: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(shown, id: \.self) { id in
                    if let item = bag.items.first(where: { $0.id == id }) {
                        CardView(bag: bag, item: item)
                    }
                }
                if bag.items.count == 1 {
                    Text("That's the only thing in the bag so far.")
                        .font(Theme.mono(10)).foregroundStyle(Theme.dim)
                }
            }
        }
    }

    private var results: some View {
        let found = bag.items.filter { $0.matches(query) }
        return List(found) { item in
            Button {
                shown = [item.id]
                query = ""
            } label: {
                VStack(alignment: .leading) {
                    Text(item.originalName).foregroundStyle(Theme.text)
                    Text(item.added, format: .dateTime.day().month().year())
                        .font(Theme.mono(10)).foregroundStyle(Theme.dim)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Theme.panel)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.panel)
        .overlay {
            if found.isEmpty {
                Text("Nothing in the bag matches “\(query)”.").foregroundStyle(Theme.dim)
            }
        }
    }

    private var paste: some View {
        VStack(alignment: .trailing) {
            TextEditor(text: $draft).frame(height: 90).scrollContentBackground(.hidden)
                .background(Theme.panel).overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 2))
            HStack {
                Button("Cancel") { pasting = false; draft = "" }
                Button("Put it in the bag") {
                    do {
                        shown = [try bag.addText(draft).id]
                        draft = ""; pasting = false; problem = nil
                    } catch { problem = error.localizedDescription }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: Actions

    private func reach(_ count: Int) {
        query = ""
        var rng = SystemRandomNumberGenerator()
        var picked: [UUID] = []
        for _ in 0..<min(count, bag.items.count) {
            if let id = picker.next(from: bag.items.map(\.id), avoiding: Set(picked), using: &rng) {
                picked.append(id)
            }
        }
        shown = picked
    }

    private func add(_ url: URL) {
        do {
            shown = [try bag.take(url).id]
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }

    private func drop(_ providers: [NSItemProvider]) -> Bool {
        bag.take(providers) { result in
            if case .failure(let error) = result { problem = error.localizedDescription }
            else { problem = nil; shown = bag.items.last.map { [$0.id] } ?? [] }
        }
        return true
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = Kind.extensions.compactMap { UTType(filenameExtension: $0) }
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK { panel.urls.forEach(add) }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60,
                                      minute: reminderMinutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                reminderMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
            })
    }

    private func reschedule() {
        Reminder.schedule(on: reminderOn, minutes: reminderMinutes, bag: bag) {
            reminderOn = false
            problem = "Notifications are off for Bag of Holding. Turn them on in System Settings › Notifications."
        }
    }
}
