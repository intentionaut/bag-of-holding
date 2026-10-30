import SwiftUI

/// The napping bag and the cover scenes, drawn in code in the theme's colours, so there are no image files.
enum Cover {
    static let scenes: [(name: String, caption: String)] = [
        ("Rainy window", "It's raining out, reach into the bag."),
        ("Campfire", "+1 to morale. Marshmallow included."),
        ("Summit", "You've climbed further than you think."),
        ("Meadow", "+1 to wisdom for stopping to look."),
    ]
}

private func tint(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color { Color(hex: Theme.mix(a, b, t)) }

/// Pixel drawing in scene coordinates, one unit to one art pixel.
private struct Sprite {
    var context: GraphicsContext
    let unit: CGFloat
    var p: Palette { Theme.palette }

    func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ c: Color) {
        context.fill(Path(CGRect(x: x.rounded() * unit, y: y.rounded() * unit, width: w * unit, height: h * unit)), with: .color(c))
    }

    func bag(_ x: Double, _ bottomY: Double, sleeping: Bool = false) {
        let y = bottomY - 26
        let main = Color(hex: p.pink), shade = tint(p.pink, p.edge, 0.3), light = tint(p.pink, 0xFFFFFF, 0.45)
        let edge = p.dark ? tint(p.panel, 0, 0.2) : Color(hex: p.edge)
        r(x + 6, y, 14, 4, edge); r(x + 7, y + 1, 12, 2, light)
        r(x + 9, y + 4, 8, 2, edge); r(x + 10, y + 4, 6, 2, Color(hex: p.cyan))
        for (i, n) in [7.0, 5, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 7].enumerated() {
            let row = y + 6 + Double(i)
            r(x + n, row, 26 - 2 * n, 1, edge)
            if i > 0, i < 20 { r(x + n + 1, row, 24 - 2 * n, 1, i > 15 ? shade : main) }
        }
        r(x + 5, y + 9, 3, 2, light)
        let eye = y + 15
        if sleeping {
            r(x + 8, eye + 1, 3, 1, edge); r(x + 15, eye + 1, 3, 1, edge)
        } else {
            r(x + 8, eye, 2, 3, edge); r(x + 16, eye, 2, 3, edge)
            r(x + 8, eye, 1, 1, .white); r(x + 16, eye, 1, 1, .white)
        }
        r(x + 5, eye + 3, 2, 1, light); r(x + 19, eye + 3, 2, 1, light); r(x + 12, eye + 3, 2, 1, edge)
    }

    func snores(_ x: Double, _ y: Double, _ t: Double) {
        for i in 0...(Int(t / 30) % 3) {
            let d = Double(i), c = Color(hex: p.dim)
            r(x + d * 4, y - d * 5, 3, 1, c); r(x + 2 + d * 4, y + 1 - d * 5, 1, 1, c); r(x + d * 4, y + 2 - d * 5, 3, 1, c)
        }
    }

    func peak(_ cx: Double, _ base: Double, _ height: Int, _ c: Color, snow: Color? = nil) {
        for i in 0..<height {
            let w = Double(i * 2 + 1)
            r(cx - Double(i), base - Double(height) + Double(i), w, 1, Double(i) < Double(height) * 0.28 ? snow ?? c : c)
        }
    }

    func stars(_ w: Int, _ h: Int, _ n: Int, _ t: Double) {
        var s = 7
        for _ in 0..<n {
            s = (s &* 1103515245 &+ 12345) & 0x7fffffff
            let twinkle = (s + Int(t / 20)) % 5 == 0
            r(Double(s % w), Double((s >> 8) % h), 1, 1, tint(p.dark ? 0xE8E0FF : p.border, p.night, twinkle ? 0.75 : 0.25))
        }
    }

    func frog(_ x: Double, _ y: Double) {
        let g = tint(p.cyan, p.border, 0.4), e = Color(hex: p.edge)
        r(x + 1, y, 2, 2, g); r(x + 6, y, 2, 2, g); r(x, y + 1, 9, 4, g)
        r(x + 1, y + 1, 1, 1, e); r(x + 7, y + 1, 1, 1, e); r(x + 3, y + 3, 3, 1, e)
    }

    func scene(_ index: Int, _ t: Double) {
        r(0, 0, 164, 96, Color(hex: p.night))
        let border = Color(hex: p.border), pink = Color(hex: p.pink), cyan = Color(hex: p.cyan), dim = Color(hex: p.dim)
        switch index {
        case 0:
            r(0, 76, 164, 20, tint(p.border, p.night, 0.65))
            r(18, 10, 68, 50, border); r(21, 13, 62, 44, Color(hex: p.panel)); r(51, 13, 2, 44, border); r(21, 34, 62, 2, border)
            var s = 3
            for _ in 0..<26 {
                s = (s &* 1103515245 &+ 12345) & 0x7fffffff
                r(Double(21 + s % 60), Double(13 + ((s >> 6) + Int(t * 0.8)) % 40), 1, 3, tint(p.cyan, p.panel, 0.3))
            }
            r(14, 60, 76, 4, border)
            r(26, 53, 9, 7, pink); r(35, 55, 2, 3, pink); r(Int(t / 18) % 2 == 0 ? 31 : 29, 47, 1, 2, dim)
            r(98, 72, 42, 6, tint(p.pink, p.night, 0.35)); r(96, 74, 46, 4, tint(p.cyan, p.night, 0.55))
            bag(106, 74, sleeping: true); snores(134, 48, t)
        case 1:
            stars(164, 50, 30, t)
            peak(126, 76, 48, tint(p.border, p.night, 0.55), snow: tint(p.text, p.night, 0.15))
            peak(62, 76, 30, tint(p.border, p.night, 0.72))
            r(0, 76, 164, 20, tint(p.border, p.night, 0.8))
            let f = Double(Int(t / 7) % 3)
            r(74, 80, 22, 3, dim); r(78, 78, 14, 2, tint(p.dim, p.night, 0.3))
            r(79, 66 + f, 12, 12 - f, pink); r(82, 60 + 2 - f, 6, 8, pink); r(82, 70, 6, 8, cyan); r(84, 73, 2, 5, .white)
            bag(34, 78); r(58, 70, 20, 1, dim); r(76, 68, 4, 3, .white)
            frog(112, 73)
        case 2:
            stars(164, 60, 34, t)
            let moon = tint(p.text, p.night, 0.1)
            r(130, 10, 14, 14, moon); r(135, 8, 6, 18, moon); r(128, 14, 18, 6, moon)
            peak(82, 96, 62, tint(p.border, p.night, 0.5), snow: tint(p.text, p.night, 0.08))
            peak(20, 96, 34, tint(p.border, p.night, 0.7)); peak(146, 96, 40, tint(p.border, p.night, 0.65))
            bag(69, 34); r(98, 6, 1, 28, dim); r(99, 6 + Double(Int(t / 14) % 2), 10, 5, cyan)
            let x = (t * 0.25).truncatingRemainder(dividingBy: 190) - 26, cloud = tint(p.text, p.night, 0.25)
            r(x, 46, 20, 3, cloud); r(x + 4, 43, 11, 3, cloud)
        default:
            r(134, 8, 10, 14, cyan); r(132, 10, 14, 10, cyan)
            r(0, 72, 164, 24, tint(p.border, p.night, 0.35))
            r(0, 66, 70, 8, tint(p.border, p.night, 0.5)); r(100, 68, 64, 6, tint(p.border, p.night, 0.5))
            var s = 9
            for i in 0..<22 {
                s = (s &* 1103515245 &+ 12345) & 0x7fffffff
                let x = Double(s % 160), y = Double(76 + (s >> 7) % 18)
                r(x, y, 1, 1, i % 2 == 0 ? cyan : pink); r(x + 1, y + 1, 1, 1, Color(hex: p.text))
            }
            bag(64, 70); frog(72, 35)
        }
    }
}

/// Eight frames a second is enough for pixel art. Reduce Motion holds a still.
private struct Moving<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var still
    @ViewBuilder let content: (Double) -> Content

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.125)) { timeline in
            content(still ? 60 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600) * 60)
        }
    }
}

struct CoverScene: View {
    let index: Int

    var body: some View {
        VStack(spacing: 6) {
            Moving { t in
                Canvas { context, size in Sprite(context: context, unit: size.width / 164).scene(index, t) }
            }
            .aspectRatio(164 / 96, contentMode: .fit)
            .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 2))
            .accessibilityLabel("\(Cover.scenes[index].name): pixel art of the bag")
            Text(Cover.scenes[index].caption).font(Theme.mono(12)).foregroundStyle(Theme.dim)
        }
    }
}

/// The bag asleep, for when there's nothing in it.
struct NappingBag: View {
    var body: some View {
        Moving { t in
            Canvas { context, size in
                let art = Sprite(context: context, unit: size.width / 96)
                art.r(22, 48, 52, 1, Theme.border)
                art.bag(35, 42, sleeping: true)
                art.snores(63, 18, t)
            }
        }
        .frame(width: 288, height: 162)
        .accessibilityHidden(true)
    }
}
