import Foundation

/// Utilities for polar coordinate conversions used in sunburst rendering and hit testing.
enum PolarMath {

    /// Convert a point to polar coordinates relative to a center.
    /// Returns (radius, angle) where angle is in radians, 0 = top (12 o'clock), clockwise.
    static func cartesianToPolar(point: CGPoint, center: CGPoint) -> (radius: Double, angle: Double) {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        let radius = sqrt(dx * dx + dy * dy)

        // atan2(x, -y) gives angle from top, clockwise
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }

        return (radius, angle)
    }

    /// Linear interpolation
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    /// Ease-in-out timing function
    static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
