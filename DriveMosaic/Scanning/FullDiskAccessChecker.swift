import Foundation
import AppKit

/// Checks whether the app has Full Disk Access and guides the user to enable it.
enum FullDiskAccessChecker {

    /// Probe paths that are protected by TCC (Transparency, Consent, and Control).
    /// If we can read any of these, Full Disk Access is likely granted.
    private static let probePaths = [
        NSHomeDirectory() + "/Library/Safari",
        NSHomeDirectory() + "/Library/Mail",
        "/Library/Application Support/com.apple.TCC/TCC.db",
    ]

    /// Check if Full Disk Access appears to be granted.
    static var hasFullDiskAccess: Bool {
        for path in probePaths {
            if FileManager.default.isReadableFile(atPath: path) {
                return true
            }
        }
        return false
    }

    /// Open System Settings to the Full Disk Access pane.
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
