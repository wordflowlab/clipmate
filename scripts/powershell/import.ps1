# 导入视频素材并分析

# 加载通用函数
$scriptDir = Split-Path -Parent $PSCommandPath
. "$scriptDir\common.ps1"

# 检查必要工具
Test-FFmpeg

# 获取项目信息
$projectDir = Get-ClipMateRoot
$projectName = Get-ProjectName

$videoDir = Join-Path $projectDir "videos"
Ensure-Directory $videoDir

# 解析命令行参数
$videoPath = $args[0]

# 如果没有提供路径,扫描 videos 目录
if (-not $videoPath) {
    $videoFiles = Get-ChildItem -Path $videoDir -Include "*.mp4","*.mov","*.avi","*.mkv" -File

    if ($videoFiles.Count -eq 0) {
        $error = @{
            status = "error"
            message = "未找到视频文件"
            hint = "请将视频文件放入 videos/ 目录，或指定视频文件路径: clipmate import C:\path\to\video.mp4"
        } | ConvertTo-Json -Depth 10

        Write-JsonOutput $error
        exit 1
    }
    elseif ($videoFiles.Count -eq 1) {
        $videoPath = $videoFiles[0].FullName
    }
    else {
        # 多个视频,输出列表供 AI 选择
        $videoList = @()
        for ($i = 0; $i -lt $videoFiles.Count; $i++) {
            $file = $videoFiles[$i]
            $info = Get-VideoInfo $file.FullName

            $videoList += @{
                index = $i
                filename = $file.Name
                path = $file.FullName
                duration = (Format-Duration ([int]$info.duration))
                resolution = "$($info.width)x$($info.height)"
            }
        }

        $result = @{
            status = "select"
            message = "发现多个视频文件,请选择要导入的视频"
            videos = $videoList
        } | ConvertTo-Json -Depth 10

        Write-JsonOutput $result
        exit 0
    }
}

# 检查视频文件是否存在
if (-not (Test-Path $videoPath)) {
    $error = @{
        status = "error"
        message = "视频文件不存在: $videoPath"
    } | ConvertTo-Json

    Write-JsonOutput $error
    exit 1
}

# 如果视频不在 videos 目录,复制进去
$filename = Split-Path $videoPath -Leaf
$targetPath = Join-Path $videoDir $filename

if ($videoPath -ne $targetPath) {
    Write-Host "正在复制视频到项目目录..." -ForegroundColor Yellow
    Copy-Item $videoPath $targetPath
    $videoPath = $targetPath
}

# 获取详细视频信息
Write-Host "正在分析视频信息..." -ForegroundColor Yellow

$videoInfo = Get-VideoInfo $videoPath

if ($videoInfo.error) {
    $error = @{
        status = "error"
        message = "无法获取视频信息: $($videoInfo.error)"
    } | ConvertTo-Json

    Write-JsonOutput $error
    exit 1
}

# 获取文件大小
$fileSize = (Get-Item $videoPath).Length
$sizeMB = [math]::Round($fileSize / 1MB, 2)

# 分析视频质量
$quality = "medium"
$isHD = $false
$aspectRatio = "unknown"

if ($videoInfo.width -ge 1920 -and $videoInfo.height -ge 1080) {
    $quality = "high"
    $isHD = $true
}
elseif ($videoInfo.width -ge 1280 -and $videoInfo.height -ge 720) {
    $quality = "good"
    $isHD = $true
}

# 计算宽高比
if ($videoInfo.width -gt 0 -and $videoInfo.height -gt 0) {
    $ratio = [math]::Round($videoInfo.width / $videoInfo.height, 2)

    if ($ratio -ge 1.7) {
        $aspectRatio = "16:9"
    }
    elseif ($ratio -le 0.6) {
        $aspectRatio = "9:16"
    }
    elseif ($ratio -ge 1.3 -and $ratio -le 1.4) {
        $aspectRatio = "4:3"
    }
    else {
        $aspectRatio = "$ratio`:1"
    }
}

# 估算处理时间
$estimatedTime = "1-2分钟"
if ($videoInfo.duration -gt 600) {
    $estimatedTime = "5-10分钟"
}
elseif ($videoInfo.duration -gt 300) {
    $estimatedTime = "2-5分钟"
}

# 输出结果
$result = @{
    status = "success"
    project_name = $projectName
    project_path = $projectDir
    video_path = $videoPath
    video_info = @{
        filename = $filename
        duration = $videoInfo.duration
        duration_formatted = Format-Duration ([int]$videoInfo.duration)
        resolution = "$($videoInfo.width)x$($videoInfo.height)"
        width = $videoInfo.width
        height = $videoInfo.height
        fps = $videoInfo.fps
        bitrate = $videoInfo.bitrate
        size_mb = $sizeMB
        codec = "h264"
        audio_codec = "aac"
    }
    analysis = @{
        quality = $quality
        aspect_ratio = $aspectRatio
        is_hd = $isHD
        estimated_process_time = $estimatedTime
    }
    message = "视频导入成功，已分析视频信息"
} | ConvertTo-Json -Depth 10

Write-JsonOutput $result
