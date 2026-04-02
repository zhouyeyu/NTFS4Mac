#!/bin/bash
# Dependency checking

# ============================================================
# Check all dependencies
# ============================================================
check_all_deps() {
    echo ""
    bold "Dependency Check"
    echo "─────────────────────────────────────────────────────────────"

    check_macos
    echo ""

    check_dep "macOS"     "sw_vers"   ""                         "System"
    check_dep "Homebrew"  "brew"      "https://brew.sh"          "brew install --cask macfuse && brew install ntfs-3g-mac"
    check_dep "macFUSE"   "brew"      ""                         "brew list --cask macfuse"
    check_dep "ntfs-3g"   "ntfs-3g"   ""                         "brew install ntfs-3g-mac"
    check_dep "fswatch"   "fswatch"   "https://emcrisostomo.github.io/fswatch/" "brew install fswatch"

    echo "─────────────────────────────────────────────────────────────"
    echo ""
}

# ============================================================
# Check a single dependency
# ============================================================
check_dep() {
    local name="$1"
    local cmd="$2"
    local url="$3"
    local install_hint="$4"
    local found=false
    local version=""

    case "$name" in
        macOS)
            version="$(sw_vers -productVersion 2>/dev/null)" || version="unknown"
            if [ -n "$version" ]; then
                local major="${version%%.*}"
                if [ "$major" -ge 14 ]; then
                    ok "  macOS $version"
                else
                    warn "  macOS $version (14+ recommended)"
                fi
            else
                warn "  macOS (unknown version)"
            fi
            return
            ;;
        Homebrew)
            if command -v brew >/dev/null 2>&1; then
                version="$(brew --version 2>/dev/null | head -1)"
                ok "  Homebrew $version"
            else
                warn "  Homebrew not found"
                [ -n "$url" ] && echo "    Install: $url"
                [ -n "$install_hint" ] && echo "    Then: $install_hint"
            fi
            return
            ;;
        macFUSE)
            # Check via brew or kernel extension
            if brew list --cask macfuse &>/dev/null 2>&1; then
                version="$(brew info --cask macfuse 2>/dev/null | grep macfuse | head -1 | awk '{print $2}')"
                ok "  macFUSE ${version:-installed}"
            elif kextstat 2>/dev/null | grep -q fuse; then
                ok "  macFUSE (loaded)"
            else
                warn "  macFUSE not found"
                echo "    Install: $install_hint"
            fi
            return
            ;;
        *)
            if command -v "$cmd" >/dev/null 2>&1; then
                version="$($cmd --version 2>/dev/null | head -1 || true)"
                ok "  $name ${version:+($version)}"
            else
                warn "  $name not found"
                [ -n "$url" ] && echo "    Install: $url"
                [ -n "$install_hint" ] && echo "    Then: $install_hint"
            fi
            ;;
    esac
}

# ============================================================
# Require ntfs-3g (exit if not found)
# ============================================================
check_ntfs3g() {
    local path
    path="$(find_ntfs3g)" || error "ntfs-3g not found.
  Install: brew tap gromgit/fuse && brew install ntfs-3g-mac
  Also requires: brew install --cask macfuse (restart after install)"
}
