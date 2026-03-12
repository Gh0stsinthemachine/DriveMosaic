import Foundation

/// Maps screen coordinates to arc descriptors for hover and click interactions.
enum SunburstHitTesting {

    enum HitResult {
        case arc(ArcDescriptor)
        case center  // Clicked on the center circle (navigate up)
        case none    // Clicked outside the sunburst
    }

    /// Find which arc (if any) contains the given point.
    /// - Parameters:
    ///   - point: The click/hover point in view coordinates
    ///   - center: The center of the sunburst in view coordinates
    ///   - totalRadius: The total radius of the sunburst in points
    ///   - centerRadius: The normalized center radius (0..1)
    ///   - arcs: The current arc descriptors
    static func hitTest(
        point: CGPoint,
        center: CGPoint,
        totalRadius: Double,
        centerRadius: Double,
        arcs: [ArcDescriptor]
    ) -> HitResult {
        let (distance, angle) = PolarMath.cartesianToPolar(point: point, center: center)
        let normalizedR = distance / totalRadius

        // Check if we're inside the center circle
        if normalizedR < centerRadius {
            return .center
        }

        // Check if we're outside the sunburst entirely
        guard normalizedR <= 1.0 else {
            return .none
        }

        // Find matching arc: filter by radius, then by angle
        for arc in arcs {
            if normalizedR >= arc.innerRadius && normalizedR < arc.outerRadius {
                if angle >= arc.startAngle && angle < arc.endAngle {
                    return .arc(arc)
                }
            }
        }

        return .none
    }
}
