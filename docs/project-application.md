# Scantling：MoonBit MQTT 3.1.1 异步 TCP 客户端

**方向：** MoonBit 网络基础库 / 协议客户端　 **仓库：** <https://github.com/Wchwch777/Scantling>　 **许可证：** Apache-2.0

## 项目目标

Scantling 为 MoonBit 应用提供可复用的 MQTT 3.1.1 客户端运行时，供需要连接 MQTT Broker 的程序使用。MoonBit 已有 `zbhzs1/moonbit-mqtt` 报文编解码包，但它不提供 TCP 传输或客户端会话流程；Scantling 复用该 codec，补充客户端侧能力，不重复实现 Broker 或报文编解码。此生态缺口判断基于公开包功能说明，不代表已完成用户调研或生产部署。

## 当前功能

- 使用 MoonBit 和 `moonbitlang/async` 进行 TCP 连接，完成 CONNECT/CONNACK；
- 单主题订阅并等待匹配 SUBACK；
- QoS 0 发布、QoS 1 发布并等待匹配 PUBACK；
- 接收 QoS 0/1 消息并在交付 QoS 1 消息前发送 PUBACK；返回主题、payload、QoS 和 retain 标志；
- 单主题取消订阅并等待匹配 UNSUBACK；可发送 PINGREQ 并等待 PINGRESP；
- 限制入站报文体不超过 1 MiB；拒绝空发布主题、发布主题通配符、空订阅过滤器及空 Client ID。

## 范围与限制

当前目标是单连接、顺序调用的 MQTT 3.1.1 原生 TCP 客户端。当前不提供 TLS、身份认证、自动重连、自动 Keep Alive 调度、操作超时、持久会话、QoS 2、MQTT 5.0 或 WebSocket，也不声称生产级可用或完整协议认证。应用需自行按连接配置安排 PINGREQ，不能并发操作同一 Client。

## 使用与验收

仓库 README 提供安装、快速开始与本地 Broker 示例；`examples/mqtt_client` 演示连接、订阅、发布、接收、取消订阅和 ping。测试包括 Remaining Length 与报文限制单元测试，以及使用 loopback TCP 协议对端覆盖 CONNECT、SUBSCRIBE/SUBACK、QoS 1 接收/PUBACK、QoS 1 发布/PUBACK、UNSUBSCRIBE/UNSUBACK、PINGREQ/PINGRESP 和 DISCONNECT。CI 检查格式、Wasm/native 类型、Wasm 测试和 native 回环测试。CI 的实际状态以对应 GitHub Actions 运行记录为准；本地 Windows 环境没有 C 编译器，不能在此运行 native 测试。

## 开源与 AI 辅助

仓库采用 Apache-2.0，并在 `moon.mod` 声明 codec 与 async 依赖。本项目以 AI 辅助开发，AI 参与代码、测试和文档草拟；项目方向、功能边界与最终质量由参赛者本人负责。实际变更、测试结果及已知限制以仓库代码和 CI 记录为准。
