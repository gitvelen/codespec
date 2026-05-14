# Codespec

基于阶段门控（Phase-Gate）的软件开发流程管理框架。通过结构化文档和自动化检查，确保每个阶段的工作质量达标后才能进入下一阶段。

说明：本仓库根目录是框架源码仓，不是一个已初始化的业务 dossier。业务项目的
`spec.md`、`design.md`、`testing.md`、`deployment.md`、`meta.yaml` 应只出现在
执行 `init-dossier.sh` 之后的项目目录里，模板则统一位于 `templates/`。

## 设计理念

**问题**：软件开发中常见的质量问题：
- 需求不清晰就开始编码
- 设计不完整就开始实现
- 测试不充分就上线部署

**解决方案**：Phase-Gate 机制
- 每个阶段有明确的**交付物**（文档）
- 每个阶段转换前执行**门控检查**（gate）
- 检查不通过，无法进入下一阶段

## 核心概念

### 阶段（Phase）

项目生命周期分为 5 个阶段，必须按顺序推进：

```
Requirement → Design → Implementation → Testing → Deployment
```

每个阶段的职责：
- **Requirement**: 在 spec.md 中记录需求（REQ-*）、验收标准（ACC-*）、验证方法（VO-*）
- **Design**: 在 design.md 中完成架构设计，拆解实现切片（SLICE-001, SLICE-002...）
- **Implementation**: 编写代码实现设计
- **Testing**: 在 testing.md 中记录测试执行和结果
- **Deployment**: 在 deployment.md 中记录发布对象、部署步骤、运行验证和人工验收

完成 Deployment 阶段后，可执行 `codespec complete-change <version>` 将 status 设为 completed，表示整个变更已完成并归档；如果当前在非默认分支且要直接进入交付评审，推荐使用 `codespec submit-pr <version>` 作为一键交接入口。

### 实现切片（Slice）

设计阶段将需求拆解为独立的实现切片（SLICE-001, SLICE-002...），在 design.md §7 中定义：
- 明确的实现目标和验收标准
- 依赖关系声明
- 可修改和不可修改的文件范围（design.md §4）
- 关联的测试覆盖

### 门控检查（Gate）

阶段转换命令（如 `codespec start-design`）会自动执行门控检查，确保：
- **文档完整性**：必填字段存在，占位符已清理
- **逻辑一致性**：依赖关系正确，测试覆盖完整
- **流程合规性**：审查已通过，验证已完成

检查失败会阻止阶段转换，并给出明确的错误信息。

## 快速开始

### 场景 1：新项目（从零开始）

#### 步骤 1：安装框架

```bash
# 克隆框架仓库
git clone <codespec-repo-url> /path/to/codespec-framework
cd /path/to/codespec-framework

# 创建工作区和项目
./scripts/quick-start.sh /path/to/workspace

# 进入项目目录（默认名称为 main，可自定义）
cd /path/to/workspace/main
```

安装后的工作区结构：
```
workspace/
├── .codespec/              # 框架运行时（共享）
│   ├── codespec           # 主程序
│   ├── scripts/           # 检查脚本
│   └── templates/         # 文档模板
├── lessons_learned.md      # 工作区级别的经验总结
├── phase-review-policy.md  # 审查规则
└── main/                   # 项目目录（可自定义名称）
    ├── spec.md            # 需求规格（init-dossier 时创建）
    ├── design.md          # 设计文档（init-dossier 时创建）
    ├── testing.md         # 测试记录（init-dossier 时创建）
    ├── meta.yaml          # 项目元数据（init-dossier 时创建）
    ├── CLAUDE.md          # AI 指令（init-dossier 时创建）
    └── AGENTS.md          # Agent 指令（init-dossier 时创建）
```

注意：
- `.claude/` 目录由 AI 工具自动创建，不在 init-dossier 范围内
- `deployment.md` 在执行 `codespec start-deployment` 时创建

#### 命令入口约定

在项目目录执行阶段命令时，优先使用 `codespec <cmd>`。如果当前 shell 找不到 `codespec`，则改用工作区 runtime（常见布局：`../.codespec/codespec <cmd>`）。如果两者都不可用，先修复 runtime 安装；不要手改 `meta.yaml` 推进阶段。

对 `init-dossier.sh`、`install-hooks.sh` 这类脚本也是同一个原则：脚本路径可以写成
`../.codespec/scripts/...` 或绝对路径，但**执行前当前目录必须是项目目录**，不要先
`cd` 到 `.codespec/scripts/` 再直接运行 `./init-dossier.sh`。

#### 步骤 2：启动 AI 助手，开始协作

```bash
# 在项目目录中启动 Claude/Codex
# 简单告诉 AI 你的需求：

"我想开发一个用户登录功能"
```

**AI 会协助**：
- 读取 `meta.yaml`（知道当前在 Requirement 阶段）
- 读取 `CLAUDE.md`/`AGENTS.md`（知道该做什么）
- 读取 `spec.md` 模板
- 根据你的需求填写 `需求概览`、`决策与来源`、`场景、流程与运行叙事`、`需求与验收`、`运行约束`
- 完成后告诉你审查

