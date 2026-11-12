import AppKit
import CoreGraphics

/// Side-view laptop drawn with Core Graphics: a base line running right from a
/// bottom-left hinge, and a lid line pivoting out of that hinge at the current
/// sensor angle (0deg = closed / lying on the base, 180deg = folded flat).
///
/// Images are rendered only when the angle actually changes — nothing animates
/// or pumps a layer at idle.
enum LaptopIcon {

    static let statusItemSize = NSSize(width: 20, height: 18)
    static let menuSize = NSSize(width: 90, height: 50)

    static func image(size: NSSize, angle: Double) -> NSImage {
        let image = NSImage(size: size, flipped: false) { (rect: NSRect) -> Bool in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            LaptopIcon.draw(in: ctx, rect: rect, angle: angle)
            return true
        }
        // Template: AppKit tints it for light/dark menu bars and menu highlight.
        image.isTemplate = true
        return image
    }

    private static func draw(in ctx: CGContext, rect: NSRect, angle: Double) {
        let clamped = min(max(angle, 0.0), 180.0)
        let lineWidth = max(1.0, min(rect.width, rect.height) * 0.075)
        let inset = lineWidth

        // Both arms share one length so the widest pose (180deg, spanning
        // hinge +/- arm) still fits the canvas, and the hinge sits centred.
        let arm = max(1.0, min((rect.width - 2 * inset) / 2, rect.height - 2 * inset))
        let hinge = CGPoint(x: rect.midX, y: rect.minY + inset + lineWidth / 2)

        let theta = clamped * Double.pi / 180.0
        let lidTip = CGPoint(x: hinge.x + CGFloat(cos(theta)) * arm,
                             y: hinge.y + CGFloat(sin(theta)) * arm)

        let ink = CGColor(gray: 0.0, alpha: 1.0)
        ctx.setStrokeColor(ink)
        ctx.setFillColor(ink)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)

        // Base / keyboard.
        ctx.move(to: hinge)
        ctx.addLine(to: CGPoint(x: hinge.x + arm, y: hinge.y))
        ctx.strokePath()

        // Lid.
        ctx.move(to: hinge)
        ctx.addLine(to: lidTip)
        ctx.strokePath()

        // Hinge pin.
        let r = lineWidth * 0.8
        ctx.fillEllipse(in: CGRect(x: hinge.x - r, y: hinge.y - r, width: 2 * r, height: 2 * r))
    }
}
