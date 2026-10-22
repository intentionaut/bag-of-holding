import XCTest
@testable import BagCore

/// Repeatable randomness, so a failure can be replayed.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class PickerTests: XCTestCase {
    func testEmptyBagGivesNothing() {
        var picker = Picker<Int>()
        var rng = SeededRNG(state: 1)
        XCTAssertNil(picker.next(from: [], using: &rng))
    }

    func testOneItemComesBackEveryTime() {
        var picker = Picker<Int>()
        var rng = SeededRNG(state: 2)
        for _ in 0..<10 { XCTAssertEqual(picker.next(from: [7], using: &rng), 7) }
    }

    func testNeverTheSameTwiceInARow() {
        for ids in [[1, 2], [1, 2, 3], Array(0..<20)] {
            var picker = Picker<Int>()
            var rng = SeededRNG(state: 3)
            var previous = picker.next(from: ids, using: &rng)
            for _ in 0..<1000 {
                let pick = picker.next(from: ids, using: &rng)
                XCTAssertNotEqual(pick, previous)
                previous = pick
            }
        }
    }

    func testEveryItemCanComeUp() {
        var picker = Picker<Int>()
        var rng = SeededRNG(state: 4)
        let seen = Set((0..<500).compactMap { _ in picker.next(from: Array(0..<5), using: &rng) })
        XCTAssertEqual(seen, Set(0..<5))
    }

    func testBadDayRunHasNoRepeatsWhenItCan() {
        var picker = Picker<Int>()
        var rng = SeededRNG(state: 5)
        for _ in 0..<100 {
            var run: [Int] = []
            for _ in 0..<3 {
                run.append(picker.next(from: [1, 2, 3, 4], avoiding: Set(run), using: &rng)!)
            }
            XCTAssertEqual(Set(run).count, 3)
        }
    }
}

final class BagTests: XCTestCase {
    var dir: URL!
    let day = DateComponents(calendar: .current, year: 2026, month: 10, day: 21).date!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testOriginalIsCopiedAndLeftAlone() throws {
        let original = dir.appendingPathComponent("note.md")
        try Data("Shipped the thing.".utf8).write(to: original)
        let before = try FileManager.default.attributesOfItem(atPath: original.path)

        let bag = Bag(folder: dir.appendingPathComponent("Bag"))
        let item = try bag.add(original, on: day)

        XCTAssertEqual(item.file, "2026/10 October/2026-10-21 note.md")
        XCTAssertEqual(try Data(contentsOf: original), Data("Shipped the thing.".utf8))
        let after = try FileManager.default.attributesOfItem(atPath: original.path)
        XCTAssertEqual(before[.modificationDate] as? Date, after[.modificationDate] as? Date)
        XCTAssertTrue(FileManager.default.fileExists(atPath: bag.url(for: item).path))
    }

    func testSameNameSameDayGetsANumber() throws {
        let original = dir.appendingPathComponent("note.md")
        try Data("x".utf8).write(to: original)
        let bag = Bag(folder: dir.appendingPathComponent("Bag"))
        try bag.add(original, on: day)
        XCTAssertEqual(try bag.add(original, on: day).file, "2026/10 October/2026-10-21 note 2.md")
    }

    func testIndexSurvivesReopening() throws {
        let folder = dir.appendingPathComponent("Bag")
        let id = try Bag(folder: folder).addText("Kind words", on: day).id
        Bag(folder: folder).update(id) { $0.tags = ["praise"] }
        let reopened = Bag(folder: folder)
        XCTAssertEqual(reopened.items.map(\.tags), [["praise"]])
        XCTAssertTrue(reopened.items[0].matches("praise"))
    }

    func testOlderIndexWithoutPraiseFieldsStillOpens() throws {
        let folder = dir.appendingPathComponent("Bag")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let old = #"[{"id":"\#(UUID().uuidString)","file":"a.txt","originalName":"a.txt","added":"2026-10-21T09:00:00Z","kind":"text","tags":[],"text":"Nice work"}]"#
        try Data(old.utf8).write(to: folder.appendingPathComponent("index.json"))
        let bag = Bag(folder: folder)
        XCTAssertEqual(bag.items.count, 1)
        bag.update(bag.items[0].id) { $0.from = "Alex"; $0.about = "Checkout launch" }
        XCTAssertTrue(Bag(folder: folder).items[0].matches("checkout"))
    }

    func testRemoveDeletesOnlyTheBagCopy() throws {
        let original = dir.appendingPathComponent("shot.png")
        try Data("x".utf8).write(to: original)
        let folder = dir.appendingPathComponent("Bag")
        let bag = Bag(folder: folder)
        let item = try bag.add(original, on: day)
        try bag.remove(item.id)
        XCTAssertTrue(bag.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: bag.url(for: item).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: original.path))
        XCTAssertTrue(Bag(folder: folder).items.isEmpty)
    }

    func testUnreadableIndexIsKeptBeforeOverwrite() throws {
        let folder = dir.appendingPathComponent("Bag")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: folder.appendingPathComponent("index.json"))
        try Bag(folder: folder).addText("new", on: day)
        let kept = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix("unreadable.json") }
        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(kept[0])), Data("not json".utf8))
    }

    func testFolderNamedLikeAnImageIsRefused() throws {
        let fake = dir.appendingPathComponent("folder.png")
        try FileManager.default.createDirectory(at: fake, withIntermediateDirectories: true)
        XCTAssertThrowsError(try Bag(folder: dir.appendingPathComponent("Bag")).add(fake))
    }

    func testOldBagMovesAcrossFiledByMonth() throws {
        let original = dir.appendingPathComponent("note.md")
        try Data("kind".utf8).write(to: original)
        let old = Bag(folder: dir.appendingPathComponent("Old"))
        let item = try old.add(original, on: day)
        let new = Bag(folder: dir.appendingPathComponent("New"))
        XCTAssertEqual(new.takeAll(from: old), 1)
        XCTAssertEqual(new.takeAll(from: old), 0)   // never twice
        XCTAssertEqual(new.items.first?.file, "2026/10 October/2026-10-21 note.md")
        XCTAssertEqual(try Data(contentsOf: new.url(for: new.items[0])), Data("kind".utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: old.url(for: item).path))
    }

    func testUnsupportedFileIsRefused() throws {
        let original = dir.appendingPathComponent("song.mp3")
        try Data().write(to: original)
        XCTAssertThrowsError(try Bag(folder: dir.appendingPathComponent("Bag")).add(original))
    }

    func testScreenshotTextIsSearchable() throws {
        let sample = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("samples/kind-words.png")
        let text = Indexer.text(at: sample, kind: .image)
        XCTAssertTrue(text.localizedCaseInsensitiveContains("launch"), "recognised: \(text)")
    }
}

final class ReadingTests: XCTestCase {
    func testWrappedLinesRejoinAndTimesGo() {
        let raw = "Give me a shout when you're\nready\n14:37\nThe plan worked.\nThanks again\n9:05 PM"
        XCTAssertEqual(Reading.clean(raw), "Give me a shout when you're ready\n\nThe plan worked.\n\nThanks again")
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(Reading.clean(""), "")
    }
}
