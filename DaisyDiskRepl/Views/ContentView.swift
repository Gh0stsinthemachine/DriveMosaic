import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        VStack(spacing: 0) {
            if let root = appState.currentRoot {
                // Breadcrumb bar with scan duration
                HStack {
                    BreadcrumbBar(nodes: appState.breadcrumbs) { index in
                        appState.navigateTo(index: index)
                    }

                    if let duration = appState.lastScanDuration {
                        Text(String(format: "%.1fs", duration))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()

                // Main content: sidebar + sunburst + detail
                MainContentView(root: root)

                // Collector bar at the bottom
                CollectorView(items: $state.collectorItems) {
                    appState.deleteCollectorItems()
                }

            } else if appState.coordinator.isScanning {
                ScanProgressOverlay(progress: appState.coordinator.scanProgress)
            } else {
                // Disk selector / welcome
                DiskSelectorView(
                    onScanVolume: { path in
                        appState.scan(path: path)
                    },
                    onChooseFolder: {
                        chooseFolder()
                    }
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: appState.coordinator.scanResult) {
            appState.onScanComplete()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if appState.currentRoot != nil {
                    Button {
                        appState.goHome()
                    } label: {
                        Label("Home", systemImage: "house")
                    }
                }
            }

            if appState.canNavigateUp {
                ToolbarItem(placement: .navigation) {
                    Button {
                        appState.navigateUp()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    chooseFolder()
                } label: {
                    Label("Scan Folder", systemImage: "folder.badge.gearshape")
                }
            }

            if appState.currentRoot != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let root = appState.scanRoot {
                            appState.scan(path: root.path)
                        }
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .onKeyPress(.escape) {
            if appState.canNavigateUp {
                appState.navigateUp()
                return .handled
            }
            return .ignored
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to scan"

        if panel.runModal() == .OK, let url = panel.url {
            appState.scan(path: url.path)
        }
    }
}

// MARK: - Main Content (Sidebar + Sunburst + Detail)

struct MainContentView: View {
    @Environment(AppState.self) private var appState
    let root: FileNode

    @State private var arcs: [ArcDescriptor] = []

    var body: some View {
        HSplitView {
            // Left sidebar
            SidebarView(root: root, hoveredNode: appState.hoveredNode)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)

            // Center: sunburst
            SunburstCanvasView(
                root: root,
                arcs: arcs,
                onDrillDown: { node in
                    appState.drillDown(to: node)
                },
                onNavigateUp: {
                    appState.navigateUp()
                },
                onHover: { node in
                    appState.hoveredNode = node
                },
                onCollect: { node in
                    appState.addToCollector(node: node)
                },
                canNavigateUp: appState.canNavigateUp
            )
            .frame(minWidth: 400)
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))

            // Right detail panel
            DetailPanelView(node: appState.hoveredNode, root: root)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
        }
        .onAppear { rebuildLayout() }
        .onChange(of: root) { rebuildLayout() }
    }

    private func rebuildLayout() {
        ColorAssigner.assignColors(root: root)
        arcs = SunburstLayout.layout(root: root)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    let root: FileNode
    let hoveredNode: FileNode?

    var body: some View {
        List {
            Section("Contents") {
                ForEach(root.children.prefix(30)) { child in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColorAssigner.color(for: child))
                            .frame(width: 12, height: 12)

                        Image(systemName: child.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(child.name)
                            .font(.callout)
                            .lineLimit(1)

                        Spacer()

                        Text(ByteFormatter.format(child.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 1)
                    .background(
                        hoveredNode?.id == child.id
                            ? Color.accentColor.opacity(0.1)
                            : Color.clear
                    )
                }
            }

            Section("Summary") {
                LabeledContent("Total Size", value: ByteFormatter.format(root.size))
                LabeledContent("Files", value: root.fileCount.formatted())
                LabeledContent("Folders", value: root.directoryCount.formatted())
            }
            .font(.caption)
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Detail Panel

struct DetailPanelView: View {
    let node: FileNode?
    let root: FileNode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let node {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                            .font(.title2)
                            .foregroundStyle(ColorAssigner.color(for: node))
                        Text(node.name)
                            .font(.headline)
                            .lineLimit(2)
                    }

                    Divider()

                    DetailRow(label: "Size", value: ByteFormatter.format(node.size))

                    if root.size > 0 {
                        let percentage = Double(node.size) / Double(root.size) * 100
                        DetailRow(label: "Percentage", value: String(format: "%.1f%%", percentage))

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(.quaternary)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(ColorAssigner.color(for: node))
                                    .frame(width: geo.size.width * min(percentage / 100, 1))
                            }
                        }
                        .frame(height: 6)
                    }

                    if node.isDirectory {
                        DetailRow(label: "Files", value: node.fileCount.formatted())
                        DetailRow(label: "Folders", value: node.directoryCount.formatted())
                    }

                    DetailRow(label: "Path", value: node.path)

                    if node.isRestricted {
                        Label("Access restricted", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()

                Spacer()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cursorarrow.rays")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Hover over the chart\nto see details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.callout)
                .lineLimit(3)
        }
    }
}

// MARK: - Breadcrumb Bar

struct BreadcrumbBar: View {
    let nodes: [FileNode]
    let onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button {
                    onTap(index)
                } label: {
                    Text(node.name)
                        .font(.callout)
                        .fontWeight(index == nodes.count - 1 ? .semibold : .regular)
                        .foregroundStyle(index == nodes.count - 1 ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Scan Progress Overlay

struct ScanProgressOverlay: View {
    let progress: ScanCoordinator.ScanProgress?
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 6)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))

                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Text("Scanning...")
                .font(.title2)
                .fontWeight(.semibold)

            if let progress {
                Text("\(progress.scannedCount.formatted()) items scanned")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Text(progress.currentPath)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}
