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

云端 **阶跃星辰** API：`https://api.stepfun.com/v1`，ASR 模型 `stepaudio-2.5-asr`，TTS 模型 `stepaudio-2.5-tts`。

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
OPENAI_BASE_URL=https://api.stepfun.com/v1
WHISPER_MODEL=stepaudio-2.5-asr                    ← 2026-05-14 从 step-asr 升级，中文短语音识别更准确
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

### 4.5 当前已验证

- ASR/TTS 通路：完整链路已于 2026-05-14 跑通（见 8.1）。
- ASR 模型于 2026-05-14 从 `step-asr` 升级为 `stepaudio-2.5-asr`，中文识别更准确，减少乱识别。

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

## 8. 已完成操作（2026-05-14）

### 8.1 ASR/TTS 通路验证 ✅

- 2026-05-14 实测完整链路跑通：
  - Turn 1：ASR 识别"你好。"→ OpenClaw LLM 回复 272字 → TTS wav 2.27MB → 设备播放出声。
  - 后续轮次出现 `no speech found` 属正常（麦克风采到空音频），不是 Bug。

### 8.2 GitHub 版本管理 ✅

- 仓库：[https://github.com/sky-wang-salvation/LingSoul](https://github.com/sky-wang-salvation/LingSoul)
- 初始提交包含：xiaozhi-server、myapp-channel 插件、ESP32 工程骨架、开题报告。
- `.gitignore` 已排除 `.env`（API Key）、`.venv`、`build/`。

### 8.3 OpenClaw 模型升级 ✅

- 从 `step-3.5-flash` 升级为 `step-3.7-flash`（通过 CC Switch 添加，`openclaw.json` 已更新）。
- `custom-api-stepfun-com`（旧 3.5 Provider）已删除。
- `agents.defaults.model.primary` 现为 `step-3-7-flash/step-3.7-flash`。
- 已执行 `openclaw gateway restart` 使配置生效。

### 8.4 SOUL.md 改写（灵伴 ASD 场景）✅

- 文件：`~/.openclaw/workspace/SOUL.md`
- 保留"灵伴"名字，针对自闭症儿童定制：
  - 每句话不超过 20 字，简单词汇
  - 积极强化、重复确认、情绪优先、不评判
  - 情绪响应策略（哭泣/沉默/焦虑）
  - 互动游戏库（按情绪状态选择）
- `IDENTITY.md` 同步更新，预留孩子基本信息填写位置。

### 8.5 固件：始终聆听模式（方案 B）✅

- 文件：`~/Downloads/xiaozhi-esp32-main/main/application.cc`
- 修改内容：
  1. `kDeviceStateIdle` 分支：`EnableWakeWordDetection(false)`，并 `Schedule` 自动调用 `WakeWordInvoke("")`
  2. `ContinueWakeWordInvoke`：连接失败时改为 `SetDeviceState(kDeviceStateIdle)` 触发重试，而非重新开启唤醒词
- **需重新编译烧录固件**：`idf.py build flash`（需先修复 cryptography 依赖，见 8.7）

### 8.6 家长监控前端 ✅

- 文件：`xiaozhi-openclaw/xiaozhi-server/frontend/dashboard.html`
- 访问方式：服务启动后浏览器打开 `http://<MacIP>:8080/dashboard.html`
- 实现：
  - `core/event_bus.py`：内存事件总线，存 200 条历史
  - `core/session.py`：在 ASR、LLM、设备上线/离线时 emit 事件
  - `core/server.py`：新增 `/dashboard` WebSocket 端点推送事件，`/dashboard.html` HTTP 端点提供页面
  - 前端：对话气泡（孩子/灵伴分左右）、今日统计、事件原始日志，纯 HTML/JS，无框架依赖

### 8.7 待办：烧录新固件

- 先修复 ESP-IDF Python 依赖：
  ```bash
  ~/Downloads/esp-idf-v5.5.3/install.sh
  ```
- 再编译烧录：
  ```bash
  source ~/Downloads/esp-idf-v5.5.3/export.sh
  cd ~/Downloads/xiaozhi-esp32-main
  idf.py build flash monitor -p /dev/cu.usbmodem3101
  ```

---

## 9. 历史技术栈快照（2026-05-14 午，已被第 12 节取代）

| 组件 | 状态（午） | 说明 |
|---|---|---|
| ESP32-S3 固件 | 待烧录 | 已修改始终聆听，待 `idf.py flash` |
| xiaozhi-server | 运行中 | ASR/TTS 通路已验证，新增 event_bus + dashboard |
| OpenClaw | 运行中 | 已切换 step-3.7-flash，SOUL.md 已更新 |
| 家长监控前端 | 已写完 | 待重启 server 验证 |
| GitHub | 已推送 | 初始版本，后续修改需 `git commit && git push` |

---

---

## 11. 2026-05-14 晚间优化（本次提交）

### 11.1 ASR 模型升级 ✅

- `.env` 中 `WHISPER_MODEL` 从 `step-asr` 改为 `stepaudio-2.5-asr`。
- 背景：`step-asr` 对短语音/中文识别率低，经常返回空串触发"我没听清"循环；`stepaudio-2.5-asr` 支持同一 transcriptions 接口且识别效果更好。

### 11.2 静默优化（核心 Token 节约）✅

- 修改 `core/session.py` `_process_turn` 方法：ASR 返回空字符串时，静默 return，**不再调用 LLM、不再合成 TTS、不说"我没听清"**。
- 效果：在"始终聆听"模式下，环境噪声/无人说话时不会无意义消耗 token，也不会触发"我没听清"→ TTS 播放 → 再次采音 → 再次为空的死循环。

### 11.3 OpenClaw 重启机制 ✅

- `start_server.sh` 新增：启动服务前自动执行 `openclaw gateway restart`（等待 3s 就绪）并清理 8080 端口旧进程。
- 解决：每次改完 `openclaw.json`（如切换模型）后忘记手动重启 gateway 导致模型不生效的问题。
- 已手动执行一次 `openclaw gateway restart`，当前 gateway 运行最新配置（`step-3.7-flash`）。

### 11.4 打断机制（已确认可用）

- `session.py` 中已实现 barge-in：TTS 开始播放后 `BARGE_IN_GRACE_SECONDS=0.8s` 保护期过后，说话即可打断灵伴。
- 无需任何特殊操作，直接开口说话即触发，`listening_mode` 须为 `auto`（默认值）。

---

## 12. 当前技术栈快照（2026-05-14 晚）

| 组件 | 状态 | 说明 |
|---|---|---|
| ESP32-S3 固件 | 已烧录运行 | 始终聆听模式，WebSocket 已连接 |
| xiaozhi-server | 需重启 | 已修改 session.py + .env，重启后生效 |
| OpenClaw | 运行中 | gateway 已重启，step-3.7-flash 生效 |
| ASR 模型 | stepaudio-2.5-asr | 中文识别更准确 |
| LLM 模型 | step-3.7-flash | OpenClaw 主模型 |
| 家长监控前端 | 已上线 | http://\<MacIP\>:8080/dashboard.html |
| GitHub | 需推送 | 本次修改待 push |

---

## 13. 文档版本信息

- **整理日期**：2026-05-14 晚（更新至静默优化 + ASR 升级 + restart 机制）。
- **性质**：会话摘要 + 实施状态快照，不等同于官方文档。
- **若与机器现状不一致**：以本机 `openclaw.json`、`xiaozhi-server/.env`、`sdkconfig`、实际串口、`idf.py --version` 为准。
