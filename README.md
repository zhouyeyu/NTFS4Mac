# NTFS4Mac

A free, lightweight macOS tool for NTFS read/write support. Built with SwiftUI for macOS 14+ (Sonoma, Sequoia, Tahoe).

No Electron. No bloat. Native macOS app, ~400KB.

Built with Swift 6.2 on macOS 26 SDK, deployment target macOS 14 (Sonoma).

## Features

- **One-click read-write mount** - Remount NTFS volumes via ntfs-3g with a single click
- **Auto device detection** - File system watcher + polling detects new drives in real time
- **Restore read-only** - Switch back to macOS native read-only mount anytime
- **Safe unmount & eject** - Properly unmount or eject with ntfs-3g cleanup
- **Native macOS feel** - SwiftUI, dark mode, minimal UI
- **CLI included** - Full-featured command-line tool for scripts and automation

## How It Works

macOS natively mounts NTFS volumes as read-only. This tool remounts them in read-write mode using the [ntfs-3g](https://github.com/tuxera/ntfs-3g) driver via [macFUSE](https://macfuse.io/).

Under the hood, it executes three system commands:

```bash
# 1. Unmount macOS read-only mount
sudo umount -f /dev/diskXsY

# 2. Remount as read-write via ntfs-3g
sudo ntfs-3g /dev/diskXsY /Volumes/NAME -o auto_xattr -o local

# 3. Restore read-only (optional)
sudo umount -f /dev/diskXsY && diskutil mount /dev/diskXsY
```

That's it. No magic, no proprietary drivers.

## Requirements

| OS | Status |
|---|---|
| **macOS 26 (Tahoe)** | Tested & verified |
| **macOS 15 (Sequoia)** | Compatible (untested) |
| **macOS 14 (Sonoma)** | Compatible (untested) |

## Prerequisites

| Dependency | Purpose | Install |
|---|---|---|
| **macOS 14+** | Required | System Settings > Software Update |
| **macFUSE 5.x** | File system framework | `brew install --cask macfuse` (restart required) |
| **ntfs-3g** | NTFS read-write driver | `brew tap gromgit/fuse && brew install ntfs-3g-mac` |
| **fswatch** *(optional)* | Instant device detection | `brew install fswatch` |

## Install

### GUI App

Download the latest [DMG from Releases](../../releases) and drag `NTFS4Mac.app` to `/Applications`.

Or build from source:

```bash
git clone https://github.com/YOUR_USERNAME/NTFS4Mac.git
cd NTFS4Mac
bash build-dmg.sh
```

### CLI Tool

```bash
git clone https://github.com/YOUR_USERNAME/NTFS4Mac.git
cd NTFS4Mac
make install
```

## Usage

### GUI

Launch `NTFS4Mac.app`. Insert an NTFS drive. Click **Mount RW**.

### CLI

```bash
ntfs-cli list               # List all NTFS devices
ntfs-cli mount disk4s1      # Mount as read-write
ntfs-cli unmount disk4s1    # Unmount
ntfs-cli eject disk4s1      # Eject (safe to remove)
ntfs-cli restore disk4s1    # Restore macOS read-only
ntfs-cli watch              # Auto-mount new NTFS devices
ntfs-cli status             # Show mount status
ntfs-cli deps               # Check dependencies
```

## Build

```bash
# Build GUI app
swift build -c release

# Build and package DMG
bash build-dmg.sh

# Build CLI only
make install PREFIX=/usr/local
```

## Project Structure

```
NTFS4Mac/
├── NTFS4Mac/                    # SwiftUI macOS app
│   ├── App/NTFS4MacApp.swift
│   ├── Models/NTFSDevice.swift
│   ├── Services/
│   │   ├── Shell.swift          # Shell command execution
│   │   ├── DeviceService.swift  # Device discovery (diskutil)
│   │   ├── MountService.swift   # Mount/unmount/restore
│   │   └── DeviceWatcher.swift  # Hot-plug detection
│   └── Views/
│       ├── DeviceListView.swift
│       └── DeviceRow.swift
├── lib/                         # CLI scripts
├── ntfs-cli.sh                  # CLI entry point
├── Package.swift                # Swift package definition
├── build-dmg.sh                 # DMG packaging script
└── Makefile                     # CLI install/uninstall
```

## Comparison

| | NTFS4Mac | Free-NTFS-for-Mac | Mounty |
|---|---|---|---|
| **Framework** | SwiftUI (native) | Electron | Native |
| **App Size** | ~400 KB | ~150 MB | ~5 MB |
| **Memory** | ~20 MB | ~200 MB | ~30 MB |
| **macOS 26** | Supported | Not yet | Supported (v2.4) |
| **Device Monitoring** | FSEvents + polling | fswatch + polling | Polling only |
| **CLI** | Included | Separate scripts | No |
| **Open Source** | MIT | MIT | GPL-3.0 |

## Known Issues

- **Windows Fast Startup**: If a drive was hibernated in Windows, ntfs-3g may fail to mount. Fix: fully shut down Windows (not sleep) before connecting the drive.
- **First launch on macOS**: You may need to right-click > Open the app on first launch, since it's not signed.
- **macFUSE on macOS 26**: macFUSE 5.x supports the new FSKit backend on macOS 26, so no recovery mode reboot is needed. However, you still need to allow the system extension in System Settings.

## Requirements for Distribution

To distribute as a signed and notarized app:

1. Apple Developer account ($99/year)
2. Code signing: `codesign --sign "Developer ID Application: ..." NTFS4Mac.app`
3. Notarize: `xcrun notarytool submit NTFS4Mac.dmg --apple-id ... --team-id ... --password ...`
4. Gatekeeper will then allow the app without the right-click workaround

## License

[MIT](LICENSE)
