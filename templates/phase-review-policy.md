# Phase Review Policy

阶段切换必须同时满足机器 gate 与语义复审。`check-gate` 只检查最低客观条件，不代表文档已经高质量、需求已经合理、设计已经可实施。

## 规则权威源

- 本文件是阶段切换、语义复审、阻塞条件和 gate 序列的语义权威源。
- `templates/gate-map.yaml` 是阶段切换 gate 序列的机器可读目录；人和 Agent 查看序列时使用 `codespec gate-sequence <transition>`，不要在其他文档重复维护硬编码列表。
- `codespec` CLI、`scripts/check-gate.sh` 与 git hooks 是机器执行层，只负责把可自动检查的规则落地；若执行层与本文件冲突，先修正规则或实现，不要绕过 hook。
- `AGENTS.md` / `CLAUDE.md` 是 AI 行为入口，必须与本文件保持方向一致，但不重新定义阶段规则。
- `README.md`、`quick-start.sh` 和示例对话只负责教程说明；不得作为阶段规则的最终依据。
- `skills/rfr/SKILL.md` 只负责执行复审闭环，阶段规则仍以本文件为准。

## 通用规则

- 每次切换前先读当前 dossier 的 `AGENTS.md` 或 `CLAUDE.md`，再读本文件与 `codespec readset` 输出。
- 正式需求、验收、验证义务、测试用例必须形成 `REQ -> ACC -> VO -> TC -> RUN` 链路。
- `spec.md` 和 `design.md` 的 `0. AI 阅读契约` 是 AI 默认读取行为的权威说明。
- `testing.md` 支持 legacy 分节和 `CODESPEC:TESTING:LEDGER` 结构化块；结构化块存在时 gate 以结构化块为准，避免同时维护两套不一致的事实。
- Requirement 撰写时必须读取用户提供的原始材料来生成自足需求；从 Requirement 复审通过以后，原始材料不参与默认实施上下文，只在溯源核对、歧义、冲突或重开时读取。
- phase 推进前必须给出 `允许切换`、`有条件允许切换` 或 `禁止切换` 结论。
- `reviews/*.yaml` 是审查记录与 gate evidence ledger，不是人类授权令牌。它必须至少包含：`phase`、`verdict: approved`、`reviewed_by`、`reviewed_at`、`scope`、`gate_evidence`、`findings`、`residual_risk`、`decision_notes`；`scope` 必须指向存在的项目文件。`gate_evidence` 必须覆盖 `codespec gate-sequence <transition>` 列出的目标阶段必需 gate，每条 evidence 必须包含 `gate`、`command`、`result: pass`、`checked_at`、`checked_revision`、`output_summary`，且 `checked_revision` 必须是当前仓库中的有效 commit。可用 `codespec review-gates <target-phase> --write` 写入客观 gate evidence，再由人工补齐语义复审字段。`findings[].severity` 必须是 `P0/P1/P2/none`。可用 `codespec scaffold-review <target-phase>` 生成 pending 脚手架，但 pending 不能作为批准记录。

## Requirement 撰写 / 输入整理

必须读取：
- 用户提供的原始材料，包括已落盘的讨论记录、需求原文，或项目约定的材料目录
- `spec.md`
- `testing.md`

必须完成：
- 先判断输入成熟度与严谨度，必要时向用户确认 `light / standard / evidence-rich`。
- 把关键语义写入 `spec.md` 正文，不能只在原始材料中保留。
- 对流程、体验、协作、状态机或业务语义复杂的能力，必须写出连续的流程叙事；表格和编号只做索引，不能替代正文叙事。
- 为每个 planned / approved acceptance 写出 `TC-*` 测试用例计划。

禁止：
- 只读空模板就声称需求已理解。
- 依赖未落盘的长对话记忆生成正式需求。
- 把原始材料整体复制进正文而不做需求结构化。
- 只列角色、边界、排除项和 `REQ/ACC/VO` 链路，却没有说明核心流程如何运行。