**你需要做什么**：
- 审查 AI 填写的内容
- 确认需求理解正确
- 如果有问题，直接说"XXX 不对，应该是 YYY"
- 如果没问题，说"可以，继续"

#### 步骤 3：推进到 Design 阶段

```bash
# 简单告诉 AI：

"继续推进到 Design 阶段"
```

**AI 会协助**：
- 根据你的反馈继续补齐 `spec.md`
- 提醒你在确认 Requirement 后记录 `reviews/design-review.yaml`
- 在你确认审查记录已落盘后执行 `codespec start-design`
- 在 design.md 中完成架构设计和实现切片拆解
- 完成后告诉你审查

**你需要做什么**：
- 审查需求是否完整
- 确认后记录 `reviews/design-review.yaml`
- 审查架构设计是否合理
- 确认实现切片拆解是否合适
- 如果有问题，告诉 AI 调整

#### 步骤 4：推进到 Implementation 阶段

```bash
# 简单告诉 AI：

"开始实现"
```

**AI 会协助**：
- 提醒你在确认 Design 后记录 `reviews/implementation-review.yaml`
- 在你确认审查记录已落盘后执行 `codespec start-implementation`
- 编写代码实现设计
- 完成后告诉你测试

**你需要做什么**：
- 审查设计并记录 `reviews/implementation-review.yaml`
- 测试功能是否正常
- 如果有问题，告诉 AI 修复

#### 步骤 5：推进到 Testing 和 Deployment

```bash
# 简单告诉 AI：

"继续测试和部署"
```

**AI 会协助**：
- 提醒你在确认 Implementation 后记录 `reviews/testing-review.yaml`
- 在你确认审查记录已落盘后执行 `codespec start-testing`，按整个 Implementation span 重查 scope / contract / verification
- 运行测试，在 testing.md 中记录结果
- 执行 `codespec start-deployment`
- 补齐 deployment.md 中的发布计划、日期、发布前条件、回滚与监控后，执行 `codespec deploy`
- 在 deployment.md 中记录部署证据并通知你开始手工验收
- 若你显式确认通过，先单独提交人工验收结论；随后可执行 `codespec submit-pr <stable-version>` 一次性完成 `complete-change`、push 和建 PR
- 完成后告诉你验收

**你需要做什么**：
- 审查实现并记录 `reviews/testing-review.yaml`
- 验收最终结果
- 确认部署成功

---

### 场景 2：存量项目（引入框架）

先判断自己属于哪一种：
- **首次接入**：项目里还没有 `spec.md`、`design.md`、`meta.yaml`
- **旧版升级**：项目已经有 dossier，只是要升级 `.codespec` runtime / 模板 / hooks

新版标准入口只有四类：
- 安装或升级 workspace runtime：`scripts/install-workspace.sh <workspace_root>`
- 初始化项目 dossier：`<workspace_root>/.codespec/scripts/init-dossier.sh`
- 重大版本迁移已有 dossier：`<workspace_root>/.codespec/scripts/migrate-to-requirement-phase.sh <project_root>`
- 日常推进阶段：`codespec <cmd>`；如果 `codespec` 不在 PATH，就改用 `<workspace_root>/.codespec/codespec <cmd>`

`codespec install` 已在 v2 移除，不再使用。历史上的“专用 workspace + 软链”只算兼容做法，不是默认路径。

#### 场景 2A：首次接入存量项目

先在项目的父目录安装 workspace runtime，再回到项目目录初始化 dossier。

```bash
# 假设你的存量项目在 /path/to/workspace/existing-project
cd /path/to/workspace/existing-project

# 克隆框架仓库到临时目录
git clone <codespec-repo-url> /tmp/codespec-framework

# 在项目父目录安装共享 runtime
/tmp/codespec-framework/scripts/install-workspace.sh ..

# 回到项目目录，初始化 dossier
../.codespec/scripts/init-dossier.sh
```

执行 `init-dossier.sh` 前，先确认当前目录真的是“项目根目录”：

```bash
pwd
git rev-parse --show-toplevel
```

如果第二条命令返回的是外层大仓库，而不是你当前这个项目目录，`init-dossier.sh`
会把那个外层仓库当成项目根；这时不要继续执行，先切到真正的项目根目录。

安装后会得到两层结构：
- `../.codespec/`
- `../lessons_learned.md`
- `../phase-review-policy.md`
- `../versions/`（旧版/兼容归档位置；新的 completed dossier 默认归档到项目内 `versions/`）
- 当前项目内新增 `spec.md`、`design.md`、`testing.md`、`meta.yaml`、`CLAUDE.md`、`AGENTS.md` 等 dossier 文件

注意：`deployment.md` 在执行 `codespec start-deployment` 时创建，不在 init-dossier 范围内。

现有项目保持原地不动，不需要 `mv`，也不需要软链。

然后启动 AI，让它先补齐存量系统文档：

