# 十一月本地自查与新增证据

开始核查：2026-11-03；收尾核验：2026-11-04。工作目录：`十一月黑客松/韦昌豪/Scantling`。
这份报告记录发布前的本地核验。参赛者决定申报范围、交付顺序、推送时间和账号约束，AI 辅助实现、测试和文档。人工代码复核待参赛者确认。

## 判断

相比十月仅有线性测试对端的申报，本次已增加独立纯计算协议观察包：
双向 identifier 空间、多事务状态、阶段应答、重传一致性、已知会话恢复、
逻辑时间及结构化诊断均有实际代码与正反例。具备重新申报的实质技术增量。
这不是初审通过的保证，也不代表组委会已认定其可按新项目赛道申报。

## 规则核对

- 2026-11-03 读取用户指定的[飞书章程](https://bxup9uklfcb.feishu.cn/wiki/Dx4Bwd6D1i3GfHkajQCcF7SznEd)公开页面。
  章程允许此前参赛项目有独立、可验证新增成果后重新申报，只计算本期有效贡献。
  新项目不能直接重复成熟生态项目；申报需一页 Markdown、人工撰写，并给出至少三个完整使用场景。
- 章程正文仍含九月阶段日期，[官网](https://moonbitlang.github.io/Hackathon2026/#process)当前资源仍显示十月及 10 月 31 日。
  因此不据此编造十一月报名/验收截止日期；本期窗口和新组件赛道归属须按赛事群或官方新通知确认。
- `osc2026-guide` 的八月资料仅作检查方法，不能覆盖当前章程的赛期、commit 数或申报规则。
  当前章程写明仓库不少于 10 个有效 commits；已有历史满足仓库数量不等于本期有足够实质贡献。
  参赛者指定分三次交付。三笔提交基于先前的本地实现，按可单独验证的功能边界组织。
- 验收还要求可运行示例、测试、覆盖检查/构建/测试的 CI 和 Mooncakes 发布。
  本次补齐本地实现和 CI 配置；远程运行、发布属于后续任务。

## 十月基线与本次增量

远程默认分支为 `main`，基线提交 `1e63972`（2026-10-31）。
仓库从 `https://github.com/Wchwch777/Scantling` 新克隆到本期目录；未改十月目录。

| 驳回问题 | 本次对应实现 | 可核查证据 |
| --- | --- | --- |
| 主要是逐包匹配 | 独立观察双方历史，不要求线性脚本 | `mqtt/monitor/session.mbt`, `publications.mbt` |
| 协议语义不足 | 双向 id 所有权、QoS 阶段、重复包、订阅授权、断线恢复 | `monitor_test.mbt`、五类 `.trace` |
| 工程深度不足 | 有界在途表、首错冻结、脱离容器的报告、精确帧长、资源清理及总时限 | `types.mbt`, `trace.mbt`、`Peer::run_monitored` |
| 旧能力重复计入 | 原客户端及脚本只作底座 | 本文基线、十月申报归档、新申报技术草稿 |
| 缺少独立证据 | 原始帧轨迹、真实 TCP 集成、外部 Mosquitto 客户端 | 下列本地命令结果 |

模块从无命名空间的 `scantling_mqtt_client` 改为 `Wchwch777/scantling`，补 repository 字段。
这是包发布准备，不是已经发布的证据。Apache-2.0 许可证不变；依赖版本不变。

## 本地核验

工具链：Windows 与 WSL 均为 `moon 0.1.20261012` / `moonc 0.10.15+943464bfa`。
Native 运行在 WSL Ubuntu，本机 Windows 未配置 MSVC；未强行更换已固定的工具链。

| 检查 | 结果 |
| --- | --- |
| `moon test mqtt/monitor --target wasm --deny-warn` | 21 项通过，含可执行文档 |
| `moon test --target wasm` | 47 项通过 |
| WSL `SCANTLING_MOSQUITTO_HOST=127.0.0.1 moon test --target native` | 74 项通过，含新监控 TCP 测试、全部轨迹结果和运行中的匿名 Broker 路径 |
| 独立 `mosquitto_pub` → 监控脚本对端，QoS 2 | 成功退出；报告 8 个事件、完成 1 笔发布、0 pending、无诊断 |
| 默认轨迹 CLI | 成功；14 个事件、3 笔发布、`complete=true` |

Native 计数中，未配置认证 Broker 的认证路径按既有代码跳过；不声称本次重测了认证场景。
更严格全库检查仍受十月遗留 warning（隐式测试引用、trait 方法提升及测试专用导入）影响；
新 monitor 单独以 `--deny-warn` 通过，没有整体消警告的虚假承诺。
完整格式、构建及其他 CLI 出口核验见本文末尾。

`.github/workflows/ci.yml` 增加状态机严格测试、Wasm/Native 构建、CLI 运行，
原有独立 Mosquitto 文本脚本启用监控。远程验证以
[本期提交对应的 Actions 记录](https://github.com/Wchwch777/Scantling/actions)为准。

## 生态检索

2026-11-03 使用 `moon search mqtt --limit 5`，并检索 `conformance`、`scantling`。
MQTT 查询得到以下模块；关键词检索不是穷尽性排重或不存在同类项目的证明。

| 已检索项目 | 注册表描述范围 | 与本次区别 |
| --- | --- | --- |
| `zbhzs1/moonbit-mqtt@0.1.0` | 编解码，无传输/客户端运行时 | 被复用，不再申报编解码贡献 |
| `Strangelight-Merser/moon-mqtt-client@0.8.1` | 原生客户端、连接与可靠投递 | Scantling 观察第三方历史，不扩写通用客户端来竞争 |
| `Duckweed/moon-mqtt@0.3.3` | 客户端、纯计算状态机与会话恢复 | 其状态机驱动自身客户端；本次是双向轨迹的独立判定入口 |
| `ChaonanShen/moonbit-mqtt-broker@0.4.0` | Broker | 本次不做路由、持久 Broker 或客户端服务 |
| `zbhzs1/moonasyncapi@0.2.0` | 查询同时命中的异步 API 相关包 | 不据此声称其没有任何相关扩展能力 |

标准依据为 [OASIS MQTT 3.1.1](https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html)。
特别核对客户端允许在 CONNACK 前发送控制包，添加专门回归，避免错误地把常见实现限制当成协议要求。
没有复制第三方实现或测试集，也没有替选手编造用户访谈或部署量。

## 身份与后续材料

`gh api user --jq .login` 已验证为 `Wchwch777`。
仓库本地 `user.name=Wchwch777`，邮箱为该账号的 GitHub noreply，
author 与 committer 均用 `git var` 验证。机器全局账号配置未改，避免影响其他仓库。
`AGENTS.md` 记录每次 commit/push 的所有者身份检查。
历史存在其他作者标识，按用户“今后”的要求保留，不重写历史或伪造归属。

申报书保留为一页技术草稿。参赛者需要亲自理解并改写，尤其说明为何选择这一
实现路径、三个场景如何操作及不做哪些内容；不把 AI 材料原样标为人工原创。
未代签所有者复核、未操作报名表单。此处事项不妨碍本地工程交付。

## 收尾核验（2026-11-04）

三阶段分别从当次暂存区导出源码，在同版本 WSL 工具链下核验。

| 阶段 | 验证结果 |
| --- | --- |
| 协议状态机 | 21 项严格监控测试、47 项 Wasm、70 项 Native 通过 |
| 离线轨迹 CLI | 47 项 Wasm、71 项 Native 通过，五份轨迹实际运行并检查退出码及 JSON |
| 在线监控与 CI | 21 项严格监控测试、47 项 Wasm、74 项 Native 通过，Wasm 和 Native 构建通过 |

- `moon fmt --check`、`git diff --check` 通过。
- Wasm 与 Native 的 `moon check` / `moon build` 均通过；全库遗留 warning 仍如上披露。
- 公开接口经 `moon info mqtt/monitor` 生成并审阅；内部状态和容器均为私有，外部无法直接修改状态机。
- 最终 Native 全量重跑仍为 74 项通过；新增包严格测试为 21 项，Wasm 全量为 47 项。
- 五份轨迹实际运行 CLI：`interleaved`、`persistent-resume` 退出 0；
  `wrong-ack`、`keepalive-overdue`、`incomplete` 退出 1，JSON 与预期一致。
  `incomplete` 的 `valid_prefix=true`，不会被混写为观察到协议违规。
- 独立 Mosquitto 2.0.22 的监控订阅场景输出预期消息，7 个事件、完成 1 笔；
  Keep Alive 场景经过两轮 PING 后输出 `after-idle`，11 个事件、完成 1 笔；两者无诊断。
  服务不可用脚本使 `mosquitto_pub` 正常报告 Broker 拒绝，服务端监控报告是完成的合法拒绝流程。
- 手工拉起独立程序时遇到过客户端先启动导致的 TCP `Connection refused`；
  等待监听就绪后重跑成功，未将启动竞态当成协议校验结果。CI 已有等待监听日志的启动屏障。
- 这些是发布前的本地结果。Mooncakes 发布及参赛者人工复核状态另行核对。