## Requirement -> Design

必须读取：
- `spec.md`
- `testing.md`

必须确认：
- `spec.md` 包含 `0. AI 阅读契约`、`1. 需求概览`、`2. 决策与来源`、`3. 场景、流程与运行叙事`、`4. 需求与验收`、`5. 运行约束`、`6. 业务契约`、`7. 设计交接`。
- `spec.md` 的场景章节包含可复述的流程叙事；复杂需求必须讲清 happy path、失败/降级路径、关键产物、状态或数据语义。
- 正式 `REQ-*`、`ACC-*`、`VO-*` 都在 `spec.md` 正文中定义，不依赖 appendix 或 inputs 才能理解。
- 每个 approved `ACC-*` 至少有一个 `TC-*` 测试用例计划。
- 每个 `TC-*` 写明 `scenario / given / when / then / evidence_expectation / required_stage / verification_mode`。
- P0 若不是自动化验证，必须有 `automation_exception_reason`，并在审查记录中明确记录该例外。

必须通过：
- `codespec gate-sequence start-design` 中列出的全部 gate

禁止切换：
- `spec.md` 语义压缩，冷启动 AI 无法只靠正文设计。
- 冷启动设计者只能看到名词、边界和 ID 链路，无法复述核心流程。
- `testing.md` 只有执行记录，没有需求确认后的 `TC-*` 计划。
- acceptance 不可观测、不可判 PASS/FAIL，或 verification 只是“以后补”。

## Design -> Implementation

必须读取：
- `spec.md`
- `design.md`
- `testing.md`
- `contracts/*.md`（design.md §5 引用的）

必须确认：
- `design.md` 包含技术栈选择、外部交互、安全设计、环境配置、可靠性、可观测性、性能、兼容/迁移/回滚。
- 每个设计模块、接口、数据结构、外部交互、实现切片都能追溯到 `REQ/ACC/VO/TC`。
- 每个 slice 是可执行垂直切片，不是把需求原文复制给实现者。
- `design.md` §4 可修改/不可修改路径非空且合理。
- `design.md` §7 每个 slice 的 `goal`、`requirement_refs`、`acceptance_refs`、`verification_refs`、`test_case_refs` 完整，且覆盖 `spec.md` / `testing.md` 中所有正式 `REQ/ACC/VO/TC`。
- `design.md` §8 实现阶段输入（Runbook/Contract/View/Verification）非空。
- 若存在共享边界，`contracts/*.md` 已冻结。

必须通过：
- `codespec gate-sequence start-implementation` 中列出的全部 gate

禁止切换：
- 实现切片没有 `test_case_refs`。
- 设计缺少安全、环境、外部交互、回滚或验证设计中的关键项。
- design.md §4 实现边界为空或全为 placeholder。
- design.md §5 引用的 contract 未冻结。

## Implementation -> Testing

必须读取：
- `meta.yaml`
- `design.md`
- `testing.md`

必须确认：
- 所有实现改动都在 design.md §4 可修改路径内，且未命中不可修改路径。
- `meta.yaml` 和 `testing.md` 是 lifecycle / evidence 文件；检查其内容质量，而不是要求它们归属到某个实现切片。
- design.md §7 所有 slice 引用的自动化 `TC-*` 已追加 `branch-local` 的 `RUN-*` pass 记录。
- P0 自动化测试不是形式上的命令占位，`artifact_ref` 可复核。
- `testing.md` 已追加当前 Implementation 的 `HANDOFF-*`，主动列出未完成项、最高完成等级、证据、阻塞原因和下一步；branch-local / fixture 证据不得表述为 integrated runtime。
- 实现没有隐性扩大 scope；若设计解释不了实现，必须回写 design/spec。

必须通过：
- `codespec gate-sequence start-testing` 中列出的全部 gate

