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
            // Get mount output once
            let mountOutput = try await Shell.run("/sbin/mount")

            // Get external disks
            let output = try await Shell.run("/usr/sbin/diskutil", arguments: ["list", "external", "physical"])
            let diskIDs = parseDiskIDs(from: output)

            var found: [NTFSDevice] = []
            for diskID in diskIDs {
                let partitions = try? await Shell.run("/usr/sbin/diskutil", arguments: ["list", "/dev/\(diskID)"])
                let partIDs = parsePartitionIDs(from: partitions ?? "")

                for partID in partIDs {
                    if let device = try? await fetchDeviceInfo(partID, mountOutput: mountOutput) {
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

    private func fetchDeviceInfo(_ partID: String, mountOutput: String) async throws -> NTFSDevice? {
        let output = try await Shell.run("/usr/sbin/diskutil", arguments: ["info", "/dev/\(partID)"])
        let info = parseDiskutilInfo(output)

        // Filter: only NTFS
        guard info["fsType"]?.contains("NTFS") == true ||
              info["fsType"]?.contains("ntfs") == true else {
            return nil
        }

        let volumeName = info["volumeName"] ?? partID

        // Check mount status from mount output
        // fuse-t mount: "fuse-t:/VolumeName on /Volumes/VolumeName (nfs)"
        // macOS mount: "/dev/diskXsY on /Volumes/VolumeName (ntfs, ...read-only...)"

        var isRW = false
        var isMounted = false
        var mountPoint: String? = nil

        for line in mountOutput.components(separatedBy: "\n") {
            // Check for fuse-t mount (read-write)
            if line.contains("fuse-t:/\(volumeName)") || line.contains("fuse-t:/\(volumeName) ") {
                // Extract mount point
                if let range = line.range(of: " on ") {
                    let afterOn = line[range.upperBound...]
                    if let endRange = afterOn.range(of: " (") {
                        let mp = String(afterOn[..<endRange.lowerBound])
                        // Verify the mount is actually writable
                        if FileManager.default.isWritableFile(atPath: mp) {
                            isRW = true
                            isMounted = true
                            mountPoint = mp
                        } else {
                            // fuse-t mount exists but not writable - mark as mounted but not RW
                            isMounted = true
                            mountPoint = mp
                        }
                    }
                }
                break
            }

            // Check for ntfs-3g mount (read-write)
            if line.contains("ntfs-3g") && line.contains(partID) {
                isRW = true
                isMounted = true
                // Extract mount point
                if let range = line.range(of: " on ") {
                    let afterOn = line[range.upperBound...]
                    if let endRange = afterOn.range(of: " (") {
                        mountPoint = String(afterOn[..<endRange.lowerBound])
                    }
                }
                break
            }

            // Check for macOS native mount (read-only)
            if line.contains(partID) && line.contains("ntfs") {
                isMounted = true
                if let range = line.range(of: " on ") {
                    let afterOn = line[range.upperBound...]
                    if let endRange = afterOn.range(of: " (") {
                        mountPoint = String(afterOn[..<endRange.lowerBound])
                    }
                }
            }
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
