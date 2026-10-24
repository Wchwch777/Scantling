# Scantling：MoonBit MQTT 3.1.1 客户端与协议互操作测试对端

**项目方向：** MoonBit MQTT 协议互操作与客户端行为验证

**仓库：** <https://github.com/Wchwch777/Scantling>

**许可证：** Apache-2.0

## 项目简介

Scantling 包含一个 MoonBit MQTT 3.1.1 TCP 客户端和一个脚本化 Broker 协议对端。
本轮重点是让该对端能被独立客户端重复调用，以检查接受连接、协议拒绝和
截断响应等行为；客户端实现是被测对象之一，不据此声称填补了通用客户端空白。
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
- 可执行故障对端提供固定 MQTT 3.1.1 场景；CI 使用 Mosquitto 客户端验证
  QoS 0/1 发布、CONNACK 拒绝和截断 CONNACK 的外部客户端结果。
- CI 固定运行 MoonBit `0.10.15+943464bfa` 与 Mosquitto `2.0.22`，执行格式检查、
  Wasm/Native 类型检查与测试、独立 Broker 路径和 Mosquitto 客户端故障对端检查。
  在加入完整示例运行步骤前，基线提交
  [`27a8ab6`](https://github.com/Wchwch777/Scantling/commit/27a8ab67300bcd14c2bf48c3bf43eba96c76ddaa)
  的 [CI run 39993827022](https://github.com/Wchwch777/Scantling/actions/runs/39993827022)
  通过 18 项 Wasm 与 36 项 Native 测试。当前工作流另运行 `examples/mqtt_client`
  连接 Mosquitto，并核对遥测、命令、状态回报和事件输出，以及至少十秒的
  空闲间隔；当前提交的结果见
  [main 分支 workflow runs](https://github.com/Wchwch777/Scantling/actions/workflows/ci.yml)。

## 代表性使用场景

仓库展示三种使用同一 MQTT 客户端接口的消息流：遥测接收、应用发布命令并接收设备
状态回报、空闲保活后接收事件。它们是协议层示例，不是已部署客户案例。场景与代码、测试
之间的对应关系及未覆盖部分见 [`docs/use-cases.md`](use-cases.md)。可运行演示位于
[`examples/mqtt_client`](../examples/mqtt_client/main.mbt)。

## 运行方式

先启动 MQTT 3.1.1 Broker（README 提供 Mosquitto 示例），再运行：

```sh
moon run --target native examples/mqtt_client
```

CI 的独立 Broker 路径及本地复现步骤见 [README](../README.md#development-and-verification)。

## 能力边界

当前客户端是单连接、顺序调用的 MQTT 3.1.1 原生 TCP 实现。它不提供 TLS、
自动重连、后台 Keep Alive 任务、操作超时、持久会话、MQTT 5.0
或 WebSocket。QoS 2 状态只保存在当前 Clean Session 连接的内存中，不支持断线恢复。
项目也没有真实设备接入、客户部署、性能基准或市场调研证据。无期限等待时，应用需
使用 `receive_with_keep_alive()` 或自行安排 PINGREQ，且不得并发操作同一个客户端连接。项目不声称生产级完整性或
协议认证。

## 赛事与申报材料

本项目申报面向 MoonBit 开源生态中的 MQTT 协议互操作与客户端行为验证方向。
适用范围和验收要求
应以当届官方材料为准：[比赛章程](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)、
[比赛官网](https://moonbitlang.github.io/Hackathon2026/#process)。官网/章程的方向匹配
只说明选题背景，不替代对实际需求、用户采用或项目完成度的证明。

## AI 辅助与人工复核状态

AI 工具参与了代码、测试和文档的起草与整理；仓库公开说明见
[`AI_ASSISTED.md`](../AI_ASSISTED.md)。仓库创建者本人（`Wchwch777`）
已对截至 2026-10-24 的全部十月新增工作（包含初始基线、QoS 2 实现与协议扩展、
原生故障注入对端、独立 Mosquitto 客户端验证、`receive_with_keep_alive()`
协调保活机制与十秒长空闲三段端到端示例）完成逐行人工走查、本地自动化与端到端运行验证，
并在 [`docs/owner-review.md`](owner-review.md) 中签署了完整的复核记录、清单与日期。