禁止切换：
- 任一 slice 的自动化 `TC-*` 无 branch-local pass。
- 测试失败且无法在当前 scope 内修复。
- frozen contract 被修改或 shared boundary 未审查。
- 未记录主动未完成清单，或 fallback/fixture/API 连接级证据被当成完成。

## Testing -> Deployment

必须读取：
- `meta.yaml`
- `testing.md`
- `design.md`

必须确认：
- 每个非 deployment-only 的必测 `TC-*` 都有 latest `full-integration` pass。
- latest fail 会推翻 earlier pass。
- 每个 `RUN-*` 都有真实 `artifact_ref`、`residual_risk`、`reopen_required`。
- P0 默认自动化；非自动化必须有已接受的例外理由。
- `testing.md` 已追加 Testing 阶段 `HANDOFF-*`；若 full-integration 未覆盖真实依赖、失败态、stale、trace/retry 或冲突路径，必须列为未完成。

必须通过：
- `codespec gate-sequence start-deployment` 中列出的全部 gate

禁止切换：
- 任一必测 TC 没有 full-integration pass。
- `reopen_required: true` 仍试图推进。
- artifact 不能让第三方复核。
- 未主动披露 full-integration 之外的剩余语义缺口。

## Authority Repair Path

适用于 Implementation / Testing / Deployment 阶段：当 gate、hook、review 或 lifecycle 命令发现上游 authority 文档存在必须先修的结构性或语义性缺口时，不要直接手改 forbidden 文件，也不要 `--no-verify`。

必须执行：
- `codespec authority-repair begin <gate> --paths <最小authority路径列表> --reason "<修复原因>"`
- 只修改 repair record、`meta.yaml` 和声明的最小 authority 文件。
- 禁止借修复态扩大产品口径、修改 frozen contract、夹带 `src/**` 或 Dockerfile。
- 修复后执行 `codespec authority-repair close --evidence "<gate证据摘要>"`；该命令必须重跑 repair 记录的 gate 并通过 `metadata-consistency` 后才会关闭 repair。完整框架 smoke 由常规回归命令单独执行，不再作为每次 close 的内置步骤。

未进入修复态时，Implementation / Testing / Deployment 仍必须阻断越权 authority 修改；未关闭 repair 不得推进阶段。

## Deployment -> Completed / Promotion

必须读取：
- `deployment.md`
- `testing.md`
- `meta.yaml`

必须确认：
- `deployment.md` 已记录发布对象、环境、执行证据、运行验证、回滚与监控、人工验收。
- `release_mode=runtime` 时，`deployed_revision = runtime_observed_revision`。
- deployment-only/manual 的 `TC-*` 已有 deployment 阶段证据。
- `manual_verification_ready: pass` 只表示可开始人工验收；只有用户明确通过后，`人工验收与收口.status` 才能写 `pass`。
- 回滚计划和监控项能覆盖本次变更的主要失败模式，不是模板占位。
- `testing.md` 已追加 Deployment 阶段 `HANDOFF-*`；只有人工验收通过且 evidence 可复核时，才可将最高完成等级写为 `owner_verified`。

必须通过：
- `codespec gate-sequence complete-change` 中列出的全部 gate

禁止切换：
- 人工验收未明确通过。
- runtime readiness、smoke、回滚、监控任一项仍是占位。
- 当前运行版本未证明加载了本次部署。
- Deployment handoff 缺失，或仍有未披露的 report artifact / owner_verified 缺口。

## 命令映射

- `codespec gate-sequence <transition>` 输出阶段切换的权威 gate 序列。
- `authority-repair begin/close/status` -> 受控修复后续阶段发现的上游 authority 缺口；close 必须重跑记录的 gate，并通过 metadata consistency。
- `deploy` -> `deployment-plan-ready` + 调用 `scripts/codespec-deploy` 并回写 `deployment.md`。
- `submit-pr <stable-version>` -> 完成归档后创建 PR。
