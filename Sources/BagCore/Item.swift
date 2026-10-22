import Foundation

public enum Kind: String, Codable {
    case image, text, pdf

    public init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg": self = .image
        case "txt", "md", "markdown", "vtt", "srt": self = .text
        case "pdf": self = .pdf
        default: return nil
        }
    }

    public static let extensions = ["png", "jpg", "jpeg", "txt", "md", "markdown", "vtt", "srt", "pdf"]
}

public struct Item: Codable, Identifiable, Hashable {
    public let id: UUID
    public internal(set) var file: String   // path of the copy inside the bag folder, e.g. "2026/10 October/2026-10-22 note.md"
    public let originalName: String
    public let added: Date
    public let kind: Kind
    public var tags: [String]
    public var text: String          // recognised or extracted text, for search
    // Yours to write. Optional so bags saved before these existed still open.
    public var quote: String?        // the praise in clean words; the read text stays in `text`
    public var from: String?         // who said it
    public var about: String?        // what it was for

    public init(id: UUID = UUID(), file: String, originalName: String, added: Date,
                kind: Kind, tags: [String] = [], text: String = "") {
        self.id = id; self.file = file; self.originalName = originalName
        self.added = added; self.kind = kind; self.tags = tags; self.text = text
    }

    public func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return true }
        return [originalName, text, tags.joined(separator: " "), quote ?? "", from ?? "", about ?? ""]
            .contains { $0.localizedCaseInsensitiveContains(q) }
    }
}
