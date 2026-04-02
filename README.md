# NTFS4Mac

A free, lightweight macOS tool for NTFS read/write support. Built with SwiftUI for macOS 14+ (Sonoma, Sequoia, Tahoe).

No Electron. No bloat. Native macOS app, ~400KB.

Built with Swift 6.2 on macOS 26 SDK, deployment target macOS 14 (Sonoma).

![Screenshot](assets/NTFS.png)

## Features

- **One-click read-write mount** - Remount NTFS volumes via ntfs-3g with a single click
- **Auto device detection** - File system watcher + polling detects new drives in real time
- **Open in Finder** - Quick access to mounted volumes
- **Native macOS feel** - SwiftUI, dark mode, minimal UI
- **CLI included** - Full-featured command-line tool for scripts and automation

## How It Works

macOS natively mounts NTFS volumes as read-only. This tool remounts them in read-write mode using the [ntfs-3g](https://github.com/tuxera/ntfs-3g) driver via [fuse-t](https://github.com/macos-fuse-t/fuse-t).

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
| **fuse-t** | File system framework (user-space FUSE) | Download from [fuse-t releases](https://github.com/macos-fuse-t/fuse-t/releases) |
| **ntfs-3g** | NTFS read-write driver | `brew tap gromgit/fuse && brew install ntfs-3g-mac` |
| **fswatch** *(optional)* | Instant device detection | `brew install fswatch` |

### Install fuse-t

1. Download `fuse-t-macos-installer-X.X.X.pkg` from [fuse-t releases](https://github.com/macos-fuse-t/fuse-t/releases)
2. Double-click to install
3. Grant **Full Disk Access** to `fuse-t.app` in System Settings > Privacy & Security

### Link fuse-t library

After installing fuse-t, link the library for ntfs-3g:

```bash
sudo mv /usr/local/lib/libfuse.2.dylib /usr/local/lib/libfuse.2.dylib.bak
sudo ln -sf libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
```

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

- **RW** (green) = Read-write mode via fuse-t
- **RO** (orange) = Read-only mode (macOS native)
- **--** (gray) = Not mounted

Click the folder icon to open the volume in Finder.

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

## Known Issues

- **Windows Fast Startup**: If a drive was hibernated in Windows, ntfs-3g may fail to mount. Fix: fully shut down Windows (not sleep) before connecting the drive.
- **First launch on macOS**: You may need to right-click > Open the app on first launch, since it's not signed.

## Requirements for Distribution

To distribute as a signed and notarized app:

1. Apple Developer account ($99/year)
2. Code signing: `codesign --sign "Developer ID Application: ..." NTFS4Mac.app`
3. Notarize: `xcrun notarytool submit NTFS4Mac.dmg --apple-id ... --team-id ... --password ...`
4. Gatekeeper will then allow the app without the right-click workaround

## License

MIT License

Copyright (c) 2026 zhouyeyu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
