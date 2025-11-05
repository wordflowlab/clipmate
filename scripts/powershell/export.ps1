# 导出视频

$scriptDir = Split-Path -Parent $PSCommandPath
. "$scriptDir\common.ps1"

Test-FFmpeg

$projectDir = Get-ClipMateRoot
$projectName = Get-ProjectName

# 查找剪辑后的视频
$clipsDir = Join-Path $projectDir "clips"
$videoFile = Get-ChildItem -Path $clipsDir -Filter "*-edited.mp4" -File | Select-Object -First 1

if (-not $videoFile) {
    $videoFile = Get-ChildItem -Path $clipsDir -Filter "merged-video.mp4" -File | Select-Object -First 1
}

if (-not $videoFile) {
    $videoFile = Find-VideoFile
}

if (-not $videoFile) {
    $error = @{
        status = "error"
        message = "未找到视频文件"
    } | ConvertTo-Json

    Write-JsonOutput $error
    exit 1
}

# 解析预设
$preset = "youtube"
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq "--preset" -and ($i + 1) -lt $args.Count) {
        $preset = $args[$i + 1]
        $i++
    }
}

# 导出目录
$exportDir = Join-Path $projectDir "exports"
Ensure-Directory $exportDir

# 根据预设设置参数
switch ($preset) {
    "youtube" {
        $resolution = "1920x1080"
        $bitrate = "8M"
        $fps = 30
    }
    "bilibili" {
        $resolution = "1920x1080"
        $bitrate = "6M"
        $fps = 30
    }
    "douyin" {
        $resolution = "1080x1920"
        $bitrate = "5M"
        $fps = 30
    }
    default {
        $resolution = "1920x1080"
        $bitrate = "6M"
        $fps = 30
    }
}

$output = Join-Path $exportDir "video-$preset.mp4"

Write-Host "正在导出..." -ForegroundColor Yellow

& ffmpeg -y -i $videoFile.FullName `
    -vf "scale=$resolution`:force_original_aspect_ratio=decrease,pad=$resolution`:(ow-iw)/2:(oh-ih)/2" `
    -c:v libx264 -preset medium -b:v $bitrate `
    -c:a aac -b:a 128k `
    -r $fps `
    $output 2>&1 | Where-Object { $_ -match "time=|frame=" } | ForEach-Object { Write-Host $_ }

if (Test-Path $output) {
    $fileSize = (Get-Item $output).Length
    $sizeMB = [math]::Round($fileSize / 1MB, 2)

    $result = @{
        status = "success"
        project_name = $projectName
        output = $output
        preset = $preset
        size_mb = $sizeMB
        resolution = $resolution
        message = "导出完成"
    } | ConvertTo-Json

    Write-JsonOutput $result
}
else {
    $error = @{
        status = "error"
        message = "导出失败"
    } | ConvertTo-Json

    Write-JsonOutput $error
}
