import AppKit

/// The menu bar gauge: a robot head that fills from the bottom with the 5-hour
/// utilisation, so the empty space above the level is the headroom left. The eyes
/// stay visible through the fill, and the antenna ball turns solid at the limit.
/// A template image, so it follows the menu bar's appearance.
enum GaugeIcon {
    static func image(fill: Double) -> NSImage {
        // Overage utilisation can exceed 1.0; clamp so the fill cannot paint over the
        // border, and guard against NaN from a malformed header.
        let level = fill.isFinite ? min(1, max(0, fill)) : 0

        let image = NSImage(size: NSSize(width: 18, height: 22), flipped: false) { _ in
            NSColor.black.setFill()

            // Head outline.
            let head = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 16, height: 14), xRadius: 3.5, yRadius: 3.5)
            head.append(NSBezierPath(roundedRect: NSRect(x: 2.25, y: 2.25, width: 13.5, height: 11.5), xRadius: 2.5, yRadius: 2.5))
            head.windingRule = .evenOdd
            head.fill()

            // Antenna: a stem and a ball that is hollow until the limit is reached.
            NSRect(x: 8.25, y: 15, width: 1.5, height: 2.5).fill()
            let ball = circle(x: 9, y: 19, radius: 2)
            if level < 1 {
                ball.append(circle(x: 9, y: 19, radius: 0.9))
                ball.windingRule = .evenOdd
            }
            ball.fill()

            // The fill zone is 9.5pt tall; snap its height to whole Retina pixels. The
            // eyes are drawn with the fill under even-odd, so they are solid above the
            // level and cut out of the fill below it.
            let height = (level * 19).rounded() / 2
            let face = NSBezierPath(rect: NSRect(x: 3, y: 3.25, width: 12, height: height))
            face.append(circle(x: 6.25, y: 8.5, radius: 1.6))
            face.append(circle(x: 11.75, y: 8.5, radius: 1.6))
            face.windingRule = .evenOdd
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: NSRect(x: 3.25, y: 3.25, width: 11.5, height: 9.5), xRadius: 1.75, yRadius: 1.75).addClip()
            face.fill()
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func circle(x: CGFloat, y: CGFloat, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }
}
