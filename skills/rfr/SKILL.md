---
name: rfr
description: Use when a codespec change dossier has reviewable phase output and the user wants a strict review-before-advance loop before changing phase, especially after prompts such as review, 复审, 走查, 复查, 阶段验收, comprehensive check, gate check, 阶段切换, ready to advance, or can we move to next phase.
---

# RFR 阶段复审闭环

`rfr` 只服务 `codespec`。它负责把阶段复审执行成稳定闭环，不负责重新定义阶段规则。所有阶段切换规则、gate 与阻塞条件，以 `phase-review-policy.md` 为权威源。

用户可见输出默认使用简体中文。

## 先读什么

1. `codespec status` — 获取 project_root、phase、focus_work_item、phase_capabilities
2. `codespec readset --json` — 按 `layered_readset.default -> work_item/phase -> on_demand` 分层读取；`entry_files` 字段指明读 `AGENTS.md` 还是 `CLAUDE.md`，不要两个都读
3. `../lessons_learned.md` — 读取快速索引中的全部硬规则，不要写死只读某几个编号
4. `phase-review-policy.md` — 阶段切换规则权威源
5. 权威文档先读 `0. AI 阅读契约`；空/冲突/不足时停止

`phase_capabilities.allowed/forbidden` 决定修复时能动什么、不能动什么。

如果 `phase` 与当前工作内容不匹配，先指出错位，不要硬做 review。
如果 `phase` 仍是旧的 `Proposal` / `Requirements`，先要求执行迁移脚本再继续。

## 路径说明
- 审查业务项目：读项目根的 `phase-review-policy.md`
- 审查框架源码仓：对应规则来源是 `templates/phase-review-policy.md`

## 什么时候用
- 用户说"复审""走查""复查""阶段验收""全面检查""阶段切换前检查"
- 某个 phase 已产出可审查结果，推进下一阶段前要做严格门禁
- 需要的不是普通 code review，而是"发现问题 -> 修明确问题 -> 复审确认是否收敛"

不要用于：
- 纯 brainstorming
- 还没形成可审查产物的阶段
- 只想看一段代码有没有 bug 的普通 review

## 执行顺序
1. `codespec status` — 确认 project_root、phase、focus_work_item、phase_capabilities
2. `codespec readset --json` — 按 layered_readset 分层读取全部必读文件
3. 读 `../lessons_learned.md` 硬规则 + `phase-review-policy.md`
4. 按当前 phase 对应的 gate 序列执行 `codespec check-gate`（见"门禁序列"），记录全部失败点；不要边扫边修
5. 按当前 phase 做语义全量检查（见"阶段提示"），先找全问题再统一分级
6. 只修"修复边界"内允许的问题
7. 重跑失败 gate + 同口径复审，直到 P0/P1 收敛或暴露真实阻塞

## 门禁序列

每个阶段切换对应的 gate 序列，必须全部 pass 才能推进。带环境变量的 gate 必须在执行前设置。gate pass != phase 已批准；语义复审仍是必要条件。

- **start-design**：`requirement-complete` → `spec-quality` → `test-plan-complete` → `CODESPEC_TARGET_PHASE=Design check-gate review-quality`
- **start-implementation**：`CODESPEC_FOCUS_WI=<WI> CODESPEC_TARGET_PHASE=Implementation check-gate implementation-ready` → `CODESPEC_TARGET_PHASE=Implementation check-gate review-quality`
- **start-testing**：`metadata-consistency` → `active-work-items-complete` → `CODESPEC_SCOPE_MODE=implementation-span check-gate scope` → `CODESPEC_CONTRACT_BOUNDARY_MODE=implementation-span check-gate contract-boundary` → `verification`
- **start-deployment**：`trace-consistency` → `verification`
- **complete-change**：`promotion-criteria`

## 阶段提示

### Requirement 撰写（需求尚未结构化时的输入整理）
权威阶段规则：见 `phase-review-policy.md` "Requirement 撰写 / 输入整理"。

