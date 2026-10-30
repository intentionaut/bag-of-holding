import BagCore
import Foundation

// `bag`: the Bag of Holding from the command line, and as an MCP server for agents (`bag mcp`).
// It works on the same folder as the app. No network: MCP runs over stdin and stdout.

let usage = """
usage: bag [--folder PATH] COMMAND
  random [N]                 one item at random, or N different ones
  search WORDS               items whose text, tags or praise match
  list                       everything, oldest first
  show ID                    one item, with all its text
  add FILE...                copy files in (originals are only read)
  add --text "WORDS"         add a note
  edit ID [--praise P] [--from F] [--about A] [--tags a,b]
  remove ID                  delete the bag's copy (your original is untouched)
  mcp                        serve the same over MCP on stdin/stdout
Folder: --folder, else $BAG_FOLDER, else ~/Desktop/Bag of Holding.
Add --json before the command for JSON output.
"""

struct Failure: Error, CustomStringConvertible { let description: String }

var args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    let value = args[i + 1]
    args.removeSubrange(i...i + 1)
    return value
}
func flag(_ name: String) -> Bool {
    guard let i = args.firstIndex(of: name) else { return false }
    args.remove(at: i)
    return true
}

let json = flag("--json")
let folderPath = option("--folder") ?? ProcessInfo.processInfo.environment["BAG_FOLDER"]
    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/Bag of Holding").path

// MARK: What every command and tool shares

struct Bagger {
    let bag: Bag
    var picker = Picker<UUID>()

    func describe(_ item: Item, full: Bool = false) -> [String: Any] {
        let read = item.kind == .image ? Reading.clean(item.text)
                                       : item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let praise = item.quote ?? (full ? read : String(read.prefix(400)))
        var out: [String: Any] = [
            "id": item.id.uuidString, "added": ISO8601DateFormatter().string(from: item.added),
            "kind": item.kind.rawValue, "name": item.originalName, "praise": praise,
            "tags": item.tags, "file": bag.url(for: item).path,
        ]
        if let from = item.from { out["from"] = from }
        if let about = item.about { out["about"] = about }
        if full, item.quote != nil { out["text"] = read }
        return out
    }

    func find(_ id: String) throws -> Item {
        guard let item = bag.items.first(where: { $0.id.uuidString.lowercased().hasPrefix(id.lowercased()) && id.count >= 4 })
        else { throw Failure(description: "No item with id \(id).") }
        return item
    }

    mutating func random(_ count: Int) -> [[String: Any]] {
        var rng = SystemRandomNumberGenerator()
        var picked: [UUID] = []
        for _ in 0..<min(max(count, 1), bag.items.count) {
            if let id = picker.next(from: bag.items.map(\.id), avoiding: Set(picked), using: &rng) { picked.append(id) }
        }
        return picked.compactMap { id in bag.items.first { $0.id == id }.map { describe($0) } }
    }

    func search(_ query: String) -> [[String: Any]] { bag.items.filter { $0.matches(query) }.map { describe($0) } }

