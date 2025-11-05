# 视频智能检测

$scriptDir = Split-Path -Parent $PSCommandPath
. "$scriptDir\common.ps1"

Test-FFmpeg
Test-Python

$projectDir = Get-ClipMateRoot
$projectName = Get-ProjectName

# 检查是否有视频文件
$videoFile = Find-VideoFile

if (-not $videoFile) {
    $error = @{
        status = "error"
        message = "未找到视频文件"
        hint = "请将视频文件放入 videos/ 目录，或运行 /import 导入视频"
    } | ConvertTo-Json

    Write-JsonOutput $error
    exit 1
}

# 确保 clips 目录存在
$clipsDir = Join-Path $projectDir "clips"
Ensure-Directory $clipsDir

# 检查是否已有检测报告
$reportFile = Join-Path $clipsDir "detect-report.json"

if (Test-Path $reportFile) {
    $fileAge = (Get-Date) - (Get-Item $reportFile).LastWriteTime
    $ageMinutes = [int]$fileAge.TotalMinutes

    if ($ageMinutes -lt 60) {
        # 1小时内的报告,使用缓存
        $cachedReport = Get-Content $reportFile -Raw | ConvertFrom-Json

        $result = @{
            status = "success"
            project_name = $projectName
            project_path = $projectDir
            video_path = $videoFile
            cached = $true
            cache_age_minutes = $ageMinutes
            message = "发现最近的检测报告(${ageMinutes}分钟前)"
            report = $cachedReport
            hint = "如果视频未改变,建议使用缓存结果。如需重新检测,请删除 clips\detect-report.json"
        } | ConvertTo-Json -Depth 10

        Write-JsonOutput $result
        exit 0
    }
}

# 解析命令行参数
$preset = "teaching"
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq "--preset" -and ($i + 1) -lt $args.Count) {
        $preset = $args[$i + 1]
        $i++
    }
}

# 调用 Python 检测脚本
Write-Host "正在分析视频..." -ForegroundColor Yellow
Write-Host "视频文件: $videoFile" -ForegroundColor Yellow
Write-Host "检测预设: $preset" -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow

$detectResult = Invoke-PythonScript "detect_silence.py" @($videoFile, "--preset", $preset)

if ($LASTEXITCODE -ne 0) {
    $error = @{
        status = "error"
        message = "检测脚本执行失败"
        details = $detectResult
    } | ConvertTo-Json

    Write-JsonOutput $error
    exit 1
}

# 保存检测报告
$detectResult | Out-File -FilePath $reportFile -Encoding UTF8

# 输出结果
$result = @{
    status = "success"
    project_name = $projectName
    project_path = $projectDir
    video_path = $videoFile
    preset = $preset
    report_file = $reportFile
    cached = $false
    message = "检测完成，报告已保存"
    report = ($detectResult | ConvertFrom-Json)
} | ConvertTo-Json -Depth 10

Write-JsonOutput $result
