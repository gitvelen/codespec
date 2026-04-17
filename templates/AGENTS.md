# AGENTS.md

本文件只负责当前 change dossier 的导航与决策路由；禁止用worktree；尽量用简体中文交流（包括文档，除非涉及专业术语）；需求 / 验收 / 验证义务以 `spec.md` 为准，设计 / 边界 / Work Item 派生以 `design.md` 为准，执行范围 / 禁改范围 / 依赖以 `work-items/*.yaml` 为准，验证记录以 `testing.md` 为准，部署结论 / 回滚 / 监控以 `deployment.md` 为准，接口边界以 `contracts/*.md` 为准，硬规则以 `../../lessons_learned.md` 为准。

## 核心原则
1. 先澄清再动手：目标/边界/约束/风险/验收，不清楚先问；范围变更必须说明代价并重新确认。
2. 可验收可追溯：需求有可判定验收标准（第三方可判 PASS/FAIL）；成功指标给出"基线→目标"；维护场景→需求→实现→验证追溯链。
3. 偏了就停：执行中发现方向偏离、连续失败、或复杂度超预期，立即停下重新规划，不硬推。
4. 最小必要变更、始终可回滚：只改必须改的；垂直切片优先；线上行为变化必须有回滚/开关/灰度方案。
5. 证据驱动、质量闭环：关键结论附命令/环境/输出；完成前 diff 基线确认变更范围；合入前自测；缺陷立即处理并记录。
6. 安全合规优先：最小权限、输入校验、密钥不落盘；新依赖需评估必要性与安全性。
7. 第一性原理：拒绝经验主义和路径盲从，不要假设我完全清楚目标，应保持审慎；若目标模糊请停下和我讨论；若目标清晰但路径非最优，请直接建议路径更优的办法；任务澄清且明确无歧义之后就直接执行。

### Compact Instructions 如何保留关键信息
保留优先级：
1. 架构决策，不得摘要
2. 已修改文件和关键变更
3. 验证状态，pass/fail
4. 未解决的 TODO 和回滚笔记
5. 工具输出，可删，只保留 pass/fail 结论

## 启动顺序
1. 读取根目录 `../../lessons_learned.md`
2. 读取当前目录 `./CLAUDE.md`
3. 读取当前目录 `./meta.yaml`
4. 只有在默认层不足以解释当前任务时，才继续下钻 `./spec-appendices/` 或 `./design-appendices/`
5. 先读当前目录 `./spec.md` 的 Default Read Layer，并在 `<!-- SKELETON-END -->` 处先停
6. 再读当前目录 `./design.md` 的 Default Read Layer
7. 如果 `focus_work_item != null`，读取 `./work-items/<focus_work_item>.yaml`
8. 如果当前 Work Item 的 `contract_refs` 非空，读取对应 `./contracts/*.md`

## 冲突升级规则
- 同一 concern 内出现冲突：以后更新且证据更充分的条目为准，并在当前文件补充“为何覆盖”。
- 跨 concern 出现冲突：不得直接覆盖，必须回写对应权威文件对齐（Spec/Design/Work Item/Testing/Deployment/Contract），必要时暂停并升级决策。

## 按 phase 的默认导航
- Requirements：主读 `spec.md` 的 Intent / Requirements / Acceptance / Verification / Clarification Status；只在边界或实现影响需要时回看 `design.md`
- Design：先对齐 `spec.md` 的 goals / anchors / acceptance，再读 `design.md` 的 Goal / Scope Link、Architecture Boundary、Work Item Execution Strategy、Work Item Derivation、Verification Design；需要共享边界时读 `contracts/*.md`
- Implementation：默认聚焦当前 Work Item、`design.md` 中对应的 Work Item Derivation row、`design.md` / `design-appendices/` 中对应的 design slice；命中边界时再读对应 Contract；触及 acceptance 或 verification obligations 时回看 `spec.md`
- Testing：先回看 `spec.md` 的 approved acceptance 与 verification obligations，再看 `design.md` 的 Verification Design，最后核对 `testing.md` 的 pass record / artifact / residual risk / reopen_required
- Deployment：先确认 `testing.md` 已覆盖应验证 acceptance，再读 `deployment.md` 的部署计划、验证结果、回滚方案、监控与收尾动作；必要时回看 `design.md` / `spec.md`

## 必须先澄清的条件
- 当前任务无法映射到明确的目标、边界或 acceptance
- `Clarification Status` 中存在会影响当前动作的 open decision
- `spec.md` / `design.md` / `work-items/*.yaml` 之间对 scope、acceptance、verification 的描述不一致
- 需要做产品 / 需求判断，而非纯工程判断

