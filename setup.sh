#!/bin/bash
# One-click setup script for NTFS4Mac
# 一键安装脚本

set -e

echo "=========================================="
echo "  NTFS4Mac Setup Script"
echo "  NTFS4Mac 安装脚本"
echo "=========================================="
echo ""

# Check macOS version
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ This script only runs on macOS"
    echo "❌ 此脚本仅适用于 macOS"
    exit 1
fi

# Check Apple Silicon or Intel
ARCH=$(uname -m)
echo "📋 Architecture: $ARCH"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Install Homebrew if needed
echo ""
echo "Step 1/4: Checking Homebrew..."
echo "步骤 1/4: 检查 Homebrew..."
if command_exists brew; then
    echo "✅ Homebrew already installed"
else
    echo "📦 Installing Homebrew..."
    echo "📦 正在安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "✅ Homebrew installed"
fi

# Step 2: Install fuse-t
echo ""
echo "Step 2/4: Installing fuse-t..."
echo "步骤 2/4: 安装 fuse-t..."
if [[ -d "/Applications/fuse-t.app" ]]; then
    echo "✅ fuse-t already installed"
else
    echo "📦 Downloading fuse-t..."
    echo "📦 正在下载 fuse-t..."

    FUSE_T_VERSION="1.2.0"
    FUSE_T_PKG="/tmp/fuse-t-$FUSE_T_VERSION.pkg"

    curl -L -o "$FUSE_T_PKG" \
        "https://github.com/macos-fuse-t/fuse-t/releases/download/$FUSE_T_VERSION/fuse-t-macos-installer-$FUSE_T_VERSION.pkg"

    echo "📦 Installing fuse-t (requires password)..."
    echo "📦 正在安装 fuse-t (需要密码)..."
    sudo installer -pkg "$FUSE_T_PKG" -target /

    echo "✅ fuse-t installed"
    echo ""
    echo "⚠️  IMPORTANT: Grant Full Disk Access to fuse-t.app"
    echo "⚠️  重要: 在系统设置中授予 fuse-t.app 完全磁盘访问权限"
    echo "   System Settings > Privacy & Security > Full Disk Access > + > /Applications/fuse-t.app"
    echo "   系统设置 > 隐私与安全性 > 完全磁盘访问 > + > /Applications/fuse-t.app"
fi

# Step 3: Install ntfs-3g
echo ""
echo "Step 3/4: Installing ntfs-3g..."
echo "步骤 3/4: 安装 ntfs-3g..."
if command_exists ntfs-3g; then
    echo "✅ ntfs-3g already installed"
else
    echo "📦 Installing ntfs-3g..."
    echo "📦 正在安装 ntfs-3g..."
    brew tap gromgit/fuse
    brew install ntfs-3g-mac
    echo "✅ ntfs-3g installed"
fi

# Step 4: Link fuse-t library
echo ""
echo "Step 4/4: Linking fuse-t library..."
echo "步骤 4/4: 链接 fuse-t 库..."
if [[ -L "/usr/local/lib/libfuse.2.dylib" ]]; then
    LINK_TARGET=$(readlink /usr/local/lib/libfuse.2.dylib)
    if [[ "$LINK_TARGET" == *"fuse-t"* ]]; then
        echo "✅ Library already linked"
    else
        echo "📦 Re-linking library..."
        echo "📦 正在重新链接库..."
        sudo mv /usr/local/lib/libfuse.2.dylib /usr/local/lib/libfuse.2.dylib.bak 2>/dev/null || true
        sudo ln -sf libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
        echo "✅ Library linked"
    fi
else
    echo "📦 Linking library..."
    echo "📦 正在链接库..."
    sudo mv /usr/local/lib/libfuse.2.dylib /usr/local/lib/libfuse.2.dylib.bak 2>/dev/null || true
    sudo ln -sf libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
    echo "✅ Library linked"
fi

# Done
echo ""
echo "=========================================="
echo "  ✅ Setup Complete!"
echo "  ✅ 安装完成!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "后续步骤:"
echo "  1. Grant Full Disk Access to fuse-t.app (if not done)"
echo "     授予 fuse-t.app 完全磁盘访问权限 (如未完成)"
echo ""
echo "  2. Download NTFS4Mac.app from GitHub Releases"
echo "     从 GitHub Releases 下载 NTFS4Mac.app"
echo ""
echo "  Or build from source:"
echo "  或从源码构建:"
echo "     git clone https://github.com/zhouyeyu/NTFS4Mac.git"
echo "     cd NTFS4Mac && bash build-dmg.sh"
echo ""
