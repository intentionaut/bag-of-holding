import SwiftUI

private extension CGFloat {
    func clamped() -> CGFloat { Swift.min(Swift.max(self, 0), 255) }
}

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
    static let customKey = "themeCustom"
    static let custom = "Custom"

    static var palette: Palette {
        let name = UserDefaults.standard.string(forKey: key)
        if name == custom, let p = customPalette(UserDefaults.standard.string(forKey: customKey) ?? "") { return p }
        return palettes.first { $0.name == name } ?? palettes[0]
    }

    /// The six colours you can pick, in order. The muted text and the dark edge are worked out from them.
    static let pickable = ["Background", "Cards", "Border", "Headings", "Accent", "Text"]

    static func colours(of p: Palette) -> [UInt32] { [p.night, p.panel, p.border, p.cyan, p.pink, p.text] }

    /// A custom theme is stored as six hex colours, e.g. "161230,0E0A22,8878E0,9FE8FF,FF8AC8,F6EBE2".
    static func customPalette(_ stored: String) -> Palette? {
        let c = stored.split(separator: ",").compactMap { UInt32($0, radix: 16) }
        guard c.count == 6 else { return nil }
        let dark = luminance(c[0]) < 0.5
        return Palette(name: custom, dark: dark, night: c[0], panel: c[1], border: c[2], cyan: c[3], pink: c[4],
                       text: c[5], dim: mix(c[5], c[0], 0.45), edge: dark ? 0x000000 : c[5])
    }

    static func store(_ colours: [UInt32]) -> String {
        colours.map { String(format: "%06X", $0) }.joined(separator: ",")
    }

    private static func luminance(_ c: UInt32) -> Double {
        (0.299 * Double(c >> 16 & 0xFF) + 0.587 * Double(c >> 8 & 0xFF) + 0.114 * Double(c & 0xFF)) / 255
    }

    private static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        [16, 8, 0].reduce(0) { sum, shift in
            let x = Double(a >> UInt32(shift) & 0xFF), y = Double(b >> UInt32(shift) & 0xFF)
            return sum | UInt32((x + (y - x) * t).rounded()) << UInt32(shift)
        }
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
    var hex: UInt32 {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return 0 }
        return [c.redComponent, c.greenComponent, c.blueComponent]
            .reduce(0) { $0 << 8 | UInt32(($1 * 255).rounded().clamped()) }
    }

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

/// A tab: lit border and heading colour when selected.
struct TabStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.textCase(.uppercase)
            .font(Theme.mono(11, .bold))
            .foregroundStyle(selected ? Theme.cyan : configuration.isPressed ? Theme.pink : Theme.dim)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(selected ? Theme.panel : .clear)
            .overlay(Rectangle().strokeBorder(selected ? Theme.border : .clear, lineWidth: 2))
            .contentShape(Rectangle())
    }
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

/// A few fixed stars, as in the banner's sky. Dimmer on light themes.
struct StarField: View {
    var body: some View {
        Canvas { context, size in
            guard UserDefaults.standard.object(forKey: "stars") as? Bool ?? true else { return }
            var seed: UInt64 = 7
            for _ in 0..<40 {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let x = CGFloat((seed >> 33) % 10_000) / 10_000 * size.width
                let y = CGFloat((seed >> 13) & 0xFFFF) / 0xFFFF * size.height
                let s: CGFloat = seed & 3 == 0 ? 3 : 2
                let bright = Theme.palette.dark ? (seed & 1 == 0 ? 0.8 : 0.4) : 0.35
                context.fill(Path(CGRect(x: x, y: y, width: s, height: s)),
                             with: .color((Theme.palette.dark ? Color(hex: 0xE8E0FF) : Theme.border).opacity(bright)))
            }
        }
        .background(Theme.night)
    }
}

/// The menu bar pouch, in the theme's accent, for the window title.
struct Pouch: View {
    var size: CGFloat = 16
    var body: some View {
        Image(nsImage: PouchIcon.image).renderingMode(.template).resizable()
            .frame(width: size, height: size).foregroundStyle(Theme.pink)
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

/// Slack-style theme picker: a row of ready-made themes, then six colour wells for your own.
struct ThemePicker: View {
    @AppStorage(Theme.key) private var theme = Theme.palettes[0].name
    @AppStorage(Theme.customKey) private var stored = ""
    @AppStorage("stars") private var stars = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THEME").font(Theme.mono(10, .bold)).foregroundStyle(Theme.cyan)
            HStack(spacing: 8) {
                ForEach(Theme.palettes, id: \.name) { p in
                    Button { theme = p.name } label: { swatch(p, selected: theme == p.name) }
                        .buttonStyle(.plain).help(p.name)
                }
            }
            Text("CUSTOM").font(Theme.mono(10, .bold)).foregroundStyle(Theme.cyan)
            HStack(spacing: 10) {
                ForEach(Array(Theme.pickable.enumerated()), id: \.offset) { i, label in
                    ColorPicker(selection: well(i), supportsOpacity: false) { EmptyView() }
                        .labelsHidden().help(label)
                }
                Text(theme == Theme.custom ? "In use" : "Change a colour to make your own")
                    .font(Theme.mono(10)).foregroundStyle(Theme.dim)
            }
            Toggle("Stars", isOn: $stars)
        }
    }

    private func swatch(_ p: Palette, selected: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color(hex: p.night); Color(hex: p.border); Color(hex: p.pink)
            }
            .frame(width: 66, height: 22)
            Text(p.name).font(Theme.mono(8, .bold)).foregroundStyle(Color(hex: p.text))
                .frame(width: 66, height: 14).background(Color(hex: p.panel))
        }
        .overlay(Rectangle().strokeBorder(selected ? Theme.pink : Theme.edge.opacity(0.5), lineWidth: selected ? 3 : 1))
    }

    /// Editing a colour switches to Custom, starting from whichever theme is showing.
    private func well(_ i: Int) -> Binding<Color> {
        Binding(
            get: { Color(hex: Theme.colours(of: Theme.palette)[i]) },
            set: { colour in
                var colours = Theme.colours(of: Theme.palette)
                colours[i] = colour.hex
                stored = Theme.store(colours)
                theme = Theme.custom
            })
    }
}
