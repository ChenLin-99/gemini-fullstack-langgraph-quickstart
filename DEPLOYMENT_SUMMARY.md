# Gemini Fullstack LangGraph 部署总结

## 🎉 部署完成状态

✅ **所有依赖已安装完成**
✅ **端口已调整到50300-50399范围**
✅ **开发环境已配置完成**
✅ **启动脚本已创建**

## 📊 端口分配

| 服务 | 端口 | 说明 |
|------|------|------|
| 后端API (LangGraph) | 50300 | 主要的API服务 |
| PostgreSQL数据库 | 50301 | 数据库服务 (Docker模式) |
| 前端开发服务 | 50302 | React开发服务器 |

## 🚀 快速启动

### 方法1: 使用启动脚本 (推荐)
```bash
# 启动所有服务
./start-dev.sh

# 停止所有服务
./stop-dev.sh
```

### 方法2: 手动启动
```bash
# 启动后端 (终端1)
cd backend
source venv/bin/activate
langgraph dev --port 50300

# 启动前端 (终端2)
cd frontend
npm run dev
```

## 🔧 访问地址

- **前端应用**: http://localhost:50302/app/
- **后端API**: http://localhost:50300/
- **LangGraph Studio**: 后端启动时会自动打开

## ⚠️ 重要配置

### 1. 设置Gemini API密钥
编辑 `backend/.env` 文件：
```bash
GEMINI_API_KEY="your_actual_gemini_api_key"
LANGSMITH_API_KEY="your_langsmith_api_key"  # 可选
PORT=50300
```

### 2. 获取Gemini API密钥
1. 访问 [Google AI Studio](https://aistudio.google.com/app/apikey)
2. 创建新的API密钥
3. 将密钥复制到 `backend/.env` 文件中

## 📁 项目结构

```
250605-gemini-dr/
├── backend/                 # 后端服务
│   ├── venv/               # Python虚拟环境
│   ├── .env                # 环境变量配置
│   └── src/agent/          # LangGraph代理代码
├── frontend/               # 前端应用
│   ├── node_modules/       # Node.js依赖
│   └── src/                # React源代码
├── start-dev.sh           # 启动脚本
├── stop-dev.sh            # 停止脚本
└── DEPLOYMENT_SUMMARY.md  # 本文档
```

## 🔍 故障排除

### 检查服务状态
```bash
# 检查端口占用
netstat -tlnp | grep :503

# 检查进程
ps aux | grep -E "(langgraph|npm)"
```

### 查看日志
```bash
# 后端日志
tail -f backend.log

# 前端日志
tail -f frontend.log
```

### 常见问题

1. **后端启动失败**
   - 检查 `GEMINI_API_KEY` 是否正确设置
   - 确保虚拟环境已激活
   - 查看 `backend.log` 获取详细错误信息

2. **前端无法访问后端**
   - 确认后端在50300端口运行
   - 检查防火墙设置
   - 验证代理配置 (`frontend/vite.config.ts`)

3. **端口冲突**
   - 使用 `netstat -tlnp | grep :503` 检查端口占用
   - 运行 `./stop-dev.sh` 停止所有服务

## 🐳 Docker部署 (可选)

如果需要使用Docker部署：

1. **构建镜像**:
   ```bash
   docker build -t gemini-fullstack-langgraph -f Dockerfile .
   ```

2. **启动服务**:
   ```bash
   GEMINI_API_KEY=your_key LANGSMITH_API_KEY=your_key docker-compose up
   ```

3. **访问地址**: http://localhost:50300/app/

## 📝 开发说明

- 前端使用热重载，修改代码会自动刷新
- 后端使用LangGraph的开发模式，支持代码热重载
- 所有端口都在50300-50399范围内，避免与其他服务冲突

## 🎯 下一步

1. 在 `backend/.env` 中设置真实的 `GEMINI_API_KEY`
2. 运行 `./start-dev.sh` 启动服务
3. 访问 http://localhost:50302/app/ 开始使用应用
4. 根据需要修改代理配置和功能

---

**部署完成时间**: $(date)
**Node.js版本**: v20.18.2
**Python版本**: $(python3 --version)
**部署用户**: $(whoami) 