import Foundation

/// A rectangle in the treemap with associated metadata.
struct TreemapRect: Identifiable {
    let id: UUID
    let nodeID: UUID
    let rect: CGRect
    let depth: Int
    let isFile: Bool
    let isConsolidated: Bool
    let name: String
    let size: UInt64
}

/// Squarified treemap layout algorithm.
/// Converts a FileNode tree into nested rectangles proportional to size.
enum TreemapLayout {

    struct Config {
        var maxDepth: Int = 4
        var padding: CGFloat = 3
        var headerHeight: CGFloat = 28
        var minBlockArea: CGFloat = 120 // Skip blocks smaller than this
    }

    /// Generate treemap rectangles for the given root within the bounds.
    static func layout(root: FileNode, bounds: CGRect, config: Config = Config()) -> [TreemapRect] {
        guard root.size > 0 else { return [] }

        var rects: [TreemapRect] = []
        layoutChildren(
            of: root,
            in: bounds,
            depth: 0,
            config: config,
            rects: &rects
        )
        return rects
    }

    private static func layoutChildren(
        of node: FileNode,
        in bounds: CGRect,
        depth: Int,
        config: Config,
        rects: inout [TreemapRect]
    ) {
        let children = node.children.filter { $0.size > 0 }
        guard !children.isEmpty else { return }
        guard depth < config.maxDepth else { return }

        // Inset the content area to leave room for the header/border
        let inset = depth == 0 ? CGFloat(0) : config.padding
        let headerH = depth == 0 ? CGFloat(0) : config.headerHeight
        let contentRect = CGRect(
            x: bounds.minX + inset,
            y: bounds.minY + headerH + inset,
            width: max(bounds.width - inset * 2, 0),
            height: max(bounds.height - headerH - inset * 2, 0)
        )

        guard contentRect.width > 2 && contentRect.height > 2 else { return }

        // Squarified treemap: lay out children as rectangles
        let childRects = squarify(
            items: children.map { (id: $0.id, size: Double($0.size)) },
            in: contentRect,
            totalSize: Double(node.size)
        )

        for (i, child) in children.enumerated() {
            guard i < childRects.count else { break }
            let childRect = childRects[i]

            // Skip tiny blocks
            guard childRect.width * childRect.height >= config.minBlockArea else {
                continue
            }

            rects.append(TreemapRect(
                id: child.id,
                nodeID: child.id,
                rect: childRect,
                depth: depth,
                isFile: !child.isDirectory,
                isConsolidated: false,
                name: child.name,
                size: child.size
            ))

            // Recurse into directories
            if child.isDirectory && childRect.width > 40 && childRect.height > 40 {
                layoutChildren(
                    of: child,
                    in: childRect,
                    depth: depth + 1,
                    config: config,
                    rects: &rects
                )
            }
        }
    }

    // MARK: - Squarified Treemap Algorithm

    /// Partition items into rectangles within the given bounds,
    /// using the squarified algorithm for optimal aspect ratios.
    private static func squarify(
        items: [(id: UUID, size: Double)],
        in bounds: CGRect,
        totalSize: Double
    ) -> [CGRect] {
        guard !items.isEmpty, totalSize > 0 else { return [] }

        var result = [CGRect](repeating: .zero, count: items.count)
        var remaining = bounds
        var startIndex = 0

        while startIndex < items.count {
            let isWide = remaining.width >= remaining.height

            // Greedily add items to the current strip until aspect ratio worsens
            var stripItems: [(index: Int, size: Double)] = []
            var stripTotal: Double = 0
            let remainingTotal = items[startIndex...].reduce(0.0) { $0 + $1.size }

            for i in startIndex..<items.count {
                let candidate = items[i].size
                let newTotal = stripTotal + candidate

                if stripItems.isEmpty {
                    stripItems.append((i, candidate))
                    stripTotal = newTotal
                } else {
                    let oldWorst = worstAspect(sizes: stripItems.map(\.size), total: stripTotal, length: isWide ? remaining.height : remaining.width, areaFraction: stripTotal / remainingTotal, fullLength: isWide ? remaining.width : remaining.height)
                    var testSizes = stripItems.map(\.size)
                    testSizes.append(candidate)
                    let newWorst = worstAspect(sizes: testSizes, total: newTotal, length: isWide ? remaining.height : remaining.width, areaFraction: newTotal / remainingTotal, fullLength: isWide ? remaining.width : remaining.height)

                    if newWorst <= oldWorst {
                        stripItems.append((i, candidate))
                        stripTotal = newTotal
                    } else {
                        break
                    }
                }
            }

            // Lay out the strip
            let stripFraction = stripTotal / remainingTotal
            let stripLength: CGFloat
            if isWide {
                stripLength = remaining.width * stripFraction
            } else {
                stripLength = remaining.height * stripFraction
            }

            var offset: CGFloat = 0
            let crossLength = isWide ? remaining.height : remaining.width

            for item in stripItems {
                let itemFraction = stripTotal > 0 ? item.size / stripTotal : 0
                let itemLength = crossLength * itemFraction

                let rect: CGRect
                if isWide {
                    rect = CGRect(
                        x: remaining.minX,
                        y: remaining.minY + offset,
                        width: stripLength,
                        height: itemLength
                    )
                } else {
                    rect = CGRect(
                        x: remaining.minX + offset,
                        y: remaining.minY,
                        width: itemLength,
                        height: stripLength
                    )
                }

                result[item.index] = rect
                offset += itemLength
            }

            // Shrink remaining area
            if isWide {
                remaining = CGRect(
                    x: remaining.minX + stripLength,
                    y: remaining.minY,
                    width: remaining.width - stripLength,
                    height: remaining.height
                )
            } else {
                remaining = CGRect(
                    x: remaining.minX,
                    y: remaining.minY + stripLength,
                    width: remaining.width,
                    height: remaining.height - stripLength
                )
            }

            startIndex += stripItems.count
        }

        return result
    }

    /// Compute the worst aspect ratio of rectangles in a strip.
    private static func worstAspect(
        sizes: [Double],
        total: Double,
        length: CGFloat,
        areaFraction: Double,
        fullLength: CGFloat
    ) -> Double {
        guard total > 0, length > 0, fullLength > 0 else { return .infinity }

        let stripWidth = Double(fullLength) * areaFraction
        guard stripWidth > 0 else { return .infinity }

        var worst: Double = 0
        for size in sizes {
            let fraction = size / total
            let h = Double(length) * fraction
            guard h > 0 else { continue }
            let aspect = max(stripWidth / h, h / stripWidth)
            worst = max(worst, aspect)
        }
        return worst
    }
}
