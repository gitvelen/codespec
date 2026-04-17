# CLAUDE.md

本文件负责当前 change dossier 的导航与决策路由。禁止用 worktree；尽量用简体中文交流（除非涉及专业术语）。权威文件：`spec.md`（需求/验收/验证）、`design.md`（设计/边界/Work Item 派生）、`work-items/*.yaml`（执行范围/依赖）、`testing.md`（验证记录）、`deployment.md`（部署/回滚/监控）、`contracts/*.md`（接口边界）、`../lessons_learned.md`（硬规则）。

---

## 一、快速导航

### 启动顺序
1. 读取 `../lessons_learned.md`
2. 读取 `../phase-review-policy.md`
3. 读取 `./CLAUDE.md` 或 `./AGENTS.md`（二选一，内容等价）
4. 读取 `./meta.yaml`
5. 读取 `./spec.md` 的 Default Read Layer，在 `<!-- SKELETON-END -->` 处先停
6. 读取 `./design.md` 的 Default Read Layer
7. 如果 `focus_work_item != null`，读取 `./work-items/<focus_work_item>.yaml`
8. 如果当前 Work Item 的 `contract_refs` 非空，读取对应 `./contracts/*.md`
9. 只有在默认层不足以解释当前任务时，才下钻 `./spec-appendices/` 或 `./design-appendices/`

### 按阶段导航

**Proposal**：
- 主读：spec.md, design.md, meta.yaml
- 条件读取：contracts/*.md, work-items/*.yaml
- 禁止修改：src/**, Dockerfile, testing.md, deployment.md

**Requirements**：
- 主读：spec.md (Intent/Requirements/Acceptance/Verification/Clarification)
- 条件读取：design.md（边界或实现影响）

**Design**：
- 主读：design.md (Goal/Scope Link, Architecture Boundary, Work Item Derivation, Verification Design)
- 条件读取：spec.md (goals/anchors/acceptance), contracts/*.md（共享边界）

**Implementation**：
- 主读：work-items/<focus_work_item>.yaml, design.md (Work Item Derivation row, design slice)
- 条件读取：contracts/*.md（边界）, spec.md（acceptance/verification obligations）
- 禁止修改：forbidden_paths

**Testing**：
- 主读：testing.md, spec.md (approved acceptance, verification obligations), design.md (Verification Design)

**Deployment**：
- 主读：deployment.md, testing.md（验收覆盖）
- 条件读取：design.md, spec.md（必要时）

---

## 二、核心规则

### 执行前检查清单

**⚠️ 先澄清再动手**：
- 目标/边界/验收不清楚
- `Clarification Status` 中有 open decision 影响当前动作
- `spec.md` / `design.md` / `work-items/*.yaml` 之间描述不一致
- 需要做产品判断（非纯工程判断）
- 需要修改 `forbidden_paths` 中的文件 → **停止**，范围不允许
- 需要实现 `out_of_scope` 中的功能 → **停止**，超出范围
- 需要修改 frozen contract → **停止**，合约已冻结

**🔄 回看权威文件**：
- 切换 `focus_work_item` → 读 `design.md`
- 触及新模块/接口 → 读 `design.md` + `contracts/*.md`
- 进入 Testing/Deployment → 读 `spec.md` (approved ACC) + `testing.md`
- 测试失败且无法在当前 scope 内修复 → 回看 `work-item.yaml`，可能需要扩大 `allowed_paths`
- 发现 `spec.md`/`design.md`/`testing.md`/`deployment.md` 需要先回写 → **停止**当前任务，先更新权威文件
- 依赖 Work Item 尚未完成，但当前任务需要消费它的结果 → **停止**，等待依赖完成

### 核心原则

1. **先澄清再动手，偏了就停**：目标/边界/约束/风险/验收不清楚先问；范围变更必须说明代价并重新确认；执行中发现方向偏离、连续失败、或复杂度超预期，立即停下重新规划，不硬推。

2. **可验收可追溯**：需求有可判定验收标准（第三方可判 PASS/FAIL）；成功指标给出"基线→目标"；维护场景→需求→实现→验证追溯链。

3. **最小必要变更、始终可回滚**：只改必须改的；垂直切片优先；线上行为变化必须有回滚/开关/灰度方案。

4. **证据驱动、质量闭环**：关键结论附命令/环境/输出；完成前 diff 基线确认变更范围；合入前自测；缺陷立即处理并记录。

5. **安全合规优先**：最小权限、输入校验、密钥不落盘；新依赖需评估必要性与安全性。

6. **第一性原理**：拒绝经验主义和路径盲从，不要假设我完全清楚目标，应保持审慎；若目标模糊请停下和我讨论；若目标清晰但路径非最优，请直接建议路径更优的办法；任务澄清且明确无歧义之后就直接执行。

### Compact Instructions 保留优先级

1. 架构决策，不得摘要
2. 已修改文件和关键变更
3. 验证状态，pass/fail
4. 未解决的 TODO 和回滚笔记
5. 工具输出，可删，只保留 pass/fail 结论

---

## 三、工具参考

### 按阶段的关键 Gate

**Requirements**：
- 必查：`spec-completeness`

**Design**：
- 必查：`design-structure-complete`

**Implementation**：
- 必查：`implementation-ready`
- Hook 兜底：`metadata-consistency`, `scope`, `contract-boundary`

**Testing**：
- 必查：`trace-consistency`, `verification`

**Deployment**：
- 必查：`deployment-readiness`

**使用方法**：`../.codespec/codespec check-gate <gate-name>`

### Gate 快速参考

**组合 Gate**（调用多个原子 gate）：
- `spec-completeness` = proposal-maturity + requirements-approval
- `implementation-ready` = design-structure-complete + implementation-start + implementation-readiness-baseline
- `verification` = 依赖 WI pass 检查 + 当前 WI pass 检查；Testing/Deployment 阶段额外检查 testing-coverage
- `promotion` = metadata-consistency + deployment-readiness + promotion-criteria

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

**提醒**：
- hooks 只做兜底，不替代主动阅读与回看权威文件
- 组合 gate 失败时，可以单独运行原子 gate 定位具体问题
- 所有 gate 都可以通过环境变量覆盖上下文（CODESPEC_PROJECT_ROOT、CODESPEC_FOCUS_WI、CODESPEC_TARGET_PHASE）

### 冲突升级规则

- **同一 concern 内出现冲突**：以后更新且证据更充分的条目为准，并在当前文件补充"为何覆盖"。
- **跨 concern 出现冲突**：不得直接覆盖，必须回写对应权威文件对齐（Spec/Design/Work Item/Testing/Deployment/Contract），必要时暂停并升级决策。
