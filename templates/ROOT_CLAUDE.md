# Agent Entry

## Hard Rules
- 禁止使用 worktree；默认使用简体中文。
- 需要并行不同 Git 分支时，使用多个独立 clone 目录；不要把同一仓库副本里的不同 container 当成不同分支承载点。
- 先澄清后执行；目标、边界、验收不清楚时先问。
- 最小必要变更；涉及线上行为变化时必须能回滚。
- 证据驱动；结论附命令或输出，完成前先看 diff 和验证结果。
- 偏离即停；方向变了、连续失败或复杂度失控时先回看权威文件。

## 这是根目录导航入口，不是 dossier 执行入口
- 先选择 container，再进入 `change/<container>/` 作为当前工作上下文。
- 单 container 项目可以直接在项目根运行 `codespec status` / `codespec readset`，runtime 会自动解析当前 container。
- 多 container 项目必须先设置 `CODESPEC_CONTAINER`，或直接进入 `change/<container>/` 后再执行命令。
- 真正执行前，读取 `change/<container>/AGENTS.md` 或 `change/<container>/CLAUDE.md` 之一，不要把根目录入口当成 dossier authority。

## Root Navigation
- 用 `./.codespec/codespec status` 查看当前 phase、focus work item、branch 对齐状态。
- 用 `./.codespec/codespec readset` 或 `readset --json` 获取当前 container 的最小阅读集。
- 若当前项目有多个 container 且你在项目根目录，先设置 `CODESPEC_CONTAINER=__CONTAINER__`，或进入对应 `change/<container>/`。
- 若要新增独立变更，使用 `./.codespec/codespec init-change <container> [change_id] [base_version]`。
- 若要从 baseline / source container 派生执行线，使用 `./.codespec/codespec add-container <container> [source-container]`。

## Authority Routing
- 根目录 `phase-review-policy.md`：阶段切换规则、最低 gate 与严格复审口径。
- `change/<container>/spec.md`：需求、验收、verification obligations。
- `change/<container>/design.md`：边界、切片、Work Item 派生。
- `change/<container>/work-items/*.yaml`：允许修改范围、禁改范围、依赖。
- `change/<container>/testing.md` / `deployment.md` / `contracts/*.md`：验证、部署、契约。

## Compact
1. 架构决策
2. 已修改文件和关键变更
3. 验证状态：pass / fail
4. 未解决 TODO 和回滚笔记
