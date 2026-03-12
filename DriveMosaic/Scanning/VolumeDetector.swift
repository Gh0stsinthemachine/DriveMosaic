import Foundation

/// Detects mounted volumes and provides disk space information.
enum VolumeDetector {

    struct Volume: Identifiable {
        let id = UUID()
        let name: String
        let mountPoint: String
        let totalBytes: UInt64
        let freeBytes: UInt64
        let isRemovable: Bool
        let isInternal: Bool

        var usedBytes: UInt64 { totalBytes - freeBytes }
        var usedFraction: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(usedBytes) / Double(totalBytes)
        }
    }

    /// Discover all mounted volumes
    static func detectVolumes() -> [Volume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey,
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        return urls.compactMap { url -> Volume? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
                return nil
            }

            let name = values.volumeName ?? url.lastPathComponent
            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let importantFree = values.volumeAvailableCapacityForImportantUsage.map { UInt64($0) }
            let basicFree = values.volumeAvailableCapacity.map { UInt64($0) }
            let free = importantFree ?? basicFree ?? 0

            guard total > 0 else { return nil }

            return Volume(
                name: name,
                mountPoint: url.path,
                totalBytes: total,
                freeBytes: free,
                isRemovable: values.volumeIsRemovable ?? false,
                isInternal: values.volumeIsInternal ?? true
            )
        }
    }
}
