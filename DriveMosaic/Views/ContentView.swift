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
                            .font(.system(size: 10, weight: .regular))
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
                CollectorView(
                    items: $state.collectorItems,
                    isPro: appState.licenseManager.isPro,
                    onDelete: {
                        appState.deleteCollectorItems()
                    },
                    onUpgrade: {
                        appState.showProUpgrade = true
                    },
                    onDropNodeID: { idString in
                        appState.collectNodeByID(idString)
                    }
                )

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
                    },
                    onUpgrade: {
                        appState.showProUpgrade = true
                    },
                    isPro: appState.licenseManager.isPro
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onChange(of: appState.coordinator.scanResult) {
            appState.onScanComplete()
        }
        .sheet(isPresented: $state.showProUpgrade) {
            ProUpgradeView()
                .environment(appState)
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

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appState.showSidebar.toggle()
                        }
                    } label: {
                        Label("Toggle Sidebar", systemImage: "sidebar.left")
                    }
                    .help("Toggle sidebar")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            appState.showDetailPanel.toggle()
                        }
                    } label: {
                        Label("Toggle Detail", systemImage: "sidebar.right")
                    }
                    .help("Toggle detail panel")
                }
            }

            ToolbarItem(placement: .status) {
                Button {
                    appState.showProUpgrade = true
                } label: {
                    Text(appState.licenseManager.isPro ? "Pro" : "Free")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.3)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            appState.licenseManager.isPro
                                ? Color.green.opacity(0.2)
                                : Color.purple.opacity(0.2),
                            in: Capsule()
                        )
                        .foregroundStyle(
                            appState.licenseManager.isPro ? .green : .purple
                        )
                }
                .buttonStyle(.plain)
                .help(appState.licenseManager.isPro ? "DriveMosaic Pro — Licensed" : "Upgrade to DriveMosaic Pro")
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

// MARK: - Main Content (Sidebar + Treemap + Detail)

struct MainContentView: View {
    @Environment(AppState.self) private var appState
    let root: FileNode

    @State private var blocks: [TreemapRect] = []
    @State private var treemapSize: CGSize = .zero

