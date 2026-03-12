import Foundation

enum ScanEvent: Sendable {
    case progress(scannedCount: Int, currentPath: String)
    case completed(root: TransferNode, duration: TimeInterval)
    case error(path: String, message: String)
    case cancelled
}

/// A sendable snapshot of a file node, used to transfer scan results
/// from the background scanner to the main actor.
struct TransferNode: Sendable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: UInt64
    let children: [TransferNode]
    let isRestricted: Bool

    func toFileNode() -> FileNode {
        let node = FileNode(
            name: name,
            path: path,
            isDirectory: isDirectory,
            size: size,
            children: children.map { $0.toFileNode() }
        )
        node.isRestricted = isRestricted
        return node
    }
}
