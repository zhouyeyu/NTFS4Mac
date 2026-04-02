import Foundation

// MARK: - Mount Service

@Observable
@MainActor
final class MountService: Sendable {
    private let ntfs3gPath: String?

    init(ntfs3gPath: String? = nil) {
        if let ntfs3gPath {
            self.ntfs3gPath = ntfs3gPath
        } else {
            self.ntfs3gPath = Self.resolveNTFS3GPath()
        }
    }

    var isNTFS3GAvailable: Bool { ntfs3gPath != nil }

    private static func resolveNTFS3GPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ntfs-3g",
            "/usr/local/bin/ntfs-3g"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    // MARK: - Mount as read-write

    func mount(device: NTFSDevice) async throws {
        guard let ntfs3gPath else {
            throw MountError.ntfs3gNotFound
        }

        let mountPath = "/Volumes/\(device.displayName)"

        // Step 1: Unmount any existing mounts for this device
        // This includes both macOS native and potential duplicate mounts
        _ = try? await Shell.runWithSudo("/sbin/umount", arguments: ["-f", device.diskNode])

        // Also try diskutil unmount
        _ = try? await Shell.run("/usr/sbin/diskutil", arguments: ["unmount", "force", device.diskNode])

        try await Task.sleep(nanoseconds: 500_000_000)

        // Step 2: Clean up mount point
        var cleanupArgs = ["-rf", mountPath]
        _ = try? await Shell.runWithSudo("/bin/rm", arguments: cleanupArgs)

        // Step 3: Create fresh mount point
        _ = try await Shell.runWithSudo("/bin/mkdir", arguments: ["-p", mountPath])

        try await Task.sleep(nanoseconds: 200_000_000)

        // Step 4: Mount via ntfs-3g with fuse-t
        let result = try await Shell.runWithSudo(ntfs3gPath, arguments: [
            device.diskNode,
            mountPath,
            "-o", "auto_xattr",
            "-o", "volname=\(device.displayName)",
            "-o", "local"
        ])

        if result.exitCode != 0 {
            throw MountError.mountFailed(code: result.exitCode)
        }
    }

    // MARK: - Unmount

    func unmount(device: NTFSDevice) async throws {
        // Try umount first
        let result = try await Shell.runWithSudo("/sbin/umount", arguments: ["-f", device.diskNode])
        if result.exitCode != 0 {
            // Fallback to diskutil
            _ = try? await Shell.run("/usr/sbin/diskutil", arguments: ["unmount", "force", device.diskNode])
        }
    }

    // MARK: - Eject

    func eject(device: NTFSDevice) async throws {
        _ = try? await Shell.runWithSudo("/sbin/umount", arguments: ["-f", device.diskNode])
        try await Task.sleep(nanoseconds: 500_000_000)
        _ = try? await Shell.run("/usr/sbin/diskutil", arguments: ["eject", device.diskNode])
    }

    // MARK: - Restore read-only

    func restore(device: NTFSDevice) async throws {
        guard device.isReadWrite else {
            throw MountError.alreadyReadOnly
        }

        _ = try? await Shell.runWithSudo("/sbin/umount", arguments: ["-f", device.diskNode])
        try await Task.sleep(nanoseconds: 500_000_000)

        // Let macOS auto-remount, or force it
        _ = try? await Shell.run("/usr/sbin/diskutil", arguments: ["mount", device.diskNode])
    }
}

// MARK: - Errors

enum MountError: LocalizedError, Sendable {
    case ntfs3gNotFound
    case mountFailed(code: Int32)
    case unmountFailed
    case timeout
    case alreadyReadOnly

    var errorDescription: String? {
        switch self {
        case .ntfs3gNotFound:
            return "ntfs-3g not found. Install: brew install ntfs-3g-mac"
        case .mountFailed(let code):
            return "Mount failed (exit code \(code)). The drive may be in hibernation from Windows."
        case .unmountFailed:
            return "Unmount failed. Close any apps using this volume."
        case .timeout:
            return "Mount timed out. Possible Windows Fast Startup issue."
        case .alreadyReadOnly:
            return "Device is already read-only."
        }
    }
}
