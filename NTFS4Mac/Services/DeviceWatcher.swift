import Foundation
import Combine

// MARK: - File System Watcher

@Observable
final class DeviceWatcher: @unchecked Sendable {
    private var timer: Timer?
    private var source: DispatchSourceFileSystemObject?
    private let interval: TimeInterval = 3.0
    var onDeviceChange: (() async -> Void)?

    @MainActor
    func start() {
        stop()

        // Use FSEvents via DispatchSource for /dev monitoring
        let devFD = open("/dev", O_EVTONLY)
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

        source?.setEventHandler { [weak self] in
            Task { @MainActor in
                // Debounce: wait briefly before triggering refresh
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self?.onDeviceChange?()
            }
        }

        source?.setCancelHandler {
            close(devFD)
        }

        source?.resume()

        // Also start polling as a safety net
        startPolling()
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.onDeviceChange?()
            }
        }
    }

    func stop() {
        source?.cancel()
        source = nil
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}

private func open(_ path: String, _ flags: Int32) -> Int32 {
    return Darwin.open(path, flags)
}
