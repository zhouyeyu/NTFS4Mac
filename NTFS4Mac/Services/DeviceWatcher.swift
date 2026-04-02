import Foundation

// MARK: - File System Watcher

@Observable
final class DeviceWatcher {
    private var timer: Timer?
    private let interval: TimeInterval = 3.0
    var onDeviceChange: (() -> Void)?

    func start() {
        stop()
        startPolling()
    }

    private func startPolling() {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onDeviceChange?()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
