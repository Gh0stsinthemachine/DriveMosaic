import Foundation
import SwiftUI

/// Root application state, observable by all views.
@Observable
@MainActor
final class AppState {
    var coordinator = ScanCoordinator()

    /// The currently focused node for the sunburst display.
    var currentRoot: FileNode?

    /// Navigation stack for drill-down
    var navigationStack: [FileNode] = []

    /// Currently hovered node in the sunburst
    var hoveredNode: FileNode?

    /// Items collected for potential deletion
    var collectorItems: [CollectorItem] = []

    /// Whether to show the disk selector (welcome/home screen)
    var showDiskSelector: Bool = true

    /// Scan duration for display
    var lastScanDuration: TimeInterval?

    var scanRoot: FileNode? {
        navigationStack.first ?? currentRoot
    }

    func scan(path: String) {
        showDiskSelector = false
        navigationStack = []
        currentRoot = nil
        hoveredNode = nil
        lastScanDuration = nil
        coordinator.scan(path: path)
    }

    func onScanComplete() {
        if let root = coordinator.scanResult {
            currentRoot = root
            navigationStack = [root]
            lastScanDuration = coordinator.scanDuration
        }
    }

    func drillDown(to node: FileNode) {
        guard node.isDirectory else { return }
        navigationStack.append(node)
        currentRoot = node
        hoveredNode = nil
    }

    func navigateUp() {
        guard navigationStack.count > 1 else { return }
        navigationStack.removeLast()
        currentRoot = navigationStack.last
        hoveredNode = nil
    }

    func navigateTo(index: Int) {
        guard index < navigationStack.count else { return }
        navigationStack = Array(navigationStack.prefix(index + 1))
        currentRoot = navigationStack.last
        hoveredNode = nil
    }

    /// Add a node to the collector
    func addToCollector(node: FileNode) {
        guard !collectorItems.contains(where: { $0.id == node.id }) else { return }
        collectorItems.append(CollectorItem(from: node))
    }

    /// Move all collector items to Trash
    func deleteCollectorItems() {
        var deletedPaths: [String] = []
        for item in collectorItems {
            let url = URL(fileURLWithPath: item.path)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                deletedPaths.append(item.path)
            } catch {
                // Skip items that fail to delete
            }
        }

        collectorItems.removeAll()

        // Re-scan to update the tree if we deleted anything
        if !deletedPaths.isEmpty, let root = scanRoot {
            scan(path: root.path)
        }
    }

    func goHome() {
        showDiskSelector = true
        currentRoot = nil
        navigationStack = []
        hoveredNode = nil
        coordinator.scanResult = nil
    }

    var canNavigateUp: Bool {
        navigationStack.count > 1
    }

    var breadcrumbs: [FileNode] {
        navigationStack
    }
}
