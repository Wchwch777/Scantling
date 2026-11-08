# Scantling Trace — MQTT 有状态协议轨迹校验器

用 MoonBit 检查 MQTT 3.1.1 双向报文之间的状态关系：ACK 是否对应正确阶段，
identifier 是否仍被另一笔请求占用，重传内容是否变化，以及已知会话断开后
能否继续未完成事务。可作为纯计算库、离线轨迹 CLI 或原生测试对端的观察器使用。

十一月新增 `mqtt/monitor`、报告和轨迹工具。十月已有的编解码依赖、异步客户端、
文本脚本与 Mosquitto CI 是历史底座，不重复算作十一月成果。
十月申报未通过初审；保留原仓库和历史，不改建仓日期或隐藏旧功能。
本次独立贡献见 [本地自查](docs/november-review.md)。

## 使用场景

1. **检查交错通信**：多笔 QoS 1/2 同时在途，两端使用相同数值 id，仍按各自
   历史关联应答，无须枚举所有线性脚本排列。
2. **定位协议回归**：能解码但阶段错误的 ACK，输出事件索引、规则与原因；
   区分已发现错误和仅捕获到未完成前缀。
3. **复现恢复与时序边界**：重放已知持久会话在 PUBREL 阶段断线并恢复的过程，
   或用逻辑时间检查 Keep Alive，无须长时间睡眠。
4. **检查测试对端自身**：同时观察客户端输入与服务端输出，在写出错误 ACK 前诊断。

这些是可运行的工程场景，不是已部署客户案例。

## 快速运行

当前本地和既有 CI 使用 `moonc 0.10.15+943464bfa` / `moon 0.1.20261012`。
依赖固定在 [moon.mod](moon.mod)。Native 需要 C 构建工具；Windows 未配置
MSVC 时可以在安装了 MoonBit 的 WSL 运行。

```sh
moon update
moon test mqtt/monitor --target wasm --deny-warn
moon run --target native examples/check_trace
```

默认轨迹是双向同 id 的 QoS 2 与交错 QoS 1，输出：

```json
{"valid_prefix":true,"complete":true,"events":14,"connections":1,"completed_publications":3,"retransmissions":0,"pending":0,"abandoned":0,"diagnostics":[]}
```

PowerShell 下检查错误应答例子：

```powershell
$env:SCANTLING_TRACE = "examples/check_trace/traces/wrong-ack.trace"
moon run --target native examples/check_trace
```

该例非零退出，第四个事件报告 `TRACE-ACK-STAGE`。
输入格式、API、在线 Mosquitto 步骤及边界见 [monitor.md](docs/monitor.md)。
[可执行文档](mqtt/monitor/README.mbt.md) 随项目测试验证。

## 结构与新增边界

| 目录 | 职责 |
| --- | --- |
| `mqtt/monitor` | 十一月新增；双向状态机、在途表、诊断、轨迹解析与 JSON 报告 |
| `examples/check_trace` | 十一月新增；CLI、自制轨迹与结果回归 |
| `mqtt/fault_peer` | 十月线性对端；十一月增加可选监控、总时限及异常清理 |
| `mqtt` | 十月异步客户端，作为被测对象和示例底座 |
| `mqtt/integration_test` | 十一月补充监控真实收发、错误归因和超时测试 |

模块为 `Wchwch777/scantling`，替换原先未带命名空间的 `scantling_mqtt_client`，
包引用同步迁移。这是发布准备，尚未发布到 Mooncakes。

## 验证

```sh
moon fmt --check
moon check --target wasm
moon test --target wasm
moon build --target wasm
moon check --target native
moon test --target native
moon build --target native
```

真实 Broker 测试需在 1883 启动允许本地匿名测试的 Mosquitto，
并设置 `SCANTLING_MOSQUITTO_HOST=127.0.0.1`。
认证路径另需 `SCANTLING_MOSQUITTO_AUTH_HOST` 和独立认证 Broker；
没有环境时会跳过，不能把跳过当成实测。
配置见 [.github/workflows/ci.yml](.github/workflows/ci.yml)。
CI 增加监控器严格测试、构建及轨迹 CLI，独立客户端文本脚本启用监控。
本地核验记录和远程 CI 分别见 [十一月自查](docs/november-review.md) 和
[GitHub Actions](https://github.com/Wchwch777/Scantling/actions)。

## 边界与来源

有限规则的协议观察工具，不是完整 Broker、抓包器或一致性认证套件。
检查已观察握手不等于证明应用恰好交付一次。
持久恢复要求历史完整、同 client ID 且服务端保留会话；未知或丢失状态会报告观察边界。
完整限制见 [monitor.md](docs/monitor.md)。
既有客户端不提供 TLS、自动重连或磁盘持久化。
旧脚本语法见 [fault-peer.md](docs/fault-peer.md)。

| 来源 | 用途 | 许可证 |
| --- | --- | --- |
| [zbhzs1/moonbit-mqtt@0.1.0](https://mooncakes.io/docs/zbhzs1/moonbit-mqtt) | 编解码 | Apache-2.0 |
| [moonbitlang/async@0.21.3](https://github.com/moonbitlang/async) | 异步及 TCP | Apache-2.0 |
| [OASIS MQTT 3.1.1](https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html) | 协议参考；未复制正文 | 标准文件保留自身版权 |

本仓库采用 [Apache-2.0](LICENSE)。Mosquitto 是独立测试程序，不打包进库。
生态对比见 [自查记录](docs/november-review.md)。
AI 辅助开发范围见 [AI_ASSISTED.md](AI_ASSISTED.md)。
