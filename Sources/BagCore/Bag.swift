import Combine
import Foundation

public enum BagError: LocalizedError {
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .unsupported(let name):
            return "The bag takes PNG, JPG, text, markdown, transcripts and PDFs. \(name) isn't one of those."
        }
    }
}

/// The bag folder and its index. Every file the app writes is written here, and only here.
public final class Bag: ObservableObject {
    public let folder: URL
    @Published public private(set) var items: [Item] = []

    private var indexURL: URL { folder.appendingPathComponent("index.json") }

    private static func format(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f
    }
    private static let stamp = format("yyyy-MM-dd")
    private static let year = format("yyyy")
    private static let month = format("MM MMMM")   // "10 October", so months sort in order

    public init(folder: URL) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if !refresh() {
            // Unreadable index: keep a copy before the next save writes over it.
            let stamp = Self.stamp.string(from: Date())
            try? FileManager.default.copyItem(at: indexURL,
                                              to: folder.appendingPathComponent("index \(stamp) unreadable.json"))
        }
    }

    /// Re-reads the index, so changes made by the app and the `bag` command don't overwrite each other.
    /// Every change below calls this first. Returns false if there is an index it can't read.
    @discardableResult
    public func refresh() -> Bool {
        guard let data = try? Data(contentsOf: indexURL) else { return true }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let saved = try? decoder.decode([Item].self, from: data) else { return false }
        if saved != items { items = saved }
        return true
    }

    /// Where bags lived before you chose a folder: the app's own container.
    public static var inContainer: Bag {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return Bag(folder: support.appendingPathComponent("Bag", isDirectory: true))
    }

    /// Copies the file in with the date added to its name. The original is only read.
    @discardableResult
    public func add(_ source: URL, on date: Date = Date()) throws -> Item {
        let source = source.resolvingSymlinksInPath()
        guard let kind = Kind(url: source),
              (try? source.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        else { throw BagError.unsupported(source.lastPathComponent) }
        refresh()
        let copy = freeName(for: source.lastPathComponent, on: date)
        try FileManager.default.copyItem(at: source, to: copy)
        let item = Item(file: relative(copy), originalName: source.lastPathComponent,
                        added: date, kind: kind)
        items.append(item)
        save()
        return item
    }

    /// Typed or pasted words, with who said it, what it was about and tags if you have them.
    /// Only the words are needed. Names and tags that match one already in the bag (ignoring
    /// case and extra spaces) take its spelling, so they don't split into near-duplicates.
    @discardableResult
    public func addText(_ text: String, from: String? = nil, about: String? = nil, tags: [String] = [],
                        on date: Date = Date()) throws -> Item {
        refresh()
        let copy = freeName(for: "pasted.txt", on: date)
        try text.write(to: copy, atomically: true, encoding: .utf8)
        var item = Item(file: relative(copy), originalName: "Pasted text",
                        added: date, kind: .text, text: text)
        item.from = from.flatMap { Names.canonical($0, among: knownFrom) }
        item.about = Names.tidy(about)
        item.tags = tidyTags(tags)
        items.append(item)
        save()
        return item
    }

    /// Everyone who has said something, most often first, one spelling each.
    public var knownFrom: [String] { items.compactMap(\.from) }
    public var knownTags: [String] { items.flatMap(\.tags) }

    /// Tags in the spelling the bag already uses, each once.
    public func tidyTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { Names.canonical($0, among: knownTags) }.filter { seen.insert(Names.key($0)).inserted }
    }

    public func update(_ id: UUID, _ change: (inout Item) -> Void) {
        refresh()
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        save()
    }

    /// Takes an item out: deletes the bag's own copy and its index entry. Never touches anything outside the bag.
    public func remove(_ id: UUID) throws {
        refresh()
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let copy = url(for: items[i]).standardizedFileURL
        let root = folder.standardizedFileURL.path + "/"
        guard copy.path.hasPrefix(root) else { return }
        if FileManager.default.fileExists(atPath: copy.path) { try FileManager.default.removeItem(at: copy) }
        items.remove(at: i)
        save()
    }

    public func url(for item: Item) -> URL { folder.appendingPathComponent(item.file) }

    /// Copies everything from another bag into this one, filed by the date each item was added.
    /// The other bag is only read. Returns how many came across.
    @discardableResult
    public func takeAll(from other: Bag) -> Int {
        refresh()
        var taken = 0
        for var item in other.items where !items.contains(where: { $0.id == item.id }) {
            var name = (item.file as NSString).lastPathComponent
            if name.range(of: #"^\d{4}-\d{2}-\d{2} "#, options: .regularExpression) != nil { name = String(name.dropFirst(11)) }
            let copy = freeName(for: name, on: item.added)
            guard (try? FileManager.default.copyItem(at: other.url(for: item), to: copy)) != nil else { continue }
            item.file = relative(copy)
            items.append(item)
            taken += 1
        }
        if taken > 0 { save() }
        return taken
    }

    private func relative(_ url: URL) -> String {
        String(url.standardizedFileURL.path.dropFirst(folder.standardizedFileURL.path.count + 1))
    }

    /// A free name in this month's folder: "2026/10 October/2026-10-22 note.md".
    private func freeName(for name: String, on date: Date) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let stamp = Self.stamp.string(from: date)
        let shelf = folder.appendingPathComponent(Self.year.string(from: date), isDirectory: true)
            .appendingPathComponent(Self.month.string(from: date), isDirectory: true)
        try? FileManager.default.createDirectory(at: shelf, withIntermediateDirectories: true)
        var n = 1
        var url: URL
        repeat {
            let suffix = n == 1 ? "" : " \(n)"
            url = shelf.appendingPathComponent("\(stamp) \(base)\(suffix)" + (ext.isEmpty ? "" : ".\(ext)"))
            n += 1
        } while FileManager.default.fileExists(atPath: url.path)
        return url
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(items) { try? data.write(to: indexURL, options: .atomic) }
    }
}