```bash
# 在项目目录告诉 AI
"这是一个存量项目，请帮我补充 Codespec 文档"
```

#### `/home/admin/estimate` 对应的首次接入示例

```bash
# 如果当初 requirement-estimation 还没接入 Codespec，应这样做：
cd /home/admin/estimate/requirement-estimation
git clone <codespec-repo-url> /tmp/codespec-framework
/tmp/codespec-framework/scripts/install-workspace.sh /home/admin/estimate
cd /home/admin/estimate/requirement-estimation
/home/admin/estimate/.codespec/scripts/init-dossier.sh
```

#### 场景 2B：已接入项目升级到新框架

如果项目已经有 `meta.yaml`，说明 dossier 已存在。此时要区分两层：
- workspace 层：`/path/to/workspace/.codespec/` 下的 runtime、模板、hooks 脚本
- project 层：`/path/to/workspace/existing-project/` 下已有的 `spec.md`、`design.md`、`meta.yaml`、`reviews/` 等 dossier 内容

升级时只会自动刷新 workspace 层，不会自动重建或覆盖 project 层已有 dossier。
也就是说，`/path/to/workspace/.codespec/` 是一份安装出来的本地副本，不会随着框架仓库自动同步；每次框架升级，都需要重新执行一次 `install-workspace.sh`。

```bash
# 仍然假设项目在 /path/to/workspace/existing-project
cd /path/to/workspace/existing-project

# 1) 用新版框架覆盖刷新 workspace runtime
git clone <codespec-repo-url> /tmp/codespec-framework
/tmp/codespec-framework/scripts/install-workspace.sh ..

# 2) 给已接入项目补装/刷新 hooks
../.codespec/scripts/install-hooks.sh .

# 3) 如果项目仍处于旧阶段模型（Proposal/Requirements），执行迁移
../.codespec/scripts/migrate-to-requirement-phase.sh .

# 4) 检查当前状态
../.codespec/codespec status
```

关键点：
- **不要**对已有 `meta.yaml` 的项目再次执行 `init-dossier.sh`，否则会报 `dossier already initialized`
- 升级后继续使用现有 `spec.md`、`design.md`、`meta.yaml`，不需要重建 dossier
- `install-workspace.sh` 更新的是 `../.codespec/`、`../versions/`、`../phase-review-policy.md`、`../lessons_learned.md`
- 如果既有 `phase-review-policy.md` 与新模板不同，`install-workspace.sh` 会先备份为 `phase-review-policy.md.bak.<timestamp>`，再刷新为新版策略
- `install-hooks.sh` 更新的是当前 Git 项目的 hooks
- `migrate-to-requirement-phase.sh` 只处理旧阶段模型迁移：`Proposal/Requirements -> Requirement`，并把 `reviews/requirements-review.yaml` 迁到 `reviews/design-review.yaml`
- 但如果框架有重大升级，project 层文档仍需要人工对齐新模板，尤其是 `spec.md`、`meta.yaml`、`reviews/*.yaml`
- 如果仓库里有全局 `*.md` 忽略规则，记得为 `spec.md`、`design.md`、`testing.md`、`AGENTS.md`、`CLAUDE.md` 加例外，否则 dossier 文档不会进入版本控制

#### `/home/admin/velentrade` 对应的升级示例

假设：
- workspace root 是 `/home/admin/velentrade`
- 已接入项目是 `/home/admin/velentrade/main`

那么升级步骤应当是：

```bash
git clone <codespec-repo-url> /tmp/codespec-framework

# 1) 刷新 workspace runtime 和模板
/tmp/codespec-framework/scripts/install-workspace.sh /home/admin/velentrade

# 2) 刷新 main 这个项目的 hooks
/home/admin/velentrade/.codespec/scripts/install-hooks.sh /home/admin/velentrade/main

# 3) 如 main 仍是旧阶段模型，执行迁移
/home/admin/velentrade/.codespec/scripts/migrate-to-requirement-phase.sh /home/admin/velentrade/main

# 4) 回到项目目录核对状态
cd /home/admin/velentrade/main
/home/admin/velentrade/.codespec/codespec status
```

对于 `main` 目录，要特别注意：
- 不要站在 `/home/admin/velentrade/.codespec/scripts` 里直接跑 `./init-dossier.sh`
- 不要以为 `install-workspace.sh` 会自动覆盖 `main/spec.md`、`main/design.md`、`main/testing.md`
- 如果这次框架升级涉及 dossier schema 变化，`main` 里的 `spec.md` 和 `meta.yaml` 需要按新模板人工整理

一个最小验证组合是：

```bash
cd /home/admin/velentrade/main
/home/admin/velentrade/.codespec/codespec check-gate requirement-complete
/home/admin/velentrade/.codespec/codespec gate-sequence start-design
/home/admin/velentrade/.codespec/codespec status
```

如果这三条都能正常工作，再继续执行 `start-design`。

#### `/home/admin/estimate` 对应的升级示例

