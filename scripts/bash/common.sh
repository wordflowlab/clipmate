#!/usr/bin/env bash
# 通用函数库 - ClipMate

# 获取 ClipMate 项目根目录
get_clipmate_root() {
    # 查找包含 .clipmate/config.json 的项目根目录
    if [ -f ".clipmate/config.json" ]; then
        pwd
    else
        # 向上查找包含 .clipmate 的目录
        current=$(pwd)
        while [ "$current" != "/" ]; do
            if [ -f "$current/.clipmate/config.json" ]; then
                echo "$current"
                return 0
            fi
            current=$(dirname "$current")
        done
        echo "错误: 未找到 clipmate 项目根目录" >&2
        echo "提示: 请在 clipmate 项目目录内运行，或先运行 'clipmate init <项目名>' 创建项目" >&2
        exit 1
    fi
}

# 获取当前视频项目目录（就是工作区根目录）
get_current_project() {
    get_clipmate_root
}

# 获取项目名称（从配置文件读取）
get_project_name() {
    CLIPMATE_ROOT=$(get_clipmate_root)
    if [ -f "$CLIPMATE_ROOT/.clipmate/config.json" ]; then
        # 从 config.json 读取项目名称
        grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$CLIPMATE_ROOT/.clipmate/config.json" | \
        sed 's/"name"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/'
    else
        basename "$CLIPMATE_ROOT"
    fi
}

# 输出 JSON（用于与 AI 助手通信）
output_json() {
    echo "$1"
}

# 确保文件存在
ensure_file() {
    file="$1"
    template="$2"

    if [ ! -f "$file" ]; then
        if [ -f "$template" ]; then
            cp "$template" "$file"
        else
            touch "$file"
        fi
    fi
}

# 确保目录存在
ensure_dir() {
    dir="$1"
    mkdir -p "$dir"
}

# 获取 Python 解释器路径（优先使用虚拟环境）
get_python_interpreter() {
    CLIPMATE_ROOT=$(get_clipmate_root)
    VENV_PYTHON="$CLIPMATE_ROOT/venv/bin/python3"
    
    # 如果虚拟环境存在且包含 Python，使用虚拟环境
    if [ -f "$VENV_PYTHON" ]; then
        echo "$VENV_PYTHON"
    else
        # 否则使用系统 Python
        echo "python3"
    fi
}

# 调用 Python 脚本
run_python_script() {
    script_name="$1"
    shift
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PYTHON_CMD=$(get_python_interpreter)
    $PYTHON_CMD "$SCRIPT_DIR/../python/$script_name" "$@"
}

# 检查 Python 依赖
check_python_dependency() {
    package="$1"
    PYTHON_CMD=$(get_python_interpreter)
    $PYTHON_CMD -c "import $package" 2>/dev/null
    return $?
}

# 查找视频文件
find_video_file() {
    PROJECT_DIR=$(get_clipmate_root)
    VIDEO_DIR="$PROJECT_DIR/videos"

    # 检查 videos 目录是否存在
    if [ ! -d "$VIDEO_DIR" ]; then
        echo "❌ 错误: videos/ 目录不存在" >&2
        echo "提示: 请先创建 videos 目录并放入视频文件" >&2
        echo "   mkdir -p $VIDEO_DIR" >&2
        echo "   cp your-video.mp4 $VIDEO_DIR/" >&2
        return 1
    fi

    # 查找第一个视频文件
    local video_file=$(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.mov" -o -name "*.avi" -o -name "*.mkv" \) 2>/dev/null | head -n 1)

    if [ -z "$video_file" ]; then
        echo "❌ 错误: videos/ 目录中未找到视频文件" >&2
        echo "当前目录: $VIDEO_DIR" >&2
        echo "支持格式: .mp4, .mov, .avi, .mkv" >&2
        echo "" >&2
        echo "目录内容:" >&2
        ls -lh "$VIDEO_DIR" 2>/dev/null | head -10 >&2
        return 1
    fi

    echo "$video_file"
}

# 获取视频信息（使用 ffprobe）
get_video_info() {
    video_file="$1"

    if ! command -v ffprobe &> /dev/null; then
        echo "{\"error\": \"ffprobe 未安装\"}"
        return 1
    fi

    # 获取时长
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file")

    # 获取分辨率
    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$video_file")
    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$video_file")

    # 获取帧率
    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$video_file" | bc -l)

    # 获取码率
    bitrate=$(ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$video_file")

    echo "{\"duration\": $duration, \"width\": $width, \"height\": $height, \"fps\": $fps, \"bitrate\": $bitrate}"
}

# 格式化时长（秒转为 HH:MM:SS）
format_duration() {
    seconds="$1"
    printf "%02d:%02d:%02d" $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
}

# 检查 FFmpeg 是否安装
check_ffmpeg() {
    if ! command -v ffmpeg &> /dev/null; then
        output_json "{
            \"status\": \"error\",
            \"message\": \"FFmpeg 未安装。请安装 FFmpeg: brew install ffmpeg (macOS) 或 apt-get install ffmpeg (Linux)\"
        }"
        exit 1
    fi
}

# 检查 Python3 是否安装
check_python() {
    if ! command -v python3 &> /dev/null; then
        output_json "{
            \"status\": \"error\",
            \"message\": \"Python3 未安装。请安装 Python3: https://www.python.org/downloads/\"
        }"
        exit 1
    fi
}

# 检查虚拟环境是否存在，如果不存在则提示
check_venv() {
    CLIPMATE_ROOT=$(get_clipmate_root)
    VENV_PYTHON="$CLIPMATE_ROOT/venv/bin/python3"

    if [ ! -f "$VENV_PYTHON" ]; then
        echo "" >&2
        echo "⚠️  警告: 未找到 Python 虚拟环境" >&2
        echo "" >&2
        echo "📝 Python 依赖可能缺失，建议运行以下命令设置环境:" >&2
        echo "   clipmate setup-python" >&2
        echo "" >&2
        echo "或手动设置:" >&2
        echo "   cd $CLIPMATE_ROOT" >&2
        echo "   python3 -m venv venv" >&2
        echo "   source venv/bin/activate" >&2
        echo "   pip install opencv-python numpy pydub" >&2
        echo "" >&2
        echo "⚠️  当前将使用系统 Python，可能因依赖缺失而失败" >&2
        echo "" >&2
    fi
}
