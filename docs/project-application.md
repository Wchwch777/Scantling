# Scantling：MoonBit MQTT 3.1.1 脚本化协议测试对端

**项目方向：** MoonBit MQTT 协议测试与互操作工具

**仓库：** <https://github.com/Wchwch777/Scantling>

**许可证：** Apache-2.0

## 项目简介

Scantling 的主要可复用组件是一个 MoonBit MQTT 3.1.1 脚本化 Broker 对端。
调用者可用 MoonBit `Script`/`Exchange` API，或用命令行加载文本脚本，
按顺序匹配客户端报文并发送 MQTT 响应、PUBLISH、原始字节、延迟或断开连接；
仓库同时包含一个小型异步客户端，作为协议测试对象和可运行示例的客户端。
项目不据此声称填补了通用客户端空白，也不声称等同 Eclipse Paho 的完整测试工具集。
客户端复用 [`zbhzs1/moonbit-mqtt`](https://github.com/zbhzs1/moonbit-mqtt)
的报文编解码。项目不声称唯一性、已验证用户需求或真实部署。

## 已实现功能与可核查证据

- MQTT 3.1.1 TCP CONNECT/CONNACK 握手，以及顺序调用的连接 API：
  [`mqtt/client.mbt`](../mqtt/client.mbt)。
- 可选用户名/密码认证；密码必须与用户名一起提供。当前仅为明文 TCP，
  未实现 TLS，因此不应在不可信网络上传送凭据。
- 单主题与批量主题过滤器订阅/取消订阅，并等待对应应答；SUBACK 的数量、
  消息标识和每个主题授予的 QoS 均逐项核对；支持 QoS 0 发布、QoS 1 发布及
  PUBACK、QoS 2 发布握手及 QoS 0/1/2 接收；QoS 2 仅在 PUBREL 后交付，
  并对重复 PUBLISH/PUBREL 按协议应答而不重复交付。
- PINGREQ/PINGRESP；入站报文体限制为 1 MiB；等待应答期间最多缓冲 64 条入站消息，
  超限关闭连接并返回明确错误；拒绝无效发布主题及空订阅过滤器。
- 可选 `receive_with_keep_alive()` 在等待下一条消息时按 Keep Alive 周期发送
  PINGREQ 并校验 PINGRESP；缺少 PINGRESP 会关闭连接并返回超时错误。该保活只在
  此方法等待期间运行，不是后台任务；普通 `receive()` 仍可能无限等待且不发送 ping。
- 原生 loopback 测试覆盖客户端与协议对端的请求/应答流程；独立 Mosquitto
  测试使用两个客户端验证 QoS 1 与 QoS 2 订阅、投递和发布应答：
  [`mqtt/integration_test/client_test.mbt`](../mqtt/integration_test/client_test.mbt)。
- 可执行故障对端提供六个命令行预设，也可通过
  `SCANTLING_FAULT_SCRIPT` 加载文本脚本。脚本支持按类型、QoS、packet identifier、
  主题、PUBLISH payload 与 retain/DUP 标志匹配有序报文，并可发送 CONNACK、
  SUBACK、QoS 应答、PINGRESP、 broker-to-client PUBLISH、原始字节、延迟与关闭；
  字段错误、重复选项、关闭后的不可达步骤会被拒绝。公开 `Script`/`Exchange` API
  还可用 MoonBit 回调组合响应。集成测试覆盖无效 SUBACK、QoS 2 重复 PUBREC/PUBREL
  和截断 CONNACK。文本脚本场景另覆盖 QoS 2 的完整响应往返、两次 PINGREQ/PINGRESP
  后的事件投递和独立订阅端接收消息。当前源树在 WSL 上以 MoonBit
  `0.10.15+943464bfa`、Mosquitto CLI `2.0.22` 运行 49 项 Native 测试及三条独立 CLI
  场景均通过；完整 GitHub Actions 和需要独立 Broker 服务的条件测试仍须推送后核验。
- CI 固定运行 MoonBit `0.10.15+943464bfa` 与 Mosquitto `2.0.22`，执行格式检查、
  Wasm/Native 类型检查与测试、独立 Broker 路径和 Mosquitto 客户端故障对端检查。
  代码提交 [`2b55d44`](https://github.com/Wchwch777/Scantling/commit/2b55d44240fa3423be9804e07583cbdde849ac22)
  的 [CI run 40636347859](https://github.com/Wchwch777/Scantling/actions/runs/40636347859)
  通过格式检查、Wasm/Native 类型检查、18 项 Wasm 与 38 项 Native 测试、
  认证和非认证 Mosquitto Broker 路径、十秒客户端示例及四条独立 Mosquitto CLI
  对端预设路径。该历史结果不包含本地尚未推送的文本脚本运行器和 Mosquitto
  `mosquitto_sub`、脚本化 QoS 2 与空闲保活场景；不能把它当作这些新增代码的 CI 证据。它也不是完整
  MQTT 3.1.1 一致性认证。

## 代表性使用场景

仓库展示三种客户端 API 消息流：遥测接收、应用发布命令并接收设备状态回报、空闲保活后
接收事件；还提供一个文本脚本驱动的外部订阅端投递场景。前面三种是协议层示例，不是已部署
客户案例；外部订阅场景的本地 Native/CI 结果仍待验证。代码、测试与未覆盖边界见
[`docs/use-cases.md`](use-cases.md) 和 [`docs/fault-peer.md`](fault-peer.md)。
客户端演示位于 [`examples/mqtt_client`](../examples/mqtt_client/main.mbt)。

## 运行方式

先启动 MQTT 3.1.1 Broker（README 提供 Mosquitto 示例），再运行客户端演示：

```sh
moon run --target native examples/mqtt_client
```

运行文本脚本对端的步骤见 [`docs/fault-peer.md`](fault-peer.md#caller-defined-scripts)。

CI 的独立 Broker 路径及本地复现步骤见 [README](../README.md#development-and-verification)。

## 能力边界

客户端是单连接、顺序调用的 MQTT 3.1.1 原生 TCP 实现。它不提供 TLS、
自动重连、后台 Keep Alive 任务、操作超时、持久会话、MQTT 5.0
或 WebSocket。QoS 2 状态只保存在当前 Clean Session 连接的内存中，不支持断线恢复。
协议对端一次只服务一个连接，脚本是线性的；没有分支执行、并发客户端编排、负载测试、
系统性模糊测试或完整协议覆盖。项目也没有真实设备接入、客户部署、性能基准或市场调研证据。
无期限等待时，应用需
使用 `receive_with_keep_alive()` 或自行安排 PINGREQ，且不得并发操作同一个客户端连接。项目不声称生产级完整性或
协议认证。

## 赛事与申报材料

本项目面向 MoonBit 开源生态中的 MQTT 协议测试与互操作工具方向。
适用范围和验收要求
应以当届官方材料为准：[比赛章程](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)、
[比赛官网](https://moonbitlang.github.io/Hackathon2026/#process)。官网/章程的方向匹配
只说明选题背景，不替代对实际需求、用户采用或项目完成度的证明。

## AI 辅助与人工复核状态

AI 工具参与了代码、测试和文档的起草与整理；仓库公开说明见
[`AI_ASSISTED.md`](../AI_ASSISTED.md)。我（韦昌豪，GitHub: `Wchwch777`）
已对截至 2026-10-28 的全部十月新增工作（包含初始基线、QoS 2 实现与协议扩展、
原生故障注入对端、独立 Mosquitto 客户端验证、`receive_with_keep_alive()`
协调保活机制、十秒长空闲三段端到端示例，以及可编程 Script/Exchange 测试 API 与 38 项 Native 测试）完成逐行人工走查、本地自动化与端到端运行验证，
并在 [`docs/owner-review.md`](owner-review.md) 中签署了相应范围的复核记录、清单与日期。
2026-10-30/31 AI 辅助的脚本解析和新增协议场景尚未经过所有者复核，不视为已签署内容。
