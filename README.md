# PicBase64

一款轻盈高效的 macOS 菜单栏工具，让图片与 Base64 互转变得触手可及。

![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![macOS](https://img.shields.io/badge/macOS-13+-blue?logo=apple)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ 功能特点

- ✂️ **一键截图转 Base64** — 区域 / 窗口 / 全屏截图直接复制，告别繁琐的在线转换
- 🔄 **双向转换** — 图片 → Base64 或 Base64 → 预览图片
- 🎨 **多种输出格式** — data URL / Markdown / JSON / 纯 Base64
- 🧩 **拖拽预览** — 把 base64 文本或图片文件直接拖入预览窗口
- ⌨️ **全局快捷键** — ⌥1 / ⌥2 / ⌥3 / ⌥C / ⌥V 随时触发
- 🌍 **国际化** — 支持简体中文、英文和维吾尔语
- ⚡️ **原生实现** — 纯 Swift + AppKit，零依赖
- 🎨 **Lucide 图标** — 统一精美的扁平化 UI 图标
- 📦 **轻量体积** — 安装包约数百 KB

## 📸 截图

```
⌥1  截取区域       ──┐
⌥2  截取窗口       ──┼── 自动转换为 Base64
⌥3  全屏截图       ──┘
⌥C  剪贴板图片 → Base64
⌥V  读取 Base64 → 预览图片
```

## 🚀 安装

### 方式一：直接下载 App

前往 [Releases](https://github.com/wajipu/PicBase64/releases) 下载最新的 `PicBase64-macos.zip`，解压后把 `PicBase64.app` 拖入 `~/Applications` 目录即可。

### 方式二：自己编译

```bash
git clone https://github.com/wajipu/PicBase64.git
cd PicBase64

swiftc -O \
  -framework AppKit \
  -framework UserNotifications \
  -framework UniformTypeIdentifiers \
  PicBase64.swift SettingsWindow.swift IconManager.swift main.swift \
  -o PicBase64

# 打包为 .app
mkdir -p PicBase64.app/Contents/{MacOS,Resources/icons}
cp PicBase64 PicBase64.app/Contents/MacOS/
cp Info.plist PicBase64.app/Contents/
cp icons/*.svg PicBase64.app/Contents/Resources/icons/
find . -maxdepth 1 -type d -name "*.lproj" -exec cp -R {} PicBase64.app/Contents/Resources/ \;
cp /tmp/PicBase64.icns PicBase64.app/Contents/Resources/AppIcon.icns

# 运行
open PicBase64.app
```

## 🗂 项目结构

```
PicBase64/
├── PicBase64.swift        # 主程序 (App + 截图 + Base64 转换)
├── SettingsWindow.swift   # 设置窗口 (Lucide 图标 + UI)
├── IconManager.swift      # SVG 图标加载与缓存
├── main.swift             # 入口
├── Info.plist             # App 元数据 + 国际化配置
├── icons/                 # 所用到的 Lucide SVG 图标
├── zh-Hans.lproj/         # 中文本地化
├── en.lproj/              # 英文本地化
├── ug.lproj/              # 维吾尔语本地化
├── .vibe/config.toml      # Vibe Code 项目配置
├── AGENTS.md              # AI 协作与构建说明
└── makeIconV2.swift       # 生成扁平化图标脚本
```

## 🤖 Vibe Code 配置

仓库包含项目级 `.vibe/config.toml` 和 `AGENTS.md`。项目配置只保存通用偏好，不包含 API Key；密钥请放在本机的 `~/.vibe/config.toml` 或环境变量里。

## 🎛 快捷键

| 快捷键 | 功能 |
|-------|------|
| `⌥1` | 截取选定区域 |
| `⌥2` | 截取窗口 |
| `⌥3` | 全屏截图 |
| `⌥C` | 剪贴板图片 → Base64 |
| `⌥V` | 读取剪贴板 Base64 → 预览 |
| `⌘,`  | 打开设置 |

## 💬 输出格式示例

**data URL（推荐）**

```
data:image/png;base64,iVBORw0KGgo...
```

**Markdown**

```markdown
![screenshot](data:image/png;base64,iVBORw0KGgo...)
```

**JSON**

```json
{
  "type": "image/png",
  "data": "iVBORw0KGgo..."
}
```

## 🧩 权限

首次运行时，macOS 会请求以下权限：

- **屏幕录制** — 截图必须的权限
- **通知** — 显示截图成功通知

## 🤝 致谢

- [Lucide](https://lucide.dev) — 所有 UI 图标由 Lucide 提供
- Apple AppKit — 原生框架

## 📄 License

MIT License - 详见 [LICENSE](LICENSE)

## 📬 反馈

欢迎提 Issue 或 PR 来完善本项目 ❤️
