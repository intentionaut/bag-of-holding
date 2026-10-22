import SwiftUI

/// One colour set. `cyan` is the heading colour and `pink` the accent, named after Night climb.
struct Palette {
    let name: String
    let dark: Bool
    let night, panel, border, cyan, pink, text, dim, edge: UInt32
}

/// The look of the README banner, in five colour sets. Views read the chosen one through `Theme`.
enum Theme {
    static let palettes = [
        Palette(name: "Night climb", dark: true, night: 0x161230, panel: 0x0E0A22, border: 0x8878E0,
                cyan: 0x9FE8FF, pink: 0xFF8AC8, text: 0xF6EBE2, dim: 0xA898E0, edge: 0x000000),
        Palette(name: "Ember cave", dark: true, night: 0x1C1412, panel: 0x120C0A, border: 0xD9824A,
                cyan: 0xFFD27A, pink: 0xFF7A5C, text: 0xF6EBE2, dim: 0xB49A8A, edge: 0x000000),
        Palette(name: "Parchment", dark: false, night: 0xF4EAD6, panel: 0xFFFAF0, border: 0x8C5A3A,
                cyan: 0x7A3E1E, pink: 0xB5523A, text: 0x2E2018, dim: 0x8A7560, edge: 0x3E2717),
        Palette(name: "Snowfield", dark: false, night: 0xEEF2FB, panel: 0xFFFFFF, border: 0x6A78C8,
                cyan: 0x3B4AA0, pink: 0xD0508A, text: 0x1E2240, dim: 0x7A80A8, edge: 0x1E2240),
        Palette(name: "Meadow", dark: false, night: 0xEAF6E4, panel: 0xFBFFF8, border: 0x4F9A52,
                cyan: 0x2F6B33, pink: 0xE07A3A, text: 0x1F2A1C, dim: 0x6F8A6A, edge: 0x1F2A1C),
    ]
    static let key = "theme"

    static var palette: Palette {
        let name = UserDefaults.standard.string(forKey: key)
        return palettes.first { $0.name == name } ?? palettes[0]
    }

    static var night: Color { Color(hex: palette.night) }
    static var panel: Color { Color(hex: palette.panel) }
    static var border: Color { Color(hex: palette.border) }
    static var cyan: Color { Color(hex: palette.cyan) }
    static var pink: Color { Color(hex: palette.pink) }
    static var text: Color { Color(hex: palette.text) }
    static var dim: Color { Color(hex: palette.dim) }
    static var edge: Color { Color(hex: palette.edge) }
    static var scheme: ColorScheme { palette.dark ? .dark : .light }

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

/// A dialogue box: square corners, a coloured border inside a dark edge.
struct DialogueBox: ViewModifier {
    var lit = false
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Theme.panel)
            .overlay(Rectangle().strokeBorder(lit ? Theme.pink : Theme.border, lineWidth: 3))
            .padding(2)
            .background(Theme.edge)
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
                                                 size: CGSize(width: pixel, height: pixel))), with: .color(Theme.edge.opacity(Theme.palette.dark ? 1 : 0.25)))
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
