# MoonBit GraphQL HTTP Client 项目申报书

> 本申报书根据仓库当前公开源码、测试套件与人工审查记录编写。本项目定位于 MoonBit 通用基础设施与网络开发工具库，为 MoonBit 生态提供具备高可测试性的通用 GraphQL-over-HTTP 客户端。

---

## 一、基本信息

- **项目名称**：MoonBit 通用 GraphQL HTTP 客户端 (MoonBit GraphQL HTTP Client)
- **英文名称**：MoonBit GraphQL-over-HTTP Client with Testable Transport Seam
- **参赛形式**：个人参赛
- **参赛者**：韦昌豪（GitHub: Wchwch777）
- **联系方式**：手机：18260898003 ｜ 邮箱：1341376491@qq.com
- **GitHub 仓库链接**：<https://github.com/Wchwch777/Scantling>
- **项目方向**：MoonBit 通用网络协议库与开发者基础设施
- **实现语言**：MoonBit（基于 `moonbitlang/async` 与标准库）
- **开源许可证**：Apache-2.0
- **人工审查基准**：我已对全量代码、7 项单元测试套件、Native 集成测试用例及三大应用场景完成逐项人工审查并授权合并发布，详见 `docs/owner-review.md`。

---

## 二、选题重构与背景说明

本项目原申报题目《一维型材套裁启发式与参数化造价模型》在 2026 年 9 月 30 日初审中收到组委会反馈：
> “项目场景过于特殊，需求覆盖面较窄，审查驳回，建议更换选题。请查看赛事章程说明和需求，可以参考提供的参赛选题示例。”

收到通知后，我认真对照了赛事章程中关于“通用性、工程质量与生态价值”的评审导向，果断决定在截止日前实施项目重大重构与方向迁移：**放弃小众工业定额算法，转向 MoonBit 社区急需的通用网络与数据交互基础设施——开发首个轻量、类型安全、具备可插拔传输缝的 MoonBit GraphQL HTTP 客户端。**

在现代云原生架构中，GraphQL 已成为替代或补充传统 REST 的主流数据查询语言。相比于 REST 接口容易出现的“过度获取（Over-fetching）”或“多次往返网络延迟”，GraphQL 允许客户端精确声明所需字段。然而，MoonBit 官方社区（mooncakes.io）此前在 GraphQL 协议领域完全空白。本项目旨在填补这一生态缺口，为 MoonBit 开发者连接 GitHub、Shopify、Hasura、Strapi、Apollo 等现代化后端服务提供即插即用的通用客户端。

---

## 三、核心功能与架构设计

### 3.1 传输层解耦与可插拔设计 (Transport Seam)

网络客户端通常面临“难以进行确定性单元测试”的痛点。Scantling GraphQL 客户端通过显式抽象 `HttpSend` 传输层函数签名：

```moonbit
pub type HttpSend = async (HttpRequest) -> Result[HttpResponse, String]
```

- **默认网络传输**：在生产环境中，使用 `GraphQLClient::new(endpoint)`，自动绑定 `moonbitlang/async/http` 发送真实 HTTP POST 请求；
- **确定性测试注入**：通过 `GraphQLClient::with_transport(endpoint, send)`，开发者可以在测试环境中直接注入纯内存 Mock 传输函数，在完全不依赖外网和本地网络端口的情况下，精确模拟各类 HTTP 状态码、网络中断及非标准响应。

### 3.2 完备的 GraphQL Envelope 编解码

严格遵循 GraphQL-over-HTTP 官方规范：
- 支持 `query`（查询或突变字符串）、`variables`（JSON 对象格式变量）与 `operationName`（多操作命名提取）；
- 自动配置标准请求头：`Content-Type: application/json; charset=utf-8` 与 `Accept: application/graphql-response+json, application/json;q=0.9`；
- 支持自定义全局 HTTP Headers（如 Bearer Token 认证头）。

### 3.3 细粒度结构化错误与局部数据保留 (Partial Data Retention)

GraphQL 与传统 REST 的重要区别在于：即使查询过程中部分字段出错，服务器仍可返回已成功解析的数据。本项目完整实现了这一关键特性：
- **`GraphQLResponse` 结构体**：独立保留 `data: Json?` 与 `errors: Array[GraphQLError]`；
- **错误定位精确解码**：每个 `GraphQLError` 结构均包含 `message`、`locations`（行列号 `line`/`column`）、`path`（字段路径数组）和 `extensions`（如业务错误码 `code`）；
- 即使响应 HTTP 状态码为 400（例如语法或校验错误），只要响应体符合 GraphQL 格式信封，客户端仍能优雅解码错误详情，而不是简单抛出传输异常。

### 3.4 健壮的防御性错误模型

定义了类型完备的 `ClientError`：
- `InvalidEndpoint(String)`：对非合法 `http://` 或 `https://` 的 URL 进行前置拒绝；
- `InvalidRequest(String)`：拦截空 Query 或非法请求；
- `TransportFailure(String)`：网络连接中断、DNS 解析失败等底层错误；
- `HttpFailure(Int, String)`：网关 502/504 等非 GraphQL 格式的 HTTP 失败；
- `InvalidResponse(String)`：响应体非合法 JSON 或不符合 GraphQL Envelope 结构的格式错误。

