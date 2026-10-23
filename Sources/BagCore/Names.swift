import Foundation

/// Helpers for the words you type into From, About and Tags: tidying, matching, suggesting, dating.
public enum Names {
    /// Trims and collapses runs of spaces; nil if nothing is left.
    public static func tidy(_ s: String?) -> String? {
        guard let s else { return nil }
        let t = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return t.isEmpty ? nil : t
    }

    /// What makes two spellings the same name: "  sam   LEE" and "Sam Lee" share a key.
    public static func key(_ s: String) -> String {
        (tidy(s) ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// One spelling per key, most used first (ties keep first-seen order). The most used spelling wins.
    public static func distinct(_ values: [String]) -> [String] {
        var count: [String: Int] = [:], spelling: [String: [String: Int]] = [:], order: [String] = []
        for v in values {
            guard let t = tidy(v) else { continue }
            let k = key(t)
            if count[k] == nil { order.append(k) }
            count[k, default: 0] += 1
            spelling[k, default: [:]][t, default: 0] += 1
        }
        let ranked = order.enumerated().sorted {
            count[$0.element]! != count[$1.element]! ? count[$0.element]! > count[$1.element]! : $0.offset < $1.offset
        }
        return ranked.map { k in
            spelling[k.element]!.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }[0].key
        }
    }

    /// Suggestions for what has been typed so far. Nothing typed: the most used. Exact matches are left out.
    public static func suggestions(from values: [String], matching typed: String, excluding: [String] = [],
                                   limit: Int = 5) -> [String] {
        let typedKey = key(typed), skip = Set(excluding.map(key))
        return Array(distinct(values).filter {
            let k = key($0)
            return !skip.contains(k) && k != typedKey && (typedKey.isEmpty || k.contains(typedKey))
        }.prefix(limit))
    }

    /// The spelling already in use for `value`, if there is one; otherwise `value` tidied.
    public static func canonical(_ value: String, among existing: [String]) -> String? {
        guard let t = tidy(value) else { return nil }
        return distinct(existing).first { key($0) == key(t) } ?? t
    }

    /// The stamp for feedback given on `day`: right now if that is today, otherwise midday,
    /// so a back-dated entry files under, and shows, the day you chose in any time zone nearby.
    public static func entryDate(_ day: Date, now: Date = Date(), calendar: Calendar = .current) -> Date {
        if calendar.isDate(day, inSameDayAs: now) { return now }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }
}
