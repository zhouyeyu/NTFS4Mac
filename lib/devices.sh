#!/bin/bash
# Device discovery and management

# ============================================================
# List all external NTFS devices
# ============================================================
list_ntfs_devices() {
    # Get all external disk identifiers
    local external_disks
    external_disks="$(diskutil list external 2>/dev/null | grep -oE 'disk[0-9]+' | sort -u)" || true

    if [ -z "$external_disks" ]; then
        info "No external disks found."
        return 0
    fi

    echo ""
    bold "NTFS Devices"
    echo "─────────────────────────────────────────────────────────────"
    printf "  %-12s %-20s %-10s %-8s %s\n" "DEVICE" "VOLUME" "SIZE" "MODE" "MOUNT POINT"
    echo "─────────────────────────────────────────────────────────────"

    local found=0
    local disk_entry
    while IFS= read -r disk_entry; do
        [ -z "$disk_entry" ] && continue

        # Get all partitions for this disk
        local partitions
        partitions="$(diskutil list "/dev/$disk_entry" 2>/dev/null \
            | grep -oE 'disk[0-9]+s[0-9]+' \
            | sort -u)" || true

        while IFS= read -r part; do
            [ -z "$part" ] && continue

            # Get filesystem type
            local fs_type
            fs_type="$(diskutil info "/dev/$part" 2>/dev/null \
                | grep "Type (Bundle):" | awk -F': ' '{print $2}')" || true

            # Only show NTFS partitions
            [[ "$fs_type" != *NTFS* ]] && [[ "$fs_type" != *ntfs* ]] && continue

            # Get volume name
            local vol_name
            vol_name="$(diskutil info "/dev/$part" 2>/dev/null \
                | grep "Volume Name:" | awk -F': ' '{print $2}')" || true
            vol_name="${vol_name:-$(echo "$part")}"

            # Get mount point
            local mount_point
            mount_point="$(diskutil info "/dev/$part" 2>/dev/null \
                | grep "Mount Point:" | awk -F': ' '{print $2}')" || true

            # Get size
            local size
            size="$(diskutil info "/dev/$part" 2>/dev/null \
                | grep "Disk Size:" | sed 's/.*(\(.*\))/\1/' | tr -d ' ')" || true

            # Check mount mode
            local mode="RO"
            if [ -n "$mount_point" ]; then
                # Check if mounted via ntfs-3g (read-write)
                if mount | grep -q "ntfs-3g.*$part"; then
                    mode="RW"
                else
                    mode="RO"
                fi
            else
                mode="--"
            fi

            printf "  ${CYAN}%-12s${NC} %-20s %-10s %-8s %s\n" \
                "$part" "$vol_name" "${size:-N/A}" "$mode" "${mount_point:-not mounted}"
            found=1
        done <<< "$partitions"
    done <<< "$external_disks"

    echo "─────────────────────────────────────────────────────────────"

    if [ "$found" -eq 0 ]; then
        info "No NTFS partitions found on external disks."
    else
        echo ""
        echo "  RO = read-only (macOS native)  RW = read-write (ntfs-3g)  -- = unmounted"
    fi
    echo ""
}

# ============================================================
# Show NTFS status overview
# ============================================================
show_status() {
    echo ""
    bold "NTFS Status Overview"
    echo "─────────────────────────────────────────────────────────────"

    # ntfs-3g mounted devices
    local rw_count=0
    local ro_count=0
    local unmounted_count=0

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local dev part vol
        dev="$(echo "$line" | awk '{print $1}')"
        part="$(dev_name "$dev")"
        vol="$(echo "$line" | awk '{print $3}')"
        ok "  $part -> $vol (read-write via ntfs-3g)"
        rw_count=$((rw_count + 1))
    done < <(mount | grep "ntfs-3g" || true)

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local dev part vol
        dev="$(echo "$line" | awk '{print $1}')"
        part="$(dev_name "$dev")"
        vol="$(echo "$line" | awk '{print $3}')"
        # Skip if already counted as ntfs-3g
        mount | grep -q "ntfs-3g.*$part" && continue
        [ "$rw_count" -gt 0 ] && warn "  $part -> $vol (read-only)"
        [ "$rw_count" -eq 0 ] && warn "  $part -> $vol (read-only)"
        ro_count=$((ro_count + 1))
    done < <(mount | grep ntfs | grep -v "ntfs-3g" || true)

    echo "─────────────────────────────────────────────────────────────"
    echo "  Read-write (ntfs-3g): $rw_count"
    echo "  Read-only (macOS):    $ro_count"
    echo ""
}
