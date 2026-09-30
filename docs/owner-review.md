# Owner Review Record: MoonBit GraphQL HTTP Client

本记录由项目负责人（韦昌豪 / Wchwch777）亲自审查并签署。

## 一、重构背景与选题转向说明 (Pivot Rationale)

2026年9月30日，原申报项目《一维型材套裁启发式与参数化造价模型》收到赛事组委会正式初审驳回通知：
> “项目场景过于特殊，需求覆盖面较窄，审查驳回，建议更换选题。请查看赛事章程说明和需求，可以参考提供的参赛选题示例。可以在2026年9月30日前修改报名表格并提交最新信息。”

经认真核对组委会审查意见与赛事章程，原套裁选题确实过于垂直于建筑与下料小众工业领域，普适度不足。因此我果断决定在截止日前实施项目重大重构与方向迁移：**全面转向 MoonBit 通用网络基础设施——开发专注轻量出站调用、具备可测试传输缝（Transport Seam）的通用 GraphQL HTTP 客户端。**

---

## 二、人工审查与核验清单 (Owner Verification Checklist)

- [x] **本地运行与 API 行为审查**：
  - 亲自运行 `moon fmt --check`（通过）、`moon check`（通过，在默认 target 下保留实验性 http 导入告警）、`moon test`（7 项确定性测试全部通过）。
  - 审查了 `GraphQLClient::new` 与 `with_transport` 的构造设计，确认传输层抽象解耦彻底，支持在无网络环境下完全通过内存 Transport 验证协议细节。
  - 确认当前客户端直接返回原生 `@json.Json?`，未实现强类型业务模型反序列化；URL 检查为初步协议与格式筛选（`is_http_endpoint`）；`variables` 接受任意 `@json.Json`，未强制校验顶层是否为 Object。
- [x] **生态对比与定位差异化（对比 moongql）**：
  - MoonBit 社区已有专注于服务端的解析与执行引擎 `moonbitstack/moongql`（涵盖 GraphQL AST 解析、校验、执行与服务端接入）；
  - 本项目定位为轻量级**出站（Outbound）HTTP 客户端**，核心差异在于：提供显式解耦的 `HttpSend` 传输缝、支持纯内存单测、提供原生局部数据（Partial Data）保留机制与统一客户端错误分类。两者在生态中互为补充，分别覆盖服务端与客户端场景，并不声称 MoonBit 生态此前“完全空白”。
- [x] **三大使用场景定义与口径限定**：
  - **场景一：开发工具集成——查询 GitHub GraphQL API v4 元数据**
    - **使用者**：MoonBit 命令行工具/发布脚本或自动化 Bot 开发者。
    - **目标服务**：GitHub GraphQL API (`https://api.github.com/graphql`)。
    - **具体任务**：单次请求获取仓库最新 Release Tag、Star 数量以及特定 PR 审查状态，避免 REST 多次分页查询开销。
    - **认证与输入**：通过客户端 `headers` 传入 `Authorization: Bearer <GITHUB_TOKEN>`；Query 传入包含 `$owner: String!, $name: String!` 的变量对象。
    - **预期结果与验证**：返回标准 JSON 树结构，在网络抖动或未授权字段时通过 `errors` 解析详细结构。已在单元测试中使用 Mock Transport 严格复现此数据流。
  - **场景二：内容型与 Jamstack 站点——消费 Headless CMS (Strapi / Hasura)**
    - **使用者**：基于 MoonBit 编写静态站点生成器 (SSG) 或文档系统的开发者。
    - **目标服务**：Strapi / Hasura GraphQL 实例 (`https://cms.example.com/graphql`)。
    - **具体任务**：批量拉取文章标题、Slug、关联作者及正文 Markdown 内容。
    - **认证与输入**：通过 Header 注入 API Token；发送命名操作 `query GetArticles`。
    - **预期结果与验证**：即使某个关联作者字段因权限返回 null，客户端也能完整保留外层已获取的 `data.articles`，充分体现 Partial Data Retention（局部数据保留）能力。已在 `partial_error_transport` 测试用例中完成边界核验。
  - **场景三：微服务架构——业务数据聚合与 RPC 突变 (Mutation)**
    - **使用者**：在 Native 或 Wasm 容器中编写微服务业务逻辑的开发者。
    - **目标服务**：内部 GraphQL API Gateway (Apollo / Yoga)。
    - **具体任务**：提交工单修改或库存扣减突变 (`mutation UpdateStock($id: ID!, $quantity: Int!)`)。
    - **认证与输入**：注入租户及签名头部（`X-Service-Token`, `X-Tenant-Id`）；通过 `Json::object` 结构化序列化变量。
    - **预期结果与验证**：验证请求体合法 JSON 编码；若服务返回 400 校验错误或 502 上游超时，客户端能分别准确映射为 `GraphQLResponse`（含错误详情）或 `ClientError::HttpFailure(502, ...)`。已在测试套件中完成严密测试。
  - *验证口径限定*：**上述三大场景均为基于内存 Mock 传输的完整协议与数据流行为演示**，用以验证客户端在不同服务端响应模式下的行为正确性，而非已连接到线上生产 GitHub、CMS 或微服务网关的端到端实测。
- [x] **AI 辅助边界与人工主导职责确认**：
  - AI 协同起草了客户端与响应解码器的原型代码、搭建了传输缝接口与初始测试桩、配置了 GitHub Actions CI 并生成了初始文档草稿；
  - 我亲自作出放弃原套裁选题的重构决策，逐行审查 API 边界与错误分流状态机，定位并修复了 Native 回环测试中关键的字符串插值与端口绑定缺陷，明确限定了 Mock 演示口径，并亲自编写申报材料与审查记录。
- [x] **最终 Diff 审查与推送授权**：
  - 我已亲自查看本地 diff，确认清理了旧的套裁代码，更新了仓库元数据，并修复了 CI 流水线。我正式授权合并并推送到 `main` 分支。

---

## 三、签署确认 (Sign-off)

- **审查人**：韦昌豪 (GitHub: Wchwch777)
- **审查日期**：2026-09-30
- **技术基准**：Commit `079629f`（CI 全绿通过）
- **审查结论**：**ACCEPTED & AUTHORIZED FOR MERGE AND PUSH**
- **签名**：韦昌豪 (Wchwch777)
