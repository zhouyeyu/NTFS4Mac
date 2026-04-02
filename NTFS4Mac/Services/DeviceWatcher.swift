import Foundation
import Combine

// MARK: - File System Watcher

@Observable
final class DeviceWatcher: @unchecked Sendable {
    private var timer: Timer?
    private var source: DispatchSourceFileSystemObject?
    private let interval: TimeInterval = 3.0
    var onDeviceChange: (@MainActor @Sendable () async -> Void)?

    @MainActor
    func start() {
        stop()

        // Use FSEvents via DispatchSource for /dev monitoring
        let devFD = Darwin.open("/dev", O_EVTONLY)
        guard devFD >= 0 else {
            // Fallback to polling
            startPolling()
            return
        }

        let queue = DispatchQueue(label: "com.ntfs4mac.watcher")
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: devFD,
            eventMask: .write,
            queue: queue
        )

        let callback = onDeviceChange
        source?.setEventHandler {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                await callback?()
            }
        }

        source?.setCancelHandler {
            close(devFD)
        }

        source?.resume()

        // Also start polling as a safety net
        startPolling()
    }

    @MainActor
    private func startPolling() {
        let callback = onDeviceChange
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                await callback?()
            }
        }
    }

    @MainActor
    func stop() {
        source?.cancel()
        source = nil
        timer?.invalidate()
        timer = nil
    }
}
