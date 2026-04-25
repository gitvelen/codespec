# Phase Review Policy

阶段切换前先做走查，再通过标准 runtime 入口执行命令；不要手改 `meta.yaml` 推进 phase 或切换 `focus_work_item`。标准入口解析顺序：先尝试 `codespec <cmd>`；若当前 shell 不可调用，再尝试工作区 runtime（常见布局：`../.codespec/codespec <cmd>`）；若两者都不可用，停止并报告 runtime not found。`check-gate` 是最低硬门槛，不替代语义审查；需要严格闭环时，使用 `rfr` skill 并以本文件为准。**check-gate pass 仍不等于允许切换**，phase 推进必须同时满足本文件中的人工审查结论。注意：当前 runtime 只对 Design 和 Implementation 阶段强制检查 review verdict artifact（`design-review.yaml` / `implementation-review.yaml`）的存在性；但 artifact 存在不等于审查质量、组织批准或 reviewer judgment 已自动成立。

本文件按三层理解：
- `必须通过`：runtime / hooks 会执行的最低机器门槛。
- `必须确认`：reviewer 或 `rfr` 必须完成的语义审查。
- `禁止切换`：即使 gate 已通过，也不能推进的阻塞条件。

## 使用方式
- 先定位当前 `./meta.yaml` 中的 `phase`、`status`、`focus_work_item`、`execution_branch`。
- 先读当前 dossier 的 agent 入口文件（`AGENTS.md` 或 `CLAUDE.md`，根据使用的 agent 选择），再读本 phase 对应的权威文件。
- 每次 phase 切换前都要给出一个结论：`允许切换`、`有条件允许切换`、`禁止切换`。
- 只有 gate 通过且人工走查未发现阻塞项，才允许执行 `codespec start-*`、`deploy`、`reopen-implementation`、`complete-change` 或 `promote-version`。

## Requirement -> Design
必须读取：
- `./spec.md`

必须确认：
- `spec.md` 结构完整，至少包含 `Summary`、`Inputs`、`Scope`、`Requirements`、`Acceptance`、`Verification`。
- `source_owner`、`approval_basis`、`source_refs`、`normalization_note` 不是 placeholder。
- `maturity` 使用合法枚举值。
- 至少有一组真实 `REQ-*`、`ACC-*`、`VO-*`。
- 每个 `REQ` 都有 `source_ref` 追溯到 `Inputs`，都有 acceptance 映射，每个 `ACC` 都有 verification 映射。
- appendix 没有私自定义正式 `REQ/ACC/VO`。
- acceptance 可观测、可判 PASS/FAIL，verification 描述了证据形状而不是"以后补"。
- Requirement 阶段只允许 authority 文档与输入沉淀类改动；当前粗粒度 runtime/hook 只会硬拦最明显的实现产物（`src/**`、`Dockerfile`），其他越阶段实现仍需 reviewer 明确阻止。
- 进入 Design 前，当前 Requirement 审查结论必须以 `./reviews/design-review.yaml` 落盘，并至少包含 `phase: Requirement`、`verdict: approved`、`reviewed_by`、`reviewed_at`。

**首次使用说明**：
- `init-dossier.sh` 不会自动生成 `design-review.yaml`，必须手工创建
- 示例格式：
  ```yaml
  phase: Requirement
  verdict: approved
  reviewed_by: <your-name>
  reviewed_at: <YYYY-MM-DD>
  ```

必须通过：
- `./.codespec/codespec check-gate requirement-complete`

禁止切换：
- 输入仍是模板占位。
- acceptance 不可测或语义过大。
- verification 义务无法指导后续 testing。
- 需要靠 appendix 才能知道正式要求编号。

## Design -> Implementation
必须读取：
- `./design.md`
- `./spec.md`
- `./work-items/<WI>.yaml`
- `./contracts/*.md`（若当前 WI 使用）

