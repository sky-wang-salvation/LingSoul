# LingSoul · 灵伴

面向自闭症儿童的智能陪护玩偶——南开大学电子系统设计实战课程项目。

---

## 项目简介

本项目基于 ESP32-S3 硬件平台，结合 OpenClaw 大模型框架，构建一个能够 24 小时陪伴自闭症儿童、实时识别情绪状态、进行安抚引导的智能玩偶原型。

端到端链路：

```
ESP32-S3（听/说）
    ↕ WebSocket
xiaozhi-server（ASR / TTS via 阶跃星辰）
    ↕ WebSocket Bridge
OpenClaw（LLM 对话引擎，角色：灵伴）
```

---

## 目录结构

```
.
├── main/                       # ESP32-S3 固件占位（开发中）
├── xiaozhi-openclaw/
│   ├── xiaozhi-server/         # Python 桥接服务（ASR / TTS / WebSocket）
│   │   ├── core/               # 服务器核心（session、event_bus、dashboard）
│   │   ├── services/           # ASR、LLM、TTS、OpenClaw bridge
│   │   ├── frontend/
│   │   │   └── dashboard.html  # 家长监控端（浏览器打开）
│   │   ├── config.py
│   │   ├── main.py
│   │   └── requirements.txt
│   ├── myapp-channel-0.1.0/    # OpenClaw myapp-channel 插件
│   ├── start_server.sh         # 一键启动 xiaozhi-server
│   └── flash_esp32.sh          # 一键编译烧录固件
├── PROJECT_HISTORY_AND_STATUS.md
└── 自闭症陪护玩偶_开题报告_优化版.docx
```

---

## 快速开始

### 1. 环境依赖

- macOS / Linux
- Python 3.10+
- Node.js（OpenClaw CLI）
- ESP-IDF v5.5.3（仅烧录固件时需要）
- [OpenClaw](https://openclaw.ai) CLI（`npm install -g openclaw@latest`）

### 2. 配置 xiaozhi-server

复制并填写环境变量：

```bash
cp xiaozhi-openclaw/xiaozhi-server/.env.example xiaozhi-openclaw/xiaozhi-server/.env
```

`.env` 关键字段：

```env
OPENAI_API_KEY=<阶跃星辰 API Key>
OPENAI_BASE_URL=https://api.stepfun.com/v1
WHISPER_MODEL=stepaudio-2.5-asr
TTS_MODEL=stepaudio-2.5-tts
TTS_VOICE=cixingnansheng
OPENCLAW_BRIDGE_TOKEN=<与 openclaw.json 中一致>
```

### 3. 启动服务

```bash
# start_server.sh 会自动重启 OpenClaw gateway 并清理旧进程，直接运行即可：
cd xiaozhi-openclaw
bash start_server.sh
```

> **说明**：每次启动脚本都会先执行 `openclaw gateway restart`，确保 `openclaw.json` 中的模型配置（当前 `step-3.7-flash`）立即生效，无需手动重启。

### 4. 家长监控端

服务启动后，在同局域网的浏览器中打开：

```
http://<Mac的IP>:8080/dashboard.html
```

实时查看设备在线状态、对话记录、今日统计。

### 5. 烧录固件（首次或换网络时）

修改固件中的 WebSocket 服务端地址：

```cpp
// 文件：~/Downloads/xiaozhi-esp32-main/main/protocols/websocket_protocol.cc
std::string url = "ws://<Mac的IP>:8080";
```

然后编译烧录：

```bash
source ~/Downloads/esp-idf-v5.5.3/export.sh
cd ~/Downloads/xiaozhi-esp32-main
idf.py build flash monitor -p /dev/cu.usbmodem3101
```

---

## 关键设计说明

| 功能 | 实现方式 |
|---|---|
| 语音识别（ASR） | 阶跃星辰 `stepaudio-2.5-asr`，通过 OpenAI 兼容 transcriptions 接口调用 |
| 语音合成（TTS） | 阶跃星辰 `stepaudio-2.5-tts`，音色 `cixingnansheng` |
| 对话引擎 | OpenClaw + `step-3.7-flash`，角色设定见 `~/.openclaw/workspace/SOUL.md` |
| 静默优化 | ASR 识别为空（环境噪声/无语音）时静默跳过，不调用 LLM/TTS，不消耗 token |
| 打断支持 | 说话时可随时打断灵伴（barge-in），TTS 开始后 0.8s 保护期后即可中断 |
| 始终聆听 | 固件已禁用唤醒词，设备空闲时自动进入聆听模式（无需说"你好小智"）|
| 家长监控 | `xiaozhi-server` 内置 `/dashboard.html`，WebSocket 实时推送事件 |

---

## 成员

王佳霓、李春颖、刘崇慧  
电子信息与光学工程学院，南开大学  
指导教师：高艺

---

## 许可

本项目为课程实践作品，仅供学习与研究使用。
