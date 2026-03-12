import Foundation

/// Coordinates filesystem scanning on a background thread and delivers
/// results to the main actor via @Observable properties.
@Observable
@MainActor
final class ScanCoordinator {
    var isScanning = false
    var scanProgress: ScanProgress?
    var scanResult: FileNode?
    var scanDuration: TimeInterval?
    var errors: [ScanError] = []

    private var scanTask: Task<Void, Never>?
    private let scanner = FileScanner()

    struct ScanProgress {
        var scannedCount: Int
        var currentPath: String
    }

    struct ScanError: Identifiable {
        let id = UUID()
        let path: String
        let message: String
    }

    func scan(path: String) {
        cancel()

        isScanning = true
        scanProgress = ScanProgress(scannedCount: 0, currentPath: path)
        scanResult = nil
        scanDuration = nil
        errors = []

        let scanner = self.scanner

        scanTask = Task.detached { [weak self] in
            let stream = AsyncStream<ScanEvent> { continuation in
                scanner.scan(path: path, continuation: continuation)
            }

            for await event in stream {
                await self?.handleEvent(event)
            }
        }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    private func handleEvent(_ event: ScanEvent) {
        switch event {
        case .progress(let count, let currentPath):
            scanProgress = ScanProgress(scannedCount: count, currentPath: currentPath)

        case .completed(let transferRoot, let duration):
            let root = transferRoot.toFileNode()
            root.setParentReferences()
            root.sortBySize()

            scanResult = root
            scanDuration = duration
            isScanning = false

        case .error(let path, let message):
            errors.append(ScanError(path: path, message: message))

        case .cancelled:
            isScanning = false
        }
    }
}