额外关注：
- 用户提供的原始材料是否已读取并结构化
- 输入成熟度是否已向用户确认（light / standard / evidence-rich）
- 关键语义是否已写入 `spec.md` 正文，不是只在原始材料中保留
- 对流程、体验、协作、状态机或业务语义复杂的能力，`spec.md` 是否有连续流程叙事，而不是只有表格、编号和边界
- 每个 planned/approved acceptance 是否已写出 `TC-*` 测试用例计划
- 是否存在跳步（只读空模板就声称需求已理解 / 依赖未落盘记忆生成正式需求）

### Requirement / 准备进入 Design
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- `REQ -> ACC -> VO -> TC` 是否只是形式闭合，语义上却不对应
- 是否能不看原始材料，用自己的话复述核心 happy path、失败/降级路径、关键产物链和停止/升级条件
- acceptance 是否过大、带多个结果、只能靠主观判断
- `TC-*` 是否在需求确认后提前定义了真实场景，而不是 Testing 阶段临时补账
- P0 非自动化是否有足够强的 `automation_exception_reason`
- deferred clarification 是否会实质改变后续 design boundary

### Design / 准备进入 Implementation
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- architecture boundary 是否真正回答"改哪里、不改哪里、共享面受不受影响"
- 技术栈选择、外部交互、安全设计、环境配置、可靠性、可观测性、性能、兼容/迁移/回滚是否有实质内容
- work item 是否被切成可执行垂直切片，而不是整块需求原样下发
- 每个 work item 是否引用 `REQ/ACC/VO/TC`，且 `goal` 能说明为哪条需求服务
- 应该建 contract 却没建的共享边界是否被漏掉
- reopen trigger 是否足以约束何时必须回写 spec/design

### Implementation / 准备进入 Testing
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- 是否隐性扩大了 scope 或绕开既定 design slice
- shared boundary 是否只停留在约定，没有落到可复核证据
- 当前 WI 的自动化 `TC-*` 是否已有 branch-local `RUN-*` pass，且 artifact 可复核
- 当前实现是否仍能被 `spec.md`、`design.md`、当前 work item 合法解释

### Testing / 准备进入 Deployment
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- full-integration `RUN-*` 是否真正覆盖 `TC-*` 的 scenario / given / when / then，而不是实现细节
- `manual` / `equivalent` 证据是否足够支撑第三方复核
- 是否遗漏了 boundary alert 或 prohibition anchor 的验证
- 是否存在 `reopen_required: true` 却仍试图推进 Deployment

### Deployment / 准备 Complete Change 或 Promotion
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- smoke test 是否覆盖关键用户路径，而不是无关检查
- deployment-only/manual `TC-*` 是否已有真实运行或人工证据
- rollback trigger 与 rollback steps 是否真的可执行
- monitoring 的 metrics/alerts 是否能发现本次变更的主要风险
- post-deployment actions 是否形成闭环

## 修复边界
只有同时满足下面条件时才直接修复：
- 修复方向已被 `spec.md`、`design.md`、`work-items/*.yaml`、`testing.md`、`deployment.md` 或 gate 明确限定
- 不会改变产品方向、公共契约、业务规则或 scope 决策
- 修复范围不超出当前 phase 的 `phase_capabilities.allowed`
- 能立刻通过命令、测试、文档证据或 gate 重新验证

遇到以下情况必须停下问用户：
- 需要改 acceptance、verification obligation、scope、contract 或对外行为
- 需求、设计、work item 之间互相冲突
- 需要 Accept / Defer 一个 P0/P1
- 需要扩大 allowed_paths 或动 `forbidden_paths`
- 需要修复但 `phase_capabilities.forbidden` 阻止了必要改动

## 对话输出
至少包含：
- 结论摘要：通过 / 有条件通过 / 不通过；P0 / P1 / P2 数量
- 关键发现：证据、风险、建议修改、验证方式
- 覆盖率与证据：跑了 `codespec status`/`readset --json` 的哪些层、读了 `lessons_learned.md` 哪些硬规则、跑了哪些 gate、哪些还没覆盖
- 已修复项：修了什么，为什么无需额外产品决策
- 复审结论：是否收敛，剩余风险、阻塞项、待人决策项
