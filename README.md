# ClipMate - AI 驱动的视频剪辑工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/node-%3E%3D18.0.0-brightgreen)](https://nodejs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.3%2B-blue)](https://www.typescriptlang.org/)

ClipMate 是一款基于 AI 的视频剪辑工具，通过智能检测和自动化处理,帮助你快速剪辑录制视频。

## ✨ 核心特性

- 🔇 **智能静音检测** - 自动识别并删除或加速静音片段
- 🔁 **重复画面识别** - 检测重复操作并自动加速
- 🎬 **场景切换检测** - 识别自然的场景边界
- 🗣️ **字幕生成** - 集成阿里云语音识别,自动生成中英文字幕
- 🤖 **多 AI 平台支持** - 支持 Claude、Cursor、Gemini 等 13 种 AI 编辑器
- ⚡ **Slash Command** - 在 AI 编辑器中通过命令调用,无需独立工具

## 🏗️ 架构设计

ClipMate 采用 **Slash Command 模式**,作为 AI 编辑器的插件运行:

```
用户在 AI 编辑器中输入: /detect
              ↓
┌─────────────────────────────────────────┐
│ Markdown 模板 (.claude/commands/)      │
│ - 定义 AI 角色和行为                    │
│ - 描述检测标准                          │
│ - 引用 bash 脚本                        │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ Bash 脚本层 (scripts/bash/)            │
│ - 项目管理                              │
│ - 调用 Python 脚本                      │
│ - 输出 JSON 给 AI                      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│ Python 处理层 (scripts/python/)        │
│ - FFmpeg 视频处理                       │
│ - OpenCV 画面分析                       │
│ - 阿里云 ASR 语音识别                   │
└─────────────────────────────────────────┘
```

## 📦 安装

### 前置要求

- Node.js ≥ 18.0.0
- Python 3.8+
- FFmpeg

### 1. 安装 FFmpeg

```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt-get install ffmpeg

# Windows
# 从 https://ffmpeg.org/download.html 下载
```

### 2. 安装 ClipMate

```bash
npm install -g ai-clipmate
```

### 3. 安装 Python 依赖

由于 macOS 系统限制，需要使用虚拟环境安装 Python 依赖。

**使用 ClipMate 命令自动设置（推荐）**

```bash
# 在项目目录运行
clipmate setup-python
```

这个命令会自动：
- 检查 Python 3 是否已安装
- 创建 `requirements.txt` 文件（如果不存在）
- 创建 Python 虚拟环境（venv/）
- 安装所有必需的依赖（opencv-python >= 4.8.0, numpy >= 1.24.0, pydub >= 0.25.1）

**注意**:
- ClipMate 的脚本会自动检测并使用虚拟环境中的 Python，无需手动激活
- 虚拟环境会创建在你的项目目录中（venv/）
- 如果你直接运行 Python 脚本，需要先激活虚拟环境：
  ```bash
  source venv/bin/activate
  python3 scripts/python/detect_silence.py video.mp4
  ```

## 🚀 快速开始

### 1. 初始化项目

```bash
# 创建新项目
clipmate init my-video-project

# 或在当前目录初始化
clipmate init --here --ai claude
```

### 2. 导入视频

将视频文件放入 `videos/` 目录,或使用命令导入:

```bash
clipmate import path/to/your/video.mp4
```

### 3. 在 AI 编辑器中使用

在 Claude Code/Cursor 等编辑器中输入:

```
/detect
```

AI 会自动:
1. 运行检测脚本
2. 分析视频内容
3. 提供 ABCDE 选择模式
4. 生成详细报告
5. 建议下一步操作

## 📋 核心命令

### /detect - 智能检测

检测视频中的静音、重复画面、场景切换:

```bash
/detect                      # 使用默认预设(教学模式)
/detect --preset meeting     # 使用会议模式
/detect --preset vlog        # 使用 Vlog 模式
/detect --preset short       # 使用短视频模式
```

### /cut - 智能剪辑

根据检测报告自动剪辑:

```bash
/cut --auto                  # 自动剪辑所有片段
/cut --interactive           # 交互式确认每个片段
```

### /merge - 合并片段

合并剪辑后的片段:

```bash
/merge
```

### /transcribe - 语音识别

使用阿里云生成字幕:

```bash
/transcribe                          # 使用默认模型(通用)
/transcribe --model education        # 使用教育模型
/transcribe --model meeting          # 使用会议模型
```

### /subtitle - 字幕处理

```bash
/subtitle --burn                     # 烧录字幕到视频
/subtitle --style default            # 使用默认样式
```

### /export - 导出视频

```bash
/export --preset youtube             # YouTube 1080p
/export --preset bilibili            # B站 1080p
/export --preset douyin              # 抖音竖屏 9:16
```

## 📊 检测预设

