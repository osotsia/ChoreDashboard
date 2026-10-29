import AppKit

public enum MenuBarIcon {
    /// Vector template image configured for automatic macOS menu bar tinting and highlight inversion.
    public static let template: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: 9.0, y: 9.0)
            let radius: CGFloat = 7.0
            let ringLineWidth: CGFloat = 1.65
            let checkLineWidth: CGFloat = 1.65

            // Base color is black; macOS template engine recolors this dynamically
            NSColor.black.setStroke()

            // 1. Draw 3 Solid Runway Quadrants (75% Active Buffer)
            // Quadrant 1: Top-Right (8° to 82°)
            let arc1 = NSBezierPath()
            arc1.appendArc(withCenter: center, radius: radius, startAngle: 8, endAngle: 82)
            arc1.lineWidth = ringLineWidth
            arc1.lineCapStyle = .round
            arc1.stroke()

            // Quadrant 2: Bottom-Right (278° to 352°)
            let arc2 = NSBezierPath()
            arc2.appendArc(withCenter: center, radius: radius, startAngle: 278, endAngle: 352)
            arc2.lineWidth = ringLineWidth
            arc2.lineCapStyle = .round
            arc2.stroke()

            // Quadrant 3: Bottom-Left (188° to 262°)
            let arc3 = NSBezierPath()
            arc3.appendArc(withCenter: center, radius: radius, startAngle: 188, endAngle: 262)
            arc3.lineWidth = ringLineWidth
            arc3.lineCapStyle = .round
            arc3.stroke()

            // 2. Draw Unfilled Runway Capacity Slot (Top-Left: 98° to 172°) with faint opacity
            NSColor.black.withAlphaComponent(0.25).setStroke()
            let arc4 = NSBezierPath()
            arc4.appendArc(withCenter: center, radius: radius, startAngle: 98, endAngle: 172)
            arc4.lineWidth = ringLineWidth
            arc4.lineCapStyle = .round
            arc4.stroke()

            // 3. Draw Center Hero Checkmark
            NSColor.black.setStroke()
            let check = NSBezierPath()
            check.move(to: CGPoint(x: 6.2, y: 9.2))
            check.line(to: CGPoint(x: 8.2, y: 7.2))
            check.line(to: CGPoint(x: 12.0, y: 11.5))
            check.lineWidth = checkLineWidth
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.stroke()

            return true
        }

        image.isTemplate = true
        return image
    }()
}