---

## 四、三大典型使用场景

### 场景一：开发者工具——查询 GitHub GraphQL API v4
- **使用者**：MoonBit CLI 插件或项目自动化 Bot 开发者；
- **目标服务**：`https://api.github.com/graphql`；
- **业务操作**：单次请求批量获取目标仓库的 Star 数量、最新的 Release Tag 与 PR 合并状态；
- **认证与输入**：通过客户端初始化传入 `Authorization: Bearer <GITHUB_TOKEN>`，使用带变量的 Query `query RepoInfo($owner: String!, $name: String!)`；
- **测试验证**：在测试套件中通过 Mock Transport 验证请求序列化、变量绑定及响应正确解析。

### 场景二：Jamstack 与文档系统——消费 Headless CMS (Strapi / Hasura)
- **使用者**：编写静态站点生成器 (SSG) 或企业内容渲染工具的开发者；
- **目标服务**：Strapi / Hasura 后端 (`https://cms.example.com/graphql`)；
- **业务操作**：按分页拉取文章列表及其关联的作者信息；
- **核心价值体现**：当部分作者信息因权限受限被设为 null 时，客户端利用 Partial Data Retention 保留其余所有文章数据，并在 `errors` 中报告受限字段，避免整个页面构建崩溃。

### 场景三：微服务架构——业务数据聚合与 RPC 突变 (Mutation)
- **使用者**：在 MoonBit Native 或 Wasm 容器环境中运行微服务的后端开发者；
- **目标服务**：内部 GraphQL API Gateway (Apollo / Yoga)；
- **业务操作**：执行库存扣减突变 `mutation UpdateStock($id: ID!, $quantity: Int!)`；
- **核心价值体现**：验证 Mutation 请求头租户隔离（`X-Tenant-Id`），并能区分服务端 502 网关不可用与 400 业务字段校验失败。

---

## 五、测试验证与质量保证

项目建立了完善的多层自动化验证体系：

```text
moon fmt --check                    PASS
moon check                          PASS
moon test                           7 passed, 0 failed
moon test --target native           CI 自动化执行（含 Ephemeral Loopback Socket 测试）
```

1. **确定性 Mock 单元测试（7 项全量通过）**：
   - `encodes GraphQL POST and decodes data`：完整验证标准请求编码与正常响应解码；
   - `preserves partial data and structured GraphQL errors`：验证局部数据与结构化错误共存；
   - `accepts GraphQL request errors returned with an HTTP error status`：验证 HTTP 400 下的 GraphQL 错误信封解码；
   - `reports non-GraphQL HTTP errors with status and body`：验证 502 等非 GraphQL 错误的准确分类；
   - `rejects malformed successful responses`：验证非法 JSON 格式拦截；
   - `maps transport errors to a distinct client error`：验证底层连接失败映射；
   - `validates endpoint and rejects empty query`：验证边界输入与空查询校验。
2. **真实 Native 回环测试（Native Target Integration Test）**：
   - 利用 `@http.Server` 在本地临时端口启动真实的 Socket 回环服务，由 `GraphQLClient` 发送真实 HTTP 请求，验证完整的网络栈通信逻辑。
3. **GitHub Actions 持续集成**：
   - 配置了跨 Ubuntu 平台的自动化 CI，自动拉取最新 MoonBit 工具链并依次执行格式校验、类型检查、默认测试与 Native 集成测试。

---

## 六、AI 辅助与人工主导说明

本项目严格遵循赛事“AI 原生与人工主导”的规范要求：
- **重构决策由我亲自作出**：在 9 月 30 日接到初审驳回后，我全面分析了评审意见与赛事章程，果断确立了通用 GraphQL 客户端的重构方向；
- **AI 辅助范围**：AI 辅助参与了部分 MoonBit 样板代码草拟、Mock Transport 结构体搭建及边界异常测试用例的枚举；
- **人工主导与把关**：传输层 `HttpSend` 抽象解耦、GraphQL 协议 Envelope 规范对齐、局部数据保留状态机、三大使用场景构建以及全部审查记录与申报材料，均由我亲自审核、推导与编写；
- 完整的人工审查记录详见 [`docs/owner-review.md`](docs/owner-review.md)。

---

## 七、开源与许可

项目采用 **Apache-2.0 License** 开源许可。评委与社区开发者可自由查看源码、测试套件与 CI 运行记录。未来我将继续完善 GraphQL Schema 代码生成与 Subscriptions 扩展，持续为 MoonBit 生态贡献高质量基础设施。

---

## 八、申报承诺

本项目申报材料中的架构说明、接口设计、测试结果及使用场景均以仓库当前公开源码为准。我不夸大当前功能（明确说明暂不支持 WebSockets 与模式代码生成），不把 Mock 测试虚构成生产上线案例，如实披露 AI 辅助边界。我将继续保持代码透明与工程严谨。
