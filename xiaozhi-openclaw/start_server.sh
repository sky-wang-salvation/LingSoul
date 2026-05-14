#!/bin/bash
# xiaozhi-server 启动脚本
# 同时重启 OpenClaw gateway，确保模型/配置变更立即生效

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/xiaozhi-server"

echo "=== 小智后台服务启动 ==="
echo "Bridge URL: ws://127.0.0.1:8080/openclaw-bridge"
echo ""

# 重启 OpenClaw gateway，确保 openclaw.json 中的模型配置生效
echo "[1/2] 重启 OpenClaw gateway..."
openclaw gateway restart
# 等待 gateway 启动就绪
sleep 3
echo "[1/2] OpenClaw gateway 已重启"
echo ""

# 释放 8080 端口（如有残留旧进程）
PIDS=$(lsof -ti:8080 2>/dev/null)
if [ -n "$PIDS" ]; then
    echo "清理 8080 端口旧进程: $PIDS"
    echo "$PIDS" | xargs kill -9 2>/dev/null
    sleep 1
fi

echo "[2/2] 启动 xiaozhi-server..."
cd "$SERVER_DIR"
.venv/bin/python3 main.py
