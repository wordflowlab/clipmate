#!/usr/bin/env bash
# 合并视频片段

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_ffmpeg

PROJECT_DIR=$(get_current_project)
PROJECT_NAME=$(get_project_name)
CLIPS_DIR="$PROJECT_DIR/clips"

# 查找剪辑片段
SEGMENTS=($(find "$CLIPS_DIR" -name "*-edited.mp4" -o -name "segment-*.mp4" 2>/dev/null))

if [ ${#SEGMENTS[@]} -eq 0 ]; then
    output_json "{
        \"status\": \"error\",
        \"message\": \"未找到剪辑片段\",
        \"hint\": \"请先运行 /cut 命令生成剪辑视频\"
    }"
    exit 1
fi

# 创建 concat 文件
CONCAT_FILE="$CLIPS_DIR/filelist.txt"
> "$CONCAT_FILE"

for seg in "${SEGMENTS[@]}"; do
    echo "file '$(realpath "$seg")'" >> "$CONCAT_FILE"
done

# 合并
OUTPUT="$CLIPS_DIR/merged-video.mp4"
ffmpeg -y -f concat -safe 0 -i "$CONCAT_FILE" -c copy "$OUTPUT" 2>&1

if [ -f "$OUTPUT" ]; then
    output_json "{
        \"status\": \"success\",
        \"project_name\": \"$PROJECT_NAME\",
        \"output\": \"$OUTPUT\",
        \"segments_count\": ${#SEGMENTS[@]},
        \"message\": \"视频合并完成\"
    }"
else
    output_json "{
        \"status\": \"error\",
        \"message\": \"合并失败\"
    }"
fi