必须确认：
- `design.md` 的 `Summary`、`Technical Approach`、`Boundaries & Impacted Surfaces`、`Execution Model`、`Work Item Mapping`、`Work Item Derivation`、`Verification Design`、`Reopen Triggers` 完整。
- 至少存在一个真实 `WI-*` 派生项。
- 若计划并行执行，`Execution Model` 与 `work-items/*.yaml` 已明确每条执行线的 execution_branch、owned_paths、shared_paths、shared_file_owner、merge_order 和 conflict_policy（这些字段仅用于文档化和人工审查，只有 allowed_paths/forbidden_paths 由 runtime 强制）。execution_group 非 null 表示多分支并行模式，此时 gate 会检查 owned_paths 非空。
- 当前 WI 的 `goal`、`input_refs`、`requirement_refs`、`acceptance_refs`、`verification_refs`、`allowed_paths`、`derived_from` 完整且非 placeholder。
- 当前 WI 的 `branch_execution` 与 `design.md` 的并行分支计划一致；共享文件已有唯一 owner 或父 feature 分支集成策略。
- 当前 WI 与 `design.md` 中同名 derivation row 的 input / requirement / acceptance / verification refs 完全一致。
- 当前 WI 引用的 `REQ/ACC/VO` 都存在于 `spec.md`。
- 当前 WI 的 `input_refs` 能在 spec source coverage 中找到落点。
- 若 `contract_refs` 非空，对应 contract 文件存在且已 `status: frozen`。
- 若需要新增 shared contract，先以 `status: draft` 建档并完成显式 review，再冻结为 `status: frozen` 后被当前 WI 引用；不要直接新增 frozen contract。
- 若存在依赖 WI，依赖项已有 pass record。

必须通过：
- `./.codespec/codespec check-gate design-structure-complete`
- `./.codespec/codespec check-gate implementation-ready`（包含 design-structure-complete + implementation-start + implementation-readiness-baseline）

禁止切换：
- work item 仍不可执行。
- design 和 work item 追溯不一致。
- contract 边界未冻结或缺失。
- required verification 不能支撑当前 WI 完成判定。

## Implementation 阶段要求（进入 Testing 前）
必须读取：
- `./meta.yaml`
- `./work-items/<focus_work_item>.yaml`（Implementation 阶段）
- `./work-items/*.yaml`（Testing 阶段，读取所有 work items）
- `./design.md`
- `./testing.md`（它是当前项目 / 当前执行线的验证证据账本，不是 Testing 阶段才首次填写；多个独立 clone 不共享 pass records）

必须确认（Implementation 阶段）：
- `focus_work_item` 非空且存在于 `active_work_items`。
- `active_work_items` 表示按 design 建议或人工维护的 branch execution set；runtime 会把它作为进入 Testing 前 verification 的聚合集合，但不提供完整的多 WI union scope/boundary enforcement。
- `feature_branch`、`execution_group`、`execution_branch` 以 `meta.yaml` 为运行态真相；不要手改，统一通过 `codespec set-execution-context ...` 写入。
- pre-commit 会校验当前 git branch 与 `execution_branch` / `feature_branch` 的对齐关系；如果当前分支是并行执行分支（`execution_group != null` 且当前分支不等于 `feature_branch`），则 `spec.md`、`design.md`、`work-items/`、`contracts/`、`deployment.md` 只能在父 feature 分支修改。
- staged 改动全部在 `allowed_paths` 内，且未命中 `forbidden_paths`（由 scope gate 强制）。
- `start-testing` 会基于 `implementation_base_revision` 重新检查整个 Implementation 回路的累计变更，不只是当前 staged diff。
- staged 改动没有越过 `branch_execution.owned_paths`；命中 `shared_paths` 时已遵守 `shared_file_owner` / `conflict_policy`（人工审查，不由 runtime 强制；原因：需要跨分支信息，超出单分支 gate 的能力范围；审查方式：在 PR review 或 merge 前，手动对比当前改动与其他执行分支的 work-item.yaml，确认文件所有权和冲突策略）。
- 没有修改 frozen contract；若 contract 进入 `status: frozen`，必须同时提供 `freeze_review_ref` 指向已批准的冻结审查记录。
- 当前 active work items（按 design 建议或人工维护的 branch execution set，也是进入 Testing 前 verification 的聚合集合）的 approved acceptance 在 `testing.md` 中都有 record 且最新匹配记录为 pass（Implementation 阶段允许 test_scope=branch-local，Testing/Deployment 阶段要求 test_scope=full-integration）。
- 当前实现仍能被 `spec.md`、`design.md`、当前 WI 合法解释，没有隐性扩 scope。

