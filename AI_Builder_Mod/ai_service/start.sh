#!/bin/bash

# AI建设助手服务启动脚本

echo "=== AI建设助手服务启动脚本 ==="

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到Python3，请先安装Python3"
    exit 1
fi

# 创建虚拟环境（如果不存在）
if [ ! -d "venv" ]; then
    echo "创建Python虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
echo "激活虚拟环境..."
source venv/bin/activate

# 安装依赖
echo "安装Python依赖..."
pip install -r requirements.txt

# 检查环境配置
if [ ! -f ".env" ]; then
    echo "复制环境配置文件..."
    cp .env.example .env
    echo "请编辑 .env 文件，配置您的DeepSeek API密钥"
    echo "然后重新运行此脚本"
    exit 1
fi

# 启动服务
echo "启动AI建设助手服务..."
echo "服务将在 http://localhost:8000 运行"
echo "按 Ctrl+C 停止服务"
echo ""

python app.py