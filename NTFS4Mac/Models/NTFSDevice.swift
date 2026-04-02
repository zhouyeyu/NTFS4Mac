import AppKit

// MARK: - NTFS Device Model

struct NTFSDevice: Identifiable, Hashable, Sendable {
    let id: String          // e.g. "disk4s1"
    let diskNode: String    // e.g. "/dev/disk4s1"
    let volumeName: String
    let fileSystem: String
    let size: String        // e.g. "500.1 GB"
    let usedSpace: String
    let availableSpace: String

    var mountPoint: String?
    var isReadWrite: Bool   // true = ntfs-3g mounted
    var isMounted: Bool     // mounted at all

    var displayName: String { volumeName.isEmpty ? id : volumeName }

    var statusText: String {
        if !isMounted { return "Unmounted" }
        return isReadWrite ? "Read-Write" : "Read-Only"
    }

    var statusColor: String {
        if !isMounted { return "gray" }
        return isReadWrite ? "green" : "orange"
    }
}
