# MoonBit MQTT 异步客户端运行时项目申报书

## 一、基本信息

- **项目名称**：Scantling：MoonBit MQTT 3.1.1 异步客户端运行时
- **参赛形式**：个人参赛
- **参赛者**：韦昌豪（GitHub: Wchwch777）
- **联系方式**：报名表中填写；公开仓库不重复公开个人联系方式
- **项目仓库**：<https://github.com/Wchwch777/Scantling>
- **项目方向**：Web 与网络基础设施 / 异步消息客户端
- **实现语言**：MoonBit
- **许可证**：Apache-2.0
- **项目性质**：原创客户端运行时；依赖并复用 `zbhzs1/moonbit-mqtt` 的 MQTT 3.1.1 报文编解码，不移植或复制其源码

## 二、项目简介与选题依据

Scantling 为 MoonBit 提供 MQTT 3.1.1 客户端运行时，通过 TCP 连接消息 Broker，完成连接握手、主题订阅、消息发布与接收。它面向需要在 MoonBit 程序中连接 MQTT 服务的开发者，适用任务包括传感器数据汇集、设备命令传递和应用事件分发。

本方向对应[赛事章程附录一推荐的“MQTT 3.1.1/5.0 异步客户端与消息运行时”](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)。生态核查发现，MoonBit 已有 [`zbhzs1/moonbit-mqtt`](https://mooncakes.io/docs/zbhzs1/moonbit-mqtt)，其职责是 MQTT 3.1.1 报文编解码，并明确不提供网络传输和客户端运行时；另有 [MoonBit MQTT Broker](https://mooncakes.io/docs/ChaonanShen/moonbit-mqtt-broker%400.4.0)，职责是服务端 Broker。Scantling 复用前者的编解码，补客户端运行时这一不同层，不重复实现 Broker。

**针对初审意见的选题调整**：原项目面向一维型材套裁这一特定生产流程；当前方向转为可供不同应用复用的 MQTT 客户端基础能力，预期用途包括遥测采集、设备命令和服务间事件消息。它不再绑定单一行业，但目标仍具体限定为“需要在 MoonBit 程序中通过 MQTT 与 Broker 通信”的开发者。上述场景用于说明协议能力的可复用性，**不是**用户调研、商业部署或市场规模数据；本项目目前没有这些证据，因此不声称需求已被实证。

这说明当前可见的生态组件之间存在客户端运行时这一功能空档，并使项目方向与章程推荐相符；它**不是**用户调研、实际部署或组委会认可的证明。申报前应再次核对 Mooncakes，并考虑向相关维护者咨询协作或上游扩展方式。章程指出已有相近方向时应优先评估维护、扩展或协作，本项目不声称完全没有相邻项目。

### 需求覆盖与可核查依据

本项目要解决的具体工程任务是：MoonBit 程序如何通过 MQTT 连接现有 Broker，完成订阅、发布及 QoS 1 消息确认。若只使用现有报文编解码包，应用仍需自行补齐 TCP 传输与客户端连接/消息流程；这是根据公开包的功能边界得出的工程缺口判断，不是已收集到的用户投诉或需求统计。

- **选题适配**：赛事章程将 MQTT 3.1.1/5.0 异步客户端与消息运行时列为推荐方向，直接回应“更换选题、扩大场景覆盖”的初审意见。
- **生态缺口**：[MoonBit MQTT 编解码包文档](https://mooncakes.io/docs/zbhzs1/moonbit-mqtt)明确其不含传输层与客户端运行时；[MoonBit MQTT Broker](https://mooncakes.io/docs/ChaonanShen/moonbit-mqtt-broker%400.4.0)承担服务端职责。Scantling 补的是客户端侧，不与 Broker 或编解码器重复。
- **功能覆盖**：遥测消费对应订阅与 QoS 1 接收确认；设备命令对应 QoS 0 发布；应用事件对应按主题过滤并交付不透明 payload。对应实现由 Native 回环 CI 测试验证（[运行 36738625531](https://github.com/Wchwch777/Scantling/actions/runs/36738625531)），但这些测试验证协议路径，不代表真实设备接入或用户采用。

目前没有用户访谈、实际部署、下载量或采用率等直接需求数据，因此本申报只主张“章程推荐方向 + 可核查的 MoonBit 客户端能力缺口 + 可运行的跨场景协议路径”，不将其包装成已证实的市场需求。该证据比原套裁项目单一生产流程更能说明技术复用范围，但市场接受度仍需后续社区反馈验证。

## 三、目标用户与通用性

目标用户是编写需要通过 MQTT Broker 发布或消费消息的 MoonBit 程序开发者。MQTT 将消息生产者与消费者通过 topic 和 broker 解耦；客户端 API 不绑定建筑、工厂、家庭或某一厂商设备。不同应用可以复用连接、订阅、QoS 0 发布与 QoS 1 接收流程，再在应用层定义 payload 格式。

以下场景是协议层预期用途，不是 Scantling 已有客户或线上部署的陈述。三个场景的业务领域不同，但都依赖 MQTT 发布/订阅；这能说明技术复用面，不能单独证明市场需求规模。

## 四、预期使用场景

### 场景一：传感器遥测汇集

- **使用者与任务**：设备网关或数据采集服务需要消费温度、湿度等传感器读数。
- **输入与流程**：连接 Broker，订阅 `building/floor-2/temperature` 等主题，接收 QoS 1 PUBLISH 并发送 PUBACK。
- **结果**：调用方取得主题名与原始 payload bytes，再由业务层解析单位、时间戳和数值。
- **实现与证据**：接口已实现；仓库 Native 回环测试覆盖 CONNECT、SUBSCRIBE、QoS 1 接收及 PUBACK，并在 [GitHub Actions 运行 36738625531](https://github.com/Wchwch777/Scantling/actions/runs/36738625531) 中通过（提交基准 `3b165ef`）。该测试使用本地协议 peer，不是传感器现场部署或独立 Broker 认证；本机 Windows 未复跑 Native 测试。

### 场景二：设备命令传递

- **使用者与任务**：运维脚本或控制服务向指定设备发布简单命令。
- **输入与流程**：向 `factory/line-1/device-7/cmd` 发布 UTF-8 或二进制 payload，接收设备订阅该主题后的消息。
- **结果**：Broker 根据 topic 转发；当前客户端发布采用 QoS 0，因此不承诺 Broker 确认或重投。
- **实现与证据**：QoS 0 发布和 topic filter 订阅已实现；同一 CI 回环测试覆盖客户端 QoS 0 发布包。尚未连接真实设备或验证设备侧控制流程。

### 场景三：服务间事件分发

- **使用者与任务**：不同进程或语言实现的服务通过 Broker 传递订单创建等事件。
- **输入与流程**：订阅 `service/orders/created` 等主题过滤器，接收 topic 与不透明 payload。
- **结果**：应用层将 payload 交给自己的 handler 或解析器；客户端不规定业务数据模型。
- **实现与证据**：客户端已实现单主题过滤器订阅与消息返回；跨进程/跨语言互操作尚未验证。持久会话、重连、端到端顺序或业务处理保证不在本版本范围内。

完整步骤及证据边界见 [`docs/use-cases.md`](use-cases.md)。

## 五、核心功能与架构

1. **报文层复用**：依赖 `zbhzs1/moonbit-mqtt` 编解码 MQTT 3.1.1 控制包；本项目不重复维护一套 MQTT 字节编码器。
2. **传输层**：基于 `moonbitlang/async/socket` 建立 TCP 连接，按 MQTT Remaining Length 增量读取完整报文。
3. **客户端流程**：CONNECT/CONNACK、单主题 SUBSCRIBE/SUBACK、QoS 0 发布、QoS 0/1 接收、QoS 1 自动 PUBACK、DISCONNECT。
4. **安全边界**：限制入站 MQTT 报文最大 1 MiB，校验 host、port、keep-alive 等基础配置。

**当前不支持**：TLS、用户名/密码认证、自动重连、自动 keep-alive 调度、QoS 1 发布确认队列、QoS 2 状态机、持久会话、MQTT 5.0、WebSocket。当前实现适合学习、开发和验证，不应描述为生产完整 SDK。

## 六、测试与验证计划

- **可移植测试**：检查固定头、Remaining Length 单/多字节解析、截断帧和 1 MiB 限制。
- **Native TCP 集成测试**：本地协议 peer 与客户端通过真实 loopback socket 完成连接、订阅、QoS 0 发布、QoS 1 接收/确认及断开。
- **CI**：WASM 类型检查与测试、Native 类型检查和 TCP 回环集成测试。该工作流在 [GitHub Actions Ubuntu-22.04 运行 36738625531](https://github.com/Wchwch777/Scantling/actions/runs/36738625531) 中全绿通过（提交基准 `3b165ef`）；Native 本机复跑和独立 Broker 互操作仍未完成。
- **独立 Broker 互操作**：README 提供 Mosquitto 本地运行步骤；当前 Windows 本地环境因缺少 C 编译器未在本机复跑 Native 测试，如实记录该局限，以 Linux CI 实测结果为技术依据。

## 七、AI 辅助与人工审查边界

本项目严格遵循赛事规范，如实披露 AI 协同与人工主导边界：
- 针对 9 月 30 日初审驳回意见，由我亲自评估并确立了转向《MoonBit 开源大赛章程》推荐的 MQTT 3.1.1 客户端运行时方向；
- AI 协助梳理了章程推荐目录、检索了 Mooncakes 上游编解码生态、起草了客户端与测试桩原型并配置了 CI；
- 我亲自逐项审查了客户端 TCP 传输、协议状态分流、1 MiB 报文保护边界与三大应用场景，定位并修正了 Native 集成测试中的协议包时序问题，并对本轮申报书、用例说明和 README 的同步修订完成全面复核；已在 `docs/owner-review.md` 中签署了覆盖本轮文案与基准提交及当前审查记录的正式人工验收结论。
- 我已亲自复核新增的“需求覆盖与可核查依据”小节，确认其立论完全基于章程推荐、社区生态现状与测试验证等可核查依据，表述客观准确，已正式纳入 `docs/owner-review.md` 的人工签署范围。

## 八、开源与维护

Scantling 采用 Apache-2.0。MQTT 编解码由上游 `zbhzs1/moonbit-mqtt` 依其 Apache-2.0 许可提供；本项目通过 Mooncakes 依赖调用，不复制其源代码。后续是否向该上游贡献或与维护者协作，需在提交前评估并由负责人决定。