    var body: some View {
        HStack(spacing: 0) {
            // Left sidebar — full collapse/expand
            if appState.showSidebar {
                SidebarView(
                    root: root,
                    hoveredNode: appState.hoveredNode,
                    selectedNode: appState.selectedNode,
                    onSelect: { node in
                        if node.isDirectory {
                            appState.drillDown(to: node)
                        } else {
                            appState.selectedNode = appState.selectedNode?.id == node.id ? nil : node
                        }
                    }
                )
                .frame(width: 230)
                .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
            }

            // Center: treemap blocks
            GeometryReader { geo in
                TreemapCanvasView(
                    root: root,
                    blocks: blocks,
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
                    canNavigateUp: appState.canNavigateUp,
                    nodeLookup: appState.nodeLookup,
                    selectedNodeID: appState.selectedNode?.id
                )
                .onChange(of: geo.size) { _, newSize in
                    treemapSize = newSize
                    rebuildLayout(in: newSize)
                }
                .onAppear {
                    treemapSize = geo.size
                    rebuildLayout(in: geo.size)
                }
            }
            .padding(6)
            .background(Color(red: 0.08, green: 0.08, blue: 0.11))

            // Right detail panel — full collapse/expand, dark background
            if appState.showDetailPanel {
                Divider()

                DetailPanelView(node: appState.hoveredNode ?? appState.selectedNode, root: root)
                    .frame(width: 230)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onChange(of: root) { rebuildLayout(in: treemapSize) }
    }

    private func rebuildLayout(in size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        blocks = TreemapLayout.layout(root: root, bounds: bounds)
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    let root: FileNode
    let hoveredNode: FileNode?
    let selectedNode: FileNode?
    let onSelect: (FileNode) -> Void

    var body: some View {
        List {
            Section {
                ForEach(root.children.prefix(50)) { child in
                    Button {
                        if NSEvent.modifierFlags.contains(.command) {
                            NSWorkspace.shared.selectFile(child.path, inFileViewerRootedAtPath: "")
                        } else {
                            onSelect(child)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ColorAssigner.color(for: child))
                                .frame(width: 12, height: 12)

                            Image(systemName: child.isDirectory ? "folder.fill" : "doc.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(child.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(-0.2)
                                    .lineLimit(1)
                                if let date = child.lastModified {
                                    Text(date, style: .date)
                                        .font(.system(size: 9, weight: .regular))
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            Text(ByteFormatter.format(child.size))
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(
                            selectedNode?.id == child.id
                                ? Color.accentColor.opacity(0.2)
                                : hoveredNode?.id == child.id
                                    ? Color.accentColor.opacity(0.08)
                                    : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Contents")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
            }

            Section {
                LabeledContent("Total Size", value: ByteFormatter.format(root.size))
                LabeledContent("Files", value: root.fileCount.formatted())
                LabeledContent("Folders", value: root.directoryCount.formatted())
            } header: {
                Text("Summary")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
            }
            .font(.system(size: 11, weight: .regular))
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Detail Panel

struct DetailPanelView: View {
    let node: FileNode?
    let root: FileNode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let node {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(ColorAssigner.color(for: node))
                            Text(node.name)
                                .font(.system(size: 15, weight: .bold))
                                .tracking(-0.3)
                                .lineLimit(2)
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.08))

                        DetailRow(label: "Size", value: ByteFormatter.format(node.size))

                        if root.size > 0 {
                            let percentage = Double(node.size) / Double(root.size) * 100
                            DetailRow(label: "Percentage", value: String(format: "%.1f%%", percentage))

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.white.opacity(0.08))
                                    RoundedRectangle(cornerRadius: 4)
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

                        VStack(alignment: .leading, spacing: 2) {
                            Text("PATH")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(.secondary)
                            Text(node.path)
                                .font(.system(size: 11, weight: .regular))
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .help(node.path)
                        }

                        if let modified = node.lastModified {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("LAST MODIFIED")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundStyle(.secondary)
                                Text(modified, style: .date)
                                    .font(.system(size: 12, weight: .regular))
                            }
                        }

                        if node.isRestricted {
                            Label("Access restricted", systemImage: "lock.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.orange)
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.08))

                        Button {
                            NSWorkspace.shared.selectFile(node.path, inFileViewerRootedAtPath: "")
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "cursorarrow.rays")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        Text("Hover over the chart\nto see details")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .padding(.top, 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(red: 0.06, green: 0.06, blue: 0.08))
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 12, weight: .regular))
                .lineLimit(3)
        }
    }
}

// MARK: - Breadcrumb Bar

struct BreadcrumbBar: View {
    let nodes: [FileNode]
    let onTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                Button {
                    onTap(index)
                } label: {
                    Text(node.name)
                        .font(.system(size: 12, weight: index == nodes.count - 1 ? .bold : .regular))
                        .tracking(-0.2)
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
            // Disclaimer at top
            Text("Scan time depends on the size of the volume or folder.\nLarge drives may take several minutes.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

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
                HStack(spacing: 16) {
                    // Items count
                    VStack(spacing: 2) {
                        Text(progress.scannedCount.formatted())
                            .font(.system(size: 18, weight: .bold))
                            .monospacedDigit()
                        Text("items scanned")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }

                    if progress.elapsedTime > 1 {
                        Divider()
                            .frame(height: 30)

                        // Elapsed time
                        VStack(spacing: 2) {
                            Text(String(format: "%.0fs", progress.elapsedTime))
                                .font(.system(size: 18, weight: .bold))
                                .monospacedDigit()
                            Text("elapsed")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }

                        Divider()
                            .frame(height: 30)

                        // Scan rate
                        VStack(spacing: 2) {
                            Text("\(progress.scanRate.formatted())/s")
                                .font(.system(size: 18, weight: .bold))
                                .monospacedDigit()
                            Text("scan rate")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .foregroundStyle(.secondary)

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
