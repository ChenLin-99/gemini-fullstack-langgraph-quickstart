#!/bin/bash

echo "🛑 停止 Gemini Fullstack LangGraph 开发环境"
echo "=============================================="

# 停止在50300和50302端口运行的进程
echo "正在停止服务..."

# 查找并停止后端服务 (端口50300)
BACKEND_PID=$(lsof -ti:50300 2>/dev/null)
if [ ! -z "$BACKEND_PID" ]; then
    echo "停止后端服务 (PID: $BACKEND_PID)..."
    kill $BACKEND_PID
    sleep 2
    # 如果进程仍在运行，强制停止
    if kill -0 $BACKEND_PID 2>/dev/null; then
        echo "强制停止后端服务..."
        kill -9 $BACKEND_PID
    fi
    echo "✅ 后端服务已停止"
else
    echo "ℹ️  后端服务未运行"
fi


# 查找并停止前端服务 (端口50302)
FRONTEND_PID=$(lsof -ti:50302 2>/dev/null)
if [ ! -z "$FRONTEND_PID" ]; then
    echo "停止前端服务 (PID: $FRONTEND_PID)..."
    kill $FRONTEND_PID
    sleep 2
    # 如果进程仍在运行，强制停止
    if kill -0 $FRONTEND_PID 2>/dev/null; then
        echo "强制停止前端服务..."
        kill -9 $FRONTEND_PID
    fi
    echo "✅ 前端服务已停止"
else
    echo "ℹ️  前端服务未运行"
fi

# 停止可能的npm进程
NPM_PIDS=$(pgrep -f "npm run dev" 2>/dev/null)
if [ ! -z "$NPM_PIDS" ]; then
    echo "停止npm进程..."
    echo $NPM_PIDS | xargs kill 2>/dev/null
    echo "✅ npm进程已停止"
fi

# 停止可能的langgraph进程
LANGGRAPH_PIDS=$(pgrep -f "langgraph dev" 2>/dev/null)
if [ ! -z "$LANGGRAPH_PIDS" ]; then
    echo "停止langgraph进程..."
    echo $LANGGRAPH_PIDS | xargs kill 2>/dev/null
    echo "✅ langgraph进程已停止"
fi

echo ""
echo "🎉 所有服务已停止！"
echo ""
echo "📝 日志文件保留在:"
echo "   - backend.log"
echo "   - frontend.log" 