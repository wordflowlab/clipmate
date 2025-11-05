# 智能视频剪辑

$scriptDir = Split-Path -Parent $PSCommandPath
. "$scriptDir\common.ps1"

Test-FFmpeg
Test-Python

$projectDir = Get-ClipMateRoot
$projectName = Get-ProjectName

# 检查检测报告是否存在
$reportFile = Join-Path $projectDir "clips\detect-report.json"

if (-not (Test-Path $reportFile)) {
    $error = @{
        status = "error"
        message = "未找到检测报告"
        hint = "请先运行 /detect 命令进行视频检测"
    } | ConvertTo-Json

    Write-JsonOutput $error
    exit 1
}

# 读取检测报告
$reportData = Get-Content $reportFile -Raw

# 解析命令行参数
$mode = "auto"
$previewOnly = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--auto" { $mode = "auto" }
        "--interactive" { $mode = "interactive" }
        "--preview" { $previewOnly = $true }
        "--custom" { $mode = "custom" }
    }
}

# 获取视频路径
$videoFile = Find-VideoFile

if (-not $videoFile) {
    $error = @{
        status = "error"
        message = "未找到视频文件"
    } | ConvertTo-Json

    Write-JsonOutput $error
    exit 1
}

# 如果是预览模式
if ($previewOnly) {
    $result = @{
        status = "preview"
        project_name = $projectName
        mode = $mode
        video_path = $videoFile
        report = ($reportData | ConvertFrom-Json)
        message = "这是剪辑计划预览,未执行实际剪辑"
    } | ConvertTo-Json -Depth 10

    Write-JsonOutput $result
    exit 0
}

# 执行剪辑
Write-Host "正在准备剪辑..." -ForegroundColor Yellow
Write-Host "模式: $mode" -ForegroundColor Yellow
Write-Host "视频文件: $videoFile" -ForegroundColor Yellow
Write-Host "" -ForegroundColor Yellow

$cutResult = Invoke-PythonScript "cut_video.py" @($videoFile, "--report", $reportFile, "--mode", $mode)

if ($LASTEXITCODE -ne 0) {
    $error = @{
        status = "error"
        message = "剪辑脚本执行失败"
        details = $cutResult
    } | ConvertTo-Json

    Write-JsonOutput $error
    exit 1
}

# 输出结果
$result = @{
    status = "success"
    project_name = $projectName
    mode = $mode
    result = ($cutResult | ConvertFrom-Json)
    message = "视频剪辑完成"
} | ConvertTo-Json -Depth 10

Write-JsonOutput $result
