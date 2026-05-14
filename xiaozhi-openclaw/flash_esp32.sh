#!/bin/bash
# ESP32-S3 烧录脚本
# 运行前确认设备已用 USB 连接到 Mac

FIRMWARE_DIR="$HOME/Downloads/xiaozhi-esp32-main"

# 检测串口
PORT=$(ls /dev/cu.usbmodem* /dev/cu.usb* /dev/cu.wch* 2>/dev/null | head -1)
if [ -z "$PORT" ]; then
    echo "ERROR: 未找到 USB 串口设备，请先连接 ESP32-S3"
    echo "连接后重新运行此脚本"
    exit 1
fi

echo "=== ESP32-S3 固件烧录 ==="
echo "串口: $PORT"
echo "固件: $FIRMWARE_DIR/build"
echo ""

# 加载 IDF 5.5.3 环境
unset IDF_PATH IDF_PYTHON_ENV_PATH IDF_TOOLS_PATH ESP_IDF_VERSION
source "$HOME/Downloads/esp-idf-v5.5.3/export.sh" 2>/dev/null

cd "$FIRMWARE_DIR"
idf.py -p "$PORT" flash monitor
