#!/usr/bin/env python3
"""
视频智能检测 - 静音/重复/场景切换
"""

import sys
import json
import argparse
import subprocess
from pathlib import Path

def check_dependencies():
    """检查 Python 依赖"""
    missing_packages = []

    try:
        import cv2
    except ImportError:
        missing_packages.append('opencv-python')

    try:
        import numpy as np
    except ImportError:
        missing_packages.append('numpy')

    try:
        import pydub
    except ImportError:
        missing_packages.append('pydub')

    if missing_packages:
        print("", file=sys.stderr)
        print("❌ 错误: 缺少必要的 Python 包", file=sys.stderr)
        print("", file=sys.stderr)
        print(f"缺失的包: {', '.join(missing_packages)}", file=sys.stderr)
        print("", file=sys.stderr)
        print("🔧 快速修复:", file=sys.stderr)
        print("   clipmate setup-python", file=sys.stderr)
        print("", file=sys.stderr)
        print("或手动安装:", file=sys.stderr)
        print(f"   pip install {' '.join(missing_packages)}", file=sys.stderr)
        print("", file=sys.stderr)
        sys.exit(1)

def get_video_info(video_path):
    """获取视频基本信息"""
    try:
        # 使用 ffprobe 获取视频信息
        cmd = [
            'ffprobe', '-v', 'error',
            '-select_streams', 'v:0',
            '-show_entries', 'stream=width,height,r_frame_rate,duration',
            '-show_entries', 'format=duration,size',
            '-of', 'json',
            video_path
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            return None

        data = json.loads(result.stdout)

        # 解析帧率
        fps_str = data['streams'][0]['r_frame_rate']
        fps_parts = fps_str.split('/')
        fps = float(fps_parts[0]) / float(fps_parts[1]) if len(fps_parts) == 2 else float(fps_parts[0])

        # 获取时长
        duration = float(data['format']['duration'])

        # 获取文件大小
        size_bytes = int(data['format']['size'])
        size_mb = size_bytes / (1024 * 1024)

        return {
            "width": int(data['streams'][0]['width']),
            "height": int(data['streams'][0]['height']),
            "fps": round(fps, 2),
            "duration": round(duration, 2),
            "size_mb": round(size_mb, 2),
            "resolution": f"{data['streams'][0]['width']}x{data['streams'][0]['height']}"
        }
    except Exception as e:
        return None

def detect_silence_segments(video_path, threshold_db=-40, min_duration=2.0):
    """
    检测静音片段
    使用 ffmpeg 的 silencedetect 过滤器
    """
    try:
        cmd = [
            'ffmpeg', '-i', video_path,
            '-af', f'silencedetect=noise={threshold_db}dB:d={min_duration}',
            '-f', 'null', '-'
        ]

        result = subprocess.run(cmd, capture_output=True, text=True)
        output = result.stderr

        # 解析 ffmpeg 输出
        silence_segments = []
        silence_start = None

        for line in output.split('\n'):
            if 'silence_start' in line:
                try:
                    silence_start = float(line.split('silence_start: ')[1].split()[0])
                except:
                    pass
            elif 'silence_end' in line and silence_start is not None:
                try:
                    silence_end = float(line.split('silence_end: ')[1].split()[0])
                    duration = silence_end - silence_start
                    silence_segments.append({
                        "start": round(silence_start, 2),
                        "end": round(silence_end, 2),
                        "duration": round(duration, 2)
                    })
                    silence_start = None
                except:
                    pass

        return silence_segments
    except Exception as e:
        print(f"警告: 静音检测失败: {str(e)}", file=sys.stderr)
        return []

def detect_repeat_segments(video_path, similarity_threshold=0.95, min_duration=3.0):
    """
    检测重复画面片段
    使用简化版本:采样关键帧进行比较
    """
    try:
        import cv2
        import numpy as np

        # 打开视频
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return []

        fps = cap.get(cv2.CAP_PROP_FPS)
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

        # 采样间隔(每秒1帧)
        sample_interval = int(fps)

        prev_frame = None
        repeat_start = None
        repeat_segments = []
        same_count = 0

        frame_idx = 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            # 只处理采样帧
            if frame_idx % sample_interval == 0:
                # 转换为灰度图并缩小
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                small = cv2.resize(gray, (64, 64))

                if prev_frame is not None:
                    # 计算相似度(使用归一化差异)
                    diff = cv2.absdiff(prev_frame, small)
                    similarity = 1 - (np.sum(diff) / (64 * 64 * 255))

                    if similarity >= similarity_threshold:
                        if repeat_start is None:
                            repeat_start = frame_idx / fps
                        same_count += 1
                    else:
                        # 如果结束了重复片段
                        if repeat_start is not None and same_count >= min_duration:
                            repeat_end = frame_idx / fps
                            duration = repeat_end - repeat_start
                            if duration >= min_duration:
                                repeat_segments.append({
                                    "start": round(repeat_start, 2),
                                    "end": round(repeat_end, 2),
                                    "duration": round(duration, 2),
                                    "similarity": round(similarity_threshold, 2)
                                })
                        repeat_start = None
                        same_count = 0

                prev_frame = small

            frame_idx += 1

            # 限制处理时间(最多处理前5分钟)
            if frame_idx > fps * 300:
                break

        cap.release()

        # 由于这是简化版本,如果没有检测到,返回模拟数据
        if len(repeat_segments) == 0:
            # 返回空列表表示没有重复画面
            return []

        return repeat_segments
    except Exception as e:
        print(f"警告: 重复画面检测失败: {str(e)}", file=sys.stderr)
        return []

def detect_scene_changes(video_path):
    """
    检测场景切换
    使用简化版本:检测帧间差异突变
    """
    try:
        import cv2
        import numpy as np

        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            return []

        fps = cap.get(cv2.CAP_PROP_FPS)
        scene_changes = []

        prev_frame = None
        frame_idx = 0
        sample_interval = int(fps / 2)  # 每0.5秒采样一次

        while True:
            ret, frame = cap.read()
            if not ret:
                break

            if frame_idx % sample_interval == 0:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                small = cv2.resize(gray, (64, 64))

                if prev_frame is not None:
                    diff = cv2.absdiff(prev_frame, small)
                    mean_diff = np.mean(diff)

                    # 如果差异超过阈值,认为是场景切换
                    if mean_diff > 30:
                        timestamp = frame_idx / fps
                        scene_changes.append(round(timestamp, 2))

                prev_frame = small

            frame_idx += 1

            # 限制处理时间
            if frame_idx > fps * 300:
                break

        cap.release()

        return scene_changes
    except Exception as e:
        print(f"警告: 场景检测失败: {str(e)}", file=sys.stderr)
        return []

def load_preset(preset_name):
    """加载检测预设配置"""
    presets = {
        "teaching": {
            "silence_threshold_db": -40,
            "silence_min_duration": 2.0,
            "repeat_similarity": 0.95,
            "repeat_min_duration": 3.0
        },
        "meeting": {
            "silence_threshold_db": -35,
            "silence_min_duration": 3.0,
            "repeat_similarity": 0.93,
            "repeat_min_duration": 5.0
        },
        "vlog": {
            "silence_threshold_db": -45,
            "silence_min_duration": 1.0,
            "repeat_similarity": 0.90,
            "repeat_min_duration": 2.0
        },
        "short": {
            "silence_threshold_db": -40,
            "silence_min_duration": 1.0,
            "repeat_similarity": 0.92,
            "repeat_min_duration": 2.0
        }
    }
    return presets.get(preset_name, presets["teaching"])

def main():
    parser = argparse.ArgumentParser(description='视频智能检测')
    parser.add_argument('video', help='视频文件路径')
    parser.add_argument('--preset', default='teaching', choices=['teaching', 'meeting', 'vlog', 'short'],
                        help='检测预设')

    args = parser.parse_args()

    # 检查依赖
    check_dependencies()

    # 检查视频文件
    if not Path(args.video).exists():
        print(json.dumps({
            "status": "error",
            "message": f"视频文件不存在: {args.video}"
        }))
        sys.exit(1)

    # 加载预设
    preset_config = load_preset(args.preset)

    # 获取视频信息
    print("正在获取视频信息...", file=sys.stderr)
    video_info = get_video_info(args.video)
    if not video_info:
        print(json.dumps({
            "status": "error",
            "message": "无法获取视频信息,请检查视频文件是否损坏"
        }))
        sys.exit(1)

    # 检测静音片段
    print("正在检测静音片段...", file=sys.stderr)
    silence_segments = detect_silence_segments(
        args.video,
        threshold_db=preset_config['silence_threshold_db'],
        min_duration=preset_config['silence_min_duration']
    )

    # 检测重复画面(简化版:如果视频很长,跳过以节省时间)
    repeat_segments = []
    if video_info['duration'] < 600:  # 仅对10分钟以内的视频进行重复检测
        print("正在检测重复画面...", file=sys.stderr)
        repeat_segments = detect_repeat_segments(
            args.video,
            similarity_threshold=preset_config['repeat_similarity'],
            min_duration=preset_config['repeat_min_duration']
        )
    else:
        print("", file=sys.stderr)
        print("⏭️  视频时长超过 10 分钟，跳过重复画面检测以节省时间", file=sys.stderr)
        print("提示: 如需完整检测，请先剪辑视频或使用更短的片段", file=sys.stderr)
        print("", file=sys.stderr)

    # 检测场景切换(简化版)
    scene_changes = []
    if video_info['duration'] < 600:
        print("正在检测场景切换...", file=sys.stderr)
        scene_changes = detect_scene_changes(args.video)
    else:
        print("⏭️  视频时长超过 10 分钟，跳过场景切换检测", file=sys.stderr)

    # 计算统计信息
    total_silence_duration = sum(s['duration'] for s in silence_segments)
    total_repeat_duration = sum(r['duration'] for r in repeat_segments)

    # 估算处理后的时长
    estimated_time_saved = total_silence_duration + (total_repeat_duration * 0.5)  # 重复加速2x节省50%
    new_duration = video_info['duration'] - estimated_time_saved
    compression_rate = (estimated_time_saved / video_info['duration']) * 100 if video_info['duration'] > 0 else 0

    # 输出结果
    result = {
        "status": "success",
        "video_info": video_info,
        "silence_segments": silence_segments,
        "repeat_segments": repeat_segments,
        "scene_changes": scene_changes,
        "statistics": {
            "total_silence_duration": round(total_silence_duration, 2),
            "total_repeat_duration": round(total_repeat_duration, 2),
            "silence_count": len(silence_segments),
            "repeat_count": len(repeat_segments),
            "scene_count": len(scene_changes)
        },
        "recommendations": {
            "estimated_time_saved": round(estimated_time_saved, 2),
            "new_duration": round(new_duration, 2),
            "compression_rate": round(compression_rate, 1)
        },
        "preset": args.preset,
        "config": preset_config
    }

    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
