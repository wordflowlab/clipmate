#!/usr/bin/env bash
# 导入视频素材并分析

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# 检查必要工具
check_ffmpeg

# 获取项目信息
PROJECT_DIR=$(get_current_project)
PROJECT_NAME=$(get_project_name)

VIDEO_DIR="$PROJECT_DIR/videos"
ensure_dir "$VIDEO_DIR"

# 解析命令行参数
VIDEO_PATH=""

if [ $# -gt 0 ]; then
    VIDEO_PATH="$1"
fi

# 如果没有提供路径,扫描 videos 目录
if [ -z "$VIDEO_PATH" ]; then
    # 查找 videos 目录中的视频文件
    VIDEO_FILES=($(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.mov" -o -name "*.avi" -o -name "*.mkv" \) 2>/dev/null))

    if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
        output_json "{
            \"status\": \"error\",
            \"message\": \"未找到视频文件\",
            \"hint\": \"请将视频文件放入 videos/ 目录，或指定视频文件路径: clipmate import /path/to/video.mp4\"
        }"
        exit 1
    elif [ ${#VIDEO_FILES[@]} -eq 1 ]; then
        # 只有一个视频,直接使用
        VIDEO_PATH="${VIDEO_FILES[0]}"
    else
        # 多个视频,输出列表供 AI 选择
        VIDEO_LIST="["
        for i in "${!VIDEO_FILES[@]}"; do
            FILE="${VIDEO_FILES[$i]}"
            FILENAME=$(basename "$FILE")

            # 获取视频基本信息
            DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FILE" 2>/dev/null || echo "0")
            DURATION_INT=${DURATION%.*}
            DURATION_FORMATTED=$(format_duration $DURATION_INT)

            WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$FILE" 2>/dev/null || echo "0")
            HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$FILE" 2>/dev/null || echo "0")

            if [ $i -gt 0 ]; then
                VIDEO_LIST="$VIDEO_LIST,"
            fi

            VIDEO_LIST="$VIDEO_LIST{\"index\": $i, \"filename\": \"$FILENAME\", \"path\": \"$FILE\", \"duration\": \"$DURATION_FORMATTED\", \"resolution\": \"${WIDTH}x${HEIGHT}\"}"
        done
        VIDEO_LIST="$VIDEO_LIST]"

        output_json "{
            \"status\": \"select\",
            \"message\": \"发现多个视频文件,请选择要导入的视频\",
            \"videos\": $VIDEO_LIST
        }"
        exit 0
    fi
fi

# 检查视频文件是否存在
if [ ! -f "$VIDEO_PATH" ]; then
    output_json "{
        \"status\": \"error\",
        \"message\": \"视频文件不存在: $VIDEO_PATH\"
    }"
    exit 1
fi

# 如果视频不在 videos 目录,复制进去
FILENAME=$(basename "$VIDEO_PATH")
TARGET_PATH="$VIDEO_DIR/$FILENAME"

if [ "$VIDEO_PATH" != "$TARGET_PATH" ]; then
    echo "正在复制视频到项目目录..." >&2
    cp "$VIDEO_PATH" "$TARGET_PATH"
    VIDEO_PATH="$TARGET_PATH"
fi

# 获取详细视频信息
echo "正在分析视频信息..." >&2

DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VIDEO_PATH" 2>/dev/null)
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 "$VIDEO_PATH" 2>/dev/null)
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$VIDEO_PATH" 2>/dev/null)
FPS=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$VIDEO_PATH" 2>/dev/null | bc -l 2>/dev/null || echo "30")
BITRATE=$(ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "$VIDEO_PATH" 2>/dev/null)
SIZE_BYTES=$(stat -f%z "$VIDEO_PATH" 2>/dev/null || stat -c%s "$VIDEO_PATH" 2>/dev/null)
SIZE_MB=$(echo "scale=2; $SIZE_BYTES / 1024 / 1024" | bc)
VIDEO_CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$VIDEO_PATH" 2>/dev/null)
AUDIO_CODEC=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$VIDEO_PATH" 2>/dev/null)

# 格式化时长
DURATION_INT=${DURATION%.*}
DURATION_FORMATTED=$(format_duration $DURATION_INT)

# 分析视频质量
QUALITY="medium"
IS_HD="false"
ASPECT_RATIO="unknown"

if [ "$WIDTH" -ge 1920 ] && [ "$HEIGHT" -ge 1080 ]; then
    QUALITY="high"
    IS_HD="true"
elif [ "$WIDTH" -ge 1280 ] && [ "$HEIGHT" -ge 720 ]; then
    QUALITY="good"
    IS_HD="true"
fi

# 计算宽高比
if [ "$WIDTH" -gt 0 ] && [ "$HEIGHT" -gt 0 ]; then
    RATIO=$(echo "scale=2; $WIDTH / $HEIGHT" | bc)
    if [ $(echo "$RATIO >= 1.7" | bc) -eq 1 ]; then
        ASPECT_RATIO="16:9"
    elif [ $(echo "$RATIO <= 0.6" | bc) -eq 1 ]; then
        ASPECT_RATIO="9:16"
    elif [ $(echo "$RATIO >= 1.3 && $RATIO <= 1.4" | bc) -eq 1 ]; then
        ASPECT_RATIO="4:3"
    else
        ASPECT_RATIO="$RATIO:1"
    fi
fi

# 估算处理时间
ESTIMATED_TIME="1-2分钟"
if [ "$DURATION_INT" -gt 600 ]; then
    ESTIMATED_TIME="5-10分钟"
elif [ "$DURATION_INT" -gt 300 ]; then
    ESTIMATED_TIME="2-5分钟"
fi

# 输出结果
output_json "{
    \"status\": \"success\",
    \"project_name\": \"$PROJECT_NAME\",
    \"project_path\": \"$PROJECT_DIR\",
    \"video_path\": \"$VIDEO_PATH\",
    \"video_info\": {
        \"filename\": \"$FILENAME\",
        \"duration\": $DURATION,
        \"duration_formatted\": \"$DURATION_FORMATTED\",
        \"resolution\": \"${WIDTH}x${HEIGHT}\",
        \"width\": $WIDTH,
        \"height\": $HEIGHT,
        \"fps\": $FPS,
        \"bitrate\": $BITRATE,
        \"size_mb\": $SIZE_MB,
        \"codec\": \"$VIDEO_CODEC\",
        \"audio_codec\": \"$AUDIO_CODEC\"
    },
    \"analysis\": {
        \"quality\": \"$QUALITY\",
        \"aspect_ratio\": \"$ASPECT_RATIO\",
        \"is_hd\": $IS_HD,
        \"estimated_process_time\": \"$ESTIMATED_TIME\"
    },
    \"message\": \"视频导入成功，已分析视频信息\"
}"
