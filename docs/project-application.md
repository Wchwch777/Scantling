# Scantling：MoonBit MQTT 3.1.1 异步 TCP 客户端

**项目方向：** MoonBit 网络协议客户端与消息运行时

**仓库：** <https://github.com/Wchwch777/Scantling>

**许可证：** Apache-2.0

## 项目简介

Scantling 为 MoonBit 程序提供 MQTT 3.1.1 原生 TCP 客户端能力。它复用
[`zbhzs1/moonbit-mqtt`](https://github.com/zbhzs1/moonbit-mqtt) 的报文编解码，
在其上实现连接、订阅、发布、消息接收和连接控制流程。项目希望补充
MoonBit 应用侧的 MQTT 客户端运行时；这项生态定位来自公开包的功能边界，
不是用户调研、客户需求或生产部署的结论。

## 已实现功能与可核查证据

- MQTT 3.1.1 TCP CONNECT/CONNACK 握手，以及顺序调用的连接 API：
  [`mqtt/client.mbt`](../mqtt/client.mbt)。
- 单主题过滤器订阅与取消订阅，并等待对应应答；支持 QoS 0 发布、QoS 1
  发布及 PUBACK、QoS 0/1 接收与 QoS 1 PUBACK。
- PINGREQ/PINGRESP；入站报文体限制为 1 MiB；拒绝无效发布主题及空订阅过滤器。
- 原生 loopback 测试覆盖客户端与协议对端的请求/应答流程；独立 Mosquitto
  测试使用两个客户端验证 QoS 1 订阅、投递和发布应答：
  [`mqtt/integration_test/client_test.mbt`](../mqtt/integration_test/client_test.mbt)。
- CI 固定运行 Mosquitto `2.0.22` 并执行 MoonBit 格式、Wasm/Native 检查与测试。
  最近记录的仓库验证快照提交
  [`5c21da3`](https://github.com/Wchwch777/Scantling/commit/5c21da34147ddd4a8c832d719d6d518f8bf50d9a)
  的 CI 已通过，包括 14 项 Wasm 测试、23 项 Native 测试及独立 Mosquitto Broker 往返互操作测试：
  [GitHub Actions run 39119781810](https://github.com/Wchwch777/Scantling/actions/runs/39119781810)。后续提交状态见
  [main 分支 workflow runs](https://github.com/Wchwch777/Scantling/actions/workflows/ci.yml)。

## 代表性使用场景

仓库展示三种使用同一 MQTT 客户端接口的消息流：传感器遥测接收、设备命令
发布、应用事件消费。它们是协议层示例，不是已部署客户案例。场景与代码、测试
之间的对应关系及未覆盖部分见 [`docs/use-cases.md`](use-cases.md)。可运行演示位于
[`examples/mqtt_client`](../examples/mqtt_client/main.mbt)。

## 运行方式

先启动 MQTT 3.1.1 Broker（README 提供 Mosquitto 示例），再运行：

```sh
moon run --target native examples/mqtt_client
```

CI 的独立 Broker 路径及本地复现步骤见 [README](../README.md#development-and-verification)。

## 能力边界

当前实现是单连接、顺序调用的 MQTT 3.1.1 原生 TCP 客户端。它不提供 TLS、身份
认证、自动重连、自动 Keep Alive 调度、操作超时、持久会话、QoS 2、MQTT 5.0
或 WebSocket，也没有真实设备接入、客户部署、性能基准或市场调研证据。应用需
自行调度 PINGREQ，且不得并发操作同一个客户端连接。项目不声称生产级完整性或
协议认证。

## 赛事与申报材料

本项目申报面向 MoonBit 开源生态中的网络协议客户端方向。适用范围和验收要求
应以当届官方材料为准：[比赛章程](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)、
[比赛官网](https://moonbitlang.github.io/Hackathon2026/#process)。官网/章程的方向匹配
只说明选题背景，不替代对实际需求、用户采用或项目完成度的证明。

## AI 辅助与人工复核状态

AI 工具参与了代码、测试和文档的起草与整理；仓库公开说明见
[`AI_ASSISTED.md`](../AI_ASSISTED.md)。历史人工复核的范围见
[`docs/owner-review.md`](owner-review.md)；该记录明确标注本轮更新仍待仓库创建者复核，
不将历史签字延伸为对本次内容的认可。
