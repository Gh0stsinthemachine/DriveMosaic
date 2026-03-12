import Foundation

/// An item queued in the collector for potential deletion.
struct CollectorItem: Identifiable {
    let id: UUID
    let name: String
    let path: String
    let size: UInt64
    let isDirectory: Bool

    init(from node: FileNode) {
        self.id = node.id
        self.name = node.name
        self.path = node.path
        self.size = node.size
        self.isDirectory = node.isDirectory
    }
}
