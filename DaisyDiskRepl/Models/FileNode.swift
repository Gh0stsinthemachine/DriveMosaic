import Foundation
import SwiftUI

@Observable
final class FileNode: Identifiable, Equatable {
    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs === rhs
    }

    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    var size: UInt64
    var children: [FileNode]
    weak var parent: FileNode?

    var isConsolidated: Bool = false
    var isRestricted: Bool = false

    // Color assigned by ColorAssigner, cached for stability across navigation
    var assignedColor: Color?

    init(name: String, path: String, isDirectory: Bool, size: UInt64 = 0, children: [FileNode] = []) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.children = children
    }

    var fileCount: Int {
        if !isDirectory { return 1 }
        return children.reduce(0) { $0 + $1.fileCount }
    }

    var directoryCount: Int {
        if !isDirectory { return 0 }
        return children.reduce(1) { $0 + $1.directoryCount }
    }

    var depth: Int {
        var d = 0
        var node = parent
        while let p = node {
            d += 1
            node = p.parent
        }
        return d
    }

    /// Sort children by size descending (largest first) recursively
    func sortBySize() {
        children.sort { $0.size > $1.size }
        for child in children where child.isDirectory {
            child.sortBySize()
        }
    }

    /// Set parent references recursively after tree construction
    func setParentReferences() {
        for child in children {
            child.parent = self
            child.setParentReferences()
        }
    }

    /// Compute directory sizes bottom-up (call on root after tree is built)
    func computeSizes() {
        for child in children {
            child.computeSizes()
        }
        if isDirectory {
            size = children.reduce(0) { $0 + $1.size }
        }
    }
}
