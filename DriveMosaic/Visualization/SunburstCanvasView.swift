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
    /// O(1) node lookup — provided by AppState
    var nodeLookup: [UUID: FileNode] = [:]
    /// ID of node selected via sidebar click — highlighted distinctly
    var selectedNodeID: UUID?

    @State private var hoveredArc: ArcDescriptor?
    @State private var mouseLocation: CGPoint?
    @State private var draggedNodeID: String?

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
            .draggable(hoveredArc?.nodeID.uuidString ?? "") {
                // Drag preview: show the hovered item name
                if let arc = hoveredArc, let node = findNode(for: arc) {
                    HStack(spacing: 6) {
                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundStyle(.secondary)
                        Text(node.name)
                            .font(.callout)
                        Text(ByteFormatter.format(node.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("Drag to collector")
                        .font(.caption)
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
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

            let isHovered = hoveredArc?.id == arc.id
            let isSelected = selectedNodeID != nil && arc.nodeID == selectedNodeID

            // Determine fill color
            var fillColor = arc.color
            if isHovered {
                fillColor = arc.color.opacity(1)
            } else if isSelected {
                fillColor = arc.color.opacity(1)
            } else if hoveredArc != nil || selectedNodeID != nil {
                // Dim non-highlighted arcs
                fillColor = arc.color.opacity(0.55)
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
            if isHovered {
                context.stroke(
                    arcPath,
                    with: .color(.white),
                    lineWidth: 2
                )
            }

            // Selected arc: bright white border with glow effect
            if isSelected {
                context.stroke(
                    arcPath,
                    with: .color(.white),
                    lineWidth: 3
                )
                context.stroke(
                    arcPath,
                    with: .color(.accentColor.opacity(0.6)),
                    lineWidth: 1.5
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

    /// O(1) node lookup via dictionary instead of O(n) tree walk
    private func findNode(for arc: ArcDescriptor) -> FileNode? {
        nodeLookup[arc.nodeID]
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
