#!/bin/bash
# Device hot-plug detection and auto-mount

# ============================================================
# Cleanup markers for removed devices
# ============================================================
cleanup_markers() {
    for marker in /tmp/ntfs_mounted_*; do
        [ -f "$marker" ] || continue
        local dev
        dev="$(basename "$marker" | sed 's/ntfs_mounted_//')"
        if ! mount | grep -q "/dev/$dev"; then
            sudo rm -f "$marker" 2>/dev/null || true
        fi
    done
}

# ============================================================
# Polling-based device monitoring
# ============================================================
watch_ntfs_devices() {
    info "Watching for NTFS devices (Ctrl+C to stop)..."
    echo ""

    local poll_interval=3
    local use_fswatch=false

    # Try fswatch for instant detection
    if command -v fswatch >/dev/null 2>&1; then
        info "Using fswatch for instant detection."
        use_fswatch=true
    else
        warn "fswatch not found, using polling every ${poll_interval}s."
        warn "Install fswatch for instant detection: brew install fswatch"
        echo ""
    fi

    # Trap cleanup
    trap 'echo ""; info "Stopped."; exit 0' INT TERM

    if [ "$use_fswatch" = true ]; then
        # fswatch mode: event-driven
        fswatch -r -l 2 --event Created --event Updated \
            /dev /Volumes 2>/dev/null | while read -r _event; do
            handle_new_devices
        done
    else
        # Polling mode
        while true; do
            cleanup_markers
            handle_new_devices
            sleep "$poll_interval"
        done
    fi
}

# ============================================================
# Handle newly detected NTFS devices
# ============================================================
handle_new_devices() {
    # Get all ntfs mounted devices
    local ntfs_lines
    ntfs_lines="$(mount | grep ntfs)" || true
    [ -z "$ntfs_lines" ] && return 0

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        # Skip ntfs-3g mounts (already handled)
        echo "$line" | grep -q "ntfs-3g" && continue

        local dev vol
        dev="$(echo "$line" | awk '{print $1}')"
        vol="$(echo "$line" | awk '{split($3, a, "/"); print a[3]}')"

        # Skip already-processed devices
        [ -f "/tmp/ntfs_mounted_$(dev_name "$dev")" ] && continue

        echo ""
        info "New NTFS device detected: $vol ($dev)"
        mount_device "$(dev_name "$dev")"
        echo ""
    done <<< "$ntfs_lines"
}
