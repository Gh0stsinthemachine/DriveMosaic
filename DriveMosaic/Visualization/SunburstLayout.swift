import SwiftUI

/// Converts a FileNode tree into a flat array of ArcDescriptors for rendering.
/// The layout uses concentric rings with sector angles proportional to file size.
enum SunburstLayout {

    /// Layout configuration
    struct Config {
        var maxDepth: Int = 6
        var centerRadius: Double = 0.18
        var ringWidths: [Double] = [0.14, 0.13, 0.12, 0.11, 0.10, 0.08]
        var minArcAngle: Double = 0.02  // ~1.15 degrees
        var maxChildren: Int = 25       // Consolidate beyond this count
        var gapAngle: Double = 0.005    // Small gap between arcs
    }

    /// Generate arc descriptors for the visible portion of the tree.
    static func layout(root: FileNode, config: Config = Config()) -> [ArcDescriptor] {
        guard root.size > 0 else { return [] }

        var arcs: [ArcDescriptor] = []

        func recurse(node: FileNode, startAngle: Double, sweepAngle: Double, ringIndex: Int) {
            guard ringIndex < config.maxDepth else { return }
            guard sweepAngle >= config.minArcAngle else { return }
            guard ringIndex < config.ringWidths.count else { return }

            let innerR = config.centerRadius + config.ringWidths.prefix(ringIndex).reduce(0, +)
            let outerR = innerR + config.ringWidths[ringIndex]

            let children = node.children.filter { $0.size > 0 }
            guard !children.isEmpty else { return }

            // Separate into visible and consolidated children
            var visibleChildren: [FileNode] = []
            var consolidatedSize: UInt64 = 0
            var consolidatedCount = 0

            for (index, child) in children.enumerated() {
                let childSweep = sweepAngle * (Double(child.size) / Double(node.size))
                if childSweep >= config.minArcAngle && index < config.maxChildren {
                    visibleChildren.append(child)
                } else {
                    consolidatedSize += child.size
                    consolidatedCount += 1
                }
            }

            // Layout visible children
            var currentAngle = startAngle
            let totalGap = config.gapAngle * Double(visibleChildren.count + (consolidatedCount > 0 ? 1 : 0))
            let availableSweep = max(sweepAngle - totalGap, sweepAngle * 0.9)
            let visibleTotalSize = visibleChildren.reduce(UInt64(0)) { $0 + $1.size } + consolidatedSize

            for child in visibleChildren {
                let childSweep = availableSweep * (Double(child.size) / Double(visibleTotalSize))

                let arc = ArcDescriptor(
                    id: child.id,
                    startAngle: currentAngle,
                    endAngle: currentAngle + childSweep,
                    innerRadius: innerR,
                    outerRadius: outerR,
                    color: ColorAssigner.color(for: child),
                    nodeID: child.id,
                    depth: ringIndex,
                    isFile: !child.isDirectory,
                    isConsolidated: false
                )
                arcs.append(arc)

                // Recurse into directories
                if child.isDirectory {
                    recurse(node: child, startAngle: currentAngle, sweepAngle: childSweep, ringIndex: ringIndex + 1)
                }

                currentAngle += childSweep + config.gapAngle
            }

            // Add consolidated "Smaller Items" arc
            if consolidatedCount > 0 && consolidatedSize > 0 {
                let consolidatedSweep = availableSweep * (Double(consolidatedSize) / Double(visibleTotalSize))
                if consolidatedSweep >= config.minArcAngle / 2 {
                    let arc = ArcDescriptor(
                        id: UUID(),
                        startAngle: currentAngle,
                        endAngle: currentAngle + consolidatedSweep,
                        innerRadius: innerR,
                        outerRadius: outerR,
                        color: Color(white: 0.75),
                        nodeID: UUID(), // No specific node
                        depth: ringIndex,
                        isFile: false,
                        isConsolidated: true
                    )
                    arcs.append(arc)
                }
            }
        }

        recurse(node: root, startAngle: 0, sweepAngle: 2 * .pi, ringIndex: 0)
        return arcs
    }
}