## 必须回看权威文件的条件
- 回看 `spec.md`：可能改变目标、边界、acceptance 或 verification obligations；当前 `work-item + design` 已无法稳定解释意图；怀疑 Design 已偏离 Spec；进入 Testing 或 Deployment 前，需要重新确认 approved acceptance 与 verification obligations
- 回看 `design.md`：切换 `focus_work_item`；改动开始触及新的路径、模块或接口边界；当前实现方案与既有切片划分不一致；需要新增、合并或重新切分 Work Item；进入 Testing 或 Deployment 前，需要确认设计前提仍成立
- 回看 `testing.md`：需要确认 acceptance 是否已有 pass 记录，或 residual risk 是否仍可接受
- 回看 `deployment.md`：进入 Deployment / Promotion，或需要判断回滚、监控、上线后动作

## 必须停下的情况
- 需要修改 `forbidden_paths` 中的文件
- 需要实现 `out_of_scope` 中的功能
- 当前 phase 文档或当前 Work Item 无法解释允许修改范围
- 依赖 Work Item 尚未完成，但当前任务需要消费它的结果
- 需要修改 frozen contract
- 测试失败且无法在当前 scope 内修复
- 发现 `spec.md`、`design.md`、`testing.md` 或 `deployment.md` 需要先回写才能继续

## Gate / Hook 提醒

### 按阶段的关键 Gate
- **Requirements**：优先关注 `spec-completeness` (= proposal-maturity + requirements-approval)
- **Design**：优先关注 `design-structure-complete`（别名：`design-readiness`）
- **Implementation**：优先关注 `implementation-ready` (= design-structure-complete + implementation-start + implementation-readiness-baseline)；`pre-commit` 仍会兜底 `branch-alignment`、`metadata-consistency`、`scope`、`boundary`
- **Testing**：优先关注 `trace-consistency`、`verification`（包含 testing-coverage）
- **Deployment**：优先关注 `deployment-readiness`、`promotion-criteria`
- **pre-push**：仍会兜底 `branch-alignment`、`feature-sync`、`metadata-consistency`、`verification`

### 可用的 Gate 检查
**组合 Gate**（调用多个原子 gate）：
- `spec-completeness` → proposal-maturity + requirements-approval
- `implementation-ready` → design-structure-complete + implementation-start + implementation-readiness-baseline
- `verification` → 依赖 WI pass 检查 + 当前 WI pass 检查；Testing/Deployment 阶段额外检查 testing-coverage
- `promotion` → metadata-consistency + deployment-readiness + promotion-criteria

**原子 Gate**（单一职责检查）：
- `proposal-maturity` → spec.md 提案成熟度（章节完整、REQ/ACC/VO 存在、输入闭包）
- `requirements-approval` → 需求批准就绪（澄清决策已解决、高影响澄清已关闭）
- `review-verdict-present` → 审查结论存在（phase review 有明确的 verdict）
- `design-structure-complete` (别名 `design-readiness`) → design.md 结构完整（章节完整、工作项推导、验收映射）
- `implementation-start` → 可以开始实施（work-item.yaml 完整、依赖通过、合约冻结）
- `metadata-consistency` → 元数据一致性（meta.yaml 与文档状态一致）
- `phase-capability` → 阶段能力检查（当前阶段是否支持请求的操作）
- `scope` → 范围检查（staged 变更在 allowed_paths 内、不在 forbidden_paths 内）
- `contract-boundary` (别名 `boundary`) → 合约边界检查（合约引用可解析、frozen 合约未变更）
- `trace-consistency` → 追溯一致性（REQ→ACC→VO、ACC→WI、approved ACC 有测试记录）
- `testing-coverage` → 测试覆盖率（所有 approved ACC 都有 pass 记录）
- `deployment-readiness` → 部署就绪（deployment.md 完整、验收结论 pass、审批信息完整）
- `promotion-criteria` → 晋升标准（metadata-consistency + testing-coverage + deployment-readiness）

### 统一入口
```bash
# 在项目目录中运行（.codespec 在上一级）
../.codespec/codespec check-gate <gate-name>

# 示例
../.codespec/codespec check-gate spec-completeness
../.codespec/codespec check-gate implementation-ready
../.codespec/codespec check-gate verification
```

### 重要提醒
- hooks 只做兜底，不替代主动阅读与回看权威文件
- 组合 gate 失败时，可以单独运行原子 gate 定位具体问题
- 所有 gate 都可以通过环境变量覆盖上下文（CODESPEC_PROJECT_ROOT、CODESPEC_FOCUS_WI、CODESPEC_TARGET_PHASE）