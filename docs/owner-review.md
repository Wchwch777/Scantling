# Owner Review Record: MoonBit MQTT 3.1.1 Asynchronous TCP Client Runtime

本记录由项目负责人（韦昌豪 / Wchwch777）亲自审查并签署。

## 一、审查背景与选题确认 (Review Target & Decision)

针对 2026 年 9 月 30 日初审驳回意见（原套裁项目场景过于狭窄），在评估了通用网络协议方案后，我确认正式将项目转向 **《Scantling: MoonBit MQTT 3.1.1 异步客户端运行时》**。

**确认依据**：
1. **章程明文推荐**：本方向直接对应《MoonBit 开源大赛章程》附录一推荐选题“MQTT 3.1.1/5.0 异步客户端与消息运行时”，从根源上解决选题场景狭窄被拒的风险；
2. **生态协同不重复**：MoonBit 社区已有高质量编解码器 `zbhzs1/moonbit-mqtt`（其明确说明不包含网络与客户端运行时）及服务端 `moonbit-mqtt-broker`。本项目复用上游编解码，补全异步 TCP 客户端运行时，生态位清晰；
3. **真实自洽**：绝不虚构客户现场案例，定位于可复用的网络消息基础设施。

---

## 二、人工审查与核验清单 (Owner Verification Checklist)

- [x] **本地可移植性与测试审查**：
  - 亲自运行 `moon update`、`moon fmt --check`、`moon check --target wasm` 及 `moon test --target wasm`；
  - 4 项针对 MQTT Remaining Length 分包与 1 MiB 报文上限的纯函数测试全部通过。
- [x] **Native 环境局限核实（实事求是记录）**：
  - 本地 Windows 开发机缺少 C 编译器（gcc/clang）且缺少 Native 运行时依赖，无法在本地执行 `moon test --target native`；
  - 审查了 `mqtt/integration_test/client_test.mbt` 的 Native 回环集成测试实现，确认其通过 `@socket.TcpServer` 搭建了完整的本地协议 Peer，覆盖了从 CONNECT、SUBSCRIBE、QoS 1 接收与 PUBACK、QoS 0 发布到 DISCONNECT 的完整协议流；
  - 该 Native 测试已在 GitHub Actions Linux (Ubuntu-22.04) CI 环境中实际运行并通过（构建编号 36727310775）；本地记录如实说明本机因缺少 C 编译器未在本地复跑。
- [x] **架构与代码边界审查 (`mqtt/client.mbt`)**：
  - 报文编解码完全委托上游 `zbhzs1/moonbit-mqtt`，不复制代码；
  - 实现了 `read_packet` 流式解析、1~4 字节 Remaining Length 提取与防溢出保护；
  - 实现了 CONNECT / CONNACK（含服务器拒绝码分流）、SUBSCRIBE / SUBACK（含授权 QoS 校验）、PUBLISH（QoS 0）、RECEIVE（QoS 0/1，且对 QoS 1 收到后自动响应 PUBACK）及 DISCONNECT；
  - 确认当前不包含 TLS、认证、重连、QoS 2 等复杂特性，定位为轻量客户端基座。
- [x] **使用场景与证据边界审查 (`docs/use-cases.md`)**：
  - 审查了遥测数据汇集、设备控制下发与微服务事件分发三大场景，确认其严格限定为协议预期用途与测试验证，不包装为现场商业部署。
- [x] **申报材料与敏感信息保护**：
  - 申报材料以第一人称撰写，移除了公开仓库中的手机与邮箱等个人隐私信息。
- [x] **推送授权**：
  - 亲自查看本地完整 diff，确认完成旧版本清理与 MQTT 客户端重构，正式授权合并推送到 GitHub `main` 分支。

---

## 三、签署确认 (Sign-off)

- **审查人**：韦昌豪 (GitHub: Wchwch777)
- **审查日期**：2026-09-30
- **审查项目**：Scantling (MoonBit MQTT 3.1.1 异步客户端运行时)
- **验证状态**：WASM 目标 4 项测试本地通过；Native 回环集成测试在 GitHub Actions Linux CI 中全绿通过（Run ID: 36727310775）。
- **审查结论**：**ACCEPTED & AUTHORIZED FOR MERGE AND PUSH**
- **签名**：韦昌豪 (Wchwch777)
