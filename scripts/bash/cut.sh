#!/usr/bin/env bash
# 智能视频剪辑

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 检查必要工具
check_ffmpeg
check_python
check_venv

# 获取项目信息
PROJECT_DIR=$(get_current_project)
PROJECT_NAME=$(get_project_name)

# 检查检测报告是否存在
REPORT_FILE="$PROJECT_DIR/clips/detect-report.json"

if [ ! -f "$REPORT_FILE" ]; then
    output_json "{
        \"status\": \"error\",
        \"message\": \"未找到检测报告\",
        \"hint\": \"请先运行 /detect 命令进行视频检测\"
    }"
    exit 1
fi

# 读取检测报告
REPORT_DATA=$(cat "$REPORT_FILE")

# 解析命令行参数
MODE="auto"  # 默认自动模式
PREVIEW_ONLY="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            MODE="auto"
            shift
            ;;
        --interactive)
            MODE="interactive"
            shift
            ;;
        --preview)
            PREVIEW_ONLY="true"
            shift
            ;;
        --custom)
            MODE="custom"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# 获取视频路径
VIDEO_FILE=$(find_video_file)

if [ -z "$VIDEO_FILE" ]; then
    output_json "{
        \"status\": \"error\",
        \"message\": \"未找到视频文件\"
    }"
    exit 1
fi

# 如果是预览模式,直接输出剪辑计划
if [ "$PREVIEW_ONLY" = "true" ]; then
    output_json "{
        \"status\": \"preview\",
        \"project_name\": \"$PROJECT_NAME\",
        \"mode\": \"$MODE\",
        \"video_path\": \"$VIDEO_FILE\",
        \"report\": $REPORT_DATA,
        \"message\": \"这是剪辑计划预览,未执行实际剪辑\"
    }"
    exit 0
fi

# 执行剪辑
echo "正在准备剪辑..." >&2
echo "模式: $MODE" >&2
echo "视频文件: $VIDEO_FILE" >&2
echo "" >&2

# 调用 Python 剪辑脚本
CUT_RESULT=$(run_python_script "cut_video.py" "$VIDEO_FILE" --report "$REPORT_FILE" --mode "$MODE")

# 检查执行结果
if [ $? -ne 0 ]; then
    output_json "{
        \"status\": \"error\",
        \"message\": \"剪辑脚本执行失败\",
        \"details\": \"$CUT_RESULT\"
    }"
    exit 1
fi

# 输出结果
output_json "{
    \"status\": \"success\",
    \"project_name\": \"$PROJECT_NAME\",
    \"mode\": \"$MODE\",
    \"result\": $CUT_RESULT,
    \"message\": \"视频剪辑完成\"
}"