`/home/admin/estimate` 现在已经是这种状态：
- `/home/admin/estimate` 是 workspace root，因为它已经有 `.codespec/`、`versions/`、`lessons_learned.md`、`phase-review-policy.md`
- `/home/admin/estimate/requirement-estimation` 是已初始化项目，因为它已经有 `spec.md`、`design.md`、`meta.yaml`

所以这个例子更适合演示升级：

```bash
git clone <codespec-repo-url> /tmp/codespec-framework
/tmp/codespec-framework/scripts/install-workspace.sh /home/admin/estimate
cd /home/admin/estimate/requirement-estimation
/home/admin/estimate/.codespec/scripts/install-hooks.sh .
/home/admin/estimate/.codespec/scripts/migrate-to-requirement-phase.sh .
```

升级后继续在项目目录使用标准命令入口：

```bash
cd /home/admin/estimate/requirement-estimation
codespec status

# 如果 codespec 不在 PATH
/home/admin/estimate/.codespec/codespec status
```

#### 安装或升级后如何验证

至少检查这几件事：
- workspace 下存在 `.codespec/`、`versions/`、`lessons_learned.md`、`phase-review-policy.md`
- 首次接入的项目下存在 `spec.md`、`design.md`、`testing.md`、`meta.yaml`
- 已接入项目可以正常执行 `codespec status`，或用 workspace runtime 执行 `.../.codespec/codespec status`
- 如果项目仍在 Requirement 阶段，可以用 `gate-sequence start-design` 查看进入 Design 所需 gate
- 如果项目是 Git 仓库，`.git/hooks/pre-commit` 和 `.git/hooks/pre-push` 已安装

验证命令示例：

```bash
cd /home/admin/estimate/requirement-estimation
ls ../.codespec ../versions ../lessons_learned.md ../phase-review-policy.md
ls spec.md design.md testing.md meta.yaml
codespec status || /home/admin/estimate/.codespec/codespec status
```

如果项目还没升到 Design，可以再补两条：

```bash
/home/admin/estimate/.codespec/codespec check-gate requirement-complete
/home/admin/estimate/.codespec/codespec gate-sequence start-design
```

#### 常见报错：`dossier already initialized in /home/admin`

这通常不是 `estimate/requirement-estimation` 已经初始化失败，而是你在错误目录执行了
脚本，例如站在某个外层 Git 仓库的 `scripts/` 目录里，直接运行 `./init-dossier.sh`。

此时脚本会：
- 向上找到某个 workspace root
- 再用当前 Git 仓库的 top-level 当项目根
- 如果那个目录已经有 `meta.yaml`，就会报 `dossier already initialized in ...`

正确做法是先进入项目目录，再调用 workspace 里的脚本：

```bash
cd /home/admin/estimate/requirement-estimation
/home/admin/estimate/.codespec/scripts/init-dossier.sh
```

如果目标项目本身已经有 `meta.yaml`，那就说明它早已初始化过，不应该再执行
`init-dossier.sh`，而应该直接使用 `codespec status` 或走“旧版升级”流程。

完成接入后，后续需求推进就回到“场景 1”的标准流程。

---

### 场景 3：多人协作项目

如果多人使用同一个工作区：

```bash
# 每个人在自己的项目目录中工作
workspace/
├── .codespec/              # 共享框架
├── alice-feature-x/        # Alice 的项目
├── bob-feature-y/          # Bob 的项目
└── charlie-bugfix-z/       # Charlie 的项目

# 每个人独立推进自己的阶段
cd workspace/alice-feature-x
codespec status  # 查看自己的项目状态
```

---

### 场景 4：版本迭代工作流

当一个版本完成后，如何开始下一个版本的开发？

#### 步骤 1：完成当前版本

```bash
# AI 完成真实部署并且你确认手工验收通过后
# 若当前在业务分支，推荐直接走一键交接：
codespec submit-pr v1.0
# 它会在需要时先执行 complete-change，再 push 当前分支并创建 PR
# 当前项目目录中的 meta.yaml 最终会变为：phase=Deployment, status=completed
# 同时归档到当前项目内 versions/v1.0/
```

`versions/<version>/` 是 dossier 和交付证据快照，不等同于完整源码发布包；它会保留权威文档、合约、reviews，以及存在时的 `scripts/codespec-deploy`，用于追溯本次变更如何被验收。

**AI 会询问**："项目已完成验收，是否生成项目文档？（建议生成，用于后续版本参考）"

如果你确认生成：

```bash
codespec scaffold-project-docs v1.0
# 生成项目文档脚手架到 ../project-docs/v1.0/
# 包含：系统功能说明书、技术方案设计、接口文档、用户手册、部署记录、测试报告
```

`generate-project-docs v1.0` 仍可作为兼容别名使用，但现在明确表示“生成脚手架”，
不是“直接抽取出可发布文档”。

`promote-version v1.0` 仍可作为兼容别名使用。推荐主路径是：
- 需要一键 push + 建 PR：`submit-pr <stable-version>`
- 只做本地收口归档：`complete-change <stable-version>`

#### 步骤 2：开始新版本

**方式 A：原地重置（推荐）**

