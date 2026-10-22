import Foundation

/// Turns recognised screenshot text into something pleasant to read:
/// drops bare timestamps and rejoins lines that wrapped mid-sentence.
public enum Reading {
    public static func clean(_ text: String) -> String {
        let time = #/^\d{1,2}[:.]\d{2}(\s?[AaPp][Mm])?$/#
        var out = ""
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.count > 1, line.wholeMatch(of: time) == nil else { continue }
            if out.isEmpty {
                out = line
            } else if let first = line.first, first.isLowercase,
                      let last = out.last, !".!?:\"”)".contains(last) {
                out += " " + line
            } else {
                out += "\n\n" + line
            }
        }
        return out
    }
}
