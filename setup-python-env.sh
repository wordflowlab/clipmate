#!/bin/bash
# ClipMate Python 环境设置脚本

set -e

echo "📦 正在设置 ClipMate Python 环境..."

# 检查 Python 版本
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 python3，请先安装 Python 3.8+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo "✓ 检测到 Python $PYTHON_VERSION"

# 创建虚拟环境
if [ ! -d "venv" ]; then
    echo "📁 创建虚拟环境..."
    python3 -m venv venv
    echo "✓ 虚拟环境创建成功"
else
    echo "✓ 虚拟环境已存在"
fi

# 激活虚拟环境
echo "🔄 激活虚拟环境..."
source venv/bin/activate

# 升级 pip
echo "⬆️  升级 pip..."
pip install --upgrade pip > /dev/null 2>&1

# 安装依赖
if [ -f "requirements.txt" ]; then
    echo "📥 安装 Python 依赖..."
    pip install -r requirements.txt
    echo "✓ 依赖安装完成"
else
    echo "⚠️  警告: 未找到 requirements.txt 文件"
fi

echo ""
echo "✅ Python 环境设置完成！"
echo ""
echo "📝 使用说明:"
echo "   1. 每次使用前激活虚拟环境: source venv/bin/activate"
echo "   2. 使用完毕后退出: deactivate"
echo ""
echo "💡 提示: 你可以在项目根目录的 .env 或 bash 脚本中自动激活虚拟环境"