### 🎓 教学演示模式

适合: 在线课程、软件演示、编程教学

- 静音阈值: 2.0秒
- 删除所有静音片段
- 检测重复操作并加速 2x
- 预计节省时间: 15-25%

### 📊 会议录制模式

适合: Zoom 会议、访谈、研讨会

- 静音阈值: 3.0秒(更宽松)
- 保留自然对话节奏
- 保留开场和结尾
- 预计节省时间: 10-15%

### 📹 Vlog 生活模式

适合: 旅行 Vlog、生活记录、美食探店

- 静音阈值: 1.0秒
- 轻度加速静音片段(1.5x)
- 自动识别场景切换
- 预计节省时间: 8-12%

### ⚡ 短视频模式

适合: 抖音、快手、小红书

- 严格删除所有静音
- 无冗余片段
- 快节奏优化
- 预计节省时间: 20-30%

## 🎯 典型工作流

### 教学视频剪辑

```bash
# 1. 初始化项目
clipmate init my-course

# 2. 导入视频(在 AI 编辑器中)
/import

# 3. 智能检测(教学模式)
/detect

# AI 提示选择模式，选择 A(教学模式)

# 4. 查看检测报告
# AI 会展示:
# - 12 个静音片段(共 3分15秒)
# - 5 个重复操作(共 1分30秒)
# - 预计节省 4分00秒 (13.3%)

# 5. 自动剪辑
/cut --auto

# 6. 生成字幕
/transcribe --model education

# 7. 导出
/export --preset youtube
```

### 会议录制处理

```bash
clipmate init meeting-2024-11-05
/import zoom-recording.mp4
/detect --preset meeting
/cut --interactive  # 逐个确认
/transcribe --model meeting --enable-speaker
/export --preset bilibili
```

## 🌍 支持的 AI 平台

ClipMate 支持以下 13 个 AI 编辑器:

1. **Claude Code** (`.claude/commands/`)
2. **Cursor** (`.cursor/commands/`)
3. **Gemini CLI** (`.gemini/commands/`)
4. **Windsurf** (`.windsurf/workflows/`)
5. **Roo Code** (`.roo/commands/`)
6. **GitHub Copilot** (`.github/prompts/`)
7. **Qwen Code** (`.qwen/commands/`)
8. **OpenCode** (`.opencode/command/`)
9. **Codex CLI** (`.codex/prompts/`)
10. **Kilo Code** (`.kilocode/workflows/`)
11. **Auggie CLI** (`.augment/commands/`)
12. **CodeBuddy** (`.codebuddy/commands/`)
13. **Amazon Q Developer** (`.amazonq/prompts/`)

## ⚙️ 配置阿里云 API

编辑 `.clipmate/aliyun.json`:

```json
{
  "access_key_id": "your_access_key_id",
  "access_key_secret": "your_access_key_secret",
  "asr": {
    "app_key": "your_asr_app_key",
    "model": "generic"
  }
}
```

获取密钥: https://ram.console.aliyun.com/

### 阿里云 ASR 成本

- 免费额度: 每月前 3 小时免费
- 收费标准: ¥0.6/分钟 (按实际音频时长)
- 建议: 购买资源包更优惠 (100小时 ¥1,500)

## 📁 项目结构

```
my-video-project/
├── .clipmate/
│   ├── config.json           # 项目配置
│   └── aliyun.json           # 阿里云配置
│
├── .claude/                  # AI 平台配置(示例)
│   └── commands/
│       ├── detect.md
│       ├── cut.md
│       └── [所有命令]
│
├── scripts/
│   ├── bash/                 # Bash 脚本
│   │   ├── common.sh
│   │   ├── detect.sh
│   │   ├── cut.sh
│   │   └── ...
│   ├── powershell/           # PowerShell 脚本(Windows)
│   └── python/               # Python 处理脚本
│       ├── detect_silence.py
│       └── ...
│
├── templates/
│   ├── commands/             # Markdown 命令模板
│   └── option-templates/     # YAML 配置库
│
├── videos/                   # 原始视频
├── clips/                    # 剪辑片段和报告
├── subtitles/                # 字幕文件
└── exports/                  # 导出成品
```

## 🔧 开发

### 构建

```bash
git clone https://github.com/wordflowlab/clipmate.git
cd clipmate
npm install
npm run build
```

### 本地测试

```bash
npm run dev
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request!

## 📄 许可证

MIT License

## 🙏 致谢

- 架构灵感来自 [Scriptify](https://github.com/wordflowlab/scriptify)
- 基于 FFmpeg、OpenCV 等开源项目
- 感谢阿里云提供语音识别服务

## 📞 联系

- GitHub: https://github.com/wordflowlab/clipmate
- Issues: https://github.com/wordflowlab/clipmate/issues

---

**Made with ❤️ by ClipMate Team**
