import Foundation

/// High-performance filesystem scanner using BSD fts API.
/// Significantly faster than FileManager.enumerator for large directory trees.
final class FileScanner: Sendable {

    /// Scan a directory and stream events back to the caller.
    /// Runs synchronously — call from a detached Task.
    func scan(
        path: String,
        continuation: AsyncStream<ScanEvent>.Continuation
    ) {
        let startTime = CFAbsoluteTimeGetCurrent()
        var scannedCount = 0
        let progressInterval = 500 // Report progress every N files

        // fts_open needs a C array of C strings, NULL-terminated
        let cPath = strdup(path)!
        var paths: [UnsafeMutablePointer<CChar>?] = [cPath, nil]

        // FTS_PHYSICAL: don't follow symlinks
        // FTS_XDEV: don't cross mount points
        guard let fts = fts_open(&paths, FTS_PHYSICAL | FTS_XDEV, nil) else {
            continuation.yield(.error(path: path, message: "Failed to open directory: \(String(cString: strerror(errno)))"))
            free(cPath)
            continuation.finish()
            return
        }

        defer {
            fts_close(fts)
            free(cPath)
        }

        // Stack-based tree construction
        // We build a dictionary keyed by directory path, mapping to an array of child TransferNodes
        var childrenMap: [String: [TransferNode]] = [:]
        var sizeMap: [String: UInt64] = [:]
        var restrictedPaths: Set<String> = []

        while let entry = fts_read(fts) {
            let info = entry.pointee.fts_info
            let entryPath = String(cString: entry.pointee.fts_path)
            // fts_name is a flexible array member (char[1]) — Swift can't use it directly.
            // Derive the name from the path instead.
            let entryName = (entryPath as NSString).lastPathComponent

            switch Int32(info) {
            case FTS_F:
                // Regular file
                let fileSize = UInt64(entry.pointee.fts_statp.pointee.st_size)
                let parentPath = (entryPath as NSString).deletingLastPathComponent
                let node = TransferNode(
                    name: entryName,
                    path: entryPath,
                    isDirectory: false,
                    size: fileSize,
                    children: [],
                    isRestricted: false
                )
                childrenMap[parentPath, default: []].append(node)
                sizeMap[entryPath] = fileSize

                scannedCount += 1
                if scannedCount % progressInterval == 0 {
                    continuation.yield(.progress(scannedCount: scannedCount, currentPath: entryPath))
                }

            case FTS_D:
                // Directory, pre-order visit — initialize children array
                childrenMap[entryPath] = []

            case FTS_DP:
                // Directory, post-order visit — all children have been processed
                let children = childrenMap[entryPath] ?? []
                let dirSize = children.reduce(UInt64(0)) { $0 + $1.size }
                sizeMap[entryPath] = dirSize

                let node = TransferNode(
                    name: entryName.isEmpty ? (entryPath as NSString).lastPathComponent : entryName,
                    path: entryPath,
                    isDirectory: true,
                    size: dirSize,
                    children: children.sorted { $0.size > $1.size },
                    isRestricted: restrictedPaths.contains(entryPath)
                )

                // If this is the root, we're done
                let normalizedPath = entryPath.hasSuffix("/") ? String(entryPath.dropLast()) : entryPath
                let normalizedScanPath = path.hasSuffix("/") ? String(path.dropLast()) : path
                if normalizedPath == normalizedScanPath {
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    continuation.yield(.completed(root: node, duration: duration))
                    childrenMap.removeAll()
                    continuation.finish()
                    return
                }

                // Otherwise, add to parent's children
                let parentPath = (entryPath as NSString).deletingLastPathComponent
                childrenMap[parentPath, default: []].append(node)

                // Clean up this level's entry
                childrenMap.removeValue(forKey: entryPath)

                scannedCount += 1

            case FTS_DNR:
                // Directory that can't be read (permission denied)
                restrictedPaths.insert(entryPath)
                continuation.yield(.error(path: entryPath, message: "Permission denied"))

            case FTS_ERR:
                // General error
                let errMsg = String(cString: strerror(Int32(entry.pointee.fts_errno)))
                continuation.yield(.error(path: entryPath, message: errMsg))

            case FTS_SL, FTS_SLNONE:
                // Symbolic links — record as zero-size files
                let parentPath = (entryPath as NSString).deletingLastPathComponent
                let node = TransferNode(
                    name: entryName,
                    path: entryPath,
                    isDirectory: false,
                    size: 0,
                    children: [],
                    isRestricted: false
                )
                childrenMap[parentPath, default: []].append(node)
                scannedCount += 1

            default:
                break
            }
        }

        // If we get here without completing, something went wrong
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        continuation.yield(.error(path: path, message: "Scan ended unexpectedly after \(String(format: "%.2f", duration))s"))
        continuation.finish()
    }
}
