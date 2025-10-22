@echo off
echo === AI建设助手服务启动脚本 ===

REM 检查Python环境
python --version >nul 2>&1
if errorlevel 1 (
    echo 错误: 未找到Python，请先安装Python
    pause
    exit /b 1
)

REM 创建虚拟环境（如果不存在）
if not exist "venv" (
    echo 创建Python虚拟环境...
    python -m venv venv
)

REM 激活虚拟环境
echo 激活虚拟环境...
call venv\Scripts\activate.bat

REM 安装依赖
echo 安装Python依赖...
pip install -r requirements.txt

REM 检查环境配置
if not exist ".env" (
    echo 复制环境配置文件...
    copy .env.example .env
    echo 请编辑 .env 文件，配置您的DeepSeek API密钥
    echo 然后重新运行此脚本
    pause
    exit /b 1
)

REM 启动服务
echo 启动AI建设助手服务...
echo 服务将在 http://localhost:8000 运行
echo 按 Ctrl+C 停止服务
echo.

python app.py

pause