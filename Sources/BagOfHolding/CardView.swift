import AppKit
import BagCore
import SwiftUI

struct CardView: View {
    @ObservedObject var bag: Bag
    let item: Item
    @State private var showImage = false
    @State private var editing = false
    @State private var quote = ""
    @State private var from = ""
    @State private var about = ""
    @State private var tags = ""
    @State private var confirmingRemove = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if editing { form } else { card }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dialogueBox(lit: editing)
    }

    // MARK: Reading

    @ViewBuilder private var card: some View {
        if item.kind == .image, showImage || words.isEmpty,
           let image = NSImage(contentsOf: bag.url(for: item)) {
            Image(nsImage: image)
                .resizable().scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 480)
                .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 2))
        } else {
            Text(words.isEmpty ? placeholder : "“\(words.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”")))”")
                .font(Theme.mono(13, .medium))
                .foregroundStyle(Theme.text)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let from = item.from, !from.isEmpty {
            Text("— \(from)").font(Theme.mono(12, .bold)).foregroundStyle(Theme.cyan)
        }
        if let about = item.about, !about.isEmpty {
            Text(about).font(Theme.mono(11)).foregroundStyle(Theme.dim)
        }
        HStack {
            Text(item.tags.isEmpty ? item.originalName : item.tags.joined(separator: ", "))
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(item.added, format: .dateTime.day().month().year())
        }
        .font(Theme.mono(10)).foregroundStyle(Theme.dim)
        HStack {
            Button("Edit", action: startEditing)
            Button("Remove") { confirmingRemove = true }
            Spacer()
            if item.kind == .image, !words.isEmpty {
                Button(showImage ? "Show text" : "Show screenshot") { showImage.toggle() }
            }
        }
        .buttonStyle(PixelButtonStyle(small: true))

        .confirmationDialog("Take this out of the bag?", isPresented: $confirmingRemove) {
            Button("Remove", role: .destructive) { try? bag.remove(item.id) }
        } message: {
            Text("This deletes the bag's copy of \(item.originalName). Your original file isn't touched.")
        }
    }

    /// Your words if you've written them, otherwise the cleaned-up read.
    private var words: String {
        if let mine = item.quote, !mine.isEmpty { return mine }
        let text = item.kind == .image ? Reading.clean(item.text)
                                       : item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count > 1200 ? String(text.prefix(1200)) + "…" : text
    }

    private var placeholder: String {
        item.kind == .pdf ? "No text found in this PDF." : "Reading…"
    }

    // MARK: Editing

    private var form: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THE PRAISE").font(Theme.mono(10, .bold)).foregroundStyle(Theme.cyan)
            TextEditor(text: $quote)
                .font(Theme.mono(13))
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .background(Theme.night)
                .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 2))
            TextField("From: who said it", text: $from).textFieldStyle(.roundedBorder)
            Suggestions(options: Names.suggestions(from: bag.knownFrom, matching: from)) { from = $0 }
            TextField("About: what it was for", text: $about).textFieldStyle(.roundedBorder)
            TextField("Tags, comma separated", text: $tags).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { editing = false }
                Button("Save", action: save).keyboardShortcut(.defaultAction)
            }
            .buttonStyle(PixelButtonStyle())
        }
    }

    private func startEditing() {
        quote = words
        from = item.from ?? ""
        about = item.about ?? ""
        tags = item.tags.joined(separator: ", ")
        editing = true
    }

    private func save() {
        let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        let from = Names.canonical(from, among: bag.knownFrom)
        let tags = bag.tidyTags(tags.split(separator: ",").map(String.init))
        bag.update(item.id) {
            $0.quote = trim(quote).isEmpty ? nil : trim(quote)
            $0.from = from
            $0.about = Names.tidy(about)
            $0.tags = tags
        }
        editing = false
    }
}
