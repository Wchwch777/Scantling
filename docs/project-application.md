# MoonBit GraphQL HTTP Client 项目申报书

> 本申报书根据仓库当前公开源码、测试套件与人工审查记录编写。本项目定位于 MoonBit 通用出站网络开发工具库，为 MoonBit 生态提供具备高可测试性传输缝的轻量级通用 GraphQL-over-HTTP 客户端。

---

## 一、基本信息

- **项目名称**：MoonBit 通用 GraphQL HTTP 客户端 (MoonBit GraphQL HTTP Client)
- **英文名称**：MoonBit GraphQL-over-HTTP Client with Testable Transport Seam
- **参赛形式**：个人参赛
- **参赛者**：韦昌豪（GitHub: Wchwch777）
- **联系方式**：个人手机与邮箱等联络信息已在赛事官方报名表中如实填报，公开代码仓库中予以脱敏保护
- **GitHub 仓库链接**：<https://github.com/Wchwch777/Scantling>
- **项目方向**：MoonBit 通用网络协议库与开发者基础设施
- **实现语言**：MoonBit（基于 `moonbitlang/async` 与标准库）
- **开源许可证**：Apache-2.0
- **人工审查基准**：我已对全量代码、7 项单元测试套件、Native 集成测试用例及三大应用场景完成逐项人工审查并授权合并发布，详见 `docs/owner-review.md`。

---

## 二、选题重构与背景说明

本项目原申报题目《一维型材套裁启发式与参数化造价模型》在 2026 年 9 月 30 日初审中收到组委会反馈：
> “项目场景过于特殊，需求覆盖面较窄，审查驳回，建议更换选题。请查看赛事章程说明和需求，可以参考提供的参赛选题示例。”

收到通知后，我认真对照了赛事章程中关于“通用性、工程质量与生态价值”的评审导向，果断决定在截止日前实施项目重大重构与方向迁移：**放弃垂直小众的建筑套裁算法，转向 MoonBit 社区急需的通用网络与数据交互基础设施——开发专注轻量出站调用、具备可测试传输缝的 MoonBit GraphQL HTTP 客户端。**

在现代云原生架构中，GraphQL 已成为替代或补充传统 REST 的主流数据查询协议。相比于 REST 接口容易出现的“过度获取（Over-fetching）”或“多次往返网络延迟”，GraphQL 允许客户端精确声明所需字段。

在生态现状方面，MoonBit 社区已有专注于服务端的解析与执行引擎（如 `moonbitstack/moongql`，涵盖 GraphQL AST 解析、校验、执行与服务端接入）；但在**轻量出站（Outbound）客户端**方向，开发者向外部 GraphQL 服务发送 HTTP 请求时，仍然缺乏专门的客户端封装与测试抽象。本项目旨在提供一个专注出站调用、具备解耦传输缝与局部数据保留能力的轻量客户端库，与现有服务端生态互为补充，为 MoonBit 开发者连接 GitHub、Shopify、Hasura、Strapi、Apollo 等外部服务提供轻量通用的调用途径。

---

## 三、核心功能与架构设计

### 3.1 传输层解耦与可插拔设计 (Transport Seam)

网络客户端通常面临“难以进行确定性单元测试”的痛点。本项目通过显式抽象 `HttpSend` 传输层函数签名：

```moonbit
pub type HttpSend = async (HttpRequest) -> Result[HttpResponse, String]
```

- **默认网络传输**：在支持异步网络的环境中，使用 `GraphQLClient::new(endpoint)`，自动绑定 `moonbitlang/async/http` 发送真实 HTTP POST 请求；
- **确定性测试注入**：通过 `GraphQLClient::with_transport(endpoint, send)`，开发者可以在测试环境中直接注入纯内存 Mock 传输函数，在完全不依赖外网和本地网络端口的情况下，精确模拟各类 HTTP 状态码、网络中断及非标准响应。

### 3.2 基础 GraphQL 信封编解码

实现核心 GraphQL-over-HTTP 请求与响应编解码：
- 支持 `query`（查询或突变字符串）、`variables`（支持传入任意 `@json.Json`，未强制校验顶层类型）与 `operationName`（多操作命名提取）；
- 自动配置标准请求头：`Content-Type: application/json; charset=utf-8` 与 `Accept: application/graphql-response+json, application/json;q=0.9`；
- 支持自定义全局 HTTP Headers（如 Bearer Token 认证头）。

### 3.3 细粒度结构化错误与局部数据保留 (Partial Data Retention)

GraphQL 与传统 REST 的重要区别在于：即使查询过程中部分字段出错，服务器仍可返回已成功解析的数据。本项目实现了这一关键特性：
- **`GraphQLResponse` 结构体**：独立保留 `data: Json?` 与 `errors: Array[GraphQLError]`，返回 MoonBit 原生 Json 对象（本项目定位为轻量网络信封层，暂未提供强类型 Schema 代码生成或业务类型自动映射）；
- **错误定位精确解码**：每个 `GraphQLError` 结构均包含 `message`、`locations`（行列号 `line`/`column`）、`path`（字段路径数组）和 `extensions`（如业务错误码 `code`）；
- 即使响应 HTTP 状态码为 400（例如语法或校验错误），只要响应体符合 GraphQL 格式信封，客户端仍能解码错误详情，而不是简单抛出底层传输异常。

### 3.4 防御性错误模型与初步校验

