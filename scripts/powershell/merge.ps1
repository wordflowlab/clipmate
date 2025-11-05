# 合并视频片段

$scriptDir = Split-Path -Parent $PSCommandPath
. "$scriptDir\common.ps1"

Test-FFmpeg

$projectDir = Get-ClipMateRoot
$projectName = Get-ProjectName
$clipsDir = Join-Path $projectDir "clips"

# 查找剪辑片段
$segments = Get-ChildItem -Path $clipsDir -Filter "*-edited.mp4" -File
if ($segments.Count -eq 0) {
    $segments = Get-ChildItem -Path $clipsDir -Filter "segment-*.mp4" -File
}

if ($segments.Count -eq 0) {
    $error = @{
        status = "error"
        message = "未找到剪辑片段"
        hint = "请先运行 /cut 命令生成剪辑视频"
    } | ConvertTo-Json

    Write-JsonOutput $error
    exit 1
}

# 创建 concat 文件
$concatFile = Join-Path $clipsDir "filelist.txt"
$segments | ForEach-Object {
    "file '$($_.FullName)'" | Out-File -FilePath $concatFile -Append -Encoding UTF8
}

# 合并
$output = Join-Path $clipsDir "merged-video.mp4"
& ffmpeg -y -f concat -safe 0 -i $concatFile -c copy $output 2>&1 | Out-Null

if (Test-Path $output) {
    $result = @{
        status = "success"
        project_name = $projectName
        output = $output
        segments_count = $segments.Count
        message = "视频合并完成"
    } | ConvertTo-Json

    Write-JsonOutput $result
}
else {
    $error = @{
        status = "error"
        message = "合并失败"
    } | ConvertTo-Json

    Write-JsonOutput $error
}
