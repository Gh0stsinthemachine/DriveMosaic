import SwiftUI

/// Describes a single arc segment in the sunburst chart.
/// These are the rendering primitives — the SunburstLayout algorithm
/// converts a FileNode tree into a flat array of ArcDescriptors.
struct ArcDescriptor: Identifiable {
    let id: UUID
    let startAngle: Double     // Radians, 0 = 12 o'clock, clockwise
    let endAngle: Double
    let innerRadius: Double    // Normalized 0..1
    let outerRadius: Double    // Normalized 0..1
    let color: Color
    let nodeID: UUID           // Links back to the FileNode
    let depth: Int             // Ring level (0 = first ring around center)
    let isFile: Bool
    let isConsolidated: Bool   // "Smaller items" pseudo-arc

    var sweepAngle: Double { endAngle - startAngle }
    var midAngle: Double { (startAngle + endAngle) / 2 }
    var midRadius: Double { (innerRadius + outerRadius) / 2 }

    /// Create a Path for this arc segment
    func path(center: CGPoint, scale: CGFloat) -> Path {
        let inner = innerRadius * scale
        let outer = outerRadius * scale
        // Convert from our coordinate system (0 = top, clockwise)
        // to Core Graphics (0 = right, counterclockwise)
        let cgStart = Angle(radians: startAngle - .pi / 2)
        let cgEnd = Angle(radians: endAngle - .pi / 2)

        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: cgStart, endAngle: cgEnd, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: cgEnd, endAngle: cgStart, clockwise: true)
        path.closeSubpath()
        return path
    }
}
