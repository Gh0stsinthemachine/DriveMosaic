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
            // Files are always gray with slight variation
            let brightness = 0.55 + Double.random(in: -0.05...0.05)
            node.assignedColor = Color(hue: 0, saturation: 0, brightness: brightness)
            return
        }

        // Assign this directory's own color at the midpoint of its hue range
        let midHue = (hueStart + hueRange / 2).truncatingRemainder(dividingBy: 360)
        node.assignedColor = Color(
            hue: midHue / 360,
            saturation: saturation(forDepth: depth),
            brightness: brightness(forDepth: depth)
        )

        // Distribute hue range among directory children
        let dirChildren = node.children.filter { $0.isDirectory }
        guard !dirChildren.isEmpty else {
            // Still color file children
            for child in node.children where !child.isDirectory {
                let brightness = 0.55 + Double.random(in: -0.05...0.05)
                child.assignedColor = Color(hue: 0, saturation: 0, brightness: brightness)
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

        // Color file children (gray)
        for child in node.children where !child.isDirectory {
            let brightness = 0.55 + Double.random(in: -0.05...0.05)
            child.assignedColor = Color(hue: 0, saturation: 0, brightness: brightness)
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
