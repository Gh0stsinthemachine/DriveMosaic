import SwiftUI

/// Assigns colors to FileNodes using a hierarchical hue-splitting algorithm.
/// Directories get vibrant, distinct colors. Files are always gray.
/// Children of the same directory share a color family.
enum ColorAssigner {

    /// Assign colors to the entire tree starting from root.
    /// Call once after scan completion — colors are cached on each node.
    static func assignColors(root: FileNode) {
        assignHueRange(node: root, hueStart: 0, hueRange: 360, depth: 0)
    }

    private static func assignHueRange(node: FileNode, hueStart: Double, hueRange: Double, depth: Int) {
        if !node.isDirectory {
            // Files inherit parent's hue with moderate saturation — visible, not washed out
            let parentHue = node.parent?.assignedHue ?? 0
            let fileSat = 0.35 + Double.random(in: -0.05...0.05)
            let fileBri = 0.58 + Double.random(in: -0.04...0.04)
            node.assignedColor = Color(hue: parentHue, saturation: fileSat, brightness: fileBri)
            node.assignedHue = parentHue
            node.assignedSaturation = fileSat
            node.assignedBrightness = fileBri
            return
        }

        // Assign this directory's own color at the midpoint of its hue range
        let midHue = (hueStart + hueRange / 2).truncatingRemainder(dividingBy: 360)
        let sat = saturation(forDepth: depth)
        let bri = brightness(forDepth: depth)
        node.assignedColor = Color(hue: midHue / 360, saturation: sat, brightness: bri)
        node.assignedHue = midHue / 360
        node.assignedSaturation = sat
        node.assignedBrightness = bri

        // Distribute hue range among directory children
        let dirChildren = node.children.filter { $0.isDirectory }
        guard !dirChildren.isEmpty else {
            // File-only directory: spread files across a small hue range for variety
            let fileChildren = node.children.filter { !$0.isDirectory }
            let spread = min(hueRange * 0.6, 30.0) // Up to 30° spread
            let step = fileChildren.count > 1 ? spread / Double(fileChildren.count - 1) : 0
            let startHue = midHue - spread / 2

            for (i, child) in fileChildren.enumerated() {
                let fileHue = ((startHue + step * Double(i)).truncatingRemainder(dividingBy: 360)) / 360
                let fileSat = 0.35 + Double.random(in: -0.05...0.05)
                let fileBri = 0.58 + Double.random(in: -0.04...0.04)
                child.assignedColor = Color(hue: fileHue, saturation: fileSat, brightness: fileBri)
                child.assignedHue = fileHue
                child.assignedSaturation = fileSat
                child.assignedBrightness = fileBri
            }
            return
        }

        let totalDirSize = dirChildren.reduce(UInt64(0)) { $0 + $1.size }
        guard totalDirSize > 0 else { return }

        // Use 80% of available range, leaving gaps between subtrees
        let usableRange = hueRange * 0.80
        let gapTotal = hueRange - usableRange
        let gap = gapTotal / Double(dirChildren.count)

        var currentHue = hueStart + gap / 2

        for child in dirChildren {
            let fraction = Double(child.size) / Double(totalDirSize)
            let childRange = max(usableRange * fraction, 5) // Minimum 5 degrees
            assignHueRange(node: child, hueStart: currentHue, hueRange: childRange, depth: depth + 1)
            currentHue += childRange + gap
        }

        // File children inherit parent directory's hue with slight variation
        let fileChildren = node.children.filter { !$0.isDirectory }
        for (i, child) in fileChildren.enumerated() {
            let hueShift = Double(i) * 0.008 - Double(fileChildren.count) * 0.004
            let fileHue = (midHue / 360 + hueShift).truncatingRemainder(dividingBy: 1.0)
            let fileSat = 0.35 + Double.random(in: -0.05...0.05)
            let fileBri = 0.58 + Double.random(in: -0.04...0.04)
            child.assignedColor = Color(hue: max(fileHue, 0), saturation: fileSat, brightness: fileBri)
            child.assignedHue = max(fileHue, 0)
            child.assignedSaturation = fileSat
            child.assignedBrightness = fileBri
        }
    }

    private static func saturation(forDepth depth: Int) -> Double {
        // Saturation increases with depth for vibrancy
        min(0.50 + Double(depth) * 0.07, 0.85)
    }

    private static func brightness(forDepth depth: Int) -> Double {
        // Brightness slightly decreases with depth
        max(0.90 - Double(depth) * 0.04, 0.60)
    }

    /// Get color for a node, falling back to a default if not yet assigned
    static func color(for node: FileNode) -> Color {
        node.assignedColor ?? (node.isDirectory ? .blue : .gray)
    }
}
