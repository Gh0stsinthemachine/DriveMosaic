import SwiftUI

/// Block-based treemap visualization with frosted glass aesthetic.
/// Nested rectangles proportional to file/directory size.
struct TreemapCanvasView: View {
    let root: FileNode
    let blocks: [TreemapRect]
    let onDrillDown: (FileNode) -> Void
    let onNavigateUp: () -> Void
    let onHover: (FileNode?) -> Void
    let onCollect: (FileNode) -> Void
    let canNavigateUp: Bool
    var nodeLookup: [UUID: FileNode] = [:]
    var selectedNodeID: UUID?

    @State private var hoveredBlock: TreemapRect?
    @State private var mouseLocation: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark gradient background
                LinearGradient(
                    colors: [Color(red: 0.07, green: 0.07, blue: 0.10),
                             Color(red: 0.10, green: 0.10, blue: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Treemap blocks
                Canvas { context, canvasSize in
                    drawTreemap(context: context, size: canvasSize)
                }
                .drawingGroup()

                // Navigate up button overlay
                if canNavigateUp {
                    VStack {
                        HStack {
                            Button {
                                onNavigateUp()
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "chevron.left")
                                    Text(root.name)
                                        .lineLimit(1)
                                }
                                .font(.system(size: 12, weight: .bold))
                                .tracking(-0.2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(10)

                            Spacer()
                        }
                        Spacer()
                    }
                }

                // Hover tooltip
                if let block = hoveredBlock, let mouse = mouseLocation {
                    hoverTooltip(for: block, at: mouse, in: geometry.size)
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    mouseLocation = location
                    if let hit = hitTest(point: location) {
                        if hoveredBlock?.id != hit.id {
                            hoveredBlock = hit
                            onHover(nodeLookup[hit.nodeID])
                        }
                    } else {
                        if hoveredBlock != nil {
                            hoveredBlock = nil
                            onHover(nil)
                        }
                    }
                case .ended:
                    mouseLocation = nil
                    hoveredBlock = nil
                    onHover(nil)
                }
            }
            .draggable(hoveredBlock?.nodeID.uuidString ?? "") {
                if let block = hoveredBlock, let node = nodeLookup[block.nodeID] {
                    HStack(spacing: 6) {
                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundStyle(.secondary)
                        Text(node.name)
                            .font(.system(size: 13, weight: .bold))
                            .tracking(-0.3)
                        Text(ByteFormatter.format(node.size))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("Drag to collector")
                        .font(.system(size: 11, weight: .medium))
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let location = value.location
                        let isCmdClick = NSEvent.modifierFlags.contains(.command)
                        if let hit = hitTest(point: location), let node = nodeLookup[hit.nodeID] {
                            if isCmdClick {
                                NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
                            } else if node.isDirectory {
                                onDrillDown(node)
                            }
                        }
                    }
            )
            .contextMenu {
                if let block = hoveredBlock, let node = nodeLookup[block.nodeID] {
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

    private func drawTreemap(context: GraphicsContext, size: CGSize) {
        let isHovered = hoveredBlock != nil
        let hasSelection = selectedNodeID != nil

        for block in blocks {
            let rect = block.rect
            guard rect.width > 1.5 && rect.height > 1.5 else { continue }

            let node = nodeLookup[block.nodeID]
            let hue = node?.assignedHue ?? 0
            let sat = node?.assignedSaturation ?? 0
            let bri = node?.assignedBrightness ?? 0.5
            let isFile = node?.isDirectory == false

            let isThisHovered = hoveredBlock?.id == block.id
            let isThisSelected = selectedNodeID != nil && block.nodeID == selectedNodeID

            let cornerRadius: CGFloat = block.depth == 0 ? 10 : 5
            let inset: CGFloat = block.depth == 0 ? 2.5 : 1.5
            let insetRect = rect.insetBy(dx: inset, dy: inset)
            guard insetRect.width > 0 && insetRect.height > 0 else { continue }
            let path = Path(roundedRect: insetRect, cornerRadius: cornerRadius)

            // ─── BLOCK FILL ───
            // Strong, confident fills — directories are bold, files are muted
            let fillAlpha: Double
            if isThisHovered || isThisSelected {
                fillAlpha = isFile ? 0.7 : 0.85
            } else if isHovered || hasSelection {
                fillAlpha = isFile ? 0.25 : 0.35
            } else {
                fillAlpha = isFile ? 0.45 : 0.72
            }

            let fillSat = isFile ? max(sat, 0.12) : sat
            let fillBri = isFile ? min(bri + 0.05, 0.55) : bri

            context.fill(path, with: .color(
                Color(hue: hue, saturation: fillSat, brightness: fillBri)
                    .opacity(fillAlpha)
            ))

            // ─── CONTAINMENT: Header bar for depth-0 directories ───
            if block.depth == 0 && !isFile && insetRect.height > 36 {
                let headerH: CGFloat = 26
                let headerRect = CGRect(
                    x: insetRect.minX,
                    y: insetRect.minY,
                    width: insetRect.width,
                    height: headerH
                )
                let headerPath = Path(roundedRect: headerRect,
                                      cornerRadii: .init(topLeading: cornerRadius,
                                                         bottomLeading: 0,
                                                         bottomTrailing: 0,
                                                         topTrailing: cornerRadius))

                // Slightly brighter bar at top — establishes "this is a container"
                context.fill(headerPath, with: .color(
                    Color(hue: hue, saturation: sat * 0.6, brightness: min(bri + 0.12, 0.95))
                        .opacity(isThisHovered || isThisSelected ? 0.45 : 0.28)
                ))

                // Thin separator under header
                var separatorPath = Path()
                separatorPath.move(to: CGPoint(x: insetRect.minX + 6, y: insetRect.minY + headerH))
                separatorPath.addLine(to: CGPoint(x: insetRect.maxX - 6, y: insetRect.minY + headerH))
                context.stroke(separatorPath, with: .color(
                    Color(hue: hue, saturation: sat * 0.4, brightness: 0.7).opacity(0.2)
                ), lineWidth: 0.5)
            }

            // ─── TOP EDGE HIGHLIGHT ───
            if insetRect.height > 18 && block.depth == 0 {
                let hlH = min(insetRect.height * 0.08, 10)
                let hlRect = CGRect(x: insetRect.minX + 1, y: insetRect.minY + 1,
                                    width: insetRect.width - 2, height: hlH)
                let hlPath = Path(roundedRect: hlRect,
                                  cornerRadii: .init(topLeading: cornerRadius - 1,
                                                     bottomLeading: 0,
                                                     bottomTrailing: 0,
                                                     topTrailing: cornerRadius - 1))
                context.fill(hlPath, with: .linearGradient(
                    Gradient(colors: [
                        Color(hue: hue, saturation: sat * 0.4, brightness: 0.95)
                            .opacity(0.15),
                        Color.clear
                    ]),
                    startPoint: CGPoint(x: insetRect.midX, y: insetRect.minY),
                    endPoint: CGPoint(x: insetRect.midX, y: insetRect.minY + hlH)
                ))
            }

            // ─── BORDER ───
            let borderAlpha: Double
            let borderWidth: CGFloat
            if isThisSelected {
                borderAlpha = 0.0 // selection uses its own glow below
                borderWidth = 0
            } else if isThisHovered {
                borderAlpha = 0.7
                borderWidth = 1.8
            } else if block.depth == 0 {
                borderAlpha = 0.40
                borderWidth = 1.0
            } else {
                borderAlpha = 0.15
                borderWidth = 0.5
            }

            if borderWidth > 0 {
                context.stroke(path, with: .linearGradient(
                    Gradient(colors: [
                        Color(hue: hue, saturation: sat * 0.5, brightness: 0.85)
                            .opacity(borderAlpha),
                        Color(hue: hue, saturation: sat * 0.3, brightness: 0.5)
                            .opacity(borderAlpha * 0.25)
                    ]),
                    startPoint: CGPoint(x: insetRect.midX, y: insetRect.minY),
                    endPoint: CGPoint(x: insetRect.midX, y: insetRect.maxY)
                ), lineWidth: borderWidth)
            }

            // ─── SELECTION GLOW ───
            if isThisSelected {
                context.stroke(path, with: .color(.white.opacity(0.85)), lineWidth: 2.5)
                context.stroke(path, with: .color(Color.accentColor.opacity(0.5)), lineWidth: 1.5)
            } else if isThisHovered {
                context.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 1.2)
            }

            // ─── LABEL ───
            if block.depth == 0 && insetRect.width > 60 && insetRect.height > 32 {
                drawBlockLabel(
                    context: context,
                    block: block,
                    node: node,
                    insetRect: insetRect,
                    hue: hue,
                    sat: sat
                )
            }
        }
    }

    /// Draws the label and size text for a top-level block
    private func drawBlockLabel(
        context: GraphicsContext,
        block: TreemapRect,
        node: FileNode?,
        insetRect: CGRect,
        hue: Double,
        sat: Double
    ) {
        let name = block.name
        let maxLabelW = insetRect.width - 20
        let fontSize: CGFloat = min(12, max(9, maxLabelW / max(CGFloat(name.count), 1) * 1.4))

        let labelText = Text(name)
            .font(.system(size: fontSize, weight: .bold))
            .tracking(-0.3)
            .foregroundStyle(.white.opacity(0.92))
        let resolved = context.resolve(labelText)
        let textSize = resolved.measure(in: CGSize(width: maxLabelW, height: 20))

        let px = insetRect.minX + 8
        let py = insetRect.minY + 4
        let pillW = min(textSize.width + 14, maxLabelW)
        let pillH = textSize.height + 8

        // Frosted pill
        let pillRect = CGRect(x: px, y: py, width: pillW, height: pillH)
        let pillPath = Path(roundedRect: pillRect, cornerRadius: 5)
        context.fill(pillPath, with: .color(Color(hue: hue, saturation: sat * 0.3, brightness: 0.15).opacity(0.6)))
        context.stroke(pillPath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)

        context.draw(resolved, in: CGRect(x: px + 7, y: py + 2, width: pillW - 14, height: textSize.height))

        // Size text — readable but secondary
        if let nodeSize = node?.size {
            let sizeStr = ByteFormatter.format(nodeSize)
            let sizeText = Text(sizeStr)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
            let resolvedSize = context.resolve(sizeText)
            let sizeAvail = insetRect.maxX - (px + pillW + 8) - 4
            if sizeAvail > 25 {
                context.draw(resolvedSize, in: CGRect(
                    x: px + pillW + 6,
                    y: py + 4,
                    width: sizeAvail,
                    height: textSize.height
                ))
            }
        }
    }

    // MARK: - Hit Testing

    private func hitTest(point: CGPoint) -> TreemapRect? {
        for block in blocks.reversed() {
            if block.rect.insetBy(dx: 2, dy: 2).contains(point) {
                return block
            }
        }
        return nil
    }

    // MARK: - Tooltip

    private func hoverTooltip(for block: TreemapRect, at point: CGPoint, in size: CGSize) -> some View {
        let node = nodeLookup[block.nodeID]
        let name = node?.name ?? block.name
        let formattedSize = ByteFormatter.format(node?.size ?? block.size)

        // Truncate long names
        let displayName = name.count > 32 ? String(name.prefix(14)) + "..." + String(name.suffix(14)) : name

        let tooltipWidth: CGFloat = 200
        let x = min(max(point.x + 22, tooltipWidth / 2), size.width - tooltipWidth / 2)
        let y = max(point.y - 44, 30)

        return VStack(alignment: .leading, spacing: 3) {
            Text(displayName)
                .font(.system(size: 12, weight: .bold))
                .tracking(-0.2)
                .lineLimit(1)
            Text(formattedSize)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: tooltipWidth, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .position(x: x, y: y)
    }
}
