# Agent Entry (Workspace Root)

## Hard Rules
- 禁止使用 worktree；默认使用简体中文。
- 需要并行不同 Git 分支时，使用多个独立 clone 目录。
- 先澄清后执行；目标、边界、验收不清楚时先问。
- 最小必要变更；涉及线上行为变化时必须能回滚。
- 证据驱动；结论附命令或输出，完成前先看 diff 和验证结果。
- 偏离即停；方向变了、连续失败或复杂度失控时先回看权威文件。

## 这是工作区根目录导航入口，不是项目执行入口
- 工作区（workspace）包含共享资源：`.codespec/`, `lessons_learned.md`, `phase-review-policy.md`, `versions/`
- 项目（project）是独立的 Git clone，包含 dossier 文件：`spec.md`, `design.md`, `meta.yaml`, `work-items/` 等
- 真正执行前，进入项目目录并读取 `AGENTS.md` 或 `CLAUDE.md` 之一，不要把工作区根目录入口当成 dossier authority

## Workspace Navigation
- 工作区结构：
  ```
  workspace/
  ├── .codespec/           # 共享 runtime
  ├── lessons_learned.md   # 共享经验教训
  ├── phase-review-policy.md  # 共享审查策略
  ├── versions/            # 共享版本快照
  ├── main/                # Git clone（项目 1）
  │   ├── spec.md
  │   ├── design.md
  │   └── src/
  └── projectB/            # Git clone（项目 2，可选）
  ```

- 查看项目状态：进入项目目录后运行 `codespec status`
- 获取阅读集：进入项目目录后运行 `codespec readset`
- 初始化新项目：
  1. `cd workspace/`
  2. `git clone <REPO_URL> project-name` 或 `git init project-name`
  3. `cd project-name`
  4. `../codespec/scripts/init-dossier.sh`

## Authority Routing
- 工作区级：
  - `lessons_learned.md`：跨项目共享的经验教训
  - `phase-review-policy.md`：阶段切换规则、最低 gate 与严格复审口径
  - `versions/`：已发布版本快照
- 项目级（进入项目目录后）：
  - `spec.md`：需求、验收、verification obligations
  - `design.md`：边界、切片、Work Item 派生
  - `work-items/*.yaml`：允许修改范围、禁改范围、依赖
  - `testing.md` / `deployment.md` / `contracts/*.md`：验证、部署、契约
  - `AGENTS.md` / `CLAUDE.md`：项目级 agent 入口（二选一）

## Compact
1. 架构决策
2. 已修改文件和关键变更
3. 验证状态：pass / fail
4. 未解决 TODO 和回滚笔记
