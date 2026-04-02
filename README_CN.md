# NTFS4Mac

一款轻量的 macOS NTFS 读写工具。使用 SwiftUI 构建，支持 macOS 14+ (Sonoma, Sequoia, Tahoe)。

<p align="center">
<a href="README.md">English</a> | 简体中文
</p>

![截图](assets/NTFS.png)

## 功能特性

- **一键读写挂载** - 单击即可通过 ntfs-3g 重新挂载 NTFS 卷
- **自动设备检测** - 文件系统监视器 + 轮询实时检测新驱动器
- **在 Finder 中打开** - 快速访问已挂载的卷
- **原生 macOS 体验** - SwiftUI、深色模式、简洁界面
- **包含命令行工具** - 完整的 CLI 工具，支持脚本和自动化

## 工作原理

macOS 原生以只读模式挂载 NTFS 卷。本工具使用 [ntfs-3g](https://github.com/tuxera/ntfs-3g) 驱动通过 [fuse-t](https://github.com/macos-fuse-t/fuse-t) 将其重新挂载为读写模式。

## 系统要求

| 操作系统 | 状态 |
|---|---|
| **macOS 26 (Tahoe)** | 已测试 |
| **macOS 15 (Sequoia)** | 兼容（未测试）|
| **macOS 14 (Sonoma)** | 兼容（未测试）|

## 安装

### 一键安装

在终端运行以下命令，自动安装所有依赖：

```bash
curl -fsSL https://raw.githubusercontent.com/zhouyeyu/NTFS4Mac/main/setup.sh | bash
```

### 手动安装

| 依赖 | 用途 | 安装方式 |
|---|---|---|
| **macOS 14+** | 必需 | 系统设置 > 软件更新 |
| **fuse-t** | 文件系统框架 | 从 [fuse-t releases](https://github.com/macos-fuse-t/fuse-t/releases) 下载 |
| **ntfs-3g** | NTFS 读写驱动 | `brew tap gromgit/fuse && brew install ntfs-3g-mac` |

### 安装 fuse-t

1. 从 [fuse-t releases](https://github.com/macos-fuse-t/fuse-t/releases) 下载 `fuse-t-macos-installer-X.X.X.pkg`
2. 双击安装
3. 在 **系统设置 > 隐私与安全性 > 完全磁盘访问** 中添加 `fuse-t.app`

### 链接 fuse-t 库

安装 fuse-t 后，为 ntfs-3g 链接库：

```bash
sudo mv /usr/local/lib/libfuse.2.dylib /usr/local/lib/libfuse.2.dylib.bak
sudo ln -sf libfuse-t.dylib /usr/local/lib/libfuse.2.dylib
```

### 安装应用

从 [Releases](../../releases) 下载最新 DMG，将 `NTFS4Mac.app` 拖到 `/Applications`。

或从源码构建：

```bash
git clone https://github.com/zhouyeyu/NTFS4Mac.git
cd NTFS4Mac
bash build-dmg.sh
```

### 安装命令行工具

```bash
git clone https://github.com/zhouyeyu/NTFS4Mac.git
cd NTFS4Mac
make install
```

## 使用方法

### 图形界面

启动 `NTFS4Mac.app`，插入 NTFS 驱动器，点击 **Mount RW**。

- **RW**（绿色）= 通过 fuse-t 读写模式
- **RO**（橙色）= 只读模式（macOS 原生）
- **--**（灰色）= 未挂载

点击文件夹图标可在 Finder 中打开该卷。

### 命令行

```bash
ntfs-cli list               # 列出所有 NTFS 设备
ntfs-cli mount disk4s1      # 以读写模式挂载
ntfs-cli unmount disk4s1    # 卸载
ntfs-cli eject disk4s1      # 弹出（安全移除）
ntfs-cli restore disk4s1    # 恢复 macOS 只读模式
ntfs-cli watch              # 自动挂载新的 NTFS 设备
ntfs-cli status             # 显示挂载状态
ntfs-cli deps               # 检查依赖
```

## 构建

```bash
swift build -c release          # 构建 GUI 应用
bash build-dmg.sh               # 构建并打包 DMG
make install PREFIX=/usr/local  # 仅构建 CLI
```

## 项目结构

```
NTFS4Mac/
├── NTFS4Mac/                    # SwiftUI macOS 应用
│   ├── App/NTFS4MacApp.swift
│   ├── Models/NTFSDevice.swift
│   ├── Services/
│   │   ├── Shell.swift
│   │   ├── DeviceService.swift
│   │   ├── MountService.swift
│   │   └── DeviceWatcher.swift
│   └── Views/
│       ├── DeviceListView.swift
│       └── DeviceRow.swift
├── lib/                         # CLI 脚本
├── ntfs-cli.sh                  # CLI 入口
├── setup.sh                     # 一键安装脚本
├── Package.swift
├── build-dmg.sh
└── Makefile
```

## 已知问题

- **Windows 快速启动**：如果驱动器在 Windows 中休眠，ntfs-3g 可能无法挂载。在连接驱动器前请完全关闭 Windows。
- **macOS 首次启动**：首次启动可能需要右键 > 打开，因为应用未签名。

## 许可证

MIT License

Copyright (c) 2026 zhouyeyu

特此免费授予任何获得本软件副本和相关文档文件（"软件"）的人不受限制地处置该软件的权利，包括不受限制地使用、复制、修改、合并、发布、分发、再授权和/或出售该软件副本，以及再授权以适配软件为准备利用该软件的人进行上述行为，但须符合以下条件：

上述版权声明和本许可声明应包含在该软件的所有副本或实质性部分中。

本软件按"原样"提供，不提供任何形式的担保，包括但不限于适销性、特定用途适用性和不侵权的担保。在任何情况下，作者或版权持有人均不对任何索赔、损害或其他责任负责，无论是在合同诉讼、侵权行为还是其他方面，由软件或软件的使用或其他处置引起或与之相关。
