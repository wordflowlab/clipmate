#!/usr/bin/env bash
# 导出视频

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_ffmpeg

PROJECT_DIR=$(get_current_project)
PROJECT_NAME=$(get_project_name)

# 查找剪辑后的视频
VIDEO_FILE=$(find "$PROJECT_DIR/clips" -name "*-edited.mp4" -o -name "merged-video.mp4" 2>/dev/null | head -n 1)

if [ -z "$VIDEO_FILE" ]; then
    VIDEO_FILE=$(find_video_file)
fi

if [ -z "$VIDEO_FILE" ]; then
    output_json "{
        \"status\": \"error\",
        \"message\": \"未找到视频文件\"
    }"
    exit 1
fi

# 解析预设
PRESET="youtube"
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

# 导出目录
EXPORT_DIR="$PROJECT_DIR/exports"
ensure_dir "$EXPORT_DIR"

# 根据预设设置参数
case "$PRESET" in
    youtube)
        RESOLUTION="1920x1080"
        BITRATE="8M"
        FPS=30
        ;;
    bilibili)
        RESOLUTION="1920x1080"
        BITRATE="6M"
        FPS=30
        ;;
    douyin)
        RESOLUTION="1080x1920"
        BITRATE="5M"
        FPS=30
        ;;
    *)
        RESOLUTION="1920x1080"
        BITRATE="6M"
        FPS=30
        ;;
esac

OUTPUT="$EXPORT_DIR/video-$PRESET.mp4"

echo "正在导出..." >&2
ffmpeg -y -i "$VIDEO_FILE" \
    -vf "scale=$RESOLUTION:force_original_aspect_ratio=decrease,pad=$RESOLUTION:(ow-iw)/2:(oh-ih)/2" \
    -c:v libx264 -preset medium -b:v $BITRATE \
    -c:a aac -b:a 128k \
    -r $FPS \
    "$OUTPUT" 2>&1 | grep -E "time=|frame=" >&2

if [ -f "$OUTPUT" ]; then
    SIZE=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null)
    SIZE_MB=$(echo "scale=2; $SIZE / 1024 / 1024" | bc)

    output_json "{
        \"status\": \"success\",
        \"project_name\": \"$PROJECT_NAME\",
        \"output\": \"$OUTPUT\",
        \"preset\": \"$PRESET\",
        \"size_mb\": $SIZE_MB,
        \"resolution\": \"$RESOLUTION\",
        \"message\": \"导出完成\"
    }"
else
    output_json "{
        \"status\": \"error\",
        \"message\": \"导出失败\"
    }"
fi