```bash
# 在同一目录中开始新版本
codespec reset-to-requirement
# 自动重置到 Requirement 阶段
# base_version 设置为 v1.0
# 新 change_id 设置为 v1.0-next
# 保留 CLAUDE.md, AGENTS.md, contracts/
```

`reset-to-requirement` 的前提是：当前 completed dossier 已至少执行过一次
`complete-change <stable-version>`（或兼容别名 `promote-version <stable-version>`）。
它会从 `versions/` 归档记录中解析最近一次 promote 的稳定版本名，而不是要求当前
`meta.yaml.change_id` 与归档目录名完全一致。默认要求 git 工作树干净；若你明确要覆盖本地未提交的 dossier 文件，必须加 `--force`。

首次基线场景示例：

```bash
# 假设当前 live dossier 的 change_id 仍然是 baseline
codespec submit-pr v1.0
codespec reset-to-requirement

# reset 后：
# base_version = v1.0
# change_id = v1.0-next
```

**方式 B：新建分支（可选）**

```bash
# 如果你想在新分支中开发
git checkout -b v1.1

# AI 会检测到新分支，询问：
# "检测到新分支，是否新建项目变更（执行 reset-to-requirement）？"

# 你确认后，AI 自动执行：
codespec reset-to-requirement
```

#### 步骤 4：参考上一版本

在新版本的 Requirement 阶段，如果需要参考上一版本：

```bash
# 告诉 AI：
"基于 v1.0 添加新功能：<功能描述>"
```

**AI 会协助**：
- 读取 `../project-docs/v1.0/系统功能说明书.md` 了解现有功能
- 读取 `../project-docs/v1.0/技术方案设计.md` 了解现有架构
- 在此基础上设计新功能

**注意**：
- 项目文档不在 readset 中，只在你明确要求时读取
- 项目文档是参考资料，真相源仍是 spec.md, design.md

#### 查看所有版本

```bash
codespec list-versions
# 输出：
# Version    Created      Status      Base Version    Promoted Version    Promoted At
# -------    -------      ------      ------------    ----------------    -----------
# v1.0       2026-04-20   completed   null            v1.0                2026-04-20T10:00:00Z
# v1.1       2026-04-21   completed   v1.0            v1.1                2026-04-21T09:30:00Z
```

---

## 关键理解

