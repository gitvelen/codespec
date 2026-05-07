# spec.md

<!-- CODESPEC:SPEC:READING -->
## 0. AI 阅读契约

- 本文件是需求阶段的权威文档；进入设计阶段时，不得默认依赖原始材料才能理解需求。
- 撰写本文时必须读取用户提供的原始材料；本文完成后，应把关键语义沉淀到正文，而不是要求后续阶段继续读原始材料。
- 原始材料只作为溯源证据；关键需求语义、边界、验收与约束必须写入本文正文。
- 若本文与原始材料冲突，以本文的“决策与来源”中已确认决策为准；未确认冲突必须停止并询问用户。
- 所有后续设计、工作项、测试用例必须能追溯到本文的 `REQ-*`、`ACC-*`、`VO-*`。

| 附件类型 | 读取触发 | 权威边界 | 冲突处理 |
|---|---|---|---|
| `spec-appendices/*.md` | 当前任务命中对应领域、页面、Agent、流程、数据或 fixture 细节时读取；不要默认全量读取 | 只展开正文已批准需求的强证据和细节；不得定义正式 `REQ-*` / `ACC-*` / `VO-*` 或新增产品口径 | 与正文冲突时停止并回写 `spec.md`，不得让 appendix 覆盖正文 |

<!-- CODESPEC:SPEC:OVERVIEW -->
## 1. 需求概览

- change_goal: [用 3-5 行说明本次变更要达成什么]
- success_standard: [用可判断的语言说明什么算成功]
- primary_users:
  - [主要用户或调用方]
- in_scope:
  - [本次必须交付的范围]
- out_of_scope:
  - [本次明确不做的范围]

<!-- CODESPEC:SPEC:SOURCES -->
## 2. 决策与来源

- source_refs:
  - [稳定的 repo 文件引用，例如 docs/source/example.md#intent，禁止 conversation://]
- source_owner: [需求提出或确认人]
- rigor_profile: standard
  # 可选值：light / standard / evidence-rich
- normalization_note: [如何把原始输入和讨论整理成当前需求]
- approval_basis: [谁基于什么确认了当前需求口径]

### 已确认决策

- decision_id: DEC-001
  source_refs:
    - [来源引用]
  decision: [已确认的产品/业务/范围决策]
  rationale: [为什么这样定]

### 待澄清事项

- clarification_id: CLAR-001
  question: [仍需用户确认的问题；没有则写 none]
  impact_if_unresolved: [不解决会影响什么；没有则写 none]

<!-- CODESPEC:SPEC:SCENARIOS -->
## 3. 场景、流程与运行叙事

先用自然语言写清核心流程。不要只列角色、边界和编号；需要让冷启动设计者能复述系统在真实使用中如何开始、如何推进、谁看到什么、产出什么、哪里停止、哪里升级。简单变更可以写 1 段；复杂流程、页面工作台、Agent 协作或状态机应写多段，并覆盖 happy path、失败/降级路径和关键产物链。

### 核心流程叙事

[用连续文字描述核心用户旅程、系统行为、流程状态、关键产物、异常处理和降级路径。结构化条目只能索引本文，不能替代这段叙事。]

### 正向形态最低覆盖

撰写本章节时，确认以下每项都有实质内容（不能只是占位）：
- [ ] 系统在正常使用中如何启动（用户/触发器从哪里进入）
- [ ] 核心流程如何推进（关键步骤、状态变化、产出物）
- [ ] 各参与方看到什么（用户界面、API 响应、监控指标）
- [ ] 流程在哪里结束（成功终点、产出物交付）
- [ ] 失败/降级路径如何处理（P0 场景必须有）
- [ ] 关键业务术语在"业务契约"章节中有唯一定义

### 场景索引

- scenario_id: SCN-001
  actor: [谁]
  trigger: [在什么条件下]
  behavior: [系统应表现出的行为]
  expected_outcome: [用户或外部系统可观察结果]
  requirement_refs: [REQ-001]

<!-- CODESPEC:SPEC:REQUIREMENTS -->
## 4. 需求与验收

### 需求

- req_id: REQ-001
  summary: [需求描述，必须能脱离 inputs 理解]
  source_ref: [追溯到第 2 章 source_refs 中的稳定引用]
  rationale: [为什么需要]
  priority: P0/P1/P2

### 验收

- acc_id: ACC-001
  requirement_ref: REQ-001
  expected_outcome: [可观察、可判定 pass/fail 的结果]
  priority: P0/P1/P2
  priority_rationale: [为什么是这个优先级]
  status: approved

### 验证义务

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated/manual/equivalent
  verification_profile: focused/full
  obligations:
    - [必须验证什么行为或约束]
  artifact_expectation: [期望的测试命令、日志、截图、报告或其他证据形状]

<!-- CODESPEC:SPEC:CONSTRAINTS -->
## 5. 运行约束

- environment_constraints:
  - [运行环境、配置、账号、权限、数据或部署约束]
- security_constraints:
  - [鉴权、越权、敏感数据、输入校验等约束]
- reliability_constraints:
  - [可用性、失败处理、重试、降级、幂等等约束]
- performance_constraints:
  - [性能、容量、时延或并发要求；没有则写 none]
- compatibility_constraints:
  - [兼容、迁移、回滚或数据保留要求；没有则写 none]

<!-- CODESPEC:SPEC:BUSINESS_CONTRACT -->
## 6. 业务契约

- terminology:
  - term: [业务术语]
    definition: [唯一口径]
- invariants:
  - [必须始终成立的业务规则]
- prohibitions:
  - [明确禁止的行为或实现结果；没有则写 none]

<!-- CODESPEC:SPEC:HANDOFF -->
## 7. 设计交接

- design_must_address:
  - [设计阶段必须回答的问题，必须能追溯到第 3 节的流程叙事]
- narrative_handoff:
  - [哪些流程、页面、Agent 行为、状态机或服务编排必须在 Design 中直接展开]
- suggested_slices:
  - [建议的工作项切分；没有则写 none]
- reopen_triggers:
  - [什么情况必须回到需求阶段更新本文]
