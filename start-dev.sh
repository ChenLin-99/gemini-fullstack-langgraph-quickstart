#!/bin/bash

echo "🚀 启动 Gemini Fullstack LangGraph 开发环境"
echo "================================================"

# 检查是否在项目根目录
if [ ! -f "README.md" ] || [ ! -d "backend" ] || [ ! -d "frontend" ]; then
    echo "❌ 请在项目根目录运行此脚本"
    exit 1
fi

# 检查环境变量
if [ ! -f "backend/.env" ]; then
    echo "❌ 请先配置 backend/.env 文件，设置 GEMINI_API_KEY"
    echo "   示例: GEMINI_API_KEY=\"your_actual_api_key\""
    exit 1
fi

# 检查GEMINI_API_KEY是否设置
if grep -q "YOUR_ACTUAL_GEMINI_API_KEY" backend/.env; then
    echo "⚠️  警告: 请在 backend/.env 中设置真实的 GEMINI_API_KEY"
    echo "   当前设置为占位符，需要替换为真实的API密钥"
fi

echo "📦 检查依赖..."

# 检查端口占用情况
OCCUPIED_PORTS=""
if lsof -i :50300 2>/dev/null; then
    OCCUPIED_PORTS="$OCCUPIED_PORTS 50300"
fi
if lsof -i :50302 2>/dev/null; then
    OCCUPIED_PORTS="$OCCUPIED_PORTS 50302"
fi

if [ ! -z "$OCCUPIED_PORTS" ]; then
    echo "⚠️  警告: 以下端口被占用:$OCCUPIED_PORTS"
    echo "   建议先运行: ./stop-dev.sh 或手动清理端口"
    read -p "   是否继续启动? (y/N): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo "❌ 启动已取消"
        exit 1
    fi
fi

# 检查后端虚拟环境
if [ ! -d "backend/venv" ]; then
    echo "❌ 后端虚拟环境不存在，请运行: cd backend && python3 -m venv venv && source venv/bin/activate && pip install -i https://pypi.tuna.tsinghua.edu.cn/simple ."
    exit 1
fi

# 检查前端依赖
if [ ! -d "frontend/node_modules" ]; then
    echo "❌ 前端依赖未安装，请运行: cd frontend && npm install"
    exit 1
fi

echo "🔧 启动服务..."

# 启动后端服务 (后台运行)
echo "启动后端服务 (端口: 50300)..."
cd backend
source venv/bin/activate
# 加载环境变量（包括代理配置）
export $(grep -v '^#' .env | xargs)
nohup langgraph dev --port 50300 > ../backend.log 2>&1 &
BACKEND_PID=$!
cd ..

# 等待后端启动
echo "等待后端服务启动..."
sleep 5

# 检查后端是否启动成功
if curl -s http://localhost:50300/ > /dev/null; then
    echo "✅ 后端服务启动成功 (PID: $BACKEND_PID)"
else
    echo "❌ 后端服务启动失败，请检查 backend.log"
    exit 1
fi

# 启动前端服务 (后台运行)
echo "启动前端服务 (端口: 50302)..."
cd frontend
nohup npm run dev > ../frontend.log 2>&1 &
FRONTEND_PID=$!
cd ..

# 等待前端启动
echo "等待前端服务启动..."
sleep 5

# 检查前端是否启动成功
if curl -s http://localhost:50302/app/ > /dev/null; then
    echo "✅ 前端服务启动成功 (PID: $FRONTEND_PID)"
else
    echo "❌ 前端服务启动失败，请检查 frontend.log"
    exit 1
fi

echo ""
echo "🎉 所有服务启动成功！"
echo "================================================"
echo "📱 前端应用: http://localhost:50302/app/"
echo "🔧 后端API:  http://localhost:50300/"
echo "📊 服务状态:"
echo "   - 后端进程 PID: $BACKEND_PID"
echo "   - 前端进程 PID: $FRONTEND_PID"
echo ""
echo "📝 日志文件:"
echo "   - 后端日志: backend.log"
echo "   - 前端日志: frontend.log"
echo ""
echo "🛑 停止服务: kill $BACKEND_PID $FRONTEND_PID"
echo "   或运行: ./stop-dev.sh"
echo ""
echo "💡 提示: 请确保在 backend/.env 中设置了有效的 GEMINI_API_KEY" 