### 你的角色
- **定义需求**：告诉 AI 你想要什么
- **语义复审**：审查 AI 的输出，确认方向正确，并把结论记录到 reviews/*.yaml
- **验收结果**：测试功能，确认符合预期

### AI 的角色
- **补充文档**：根据你的需求填写 spec.md, design.md
- **拆解任务**：将需求拆解为实现切片
- **编写代码**：实现设计
- **推进流程**：使用 `codespec` 命令切换阶段
- **记录过程**：在 testing.md, deployment.md 中记录结果

### 你很少需要手工编辑文件
- AI 会协助起草大部分文档
- 你仍需要审查关键内容，并确认 reviews/*.yaml 已记录审查结论与 gate evidence
- 如果有问题，告诉 AI 修改即可

---

## 典型对话示例

```
你: "我想开发一个用户登录功能"

AI: "好的，我已经读取了 meta.yaml，当前在 Requirement 阶段。
     我先在 spec.md 中补充需求概览、决策与来源、流程叙事和需求草稿。
     你确认后，请记录 reviews/design-review.yaml。"

你: "REQ-003 需要支持第三方登录，请补充。"

AI: "已补充 REQ-003。
     请再审查一遍需求；如果没问题，请记录 reviews/design-review.yaml。"

你: "需求没问题，我已记录 reviews/design-review.yaml。"

AI: "收到，我现在执行 start-design，并完成了架构设计。
     我拆解了 3 个实现切片：
     - SLICE-001: 实现登录表单
     - SLICE-002: 实现认证逻辑
     - SLICE-003: 实现第三方登录集成
     请审查实现切片拆解；确认后请记录 reviews/implementation-review.yaml。"

你: "可以，我已记录 reviews/implementation-review.yaml，开始实现。"

AI: "已开始实现，代码已提交。
     请测试登录表单功能。"

你: "测试通过，继续"

AI: "实现完成，测试通过，部署完成。
     项目已完成。"
```

---

## 下一步

继续阅读：
- [命令参考](#命令参考) - 了解所有可用命令
- [门控检查列表](#门控检查列表) - 了解每个阶段的检查内容
- [常见问题](#常见问题) - 解答使用中的疑问

## 命令参考

下文中的 `codespec ...` 都表示“按上面的命令入口约定解析出的标准 runtime 入口”。

### 项目管理命令

| 命令 | 说明 |
|------|------|
| `codespec status` | 查看项目当前状态（阶段、分支等） |
| `codespec completion-report` | 输出当前阶段的最高完成等级、是否必须披露未完成项，以及阶段性回复必须包含的栏目 |
| `codespec readset [--json]` | 查看推荐阅读的文件列表 |

### 阶段转换命令

| 命令 | 前置条件 | 作用 |
|------|---------|------|
| `codespec start-design` | Requirement 完整，有审查记录 | 切换到 Design 阶段 |
| `codespec start-implementation` | Design 完整，有审查记录 | 进入 Implementation 阶段 |
| `codespec reopen-implementation` | 当前处于 Testing/Deployment 且发现需要代码修复 | 回到同一 change 的 Implementation 阶段（`change_id` 不变） |
| `codespec reopen-testing` | 当前处于 Deployment 且需要重新验证测试 | 回到同一 change 的 Testing 阶段 |
| `codespec authority-repair begin <gate> --paths <csv> --reason "<reason>"` | Implementation/Testing/Deployment 阶段的 gate 发现必须先修的上游 authority 缺口 | 打开受控 authority 修复态，临时放开最小 authority 文件 |
| `codespec authority-repair begin <gate> --kind source-trace --paths <csv> --reason "<reason>"` | 晚期 gate 发现需求来源/追溯元数据缺口，且不能改变需求语义 | 只允许修 `spec.md`/`spec-appendices/*.md`/`design.md` 的追溯元数据，close 时校验 REQ/ACC/VO 语义指纹不变 |
| `codespec authority-repair close --evidence "<summary>"` | 修复已完成，且准备重跑 repair 记录的 gate | 记录 gate 证据并关闭修复态；完整 smoke 作为常规回归单独执行 |
| `codespec start-testing` | 整个 Implementation span 通过 scope / contract / verification，Implementation `HANDOFF-*` 已主动披露未完成项，且有 implementation review | 切换到 Testing 阶段 |
| `codespec start-deployment` | 测试覆盖完整且通过，且 Testing `HANDOFF-*` 已记录最高完成等级和剩余缺口 | 切换到 Deployment 阶段 |
| `codespec deploy` | 当前处于 Deployment 阶段，`deployment.md` 发布计划已补齐，且项目已提供 `scripts/codespec-deploy` | 执行真实部署并回写运行态证据 |
| `codespec complete-change <version>` | 真实部署完成、手工验收通过，且 Deployment `HANDOFF-*` 已记录 owner_verified / 未完成项披露 | 完成项目并归档稳定版本 |
| `codespec submit-pr <version> [--base <branch>] [--draft]` | Deployment 阶段已人工验收通过，当前在非默认分支，git 工作树干净 | 自动执行 complete-change（若尚未 completed）、push 当前分支并创建 GitHub PR |

`reopen-implementation` 不会新建 change。`testing.md` 继续作为验证账本追加记录；下一次
`codespec deploy` 会用最新部署结果覆盖 `deployment.md` 中的 `Execution Evidence` /
`Verification Results`，并把 `Acceptance Conclusion` 重置为 `pending`。

### 版本管理命令

| 命令 | 前置条件 | 作用 |
|------|---------|------|
| `codespec scaffold-project-docs <version>` | status=completed, phase=Deployment | 生成项目文档脚手架到 project-docs/<version>/ |
| `codespec generate-project-docs <version>` | 与 `scaffold-project-docs <version>` 相同的兼容入口 | 兼容别名，建议改用 `scaffold-project-docs` |
| `codespec promote-version <version>` | 与 `complete-change <version>` 相同的兼容入口 | 兼容归档命令，建议改用 `complete-change` |
| `codespec reset-to-requirement [--reset-contracts] [--force]` | status=completed, 当前 completed dossier 已至少执行一次 complete-change/promote-version；默认要求工作树干净 | 重置 dossier 到 Requirement 阶段，开始新版本（默认保留 contracts） |
| `codespec list-versions [--json]` | - | 列出所有已归档版本 |

### 检查和工具命令

| 命令 | 说明 |
|------|------|
| `codespec check-gate <gate-name>` | 手动执行指定的门控检查 |
| `codespec gate-sequence <transition> [--json]` | 查看阶段切换的权威 gate 序列 |
| `codespec scaffold-review <target-phase>` | 生成 pending 状态的审查记录脚手架，不会自动批准 |
| `codespec review-gates <target-phase> --write` | 运行目标阶段的客观 gate，并把带 `checked_revision` 的结构化 `gate_evidence` 写入 review |
| `codespec migrate-testing-ledger [--write]` | 从 legacy `testing.md` 分节生成结构化 `CODESPEC:TESTING:LEDGER` 块；存在结构化块时 gate 以结构化块为准 |
| `codespec materialize-deployment` | 创建 deployment.md 文件 |

## 门控检查列表

框架内置以下门控检查，在阶段转换时自动执行：

| Gate 名称 | 检查内容 | 触发时机 |
|----------|---------|---------|
| `metadata-consistency` | meta.yaml 与文档的一致性 | 所有阶段转换 |
| `review-verdict-present` | 审查记录是否存在且 verdict 通过 | Requirement/Design/Implementation 转换 |
| `review-quality` | 审查记录是否包含 approved verdict、有效 scope、目标阶段必需且可验证的结构化 gate evidence、findings、残留风险、决策说明；P0 非自动化 TC 必须有审查接受记录 | Requirement/Design/Implementation 转换 |
| `requirement-complete` | Requirement 阶段文档是否完整、无占位、追溯链闭合 | Requirement → Design |
| `spec-quality` | spec.md 是否自足、无模板占位、需求语义可独立读取 | Requirement → Design |
| `test-plan-complete` | 每个 ACC 是否在进入 Design 前已有 TC-* 计划 | Requirement → Design |
| `design-structure-complete` | design.md 结构是否完整 | Design → Implementation |
| `design-quality` | design.md 是否覆盖架构、契约、数据、安全、环境、验证和追溯 | Design → Implementation |
| `implementation-readiness-baseline` | 实现切片是否准备就绪 | Design → Implementation |
| `implementation-start` | 检查 design.md §4/§7/§8 是否完整，且 §7 覆盖所有正式 REQ/ACC/VO/TC | Design → Implementation |
| `implementation-ready` | design-quality + implementation-start + baseline readiness；会阻断遗漏验收或测试覆盖的设计进入实现 | Design → Implementation |
| `phase-capability` | 当前阶段最低能力边界是否允许修改实现或冻结文件 | pre-commit hook |
| `scope` | 修改的文件是否在 design.md §4 可修改路径内 | pre-commit hook |
| `contract-boundary` | 合约是否被正确使用 | pre-commit hook |
| `trace-consistency` | 追踪关系是否一致 | Testing → Deployment / Promotion |
| `testing-coverage` | 测试是否覆盖所有验收标准 | Testing → Deployment |
| `verification` | 验证测试是否通过 | Testing → Deployment |
| `semantic-handoff` | 是否已主动披露当前阶段最高完成等级、未完成项、阻塞原因、下一步和 fallback/fixture 边界 | Implementation / Testing / Deployment 阶段收口 |
| `deployment-plan-ready` | deployment.md 发布计划、日期、发布前 checklist、回滚与监控是否已补齐 | `codespec deploy` |
| `deployment-readiness` | 是否已真实部署且达到人工验收就绪 | Deployment 阶段 |
| `promotion-criteria` | 是否已人工验收通过、trace 仍一致并可归档稳定版本 | Deployment → Completed |
| `policy-consistency` | phase-review-policy 中声明的命令映射与实际 gate 调用是否一致 | 日常自检 |

## Git 集成

框架通过 pre-commit hook 在每次提交前执行检查：

```bash
# 自动执行的检查：
1. metadata-consistency  # 元数据一致性
2. phase-capability      # 阶段最低能力检查（Requirement 禁止实现文件；Testing/Deployment 冻结实现与 authority 文件）
3. scope                 # 范围检查（Implementation 阶段检查 staged 改动；start-testing 会再按整个 Implementation span 重查）
4. contract-boundary     # 合约边界检查
```

pre-commit 读取的是 Git staged snapshot，而不是工作区当前文件。也就是说，如果本次提交要切换阶段，`meta.yaml` 必须和该阶段 gate 依赖的权威文件一起 `git add`；未暂存的本地修正不会被 hook 当作通过依据。

**注意**：框架有两层约束：
- `phase-capability`：阶段级最低能力边界，例如 Requirement 阶段不能提交 `src/**`
- `scope`：文件级路径约束，Implementation 阶段检查 staged 改动是否在 design.md §4 可修改路径内；`meta.yaml` 和 `testing.md` 属于 lifecycle / evidence 文件，不受实现路径约束。

如果 Implementation / Testing / Deployment 阶段的 gate 发现上游 authority 文档必须先修，使用 `codespec authority-repair begin ...` 进入修复态。修复态只允许修改 `meta.yaml`、`authority-repairs/*.yaml` 和声明的最小 authority 路径；`close` 会重跑记录的 gate 并通过 metadata consistency 后关闭 repair。完整框架 smoke 仍应在常规回归中执行，但不再作为每次 close 的内置步骤。未进入修复态时，`design.md`、`spec.md` 等越权修改仍会被阻断。若缺口仅是来源闭包、appendix 读取矩阵或 design trace 字段这类非语义追溯元数据，使用 `--kind source-trace`；该模式允许最小修 `spec.md`、`spec-appendices/*.md` 和 `design.md`，但禁止改变 `REQ/ACC/VO` 语义。

### Commit / PR 节奏

- 一个 commit 只承载一个可独立审查的事实边界；不要把实现、测试证据、人工验收、最终收口揉成一个大提交。
- Requirement / Design 达到一次可审查状态就提交；Implementation 按可运行切片提交。
- `testing.md` 的新增验证证据应单独提交；人工验收通过后，对 `deployment.md` 的结论也应单独提交。
- `codespec submit-pr <stable-version>` 适合放在“人工验收结论已落盘并已提交”之后使用；它会要求当前分支不是默认分支，且工作树干净。
- `submit-pr` 生成的是交付收口 commit；不要把它当作普通开发中的随手 commit 命令。
- `testing.md` 是追加账本，但 gate 以”最后一条匹配记录”为权威结果；later fail 会推翻 earlier pass
- 若 `testing.md` 已生成 `CODESPEC:TESTING:LEDGER` 结构化块，gate 以结构化块为准；继续修改时应更新结构化块，避免 legacy 分节和结构化块表达不同事实。

## 文档模板

框架提供以下模板（位于 `workspace/.codespec/templates/`）：

| 模板文件 | 说明 |
|---------|------|
| `spec.md` | 需求规格文档，包含需求概览、决策与来源、流程叙事、需求与验收、运行约束 |
| `design.md` | 设计文档，包含设计概览、需求追溯、架构决策、系统结构、契约、横切设计、实现切片与验证 |
| `testing.md` | 测试文档，记录 acceptance tests 和 verification tests |
| `deployment.md` | 部署文档，记录部署步骤和验证结果 |
| `contract.md` | 共享契约模板，用于跨切片的接口定义 |
| `CLAUDE.md` | AI 助手工作指南（会复制到项目根目录） |
| `AGENTS.md` | AI 助手详细指令（会复制到项目根目录） |
| `phase-review-policy.md` | 阶段审查规则（工作区级别） |
| `lessons_learned.md` | 经验总结模板（工作区级别） |

## 与 AI 助手协作

Codespec 框架设计为**人机协作**模式：

### 人类的职责
1. **定义需求**：在 spec.md 中确认需求概览、来源、范围、验收和约束
2. **审查设计**：检查 design.md 中的架构设计和实现切片拆解
3. **手工验收**：在 AI 完成真实部署并给出运行态证据后进行人工验收，并显式确认是否通过
4. **确认审查记录**：在每个阶段完成后确认 reviews/*.yaml 记录了 scope、gate evidence、findings 与结论

### AI 助手的职责
1. **补充文档**：细化 spec.md 中的 Requirements、Acceptance、Verification
2. **拆解任务**：在 design.md 中完成实现切片拆解
3. **编写代码**：实现设计
4. **执行测试**：运行测试并在 testing.md 中记录结果
5. **执行部署**：运行 `codespec deploy`，调用项目内 `scripts/codespec-deploy` 并把证据写回 deployment.md
6. **推进流程**：使用 `codespec` 命令切换阶段

### 典型协作流程

以下示例里的 `codespec` 也遵循“命令入口约定”；如果 `codespec` 不在 PATH，请替换为对应的工作区 runtime 路径。

```bash
# 1. 你：创建项目，填写初步需求
vim spec.md

# 2. 你：在项目目录启动 Claude/Codex
# AI 会读取 spec.md，补充详细需求

# 3. 你：查看 gate 序列，审查 Requirement，记录审查结论
codespec gate-sequence start-design
codespec scaffold-review Design
# 运行 gate 并完成语义复审后，把 reviews/design-review.yaml 从 pending 更新为 approved。
# gate pass 不等于语义复审通过；不要直接把脚手架当作批准记录。

# 4. AI：切换到 Design 阶段，完成设计与实现切片拆分
codespec start-design

# 5. 你：查看 gate 序列，审查设计，记录审查结论
codespec gate-sequence start-implementation
codespec scaffold-review Implementation
# 运行 gate 并完成语义复审后，把 reviews/implementation-review.yaml 从 pending 更新为 approved。

# 6. AI：开始实现
codespec start-implementation

# 7. AI：编写代码，提交
# 你：审查实现并记录 reviews/testing-review.yaml

# 8. AI：切换到 Testing
codespec start-testing

# 9. AI：执行测试，记录结果，切换到 Deployment
codespec start-deployment

# 10. AI：执行真实部署并准备人工验收
codespec deploy

# 11. 你：确认手工验收通过后，AI 在业务分支执行一键交接
codespec submit-pr v1.0
```

## 依赖要求

- **Bash** 4.0+
- **Git** 2.0+
- **yq** 4.0+ (YAML 处理工具，安装：`brew install yq` 或 `apt-get install yq`)

## 常见问题

### Q: 为什么阶段转换命令失败？
A: 检查错误信息，通常是因为：
- 文档中有占位符（`[TODO]`, `[TBD]` 等）未清理
- 缺少必需的章节或字段
- 缺少审查记录（reviews/*.yaml）
- 依赖关系不满足

可以手动执行检查查看详细错误：
```bash
codespec check-gate <gate-name>
```

### Q: 如何跳过某个阶段？
A: 不建议跳过阶段。框架的设计理念是确保每个阶段的工作质量。如果确实需要快速原型，可以：
1. 快速填写必需字段（不留占位符）
2. 记录审查记录，包含 approved verdict、scope、gate evidence 与 findings
3. 按顺序执行阶段转换命令

### Q: 审查记录（reviews/*.yaml）必须手动创建吗？
A: 框架不会把它自动当作“授权令牌”生成。reviews/*.yaml 是审查记录与 gate evidence ledger，用来保留谁审查了哪些文件、哪些 gate 已通过、发现了什么问题和剩余风险。

## 许可证

MIT License
