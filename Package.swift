// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NTFS4Mac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NTFS4Mac",
            path: "NTFS4Mac"
        )
    ]
)
