import SwiftUI

/// The core sunburst visualization rendered using SwiftUI Canvas.
/// Handles rendering, hover highlighting, and click interaction.
struct SunburstCanvasView: View {
    let root: FileNode
    let arcs: [ArcDescriptor]
    let onDrillDown: (FileNode) -> Void
    let onNavigateUp: () -> Void
    let onHover: (FileNode?) -> Void
    let onCollect: (FileNode) -> Void
    let canNavigateUp: Bool

    @State private var hoveredArc: ArcDescriptor?
    @State private var mouseLocation: CGPoint?

    private let config = SunburstLayout.Config()

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let totalRadius = size / 2 * 0.92 // Leave some padding
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                // Sunburst arcs
                Canvas { context, canvasSize in
                    drawSunburst(context: context, center: center, totalRadius: totalRadius)
                }
                .drawingGroup() // Metal-backed rendering

                // Center circle overlay
                centerCircle(center: center, radius: totalRadius * config.centerRadius)

                // Hover tooltip
                if let arc = hoveredArc, let mouse = mouseLocation {
                    hoverTooltip(for: arc, at: mouse, in: geometry.size)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    mouseLocation = location
                    let result = SunburstHitTesting.hitTest(
                        point: location,
                        center: center,
                        totalRadius: totalRadius,
                        centerRadius: config.centerRadius,
                        arcs: arcs
                    )
                    switch result {
                    case .arc(let arc) where !arc.isConsolidated:
                        if hoveredArc?.id != arc.id {
                            hoveredArc = arc
                            let node = findNode(for: arc)
                            onHover(node)
                        }
                    default:
                        if hoveredArc != nil {
                            hoveredArc = nil
                            onHover(nil)
                        }
                    }
                case .ended:
                    mouseLocation = nil
                    hoveredArc = nil
                    onHover(nil)
                }
            }
            .onTapGesture { location in
                let result = SunburstHitTesting.hitTest(
                    point: location,
                    center: center,
                    totalRadius: totalRadius,
                    centerRadius: config.centerRadius,
                    arcs: arcs
                )
                switch result {
                case .arc(let arc) where !arc.isConsolidated && !arc.isFile:
                    if let node = findNode(for: arc) {
                        onDrillDown(node)
                    }
                case .center:
                    if canNavigateUp {
                        onNavigateUp()
                    }
                default:
                    break
                }
            }
            .contextMenu {
                if let arc = hoveredArc, !arc.isConsolidated, let node = findNode(for: arc) {
                    Button {
                        onCollect(node)
                    } label: {
                        Label("Collect for Deletion", systemImage: "trash")
                    }

                    if node.isDirectory {
                        Button {
                            onDrillDown(node)
                        } label: {
                            Label("Drill Down", systemImage: "arrow.down.circle")
                        }
                    }

                    Divider()

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(node.path, forType: .string)
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }

                    Button {
                        NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                }
            }
        }
    }

    // MARK: - Drawing

    private func drawSunburst(context: GraphicsContext, center: CGPoint, totalRadius: Double) {
        let scale = CGFloat(totalRadius)

        for arc in arcs {
            let arcPath = arc.path(center: center, scale: scale)

            // Determine fill color
            var fillColor = arc.color
            if let hovered = hoveredArc, hovered.id == arc.id {
                // Brighten on hover
                fillColor = arc.color.opacity(1)
            } else if hoveredArc != nil {
                // Dim non-hovered arcs slightly
                fillColor = arc.color.opacity(0.7)
            }

            // Draw filled arc
            context.fill(arcPath, with: .color(fillColor))

            // Draw border
            context.stroke(
                arcPath,
                with: .color(.black.opacity(0.15)),
                lineWidth: 0.5
            )

            // Highlight border for hovered arc
            if let hovered = hoveredArc, hovered.id == arc.id {
                context.stroke(
                    arcPath,
                    with: .color(.white),
                    lineWidth: 2
                )
            }

            // Striped pattern for consolidated arcs
            if arc.isConsolidated {
                drawConsolidatedPattern(context: context, arc: arc, center: center, scale: scale)
            }
        }
    }

    private func drawConsolidatedPattern(context: GraphicsContext, arc: ArcDescriptor, center: CGPoint, scale: CGFloat) {
        // Draw diagonal lines across the consolidated arc to indicate "smaller items"
        let innerR = arc.innerRadius * Double(scale)
        let outerR = arc.outerRadius * Double(scale)
        let midAngle = arc.midAngle - .pi / 2 // Convert to CG coordinates
        let lineCount = 3

        for i in 0..<lineCount {
            let fraction = Double(i + 1) / Double(lineCount + 1)
            let angle = Angle(radians: arc.startAngle + arc.sweepAngle * fraction - .pi / 2)

            var linePath = Path()
            linePath.move(to: CGPoint(
                x: center.x + CGFloat(innerR * cos(angle.radians)),
                y: center.y + CGFloat(innerR * sin(angle.radians))
            ))
            linePath.addLine(to: CGPoint(
                x: center.x + CGFloat(outerR * cos(angle.radians)),
                y: center.y + CGFloat(outerR * sin(angle.radians))
            ))

            context.stroke(linePath, with: .color(.white.opacity(0.4)), lineWidth: 1)
        }
    }

    // MARK: - Center Circle

    private func centerCircle(center: CGPoint, radius: Double) -> some View {
        VStack(spacing: 2) {
            Text(root.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            Text(ByteFormatter.format(root.size))
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()

            if canNavigateUp {
                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: radius * 1.4, height: radius * 1.4)
        .position(center)
    }

    // MARK: - Hover Tooltip

    private func hoverTooltip(for arc: ArcDescriptor, at point: CGPoint, in size: CGSize) -> some View {
        let node = findNode(for: arc)
        let name = node?.name ?? "Unknown"
        let formattedSize = ByteFormatter.format(node?.size ?? 0)

        // Position tooltip near cursor but keep it within bounds
        let tooltipWidth: CGFloat = 200
        let tooltipHeight: CGFloat = 50
        let x = min(max(point.x + 20, tooltipWidth / 2), size.width - tooltipWidth / 2)
        let y = max(point.y - 40, tooltipHeight / 2)

        return VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(formattedSize)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        .position(x: x, y: y)
    }

    // MARK: - Helpers

    private func findNode(for arc: ArcDescriptor) -> FileNode? {
        findNode(id: arc.nodeID, in: root)
    }

    private func findNode(id: UUID, in node: FileNode) -> FileNode? {
        if node.id == id { return node }
        for child in node.children {
            if let found = findNode(id: id, in: child) {
                return found
            }
        }
        return nil
    }

    private func cursorForCurrentState(center: CGPoint, totalRadius: Double) -> NSCursor {
        guard let mouse = mouseLocation else { return .arrow }
        let result = SunburstHitTesting.hitTest(
            point: mouse,
            center: center,
            totalRadius: totalRadius,
            centerRadius: config.centerRadius,
            arcs: arcs
        )
        switch result {
        case .arc(let arc) where arc.isFile || arc.isConsolidated:
            return .arrow
        case .arc:
            return .pointingHand
        case .center where canNavigateUp:
            return .pointingHand
        default:
            return .arrow
        }
    }
}

// MARK: - Cursor modifier

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
