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

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public init(folder: URL) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: indexURL) else { return }
        if let saved = try? decoder.decode([Item].self, from: data) {
            items = saved
        } else {
            // Unreadable index: keep a copy before the next save writes over it.
            let stamp = Self.stamp.string(from: Date())
            try? FileManager.default.copyItem(at: indexURL,
                                              to: folder.appendingPathComponent("index \(stamp) unreadable.json"))
        }
    }

    /// Inside the sandbox this resolves to the app's own container.
    public static var standard: Bag {
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
        let copy = freeName(for: source.lastPathComponent, on: date)
        try FileManager.default.copyItem(at: source, to: copy)
        let item = Item(file: copy.lastPathComponent, originalName: source.lastPathComponent,
                        added: date, kind: kind)
        items.append(item)
        save()
        return item
    }

    @discardableResult
    public func addText(_ text: String, on date: Date = Date()) throws -> Item {
        let copy = freeName(for: "pasted.txt", on: date)
        try text.write(to: copy, atomically: true, encoding: .utf8)
        let item = Item(file: copy.lastPathComponent, originalName: "Pasted text",
                        added: date, kind: .text, text: text)
        items.append(item)
        save()
        return item
    }

    public func update(_ id: UUID, _ change: (inout Item) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        save()
    }

    /// Takes an item out: deletes the bag's own copy and its index entry. Never touches anything outside the bag.
    public func remove(_ id: UUID) throws {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let copy = url(for: items[i]).standardizedFileURL
        guard copy.deletingLastPathComponent() == folder.standardizedFileURL else { return }
        if FileManager.default.fileExists(atPath: copy.path) { try FileManager.default.removeItem(at: copy) }
        items.remove(at: i)
        save()
    }

    public func url(for item: Item) -> URL { folder.appendingPathComponent(item.file) }

    private func freeName(for name: String, on date: Date) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let stamp = Self.stamp.string(from: date)
        var n = 1
        var url: URL
        repeat {
            let suffix = n == 1 ? "" : " \(n)"
            url = folder.appendingPathComponent("\(stamp) \(base)\(suffix)" + (ext.isEmpty ? "" : ".\(ext)"))
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
