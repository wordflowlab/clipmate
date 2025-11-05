# 通用函数库 - ClipMate (PowerShell)

# 获取 ClipMate 项目根目录
function Get-ClipMateRoot {
    $current = Get-Location

    # 检查当前目录
    if (Test-Path ".clipmate\config.json") {
        return $current
    }

    # 向上查找
    $dir = $current
    while ($dir.Parent) {
        if (Test-Path "$dir\.clipmate\config.json") {
            return $dir
        }
        $dir = $dir.Parent
    }

    Write-Error "错误: 未找到 clipmate 项目根目录"
    Write-Error "提示: 请在 clipmate 项目目录内运行，或先运行 'clipmate init <项目名>' 创建项目"
    exit 1
}

# 获取项目名称
function Get-ProjectName {
    $root = Get-ClipMateRoot
    $configFile = Join-Path $root ".clipmate\config.json"

    if (Test-Path $configFile) {
        $config = Get-Content $configFile | ConvertFrom-Json
        return $config.name
    }

    return (Split-Path $root -Leaf)
}

# 输出 JSON
function Write-JsonOutput {
    param([string]$JsonString)
    Write-Output $JsonString
}

# 确保目录存在
function Ensure-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

# 调用 Python 脚本
function Invoke-PythonScript {
    param(
        [string]$ScriptName,
        [string[]]$Arguments
    )

    $scriptDir = Split-Path -Parent $PSCommandPath
    $pythonScript = Join-Path $scriptDir "..\python\$ScriptName"

    $result = & python $pythonScript @Arguments 2>&1
    return $result
}

# 检查 Python 依赖
function Test-PythonDependency {
    param([string]$PackageName)

    try {
        & python -c "import $PackageName" 2>$null
        return $true
    }
    catch {
        return $false
    }
}

# 查找视频文件
function Find-VideoFile {
    $root = Get-ClipMateRoot
    $videoDir = Join-Path $root "videos"

    $extensions = @("*.mp4", "*.mov", "*.avi", "*.mkv")
    $videos = @()

    foreach ($ext in $extensions) {
        $found = Get-ChildItem -Path $videoDir -Filter $ext -File -ErrorAction SilentlyContinue
        $videos += $found
    }

    if ($videos.Count -gt 0) {
        return $videos[0].FullName
    }

    return $null
}

# 获取视频信息 (使用 ffprobe)
function Get-VideoInfo {
    param([string]$VideoPath)

    # 检查 ffprobe 是否安装
    $ffprobeExists = Get-Command ffprobe -ErrorAction SilentlyContinue
    if (-not $ffprobeExists) {
        return @{ error = "ffprobe 未安装" }
    }

    try {
        # 获取时长
        $duration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $VideoPath 2>$null

        # 获取分辨率
        $width = & ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 $VideoPath 2>$null
        $height = & ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 $VideoPath 2>$null

        # 获取帧率
        $fpsRaw = & ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 $VideoPath 2>$null
        $fpsParts = $fpsRaw -split '/'
        if ($fpsParts.Count -eq 2) {
            $fps = [math]::Round([double]$fpsParts[0] / [double]$fpsParts[1], 2)
        } else {
            $fps = [double]$fpsRaw
        }

        # 获取码率
        $bitrate = & ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 $VideoPath 2>$null

        return @{
            duration = [double]$duration
            width = [int]$width
            height = [int]$height
            fps = $fps
            bitrate = [int]$bitrate
        }
    }
    catch {
        return @{ error = $_.Exception.Message }
    }
}

# 格式化时长 (秒转为 HH:MM:SS)
function Format-Duration {
    param([int]$Seconds)

    $hours = [math]::Floor($Seconds / 3600)
    $minutes = [math]::Floor(($Seconds % 3600) / 60)
    $secs = $Seconds % 60

    return "{0:D2}:{1:D2}:{2:D2}" -f $hours, $minutes, $secs
}

# 检查 FFmpeg 是否安装
function Test-FFmpeg {
    $ffmpegExists = Get-Command ffmpeg -ErrorAction SilentlyContinue

    if (-not $ffmpegExists) {
        $error = @{
            status = "error"
            message = "FFmpeg 未安装。请从 https://ffmpeg.org/download.html 下载并安装 FFmpeg"
        } | ConvertTo-Json

        Write-JsonOutput $error
        exit 1
    }
}

# 检查 Python3 是否安装
function Test-Python {
    $pythonExists = Get-Command python -ErrorAction SilentlyContinue

    if (-not $pythonExists) {
        $error = @{
            status = "error"
            message = "Python 未安装。请从 https://www.python.org/downloads/ 下载并安装 Python"
        } | ConvertTo-Json

        Write-JsonOutput $error
        exit 1
    }
}

# 导出函数供其他脚本使用
Export-ModuleMember -Function *