定义了类型完备的 `ClientError`：
- `InvalidEndpoint(String)`：对非合法 `http://` 或 `https://` 的 URL 进行初步协议与前缀筛选；
- `InvalidRequest(String)`：拦截空 Query 请求；
- `TransportFailure(String)`：网络连接中断、底层网络异常等传输错误；
- `HttpFailure(Int, String)`：网关 502/504 等非 GraphQL 格式的 HTTP 失败；
- `InvalidResponse(String)`：响应体非合法 JSON 或不符合 GraphQL Envelope 结构的格式错误。

---

## 四、典型使用场景（基于 Mock 传输的行为演示）

> **说明**：以下三大场景均为**基于内存 Mock 传输（`with_transport`）构建的协议行为与数据流演示**，用以验证客户端在这些典型规范下的请求序列化、局部数据保留与错误分流行为，并非已连接到线上生产环境的实测案例。

### 场景一：开发工具模式——查询 GitHub GraphQL API v4 元数据演示
- **目标场景**：模拟消费 `https://api.github.com/graphql`；
- **业务操作**：发送包含变量的 Query `query RepoInfo($owner: String!, $name: String!)`；
- **测试验证**：在测试套件中通过 Mock Transport 验证客户端对自定义 Header（Bearer Token）、变量序列化及标准 JSON 响应的解码行为。

### 场景二：内容与文档系统——消费 Headless CMS (Strapi / Hasura) 演示
- **目标场景**：模拟从 Headless CMS 批量拉取文章列表及作者信息；
- **核心行为体现**：当模拟服务端返回部分字段错误（例如某个作者信息因权限返回 null，同时附带 `errors` 数组）时，验证客户端利用 Partial Data Retention 完整保留已获取文章正文（`data.articles`），避免上层构建直接崩溃。

### 场景三：微服务架构——业务数据聚合与 RPC 突变 (Mutation) 演示
- **目标场景**：模拟内部 GraphQL API Gateway 执行库存扣减突变 `mutation UpdateStock($id: ID!, $quantity: Int!)`；
- **核心行为体现**：验证 Mutation 请求头中租户标识（`X-Tenant-Id`）的注入，以及客户端准确区分 502 网关不可用（`ClientError::HttpFailure`）与 400 业务字段校验失败（`GraphQLResponse.errors`）的能力。

---

## 五、测试验证与质量保证

项目建立了多层自动化验证体系：

```text
moon fmt --check                    PASS
moon check                          PASS
moon test                           7 passed, 0 failed
moon test --target native           PASS (GitHub Actions Ubuntu CI 环境)
```

1. **确定性 Mock 单元测试（7 项全量通过）**：
   - `encodes GraphQL POST and decodes data`：验证标准请求编码与正常响应解码；
   - `preserves partial data and structured GraphQL errors`：验证局部数据与结构化错误共存；
   - `accepts GraphQL request errors returned with an HTTP error status`：验证 HTTP 400 下的 GraphQL 错误信封解码；
   - `reports non-GraphQL HTTP errors with status and body`：验证 502 等非 GraphQL 错误的准确分类；
   - `rejects malformed successful responses`：验证非法 JSON 格式拦截；
   - `maps transport errors to a distinct client error`：验证底层连接失败映射；
   - `validates endpoint and rejects empty query`：验证边界输入与空查询校验。
2. **真实 Native 回环测试（Native Target Integration Test）**：
   - 包含利用 `@http.Server` 在本地临时端口启动真实的 Socket 回环服务测试用例，由 `GraphQLClient` 发送真实 HTTP 请求，验证底层网络栈通信。已在 Linux CI 环境中实测验证通过。
3. **GitHub Actions 持续集成**：
   - 配置了跨 Ubuntu 平台的自动化 CI 流水线，依次执行工具链拉取、依赖更新（`moon update`）、格式校验、类型检查、默认测试与 Native 集成测试，当前 CI 状态为全绿通过。

---

## 六、AI 辅助与人工主导说明

本项目严格遵循赛事“AI 原生与人工主导”的规范要求，如实披露人机协同边界：
- **重构转向决策由我亲自作出**：在 9 月 30 日收到初审关于原套裁项目“场景过于特殊，需求覆盖面较窄”的驳回通知后，我全面分析了评审意见与赛事章程，果断确立了放弃垂直算法、转向通用 GraphQL HTTP 客户端的重构决策；
- **AI 协同参与范围**：AI 协同起草了客户端与响应解码器的原型代码、搭建了传输缝接口与初始测试桩、配置了 GitHub Actions CI 并生成了初始文档草稿；
- **人工把关与深度介入**：
  1. 由我全面审查并规范化了客户端 API 边界、JSON 错误分流逻辑与数据结构；
  2. 亲自审查并修复了 Native 回环测试中关键的字符串插值与端口解析缺陷，使测试能真正在 Linux CI 上通过 Socket 回环验证；
  3. 亲自构建并核验了三大典型协议使用场景，并严格限定其 Mock 演示口径；
  4. 亲自撰写申报材料并对全量改动签署最终接受决定（详见 `docs/owner-review.md`）。

---

## 七、开源与许可

项目采用 **Apache-2.0 License** 开源许可。评委与社区开发者可自由查看源码、测试套件与 CI 运行记录。未来我将结合社区反馈，继续探索 GraphQL Schema 代码生成与 Subscriptions 扩展，持续为 MoonBit 生态贡献高质量基础设施。

---

## 八、申报承诺

本项目申报材料中的架构说明、接口设计、测试结果及使用场景均以仓库当前公开源码和真实测试记录为准。我不把 Mock 传输演示包装为线上生产实测，不把原始 Json 解析包装为强类型业务模型，如实披露 AI 协同边界与人工主导痕迹。我将继续保持代码透明与工程严谨。
