#!/bin/bash
# Common utilities: colors, logging, path helpers

# ============================================================
# Colors (auto-detect terminal support)
# ============================================================
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# ============================================================
# Logging
# ============================================================
info()  { echo -e "${BLUE}i${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}!${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; exit 1; }
bold()  { echo -e "${BOLD}$*${NC}"; }

# ============================================================
# Device path helpers
# ============================================================
# Normalize device input: accept "disk4s1" or "/dev/disk4s1"
dev_path() {
    local d="$1"
    [[ "$d" == /* ]] && echo "$d" || echo "/dev/$d"
}

dev_name() {
    local d="$1"
    echo "${d#/dev/}"
}

# ============================================================
# macOS version check
# ============================================================
check_macos() {
    local ver
    ver="$(sw_vers -productVersion 2>/dev/null)" || true
    local major="${ver%%.*}"

    if [ -z "$major" ] || [ "$major" -lt 14 ]; then
        warn "macOS $ver detected. This tool requires macOS 14 (Sonoma) or later."
        echo "  Some features may not work. Continue anyway..."
    fi
}

# ============================================================
# Find ntfs-3g binary
# ============================================================
find_ntfs3g() {
    local path
    path="$(which ntfs-3g 2>/dev/null)" || true
    [ -n "$path" ] && echo "$path" && return 0

    for p in /opt/homebrew/bin/ntfs-3g /usr/local/bin/ntfs-3g; do
        [ -f "$p" ] && echo "$p" && return 0
    done

    return 1
}