必须确认（Testing 阶段）：
- `focus_work_item` 为 null（start-testing 会清空）。
- `active_work_items` 保留 Implementation 阶段的值（start-testing 不清空），用于 verification gate 聚合所有需要验证的 work items。
- `execution_group` / `execution_branch` 被清空（start-testing 会清空）。

必须确认（Completed 状态）：
- `phase = Deployment` 且 `status = completed`。
- `focus_work_item = null`。
- 当前项目目录中的 completed dossier 满足 `active_work_items = []`；它不再表示“活跃验证集合”，但必须仍可重跑 `verification` / `promotion-criteria` 进行验真。
- `versions/<stable_version>/meta.yaml` 保留 complete-change 时的 `active_work_items` 快照，用于版本追溯和 completed reopen 恢复。

### Testing 字段定义

**测试结果（result）**：
- `pass`: 测试通过，acceptance 得到验证
- `fail`: 测试失败，需要修复实现或重新开启 spec/design

**残留风险（residual_risk）**：
- `none`: 无残留风险
- `low`: 低风险，可接受的小问题
- `medium`: 中等风险，需要监控
- `high`: 高风险，需要立即处理或重新开启 spec/design

**重新开启标记（reopen_required）**：
- `true`: 需要重新开启 spec/design 进行调整
- `false`: 不需要重新开启

必须通过：
- `./.codespec/codespec check-gate metadata-consistency`
- `./.codespec/codespec check-gate scope`
- `./.codespec/codespec check-gate contract-boundary`
- `./.codespec/codespec check-gate verification`

禁止切换：
- 改动越出当前 WI 边界。
- 依赖或当前 acceptance 没有 pass record。
- frozen contract 被直接修改。
- design / spec 已经解释不了当前实现。

## Testing -> Deployment
必须读取：
- `./meta.yaml`
- `./spec.md`
- `./design.md`
- `./work-items/*.yaml`
- `./testing.md`（继续作为全量 approved acceptance 的验证证据账本）
- `REQ -> ACC -> VO` 链路完整，且每个 `REQ/ACC/VO` 都被至少一个 work item 引用。
- 每个 input ref 都在 requirements closure 中有落点。
- 每个 approved acceptance 在 `testing.md` 中都有 record 和 pass 结果。
- 每条 testing 记录都提供真实 `artifact_ref`，不是 placeholder。
- `verification_type` 与 acceptance priority 匹配：`P0` 必须 automated；`P1/P2` 只能 automated/manual/equivalent。
- `residual_risk` 与 `reopen_required` 已经被认真填写。
- 同一 acceptance 若有多条 testing 记录，以最后一条匹配记录为权威结果；later fail 会推翻 earlier pass。

必须通过：
- `./.codespec/codespec check-gate trace-consistency`（检查追溯链完整性和测试记录存在性，不检查 test_scope）
- `./.codespec/codespec check-gate verification`（包含 testing-coverage，检查 full-integration pass 记录和 verification_type 要求）

禁止切换：
- 任一 approved acceptance 没有 pass record。
- `P0` 只靠 manual/equivalent。
- artifact 无法让第三方复核。
- `reopen_required: true` 仍试图推进 Deployment。

## Deployment -> Completed / Promotion
必须读取：
- `./deployment.md`
- `./testing.md`
- `./meta.yaml`