    func add(path: String) throws -> [String: Any] {
        let item = try bag.add(URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
        bag.update(item.id) { $0.text = String(Indexer.text(at: bag.url(for: item), kind: item.kind).prefix(100_000)) }
        return describe(try find(item.id.uuidString), full: true)
    }

    func addText(_ text: String, from: String?, about: String?, tags: [String]?) throws -> [String: Any] {
        let item = try bag.addText(text)
        try edit(item.id.uuidString, praise: nil, from: from, about: about, tags: tags)
        return describe(try find(item.id.uuidString), full: true)
    }

    @discardableResult
    func edit(_ id: String, praise: String?, from: String?, about: String?, tags: [String]?) throws -> [String: Any] {
        let item = try find(id)
        let clean = { (s: String?) -> String? in
            guard let s else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? "" : t
        }
        bag.update(item.id) { item in
            if let p = clean(praise) { item.quote = p.isEmpty ? nil : p }
            if let f = clean(from) { item.from = f.isEmpty ? nil : f }
            if let a = clean(about) { item.about = a.isEmpty ? nil : a }
            if let tags { item.tags = tags.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        }
        return describe(try find(item.id.uuidString), full: true)
    }

    func remove(_ id: String) throws -> [String: Any] {
        let item = try find(id)
        try bag.remove(item.id)
        return ["removed": item.id.uuidString, "name": item.originalName]
    }
}

func encode(_ value: Any) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
    return String(decoding: data, as: UTF8.self)
}

func print(items: [[String: Any]]) {
    if json { return print(encode(items)) }
    if items.isEmpty { return print("Nothing in the bag matches.") }
    for item in items {
        print("“\(item["praise"] as? String ?? "")”")
        if let from = item["from"] as? String { print("  — \(from)") }
        if let about = item["about"] as? String { print("  \(about)") }
        print("  \((item["id"] as? String ?? "").prefix(8))  \(item["name"] as? String ?? "")\n")
    }
}

// MARK: MCP over stdin/stdout (JSON-RPC 2.0, one message per line)

func tools() -> [[String: Any]] {
    func tool(_ name: String, _ about: String, _ props: [String: [String: Any]] = [:], _ required: [String] = [],
              destructive: Bool = false, readOnly: Bool = false) -> [String: Any] {
        ["name": name, "description": about,
         "inputSchema": ["type": "object", "properties": props, "required": required],
         "annotations": ["readOnlyHint": readOnly, "destructiveHint": destructive]]
    }
    let s = { (d: String) in ["type": "string", "description": d] as [String: Any] }
    let edits: [String: [String: Any]] = [
        "id": s("Item id (the first 8 characters are enough)"),
        "praise": s("The praise in clean words; empty clears it"), "from": s("Who said it"),
        "about": s("What it was for"),
        "tags": ["type": "array", "items": ["type": "string"], "description": "Replaces the tags"],
    ]
    return [
        tool("reach_in", "Take something out of the Bag of Holding at random: praise and reminders of the person's good work. Never the same item twice in a row.",
             ["count": ["type": "integer", "description": "How many different items, default 1"]], readOnly: true),
        tool("search", "Find items whose praise, read text, tags, who or what match.", ["query": s("Words to look for")], ["query"], readOnly: true),
        tool("list", "Everything in the bag, oldest first.", readOnly: true),
        tool("show", "One item with all of its text.", ["id": s("Item id")], ["id"], readOnly: true),
        tool("add_file", "Copy a file into the bag. PNG, JPG, text, markdown, transcripts or PDF. The original is only read.",
             ["path": s("Absolute path to the file")], ["path"]),
        tool("add_text", "Add a note of praise to the bag.",
             ["text": s("The words"), "from": s("Who said it"), "about": s("What it was for"),
              "tags": ["type": "array", "items": ["type": "string"]]], ["text"]),
        tool("edit", "Change an item's praise, who it was from, what it was about, or tags.", edits, ["id"]),
        tool("remove", "Delete an item from the bag. This removes the bag's copy for good; the person's original file is untouched. Ask the person first.",
             ["id": s("Item id")], ["id"], destructive: true),
    ]
}

func serve(_ bagger: inout Bagger) {
    func send(_ message: [String: Any]) {
        let data = (try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        FileHandle.standardOutput.write(data + Data("\n".utf8))
    }
    while let line = readLine(strippingNewline: true) {
        guard let data = line.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = message["method"] as? String else { continue }
        guard let id = message["id"] else { continue }   // notifications need no reply
        let params = message["params"] as? [String: Any] ?? [:]
        switch method {
        case "initialize":
            send(["jsonrpc": "2.0", "id": id, "result": [
                "protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
                "capabilities": ["tools": [:] as [String: Any]],
                "serverInfo": ["name": "bag-of-holding", "version": "0.1.0"],
                "instructions": "The Bag of Holding keeps praise and reminders of this person's work. Reach in when they need encouragement. Ask before removing anything.",
            ]])
        case "ping":
            send(["jsonrpc": "2.0", "id": id, "result": [:] as [String: Any]])
        case "tools/list":
            send(["jsonrpc": "2.0", "id": id, "result": ["tools": tools()]])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let a = params["arguments"] as? [String: Any] ?? [:]
            let text = { (k: String) in a[k] as? String }
            var isError = false
            let result: Any
            do {
                switch name {
                case "reach_in": result = bagger.random(a["count"] as? Int ?? 1)
                case "search": result = bagger.search(text("query") ?? "")
                case "list": result = bagger.bag.items.map { bagger.describe($0) }
                case "show": result = bagger.describe(try bagger.find(text("id") ?? ""), full: true)
                case "add_file": result = try bagger.add(path: text("path") ?? "")
                case "add_text": result = try bagger.addText(text("text") ?? "", from: text("from"), about: text("about"), tags: a["tags"] as? [String])
                case "edit": result = try bagger.edit(text("id") ?? "", praise: text("praise"), from: text("from"), about: text("about"), tags: a["tags"] as? [String])
                case "remove": result = try bagger.remove(text("id") ?? "")
                default: throw Failure(description: "Unknown tool \(name).")
                }
            } catch {
                isError = true
                result = ["error": "\(error)"]
            }
            send(["jsonrpc": "2.0", "id": id, "result": [
                "content": [["type": "text", "text": encode(result)]], "isError": isError]])
        default:
            send(["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "Method not found: \(method)"]])
        }
    }
}

// MARK: Run

do {
    guard let command = args.first else { print(usage); exit(0) }
    args.removeFirst()
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw Failure(description: "No bag folder at \(folderPath). Choose one in the app, or pass --folder.")
    }
    var bagger = Bagger(bag: Bag(folder: URL(fileURLWithPath: folderPath, isDirectory: true)))
    switch command {
    case "random": print(items: bagger.random(Int(args.first ?? "") ?? 1))
    case "search": print(items: bagger.search(args.joined(separator: " ")))
    case "list": print(items: bagger.bag.items.map { bagger.describe($0) })
    case "show": print(encode(bagger.describe(try bagger.find(args.first ?? ""), full: true)))
    case "add":
        if let text = option("--text") {
            print(items: [try bagger.addText(text, from: option("--from"), about: option("--about"),
                                             tags: option("--tags")?.components(separatedBy: ","))])
        } else {
            guard !args.isEmpty else { throw Failure(description: "add needs a file or --text.") }
            print(items: try args.map { try bagger.add(path: $0) })
        }
    case "edit":
        guard let id = args.first else { throw Failure(description: "edit needs an id.") }
        let praise = option("--praise"), from = option("--from"), about = option("--about")
        let tags = option("--tags")?.components(separatedBy: ",")
        print(items: [try bagger.edit(id, praise: praise, from: from, about: about, tags: tags)])
    case "remove":
        let gone = try bagger.remove(args.first ?? "")
        print(json ? encode(gone) : "Removed \(gone["name"] ?? ""). Your original is untouched.")
    case "mcp": serve(&bagger)
    default: throw Failure(description: "Unknown command \(command).\n\n\(usage)")
    }
} catch {
    FileHandle.standardError.write(Data("bag: \(error)\n".utf8))
    exit(1)
}
