#!/bin/bash
# xiaozhi-server 启动脚本
# OpenClaw 需要已经在运行 (openclaw gateway status)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/xiaozhi-server"

echo "=== 小智后台服务启动 ==="
echo "Bridge URL: ws://127.0.0.1:8080/openclaw-bridge"
echo "ESP32 连接地址: ws://10.142.19.119:8080"
echo ""

cd "$SERVER_DIR"
.venv/bin/python3 main.py
