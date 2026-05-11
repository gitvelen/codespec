# design.md

<!-- CODESPEC:DESIGN:READING -->
## 0. AI 阅读契约

- 本文件是 Implementation 阶段的默认权威输入。
- 所有架构决策、模块、接口、数据结构、外部交互和实现计划必须追溯到 REQ-*、ACC-*、VO-*、TC-*。
- 若实现需要越出本文实现边界的范围，必须停止并回写设计或需求，不得隐性扩 scope。
- 本文件各章节标题和 `<!-- CODESPEC:... -->` 标记必须保留；框架 gate 通过这些标记和标题别名来定位章节内容。

| 附件类型 | 读取触发 | 权威边界 | 冲突处理 |
|---|---|---|---|
| `design-appendices/*.md` | 当前任务命中对应模块、页面、Agent、流程、数据或运维细节时读取；不要默认全量读取 | 只展开本文已批准设计的强证据和实现输入；不得新增需求、扩大 scope 或改写 `REQ-*` / `ACC-*` / `VO-*` / `TC-*` 口径 | 与本文或 `spec.md` 冲突时停止并回写权威文档，Implementation 阶段按 authority repair 路径处理 |

<!-- CODESPEC:DESIGN:OVERVIEW -->
## 1. 设计概览

- solution_summary: [用 3-5 行说明方案核心]
- minimum_viable_design: [为什么这是满足需求的最小必要设计]
- non_goals:
  - [明确不解决的问题]

<!-- CODESPEC:DESIGN:TRACE -->
## 2. 需求追溯

- requirement_ref: REQ-001
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  design_response: [本设计如何满足该需求]

<!-- CODESPEC:DESIGN:DECISIONS -->
## 3. 架构决策

- decision_id: ADR-001
  requirement_refs: [REQ-001]
  decision: [技术栈、架构或关键实现决策]
  alternatives_considered:
    - [备选方案及放弃原因]
  rationale: [为什么选择当前方案]
  consequences:
    - [带来的约束、成本或风险]

### 技术栈选择

- runtime: [语言、框架、运行时版本或 none]
- storage: [数据库、缓存、文件系统或 none]
- external_dependencies:
  - [第三方服务、SDK、API 或 none]
- tooling:
  - [测试、构建、部署工具或 none]

<!-- CODESPEC:DESIGN:STRUCTURE -->
## 4. 系统结构

- system_context: [当前系统入口、调用链或模块背景]
- data_flow: [关键数据流或状态流]
- external_interactions:
  - name: [外部系统或 none]
    direction: inbound/outbound/both
    protocol: [HTTP/event/SDK/file/none]
    failure_handling: [失败、超时、重试或降级策略]

<!-- CODESPEC:SCOPE_ALLOWED -->
### 可修改路径

- `src/auth/**` — [说明]
- `src/middleware/token.ts` — [说明]
<!-- CODESPEC:SCOPE_ALLOWED_END -->

<!-- CODESPEC:SCOPE_FORBIDDEN -->
### 不可修改路径

- `versions/**` — 归档快照
- `src/billing/**` — 不在本次变更范围
<!-- CODESPEC:SCOPE_FORBIDDEN_END -->

<!-- CODESPEC:DESIGN:CONTRACTS -->
## 5. 契约设计

- api_contracts:
  - contract_ref: [contracts/*.md 或 none]
    requirement_refs: [REQ-001]
    summary: [接口、参数、返回、权限、错误码]
- data_contracts:
  - contract_ref: [contracts/*.md 或 none]
    requirement_refs: [REQ-001]
    summary: [数据结构、字段、约束、迁移要求]
- compatibility_policy:
  - [兼容、迁移、回滚、开关或灰度策略]

<!-- CODESPEC:DESIGN:CROSS_CUTTING -->
## 6. 横切设计

- environment_config:
  - [必需环境变量、配置、账号、权限、启动条件]
- security_design:
  - [鉴权、授权、输入校验、敏感信息处理]
- reliability_design:
  - [错误处理、重试、幂等、降级、恢复]
- observability_design:
  - [日志、指标、告警、审计、排障证据]
- performance_design:
  - [容量、时延、并发、资源消耗；没有则写 none]

<!-- CODESPEC:DESIGN:SLICES -->
## 7. 实现计划与验证

### 实现计划

- slice_id: SLICE-001
  goal: [本次交付的可验证目标]
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]

### 验证设计

- test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  approach: [如何验证]
  evidence: [预期证据]
  required_stage: implementation/testing/deployment

### 重开触发器

- [什么情况必须重开 spec/design]
<!-- CODESPEC:DESIGN:SLICES_END -->

<!-- CODESPEC:DESIGN:IMPLEMENTATION_INPUT -->
## 8. 实现阶段输入

### Runbook（场景如何跑）

- runbook: [用连续文字描述场景如何从触发走到终态]

### Contract（接口与数据结构）

- contract_summary: [引用 contracts/*.md 或在此描述]

### View（各方看到什么）

- view_summary: [完成后用户/调用方/监控看到的变化]

### Verification（验证证据）

- verification_summary: [引用 TC-*，说明每个 TC 证明什么行为]
