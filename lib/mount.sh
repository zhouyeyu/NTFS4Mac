#!/bin/bash
# Mount, unmount, restore operations

# ============================================================
# Mount device as read-write via ntfs-3g
# ============================================================
mount_device() {
    local device="$1"
    local dev="$(dev_path "$device")"

    # Verify device exists
    diskutil info "$dev" &>/dev/null || error "Device $dev not found."

    # Verify it's NTFS
    local fs_type
    fs_type="$(diskutil info "$dev" 2>/dev/null | grep "Type (Bundle):" | awk -F': ' '{print $2}')" || true
    [[ "$fs_type" != *NTFS* ]] && [[ "$fs_type" != *ntfs* ]] && \
        error "$dev is not NTFS (type: ${fs_type:-unknown})."

    # Check if already mounted read-write via ntfs-3g
    if mount | grep -q "ntfs-3g.*$(dev_name "$dev")"; then
        warn "Already mounted as read-write via ntfs-3g."
        return 0
    fi

    # Get volume name
    local vol_name mount_point
    vol_name="$(diskutil info "$dev" 2>/dev/null | grep "Volume Name:" | awk -F': ' '{print $2}')" || true
    vol_name="${vol_name:-$(dev_name "$dev")}"

    # Get current mount point (if mounted read-only by macOS)
    mount_point="$(diskutil info "$dev" 2>/dev/null | grep "Mount Point:" | awk -F': ' '{print $2}')" || true

    # Unmount existing read-only mount
    if [ -n "$mount_point" ]; then
        info "Unmounting macOS read-only mount..."
        sudo umount -f "$dev" 2>/dev/null || \
            sudo diskutil unmount force "$dev" >/dev/null 2>&1 || \
            error "Failed to unmount $dev. Close any apps using this volume and try again."
        ok "Unmounted."
        sleep 0.5
    fi

    # Ensure mount point directory exists
    sudo mkdir -p "/Volumes/$vol_name"

    # Find ntfs-3g
    local ntfs3g
    ntfs3g="$(find_ntfs3g)" || error "ntfs-3g not found. Run: brew install ntfs-3g-mac"

    # Mount via ntfs-3g
    info "Mounting $dev as read-write..."
    local mount_args=(
        "$ntfs3g"
        "$dev"
        "/Volumes/$vol_name"
        -o auto_xattr
        -o volname="$vol_name"
        -o local
    )

    # Run with timeout to avoid hanging (Windows Fast Startup issue)
    local mount_result=0
    if command -v timeout >/dev/null 2>&1; then
        timeout 15 sudo "${mount_args[@]}" 2>&1 || mount_result=$?
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout 15 sudo "${mount_args[@]}" 2>&1 || mount_result=$?
    else
        sudo "${mount_args[@]}" 2>&1 &
        local pid=$!
        local waited=0
        while kill -0 "$pid" 2>/dev/null && [ $waited -lt 15 ]; do
            sleep 1
            waited=$((waited + 1))
        done
        if kill -0 "$pid" 2>/dev/null; then
            sudo kill -9 "$pid" 2>/dev/null
            mount_result=124
        else
            wait "$pid" 2>/dev/null
            mount_result=$?
        fi
    fi

    if [ $mount_result -eq 0 ]; then
        ok "Mounted: /Volumes/$vol_name"
        # Create marker for watch mode
        sudo touch "/tmp/ntfs_mounted_$(dev_name "$dev")" 2>/dev/null || true
    elif [ $mount_result -eq 124 ]; then
        error "Mount timed out (15s). Possible causes:
  - Windows Fast Startup / Hibernation enabled on the drive
  - Corrupted NTFS filesystem
  Fix: Fully shut down Windows (not sleep), or run: ntfsfix /dev/$device"
    else
        error "Mount failed (exit code $mount_result).
  Try: ntfs-3g $dev /Volumes/$vol_name -o force"
    fi
}

# ============================================================
# Unmount device
# ============================================================
unmount_device() {
    local device="$1"
    local dev="$(dev_path "$device")"

    # Try ntfs-3g unmount first
    if mount | grep -q "ntfs-3g.*$(dev_name "$dev")"; then
        info "Unmounting ntfs-3g mount..."
        sudo umount -f "$dev" 2>/dev/null || \
            error "Failed to unmount $dev."
    else
        info "Unmounting $dev..."
        sudo diskutil unmount force "$dev" >/dev/null 2>&1 || \
            error "Failed to unmount $dev."
    fi

    # Clean marker
    sudo rm -f "/tmp/ntfs_mounted_$(dev_name "$dev")" 2>/dev/null || true
    ok "Unmounted."
}

# ============================================================
# Eject device (physical removal)
# ============================================================
eject_device() {
    local device="$1"
    local dev="$(dev_path "$device")"

    # First unmount if mounted via ntfs-3g
    if mount | grep -q "ntfs-3g.*$(dev_name "$dev")"; then
        info "Unmounting ntfs-3g mount..."
        sudo umount -f "$dev" 2>/dev/null || true
        sudo rm -f "/tmp/ntfs_mounted_$(dev_name "$dev")" 2>/dev/null || true
        sleep 0.5
    fi

    info "Ejecting $dev..."
    sudo diskutil eject "$dev" >/dev/null 2>&1 || \
        error "Failed to eject $dev."

    ok "Ejected. Safe to remove."
}

# ============================================================
# Restore to macOS read-only mount
# ============================================================
restore_readonly() {
    local device="$1"
    local dev="$(dev_path "$device")"

    # Unmount ntfs-3g mount
    if mount | grep -q "ntfs-3g.*$(dev_name "$dev")"; then
        info "Unmounting ntfs-3g mount..."
        sudo umount -f "$dev" 2>/dev/null || \
            error "Failed to unmount $dev."

        sudo rm -f "/tmp/ntfs_mounted_$(dev_name "$dev")" 2>/dev/null || true
        sleep 0.5

        # Let macOS auto-remount as read-only
        info "Waiting for macOS to auto-remount as read-only..."
        local retries=0
        while [ $retries -lt 10 ]; do
            if mount | grep -q "ntfs.*$(dev_name "$dev")"; then
                ok "Restored to macOS read-only mount."
                return 0
            fi
            sleep 1
            retries=$((retries + 1))
        done

        # Force mount if auto-remount didn't happen
        info "Auto-remount didn't trigger, forcing..."
        sudo diskutil mount "$dev" >/dev/null 2>&1 && \
            ok "Restored to macOS read-only mount." || \
            warn "Could not restore. macOS may remount it on reconnection."
    else
        # Check if it's a macOS native mount (already read-only)
        if mount | grep -q "ntfs.*$(dev_name "$dev")"; then
            warn "Already mounted as macOS read-only."
        else
            warn "Device $dev is not currently mounted."
        fi
    fi
}
