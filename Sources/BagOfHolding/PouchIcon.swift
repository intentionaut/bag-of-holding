import AppKit

/// A filled drawstring coin purse, drawn as a template image so macOS tints it for light and dark menu bars.
enum PouchIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()

            let body = NSBezierPath()
            body.move(to: NSPoint(x: 6.8, y: 10.6))
            body.curve(to: NSPoint(x: 2.2, y: 5), controlPoint1: NSPoint(x: 3.4, y: 9.6), controlPoint2: NSPoint(x: 2.2, y: 7.8))
            body.curve(to: NSPoint(x: 9, y: 1), controlPoint1: NSPoint(x: 2.2, y: 2), controlPoint2: NSPoint(x: 5.4, y: 1))
            body.curve(to: NSPoint(x: 15.8, y: 5), controlPoint1: NSPoint(x: 12.6, y: 1), controlPoint2: NSPoint(x: 15.8, y: 2))
            body.curve(to: NSPoint(x: 11.2, y: 10.6), controlPoint1: NSPoint(x: 15.8, y: 7.8), controlPoint2: NSPoint(x: 14.6, y: 9.6))
            body.close()
            body.fill()

            // The ruffled top above the tie.
            let ruffle = NSBezierPath()
            ruffle.move(to: NSPoint(x: 7.2, y: 12))
            ruffle.line(to: NSPoint(x: 4.8, y: 15.4))
            ruffle.curve(to: NSPoint(x: 9, y: 15.2), controlPoint1: NSPoint(x: 6.4, y: 16.4), controlPoint2: NSPoint(x: 7.6, y: 14.6))
            ruffle.curve(to: NSPoint(x: 13.2, y: 15.4), controlPoint1: NSPoint(x: 10.4, y: 14.6), controlPoint2: NSPoint(x: 11.6, y: 16.4))
            ruffle.line(to: NSPoint(x: 10.8, y: 12))
            ruffle.close()
            ruffle.fill()

            // A gap cut round the neck, so the tie shows.
            NSGraphicsContext.current?.compositingOperation = .clear
            NSRect(x: 4, y: 10.9, width: 10, height: 0.8).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Bag of Holding"
        return image
    }()
}
