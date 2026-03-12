import Foundation

enum ByteFormatter {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    /// Format bytes into a human-readable string (e.g., "1.23 GB")
    static func format(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0 B" }

        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1000 && unitIndex < units.count - 1 {
            value /= 1000
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }

    /// Format bytes using binary units (KiB, MiB, GiB)
    static func formatBinary(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
