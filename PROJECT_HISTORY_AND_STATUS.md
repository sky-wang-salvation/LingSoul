# 项目历史与进度摘要（提供给后续 Agent 的背景）

本文档依据当前多轮对话内容整理：**不修改业务代码**，仅记录背景、已完成项、待办与环境事实，便于下一段会话接续。

---

## 1. 用户目标（贯穿对话）

在 **Mac + Cursor** 上实现「虾哥小智 AI（ESP32-S3）+ 本地 OpenClaw」串联，思路参考博文  
[对虾：虾哥小智 AI 和 OpenClaw合体](https://www.frogchou.com/2026/03/12/对虾：虾哥小智ai和openclaw合体/)。

端到端链路（概念）：

```text
ESP32 终端（听/说） ↔ xiaozhi-server（WS、ASR、TTS、OpenClaw bridge）↔ OpenClaw（myapp-channel 插件）
```

云端 **阶跃星辰** API：`https://api.stepfun.com/v1`，ASR 模型 `step-asr`，TTS 模型 `stepaudio-2.5-tts`。

**后续扩展目标（2026-05-12 新增）**：将应用场景切换为「**自闭症陪护智能娃娃**」，需要另行规划前后端，待 ASR/TTS 通路跑稳后详谈。

---

## 2. 仓库与路径（需在后续对话中继续使用）

| 说明 | 路径 |
|------|------|
| 当前 Cursor 工作区（电子系统工程） | `~/Desktop/electronic_system/` |
| **`xiaozhi-openclaw` 项目根** | `~/Desktop/electronic_system/xiaozhi-openclaw/` |
| **`xiaozhi-server`**（Python bridge 服务） | `~/Desktop/electronic_system/xiaozhi-openclaw/xiaozhi-server/` |
| **myapp-channel 插件源码包** | `~/Desktop/electronic_system/xiaozhi-openclaw/myapp-channel-0.1.0/myapp-channel/` |
| **小智固件源码** | `~/Downloads/xiaozhi-esp32-main/` |
| OpenClaw 配置与插件 | `~/.openclaw/openclaw.json`，`~/.openclaw/extensions/`（含 `myapp-channel`、`feishu`、`stepfun` 等） |

**启动脚本**

- `~/Desktop/electronic_system/xiaozhi-openclaw/start_server.sh`：进入 `xiaozhi-server`，使用项目内 `.venv` 启动 `main.py`。
- `~/Desktop/electronic_system/xiaozhi-openclaw/flash_esp32.sh`：用 IDF 5.5.3 export 后烧录固件。

---

## 3. OpenClaw 侧（已完成 / 需注意）

### 3.1 版本

- CLI 版本：**v2026.5.7**（对话中通过 `npm install -g openclaw@latest` 升级）。
- 曾执行 **`openclaw gateway install --force`** 修复 LaunchAgent 问题。

### 3.2 myapp-channel（桥）

- **安装位置**：`~/.openclaw/extensions/myapp-channel/`。
- **`openclaw.json`** 中 `channels.myapp-channel`：`bridgeUrl = ws://127.0.0.1:8080/openclaw-bridge`，`bridgeToken` 与服务端 `.env` 中 `OPENCLAW_BRIDGE_TOKEN` 对齐。
- 日志验证：**`[myapp-channel] bridge connected`** 正常循环（无设备时每 30s 空闲超时后自动重连，属正常现象）。

### 3.3 已知非致命告警

- `feishu`、`stepfun`、`myapp-channel` 曾因仅有 `index.ts` 无编译产物 / manifest 缺 `channelConfigs` 出现告警；网关仍正常列出 `myapp-channel` channel。

---

## 4. xiaozhi-server（Python）侧（已完成 / 需注意）

### 4.1 依赖与环境

- 使用 `xiaozhi-server/.venv` 隔离环境，`start_server.sh` 用 `.venv/bin/python3` 启动。

### 4.2 配置（`.env`）—— 2026-05-11 最终状态

```
HOST=0.0.0.0
PORT=8080
OPENAI_API_KEY=<阶跃Key，见本机.env>
OPENAI_BASE_URL=https://api.stepfun.com/v1        ← 标准端点（非 plan）
WHISPER_MODEL=step-asr                             ← 文件转写模型（原 stepaudio-2.5-asr 走 SSE，不适用）
TTS_MODEL=stepaudio-2.5-tts
TTS_VOICE=cixingnansheng                           ← 阶跃中文音色（原 alloy 为 OpenAI 专属，报 400）
OPENCLAW_BRIDGE_PATH=/openclaw-bridge
OPENCLAW_BRIDGE_TOKEN=<见本机.env>
OPENCLAW_BRIDGE_REQUEST_TIMEOUT_SECONDS=120
OPENAI_TIMEOUT_SECONDS=30
```

### 4.3 config.py 修改

- `load_dotenv()` 改为 `load_dotenv(override=True)`，使 `.env` 始终优先于 shell 环境变量（Shell 中曾有 `OPENAI_BASE_URL=https://api.stepfun.com/step_plan/v1` 残留，会干扰）。

### 4.4 运行时已知问题

- **8080 端口占用**：旧进程存活时需 `lsof -ti:8080 | xargs kill` 再重启。
- **ffmpeg**：本机已安装，TTS WAV→Opus 路径正常。

### 4.5 当前待验证

- ASR/TTS 通路：修正 `step-asr` + `cixingnansheng` + `override=True` 后**尚未完成完整一轮测试**（2026-05-12 截止）。重启服务后需再唤醒设备说一句话，观察是否出现 `ASR Result: xxx` 和 `TTS response wav bytes=xxx`。

---

## 5. 小智 ESP32 固件（`~/Downloads/xiaozhi-esp32-main`）

### 5.1 板型配置（已确认）

- `sdkconfig`：`CONFIG_BOARD_TYPE_XINGZHI_CUBE_1_54TFT_WIFI=y`（星智 Cube 1.54 寸 TFT WiFi）。

### 5.2 关键源码修改（已做）

| 文件 | 修改内容 |
|---|---|
| `main/application.cc` | 强制 `protocol_ = std::make_unique<WebsocketProtocol>()` 绕过 OTA 协议判断；**删除激活死循环**：`ota_->MarkCurrentVersionValid()` 后直接 `break`，跳过 `HasActivationCode` 检查 |
| `main/protocols/websocket_protocol.cc` | `std::string url = "ws://172.20.10.2:8080";`（当前 Mac 在 iPhone 热点下的 IP） |

### 5.3 WiFi 配网（已完成）

- 设备通过 AP 配网页面（`Xiaozhi-DDC9` 热点 → `192.168.4.1`）接入当前 iPhone 热点。
- **串口确认**：设备成功连接 `ws://172.20.10.2:8080`，Session ID 生成，状态进入 `listening`。

### 5.4 激活（已处理）

- 官方激活码 `563865`：在第 2/10 次尝试时 `Activation successful`（设备已注册 xiaozhi.me）。
- 后续 **已在 `application.cc` 中移除激活死循环**，再换网络/重编译后不会再卡住。

### 5.5 换网络注意事项（重要）

- 固件 WebSocket URL **硬编码**为 `172.20.10.2`（当前 iPhone 热点 IP）。
- 换网络 → Mac IP 变化 → **必须修改 `websocket_protocol.cc` → `idf.py build` → `flash`**。
- ESP32 同时需要重新配网到新 WiFi（设备失联后自动进入 `Xiaozhi-DDC9` AP 配网模式）。
- IDF 环境：`source ~/Downloads/esp-idf-v5.5.3/export.sh` + `cd ~/Downloads/xiaozhi-esp32-main`。
- 串口设备：`/dev/cu.usbmodem3101`（以实际插入为准）。

---

## 6. Cursor / VS Code 与 ESP-IDF 插件

- **Cursor 全局 `settings.json`**（`~/Library/Application Support/Cursor/User/settings.json`）已将 `idf.espIdfPath` 指向 `~/Downloads/esp-idf-v5.5.3`。
- 状态栏应显示 5.5.x；若仍显示 6.1，执行 `Developer: Reload Window`。

---

## 7. 端到端自检清单（给下一 Agent）

1. **Mac IP** 是否与固件 `websocket_protocol.cc` 中的 `ws://xxx:8080` 一致。
2. **xiaozhi-server**：`.venv` 存在、8080 空闲、`.env` 的 `OPENAI_BASE_URL=https://api.stepfun.com/v1`、`WHISPER_MODEL=step-asr`、`TTS_VOICE=cixingnansheng`、`config.py` 使用 `load_dotenv(override=True)`。
3. **OpenClaw gateway**：`openclaw gateway status` 显示 running；日志有 `bridge connected`。
4. **设备**：屏幕显示"聆听中..."说明 WS 已建立；说话后 xiaozhi-server 日志出现 `ASR Result:`。
5. **ASR/TTS 通路**（当前最高优先级，尚未验证）：重启 server 后唤醒说一句话，确认无 404/400 错误。

---

## 8. 后续规划（2026-05-12 新增）

### 8.1 ASR/TTS 通路验证（当前优先级最高）

- 重启 `xiaozhi-server`，唤醒设备说话，确认 `step-asr` + `cixingnansheng` 组合无报错，能听到 TTS 回复。

### 8.2 自闭症陪护智能娃娃（新应用场景，待详谈）

- 现有技术栈（ESP32 + xiaozhi-server + OpenClaw）可复用。
- 需要另行规划：专属前端页面（家长/护理者监控端）、对话策略调整（温柔/鼓励型 Prompt）、数据记录等。
- **详细方案待下一轮会话讨论**。

### 8.3 其他待做

- bridge idle timeout 优化（当前 30s，可在 `openclaw.json` 调大 `timeoutMs`）。
- 固件 IP 硬编码问题（长期方案：mDNS 或配网页面输入服务端地址）。
- `start_server.sh` 中打印的 IP 地址（`10.142.19.119`）为过时硬编码，无实际影响但可更新。

---

## 9. 文档版本信息

- **整理日期**：2026-05-12（含 2026-05-11 操作）。
- **性质**：会话摘要 + 实施状态快照，不等同于官方文档。
- **若与机器现状不一致**：以本机 `openclaw.json`、`xiaozhi-server/.env`、`sdkconfig`、实际串口、`idf.py --version` 为准。
