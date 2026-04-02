#!/bin/bash
# NTFS4Mac CLI - macOS NTFS Read/Write Tool
# Compatible with macOS 14+ (Sonoma, Sequoia, Tahoe)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/common.sh"

# ============================================================
# Usage
# ============================================================
show_help() {
    cat <<EOF
$(bold NTFS4Mac CLI) - Free NTFS read/write tool for macOS

$(bold USAGE:)
  ntfs-cli list                     List all NTFS devices
  ntfs-cli mount <device>           Mount device as read-write (e.g. disk4s1)
  ntfs-cli unmount <device>         Unmount device
  ntfs-cli eject <device>           Eject device
  ntfs-cli restore <device>         Restore to macOS read-only mount
  ntfs-cli watch                    Monitor and auto-mount new NTFS devices
  ntfs-cli status                   Show NTFS device status overview
  ntfs-cli deps                     Check dependencies (macfuse, ntfs-3g, fswatch)
  ntfs-cli help                     Show this help

$(bold EXAMPLES:)
  ntfs-cli list                     # Show all external NTFS devices
  ntfs-cli mount disk4s1            # Mount /dev/disk4s1 as read-write
  ntfs-cli unmount disk4s1          # Unmount device
  ntfs-cli watch                    # Auto-mount new NTFS devices

$(bold DEPENDENCIES:)
  - macOS 14+ (Sonoma, Sequoia, Tahoe)
  - Homebrew: brew install --cask macfuse && brew install ntfs-3g-mac
  - Optional: brew install fswatch (for watch mode)
EOF
}

# ============================================================
# Main
# ============================================================
ACTION="${1:-help}"
shift 2>/dev/null || true

case "$ACTION" in
    list)
        source "$LIB_DIR/devices.sh"
        list_ntfs_devices
        ;;
    mount)
        [ -z "${1:-}" ] && error "Usage: ntfs-cli mount <device>  (e.g. disk4s1)"
        source "$LIB_DIR/deps.sh"
        check_ntfs3g
        source "$LIB_DIR/devices.sh"
        source "$LIB_DIR/mount.sh"
        mount_device "$1"
        ;;
    unmount)
        [ -z "${1:-}" ] && error "Usage: ntfs-cli unmount <device>"
        source "$LIB_DIR/devices.sh"
        source "$LIB_DIR/mount.sh"
        unmount_device "$1"
        ;;
    eject)
        [ -z "${1:-}" ] && error "Usage: ntfs-cli eject <device>"
        source "$LIB_DIR/devices.sh"
        source "$LIB_DIR/mount.sh"
        eject_device "$1"
        ;;
    restore)
        [ -z "${1:-}" ] && error "Usage: ntfs-cli restore <device>"
        source "$LIB_DIR/deps.sh"
        check_ntfs3g
        source "$LIB_DIR/devices.sh"
        source "$LIB_DIR/mount.sh"
        restore_readonly "$1"
        ;;
    watch)
        source "$LIB_DIR/deps.sh"
        check_ntfs3g
        source "$LIB_DIR/devices.sh"
        source "$LIB_DIR/mount.sh"
        source "$LIB_DIR/detect.sh"
        watch_ntfs_devices
        ;;
    status)
        source "$LIB_DIR/devices.sh"
        show_status
        ;;
    deps)
        source "$LIB_DIR/deps.sh"
        check_all_deps
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $ACTION. Run 'ntfs-cli help' for usage."
        ;;
esac
