import Foundation

// MARK: - Device Service

@Observable
@MainActor
final class DeviceService {
    var devices: [NTFSDevice] = []
    var isRefreshing = false

    private var ntfs3gPath: String?

    init() {
        resolveNTFS3GPath()
    }

    // MARK: - Find ntfs-3g binary

    private func resolveNTFS3GPath() {
        let candidates = [
            "/opt/homebrew/bin/ntfs-3g",
            "/usr/local/bin/ntfs-3g"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                ntfs3gPath = path
                return
            }
        }
        // Try `which` synchronously via Process
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ntfs-3g"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let which = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !which.isEmpty {
                ntfs3gPath = which
            }
        } catch {}
    }

    var isNTFS3GAvailable: Bool {
        ntfs3gPath != nil
    }

    // MARK: - Discover Devices

    @MainActor
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let output = try await Shell.run("/usr/sbin/diskutil", arguments: ["list", "external"])
            let diskIDs = parseDiskIDs(from: output)

            var found: [NTFSDevice] = []
            for diskID in diskIDs {
                let partitions = try? await Shell.run("/usr/sbin/diskutil", arguments: ["list", "/dev/\(diskID)"])
                let partIDs = parsePartitionIDs(from: partitions ?? "")

                for partID in partIDs {
                    if let device = try? await fetchDeviceInfo(partID) {
                        found.append(device)
                    }
                }
            }
            self.devices = found
        } catch {
            print("Failed to list devices: \(error)")
        }
    }

    // MARK: - Parse diskutil output

    private func parseDiskIDs(from output: String) -> [String] {
        let pattern = "disk[0-9]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(output.startIndex..., in: output)
        let matches = regex.matches(in: output, range: range)
        return matches
            .compactMap { Range($0.range, in: output).map { String(output[$0]) } }
            .removingDuplicates()
    }

    private func parsePartitionIDs(from output: String) -> [String] {
        let pattern = "(disk[0-9]+s[0-9]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(output.startIndex..., in: output)
        let matches = regex.matches(in: output, range: range)
        return matches
            .compactMap { Range($0.range, in: output).map { String(output[$0]) } }
            .removingDuplicates()
    }

    // MARK: - Fetch single device info

    private func fetchDeviceInfo(_ partID: String) async throws -> NTFSDevice? {
        let output = try await Shell.run("/usr/sbin/diskutil", arguments: ["info", "/dev/\(partID)"])
        let info = parseDiskutilInfo(output)

        // Filter: only NTFS
        guard info["fsType"]?.contains("NTFS") == true ||
              info["fsType"]?.contains("ntfs") == true else {
            return nil
        }

        let volumeName = info["volumeName"] ?? partID
        let mountOutput = try? await Shell.run("/sbin/mount")

        // Check if mounted via fuse-t (read-write)
        let isFuseMount = mountOutput?.contains("fuse-t:/\(volumeName)") == true

        // Check if mounted via ntfs-3g (read-write)
        let isNtfs3gMount = mountOutput?.contains("ntfs-3g") == true && mountOutput?.contains(partID) == true

        let isRW = isFuseMount || isNtfs3gMount

        // Check if mounted at all (including macOS native read-only mount)
        let isMacOSMount = mountOutput?.contains(partID) == true && mountOutput?.contains("ntfs") == true
        let isMounted = isRW || isMacOSMount

        // Determine actual mount point
        var mountPoint: String? = nil
        if isFuseMount {
            mountPoint = "/Volumes/\(volumeName)"
        } else if let mp = info["mountPoint"], mp != "Not mounted" {
            mountPoint = mp
        }

        return NTFSDevice(
            id: partID,
            diskNode: "/dev/\(partID)",
            volumeName: volumeName,
            fileSystem: info["fsType"] ?? "NTFS",
            size: info["diskSize"] ?? "Unknown",
            usedSpace: info["usedSpace"] ?? "",
            availableSpace: info["freeSpace"] ?? "",
            mountPoint: mountPoint,
            isReadWrite: isRW,
            isMounted: isMounted
        )
    }

    private func parseDiskutilInfo(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "Type (Bundle)":
                result["fsType"] = value
            case "Volume Name":
                result["volumeName"] = (value == "Not applicable (no file system)") ? "" : value
            case "Mount Point":
                result["mountPoint"] = (value == "Not mounted") ? nil : value
            case "Disk Size":
                // Extract human-readable size: "500.1 GB (...)
                if let parenRange = value.range(of: "(", options: []) {
                    result["diskSize"] = String(value[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                } else {
                    result["diskSize"] = value
                }
            case "Volume Used Space":
                if let parenRange = value.range(of: "(", options: []) {
                    result["usedSpace"] = String(value[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                } else {
                    result["usedSpace"] = value
                }
            case "Volume Free Space":
                if let parenRange = value.range(of: "(", options: []) {
                    result["freeSpace"] = String(value[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                } else {
                    result["freeSpace"] = value
                }
            default:
                break
            }
        }
        return result
    }
}

// MARK: - Array extension

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
