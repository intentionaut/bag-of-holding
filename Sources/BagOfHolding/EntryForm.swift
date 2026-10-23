import BagCore
import SwiftUI

/// Type or paste feedback, and say who said it, what it was about and when, in one place.
/// Only the words are required: ⌘↩ (or the button) saves them alone.
struct EntryForm: View {
    @ObservedObject var bag: Bag
    var saved: (Item) -> Void
    @State private var words = ""
    @State private var from = ""
    @State private var about = ""
    @State private var tags = ""
    @State private var day = Date()
    @State private var problem: String?
    @FocusState private var field: Field?
    private enum Field { case words, from, about, tags }

    private var empty: Bool { words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NEW ENTRY").font(Theme.mono(10, .bold)).foregroundStyle(Theme.cyan)
            TextEditor(text: $words)
                .font(Theme.mono(13))
                .frame(minHeight: 90, maxHeight: 130)
                .scrollContentBackground(.hidden)
                .background(Theme.night)
                .overlay(Rectangle().strokeBorder(Theme.border.opacity(field == .words ? 1 : 0.5), lineWidth: 2))
                .focused($field, equals: .words)
                .onKeyPress(.tab, phases: .down) { press in   // Tab moves on; it doesn't type a tab
                    guard !press.modifiers.contains(.shift) else { return .ignored }
                    field = .from
                    return .handled
                }
                .accessibilityLabel("The feedback")
            TextField("From: who said it (optional)", text: $from)
                .textFieldStyle(.roundedBorder).focused($field, equals: .from)
            if field == .from {
                Suggestions(options: Names.suggestions(from: bag.knownFrom, matching: from)) { from = $0 }
            }
            TextField("About: a project, a moment, why it mattered (optional)", text: $about)
                .textFieldStyle(.roundedBorder).focused($field, equals: .about)
            HStack(spacing: 8) {
                TextField("Tags, comma separated", text: $tags)
                    .textFieldStyle(.roundedBorder).focused($field, equals: .tags)
                DatePicker("Said on", selection: $day, in: ...Date(), displayedComponents: .date)
                    .labelsHidden().fixedSize()
                    .help("When it was said. Today unless you change it.")
            }
            if field == .tags {
                Suggestions(options: Names.suggestions(from: bag.knownTags, matching: lastTag,
                                                       excluding: typedTags)) { pick in
                    var kept = typedTags
                    kept.append(pick)
                    tags = kept.joined(separator: ", ") + ", "
                }
            }
            if let problem { Text(problem).font(Theme.mono(11)).foregroundStyle(Theme.pink) }
            HStack {
                Text("⌘↩ saves").font(Theme.mono(10)).foregroundStyle(Theme.dim)
                Spacer()
                Button("Clear", action: clear).disabled(empty && from.isEmpty && about.isEmpty && tags.isEmpty)
                Button("Put it in the bag", action: save)
                    .keyboardShortcut(.return, modifiers: .command).disabled(empty)
            }
        }
        .onAppear { field = .words }
    }

    /// The tags typed so far, and the one being typed now.
    private var typedTags: [String] {
        let parts = tags.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        return parts.dropLast().compactMap(Names.tidy)
    }
    private var lastTag: String { tags.split(separator: ",", omittingEmptySubsequences: false).last.map(String.init) ?? "" }

    private func save() {
        let all = tags.split(separator: ",").map(String.init)
        do {
            let item = try bag.addText(words.trimmingCharacters(in: .whitespacesAndNewlines),
                                       from: from, about: about, tags: all, on: Names.entryDate(day))
            clear()
            saved(item)
        } catch { problem = error.localizedDescription }
    }

    private func clear() {
        words = ""; from = ""; about = ""; tags = ""; day = Date(); problem = nil; field = .words
    }
}

/// Names or tags already in the bag, as buttons that fill the field you're typing in.
struct Suggestions: View {
    let options: [String]
    let pick: (String) -> Void

    var body: some View {
        if !options.isEmpty {
            HStack(spacing: 4) {
                ForEach(options, id: \.self) { option in
                    Button(option) { pick(option) }
                        .buttonStyle(PixelButtonStyle(small: true)).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
