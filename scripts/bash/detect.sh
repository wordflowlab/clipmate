#!/usr/bin/env bash
# 视频智能检测 - 静音/重复/场景

# 加载通用函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 检查必要工具
check_ffmpeg
check_python
check_venv

# 获取项目信息
PROJECT_DIR=$(get_current_project)
PROJECT_NAME=$(get_project_name)

# 检查是否有视频文件
VIDEO_FILE=$(find_video_file)

if [ -z "$VIDEO_FILE" ]; then
    output_json "{
        \"status\": \"error\",
        \"message\": \"未找到视频文件\",
        \"hint\": \"请将视频文件放入 videos/ 目录，或运行 /import 导入视频\"
    }"
    exit 1
fi

# 确保 clips 目录存在
ensure_dir "$PROJECT_DIR/clips"

# 检查是否已有检测报告
REPORT_FILE="$PROJECT_DIR/clips/detect-report.json"

if [ -f "$REPORT_FILE" ]; then
    # 如果已有报告,询问是否使用缓存
    REPORT_AGE=$(( $(date +%s) - $(stat -f %m "$REPORT_FILE" 2>/dev/null || stat -c %Y "$REPORT_FILE" 2>/dev/null) ))

    if [ "$REPORT_AGE" -lt 3600 ]; then
        # 1小时内的报告,建议使用缓存
        CACHED_REPORT=$(cat "$REPORT_FILE")

        output_json "{
            \"status\": \"success\",
            \"project_name\": \"$PROJECT_NAME\",
            \"project_path\": \"$PROJECT_DIR\",
            \"video_path\": \"$VIDEO_FILE\",
            \"cached\": true,
            \"cache_age_minutes\": $(($REPORT_AGE / 60)),
            \"message\": \"发现最近的检测报告($(($REPORT_AGE / 60))分钟前)\",
            \"report\": $CACHED_REPORT,
            \"hint\": \"如果视频未改变,建议使用缓存结果。如需重新检测,请删除 clips/detect-report.json\"
        }"
        exit 0
    fi
fi

# 解析命令行参数
PRESET="teaching"  # 默认预设

while [[ $# -gt 0 ]]; do
    case $1 in
        --preset)
            PRESET="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# 调用 Python 检测脚本
echo "正在分析视频..." >&2
echo "视频文件: $VIDEO_FILE" >&2
echo "检测预设: $PRESET" >&2
echo "" >&2

# 分别捕获 stdout（JSON）和 stderr（日志）
TEMP_STDOUT=$(mktemp)
TEMP_STDERR=$(mktemp)
trap "rm -f $TEMP_STDOUT $TEMP_STDERR" EXIT

run_python_script "detect_silence.py" "$VIDEO_FILE" --preset "$PRESET" > "$TEMP_STDOUT" 2> "$TEMP_STDERR"
EXIT_CODE=$?

# 显示 Python 的日志输出
if [ -s "$TEMP_STDERR" ]; then
    cat "$TEMP_STDERR" >&2
fi

# 检查 Python 脚本执行结果
if [ $EXIT_CODE -ne 0 ]; then
    ERROR_OUTPUT=$(cat "$TEMP_STDOUT" "$TEMP_STDERR" 2>/dev/null)
    echo "" >&2
    echo "❌ Python 脚本执行失败" >&2
    echo "退出代码: $EXIT_CODE" >&2
    echo "" >&2

    # 检查常见错误
    if echo "$ERROR_OUTPUT" | grep -q "ModuleNotFoundError\|No module named"; then
        echo "💡 看起来是 Python 依赖缺失" >&2
        echo "   请运行: clipmate setup-python" >&2
    elif echo "$ERROR_OUTPUT" | grep -q "FFmpeg"; then
        echo "💡 看起来是 FFmpeg 相关问题" >&2
        echo "   请确保已安装 FFmpeg: brew install ffmpeg" >&2
    fi

    output_json "{
        \"status\": \"error\",
        \"message\": \"检测脚本执行失败\",
        \"exit_code\": $EXIT_CODE,
        \"error_output\": $(echo "$ERROR_OUTPUT" | jq -Rs .)
    }"
    exit 1
fi

DETECT_RESULT=$(cat "$TEMP_STDOUT")

# 保存检测报告
echo "$DETECT_RESULT" > "$REPORT_FILE"

# 输出结果
output_json "{
    \"status\": \"success\",
    \"project_name\": \"$PROJECT_NAME\",
    \"project_path\": \"$PROJECT_DIR\",
    \"video_path\": \"$VIDEO_FILE\",
    \"preset\": \"$PRESET\",
    \"report_file\": \"$REPORT_FILE\",
    \"cached\": false,
    \"message\": \"检测完成，报告已保存\",
    \"report\": $DETECT_RESULT
}"
