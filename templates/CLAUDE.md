# Agent Entry

## Hard Rules
- 禁止使用 worktree；默认使用简体中文。
- 需要并行不同 Git 分支时，使用多个独立 clone 目录。
- 先澄清后执行；目标、边界、验收不清楚时先问。
- 最小必要变更；涉及线上行为变化时必须能回滚。
- 证据驱动；结论附命令或输出，完成前先看 diff 和验证结果。
- 偏离即停；方向变了、连续失败或复杂度失控时先回看权威文件。

## File Modification Rules
**IMPORTANT**: Some files should only be modified in the parent feature branch to avoid Git merge conflicts.

Files that should ONLY be modified in parent feature branch:
- `spec.md` - Requirements and acceptance criteria are global
- `design.md` - Architecture design is global
- `work-items/*.yaml` - WI definitions are global
- `contracts/*.md` - Contracts are global
- `deployment.md` - Deployment plan is global

Files that CAN be modified in execution branches:
- `testing.md` - Test evidence ledger, records unit tests and integration tests
- `meta.yaml` - Records current execution context (focus_work_item, execution_branch)
- `src/**` - Business code, developed independently in each branch

**testing.md special notes**:
- Test types (test_type): unit, integration, e2e, performance, security, manual
- Test scope (test_scope): branch-local (execution branch), full-integration (parent feature branch)
- Execution branches record branch-local tests during Implementation (unit, integration, etc.)
- Parent feature branch records full-integration tests during Testing Phase (re-run all test types + e2e/performance/security)
- Each acceptance can have multiple test records covering different test types
- Merge conflicts are expected - keep all test records
- Final acceptance requires at least one test_scope=full-integration and result=PASS record per acceptance

**Workflow**:
1. Modify spec.md, design.md in parent feature branch (main/ directory)
2. Commit and push to remote
3. Execution branches (sanguoA/, sanguoB/) sync via `git pull origin feature/xxx`
4. Execution branches modify src/**, meta.yaml, testing.md (record unit tests)
5. After execution branches complete, merge back to parent feature branch (testing.md may conflict, keep all records)
6. Conduct Testing Phase in parent feature branch, record full integration tests
7. If you try to modify restricted files in execution branch, pre-commit hook will error

## Authority
- `phase-review-policy.md`：阶段切换、gate、严格复审。
- `spec.md`：需求、验收、verification obligations。
- `design.md`：边界、切片、Work Item 派生。
- `work-items/*.yaml`：允许修改范围、禁改范围、依赖。
- `testing.md` / `deployment.md` / `contracts/*.md`：验证、部署、契约。

## Read Route
- 最小 readset：`../../lessons_learned.md` -> `../../phase-review-policy.md` -> 当前入口文件（`AGENTS.md` 或 `CLAUDE.md`，二选一） -> `./meta.yaml` -> `./spec.md`（先读到 `<!-- SKELETON-END -->`）-> `./design.md`（先读 `Default Read Layer`）。
- `AGENTS.md` / `CLAUDE.md` 是兼容性双别名入口：内容应保持等价，读取时只选一个，避免重复上下文。
- 若 `execution_branch != null` 且当前 Git 分支不一致，先确认自己是否进入了错误的 clone 目录或错误分支，再同步上下文。
- 若 `focus_work_item != null`，读取 `./work-items/<focus_work_item>.yaml`。
- 若当前 Work Item 的 `contract_refs` 非空，读取对应 `./contracts/*.md`。
- `testing.md` 记录集成测试结果（验证 acceptance 是否满足）。
- Testing 额外读取 `./testing.md` 和 `./work-items/*.yaml`；Deployment / Promotion 额外读取 `./testing.md` 和 `./deployment.md`。
- `active_work_items` 是 branch execution set，也是进入 Testing 前 verification 的聚合集合。
- 默认层不足以解释任务时，才下钻 `./spec-appendices/` 或 `./design-appendices/`。
- 不要同时读取 `AGENTS.md` 和 `CLAUDE.md`。

## Reread
- 回看 `spec.md`：目标、边界、acceptance、verification obligations 可能变化；或进入 Testing / Deployment 前。
- 回看 `design.md`：切换 `focus_work_item`、触及新模块或接口、切片划分失效。
- 回看 `testing.md`：确认 pass record 或 residual risk。
- 回看 `deployment.md`：进入 Deployment / Promotion，或需要判断回滚、监控、上线后动作。

## Compact
1. 架构决策
2. 已修改文件和关键变更
3. 验证状态：pass / fail
4. 未解决 TODO 和回滚笔记