必须确认：
- `start-deployment` 只表示进入 Deployment 阶段，并在缺少 `deployment.md` 时自动 materialize 工作载体；不等于 deployment readiness 已达成。
- `codespec deploy` 才表示真实部署已执行；它会调用项目内 `scripts/codespec-deploy`，并把结果回写到 `deployment.md` 的 `Execution Evidence` 与 `Verification Results`。
- `deployment.md` 已 materialize，并包含 `Deployment Plan`、`Pre-deployment Checklist`、`Deployment Steps`、`Execution Evidence`、`Verification Results`、`Acceptance Conclusion`、`Rollback Plan`、`Monitoring`、`Post-deployment Actions`。
- `deployment_date` 与 `target_env` 合法。
- `Execution Evidence.status = pass`，且 `execution_ref`、`deployment_method`、`deployed_at`、`deployed_revision`、`restart_required`、`restart_reason`、`runtime_observed_revision`、`runtime_ready_evidence` 全部可复核。
- `smoke_test: pass`、`runtime_ready: pass`、`manual_verification_ready: pass`。
- `deployed_revision = runtime_observed_revision`，证明当前运行实例已加载本次部署的新版本。
- 若 `restart_required: yes`，`runtime_ready_evidence` 必须同时证明重启/rollout 已完成；若 `restart_required: no`，理由必须能解释为什么当前部署方式已天然完成热更新/滚动替换。
- `manual_verification_ready: pass` 只表示“可以开始人工验收”；人工验收失败时，应使用 `reopen-implementation <WI-ID>` 返回同一 change 的修复回路，而不是 reset 成新 change。
- `reopen-implementation <WI-ID>` 不会新建 change，`change_id` 保持不变；`testing.md` 继续作为证据账本追加记录。
- 只有用户显式确认人工验收通过后，才能把 `Acceptance Conclusion.status` 设为 `pass`，并填写 `approved_by` / `approved_at`。
- 再次执行 `codespec deploy` 会用最新部署结果覆盖 `Execution Evidence` / `Verification Results`，并把 `Acceptance Conclusion` 重置为 `pending`。
- `complete-change <stable-version>` 会同时完成两件事：把当前 dossier 置为 completed，并归档到 `versions/<stable-version>/`；当前 dossier 清空 `active_work_items`，归档快照保留 promotion 时的 `active_work_items`。
- 文档中没有任何模板占位。
- rollback plan 与 monitoring 能覆盖本次变更的主要失败模式。
- 若要 complete-change / promotion，`versions/` 目录存在且允许归档。

必须通过：
- `./.codespec/codespec check-gate trace-consistency`（start-deployment 时检查）
- `./.codespec/codespec check-gate verification`（start-deployment 时检查）
- `./.codespec/codespec check-gate deployment-readiness`（执行 `deploy` 后应通过，表示已达到人工验收就绪）
- `./.codespec/codespec check-gate promotion-criteria`（执行 `complete-change <stable-version>` 时检查；内部会重新执行 `trace-consistency`）
- `./.codespec/codespec check-gate promotion`（执行 `promote-version <stable-version>` 兼容别名时检查）

禁止切换：
- deployment.md 仍是模板。
- smoke / deployment verification 没有真实通过证据。
- 尚未确认当前服务跑的是新代码，却试图把验证交给人工。
- 需要重启却未完成重启确认，或不需要重启的理由站不住脚。
- 人工验收尚未明确通过，却试图执行 `complete-change <stable-version>`。
- rollback 或 monitoring 只是形式条目。
- promotion 证据不足却尝试归档稳定版本。

## 命令映射
- `start-design` -> `requirement-complete` + `review-verdict-present`（要求 reviews/design-review.yaml 存在且 phase=Requirement, verdict=approved）
- `start-implementation` -> `implementation-ready` + `review-verdict-present`（从 `Design` 进入 `Implementation`，或在 `Implementation` 内切换 `focus_work_item`；要求 reviews/implementation-review.yaml 存在且 phase=Design, verdict=approved）
- `set-execution-context single <feature-branch>` -> 单分支模式；要求当前 git branch 与 `feature_branch` 一致
- `set-execution-context parallel <feature-branch> <execution-group>` -> 并行模式；把当前 git branch 写入 `execution_branch`
- `reopen-implementation` -> Testing / Deployment -> Implementation（不新建 change，用于失败验收后的返工）
- `start-testing` -> `metadata-consistency` + `scope`(Implementation span) + `contract-boundary`(Implementation span) + `verification`
- `start-deployment` -> `trace-consistency` + `verification`，并在缺少 `deployment.md` 时自动 materialize
- `deploy` -> 调用 `scripts/codespec-deploy` 并更新 `deployment.md`
- `complete-change <stable-version>` -> `promotion-criteria`（含 `trace-consistency`），并归档稳定版本
- `promote-version <stable-version>` -> `promotion`（兼容别名）
