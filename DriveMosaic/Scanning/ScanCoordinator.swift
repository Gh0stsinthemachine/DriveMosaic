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
        var elapsedTime: TimeInterval
        var scanRate: Int  // items per second
    }

    struct ScanError: Identifiable {
        let id = UUID()
        let path: String
        let message: String
    }

    func scan(path: String) {
        cancel()

        isScanning = true
        scanProgress = ScanProgress(scannedCount: 0, currentPath: path, elapsedTime: 0, scanRate: 0)
        scanResult = nil
        scanDuration = nil
        errors = []

        let scanner = self.scanner
        let startTime = CFAbsoluteTimeGetCurrent()

        scanTask = Task.detached { [weak self] in
            let stream = AsyncStream<ScanEvent> { continuation in
                // CRITICAL: Dispatch scan to a separate thread so events
                // flow to the consumer immediately instead of buffering
                // until the synchronous scan completes.
                DispatchQueue.global(qos: .userInitiated).async {
                    scanner.scan(path: path, continuation: continuation)
                }
            }

            for await event in stream {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                await self?.handleEvent(event, elapsed: elapsed)
            }
        }
    }

    func cancel() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    private func handleEvent(_ event: ScanEvent, elapsed: TimeInterval) {
        switch event {
        case .progress(let count, let currentPath):
            let rate = elapsed > 0 ? Int(Double(count) / elapsed) : 0
            scanProgress = ScanProgress(
                scannedCount: count,
                currentPath: currentPath,
                elapsedTime: elapsed,
                scanRate: rate
            )

        case .completed(let transferRoot, let duration):
            scanProgress = ScanProgress(
                scannedCount: scanProgress?.scannedCount ?? 0,
                currentPath: "Building tree...",
                elapsedTime: elapsed,
                scanRate: scanProgress?.scanRate ?? 0
            )

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
