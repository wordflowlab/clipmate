# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-11-06

### Added

#### 核心架构
- 🎯 完整的 Slash Command 架构(参考 scriptify)
- 🤖 支持 13 个 AI 平台(Claude/Cursor/Gemini/Windsurf 等)
- 📦 三层架构设计: Markdown → Bash/PowerShell → Python
- 🌍 完整跨平台支持: macOS/Linux(Bash) + Windows(PowerShell)

#### 核心功能
- `/init` - 项目初始化,自动生成 AI 配置
- `/import` - 视频导入和信息分析
- `/detect` - AI 智能检测(静音/重复/场景)
  - 4 种预设模式: teaching/meeting/vlog/short
  - 基于 FFmpeg 的静音检测
  - 基于 OpenCV 的重复画面检测
  - 场景切换识别
- `/cut` - 智能视频剪辑
  - 自动剪辑模式
  - 交互式确认模式
  - 预览模式
  - 自定义剪辑
- `/merge` - 视频片段合并
- `/export` - 多平台导出预设
  - YouTube (1080p60)
  - B站 (1080p)
  - 抖音 (9:16 竖屏)
  - 小红书 (1:1 方形)

#### 脚本层
- ✅ 6 个 Bash 脚本(macOS/Linux)
- ✅ 6 个 PowerShell 脚本(Windows)
- ✅ 2 个 Python 处理脚本
- ✅ common 通用函数库

#### 模板系统
- 📝 5 个详细的 Markdown 命令模板(200-550 行/个)
- 🎨 ABCDE 选择模式设计
- 📋 检测预设配置(YAML)
- 💡 完整的 AI 角色和工作流程定义

#### 文档
- 📖 完整的 README.md
- 🚀 快速入门指南 QUICKSTART.md
- 📚 代码内详细注释

### Technical Details

**代码统计**:
- 总代码行数: 4,589 行
- 文件数量: 29 个核心文件
- TypeScript: 6 个文件
- Bash: 6 个文件
- PowerShell: 6 个文件
- Python: 2 个文件
- Markdown: 5 个模板
- 配置: 1 个 YAML

**依赖**:
- Node.js >= 18.0.0
- TypeScript 5.3+
- FFmpeg (视频处理)
- Python 3.8+ (opencv-python, numpy)

### Architecture

```
Markdown 模板 (.claude/commands/*.md)
    ↓ 定义 AI 角色和行为
Bash/PowerShell 脚本 (scripts/)
    ↓ 项目管理和调用
Python 处理脚本 (scripts/python/)
    ↓ FFmpeg + OpenCV 视频处理
```

### Supported Platforms

- ✅ macOS (Bash + Homebrew FFmpeg)
- ✅ Linux (Bash + apt FFmpeg)
- ✅ Windows (PowerShell + FFmpeg)

### AI Editors Supported

1. Claude Code
2. Cursor
3. Gemini CLI
4. Windsurf
5. Roo Code
6. GitHub Copilot
7. Qwen Code
8. OpenCode
9. Codex CLI
10. Kilo Code
11. Auggie CLI
12. CodeBuddy
13. Amazon Q Developer

[0.1.0]: https://github.com/wordflowlab/clipmate/releases/tag/v0.1.0
