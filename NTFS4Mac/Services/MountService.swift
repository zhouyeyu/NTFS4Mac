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

        // Unmount existing macOS read-only mount
        if device.isMounted && !device.isReadWrite {
            _ = try? await Shell.runWithSudo("/sbin/umount", arguments: ["-f", device.diskNode])
            try await Task.sleep(nanoseconds: 500_000_000)
        }

        // Ensure mount point exists (requires admin privileges for /Volumes)
        if !FileManager.default.fileExists(atPath: mountPath) {
            _ = try await Shell.runWithSudo("/bin/mkdir", arguments: ["-p", mountPath])
        }

        // Mount via ntfs-3g
        let result = try await Shell.runWithSudo(ntfs3gPath, arguments: [device.diskNode, mountPath, "-o", "auto_xattr", "-o", "volname=\(device.displayName)", "-o", "local"])

        if result.exitCode != 0 {
            if result.exitCode == 124 || result.exitCode == 137 {
                throw MountError.timeout
            }
            throw MountError.mountFailed(code: result.exitCode)
        }
    }

    // MARK: - Unmount

    func unmount(device: NTFSDevice) async throws {
        if device.isReadWrite {
            let result = try await Shell.runWithSudo("/sbin/umount", arguments: ["-f", device.diskNode])
            if result.exitCode != 0 {
                throw MountError.unmountFailed
            }
        } else {
            _ = try? await Shell.runDiskutil(["unmount", "force", device.diskNode])
        }
    }

    // MARK: - Eject

    func eject(device: NTFSDevice) async throws {
        if device.isReadWrite {
            _ = try? await Shell.runWithSudo("/sbin/umount", arguments: ["-f", device.diskNode])
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        _ = try? await Shell.runDiskutil(["eject", device.diskNode])
    }

    // MARK: - Restore read-only

    func restore(device: NTFSDevice) async throws {
        guard device.isReadWrite else {
            throw MountError.alreadyReadOnly
        }

        _ = try? await Shell.runWithSudo("/sbin/umount", arguments: ["-f", device.diskNode])
        try await Task.sleep(nanoseconds: 500_000_000)

        // Let macOS auto-remount, or force it
        _ = try? await Shell.runDiskutil(["mount", device.diskNode])
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
