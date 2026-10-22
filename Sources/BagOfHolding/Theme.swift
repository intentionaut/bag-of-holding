import SwiftUI

/// The look of the README banner: a night sky, dialogue boxes with a lavender pixel border,
/// cyan headings and pink accents.
enum Theme {
    static let night = Color(hex: 0x161230)
    static let panel = Color(hex: 0x0E0A22)
    static let border = Color(hex: 0x8878E0)
    static let cyan = Color(hex: 0x9FE8FF)
    static let pink = Color(hex: 0xFF8AC8)
    static let text = Color(hex: 0xF6EBE2)
    static let dim = Color(hex: 0xA898E0)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// A dialogue box: square corners, dark fill, a lavender border inside a black one.
struct DialogueBox: ViewModifier {
    var lit = false
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Theme.panel)
            .overlay(Rectangle().strokeBorder(lit ? Theme.pink : Theme.border, lineWidth: 3))
            .padding(2)
            .background(Color.black)
    }
}

extension View {
    func dialogueBox(lit: Bool = false) -> some View { modifier(DialogueBox(lit: lit)) }
}

/// Menu-style buttons: uppercase, square, with a pink ▶ cursor on hover like a game menu.
struct PixelButtonStyle: ButtonStyle {
    var small = false
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            Text("▶").foregroundStyle(Theme.pink).opacity(hover && enabled ? 1 : 0)
            configuration.label.textCase(.uppercase)
        }
        .font(Theme.mono(small ? 10 : 12, .bold))
        .foregroundStyle(enabled ? (configuration.isPressed ? Theme.pink : Theme.text) : Theme.dim.opacity(0.5))
        .padding(.vertical, small ? 2 : 5)
        .padding(.trailing, small ? 4 : 8)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

/// Text in the banner's own 5×7 pixel font. Only the letters the app uses are drawn.
struct PixelText: View {
    let string: String
    var pixel: CGFloat = 3
    var color = Theme.cyan

    private static let glyphs: [Character: [String]] = [
        "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
        "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
        "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
        "G": ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
        "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
        "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
        "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
        "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
        "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        " ": Array(repeating: "00000", count: 7),
    ]

    var body: some View {
        let chars = Array(string.uppercased())
        Canvas { context, _ in
            for (i, ch) in chars.enumerated() {
                guard let rows = Self.glyphs[ch] else { continue }
                for (r, row) in rows.enumerated() {
                    for (c, bit) in row.enumerated() where bit == "1" {
                        let origin = CGPoint(x: CGFloat(i * 6 + c) * pixel, y: CGFloat(r) * pixel)
                        context.fill(Path(CGRect(origin: CGPoint(x: origin.x + pixel, y: origin.y + pixel),
                                                 size: CGSize(width: pixel, height: pixel))), with: .color(.black))
                        context.fill(Path(CGRect(origin: origin, size: CGSize(width: pixel, height: pixel))),
                                     with: .color(color))
                    }
                }
            }
        }
        .frame(width: CGFloat(chars.count * 6) * pixel, height: 8 * pixel)
        .accessibilityLabel(string)
    }
}
