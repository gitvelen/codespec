# Codespec

基于阶段门控（Phase-Gate）的软件开发流程管理框架。通过结构化文档和自动化检查，确保每个阶段的工作质量达标后才能进入下一阶段。

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

项目生命周期分为 7 个阶段，必须按顺序推进：

```
Proposal → Requirements → Design → Implementation → Testing → Deployment → Completed
```

每个阶段的职责：
- **Proposal**: 在 spec.md 中记录初步需求和意图
- **Requirements**: 在 spec.md 中细化需求（REQ-*）、验收标准（ACC-*）、验证方法（VO-*）
- **Design**: 在 design.md 中完成架构设计，拆解工作项（WI-001, WI-002...）
- **Implementation**: 编写代码实现工作项
- **Testing**: 在 testing.md 中记录测试执行和结果
- **Deployment**: 在 deployment.md 中记录部署步骤和验证
- **Completed**: 项目完成

### 工作项（Work Item）

设计阶段将需求拆解为独立的工作项（WI-001, WI-002...），每个工作项：
- 有明确的实现目标和验收标准
- 声明依赖关系（depends_on）
- 定义允许修改的文件范围（allowed_paths, forbidden_paths）
- 关联测试（acceptance tests → verification tests）

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
    ├── spec.md            # 需求规格（自动创建）
    ├── design.md          # 设计文档（自动创建）
    ├── meta.yaml          # 项目元数据（自动创建）
    └── .claude/           # AI 工作区配置（自动创建）
```

#### 命令入口约定

在项目目录执行阶段命令时，优先使用 `codespec <cmd>`。如果当前 shell 找不到 `codespec`，则改用工作区 runtime（常见布局：`../.codespec/codespec <cmd>`）。如果两者都不可用，先修复 runtime 安装；不要手改 `meta.yaml` 推进阶段或切换 work item。

#### 步骤 2：启动 AI 助手，开始协作

```bash
# 在项目目录中启动 Claude/Codex
# 简单告诉 AI 你的需求：

"我想开发一个用户登录功能"
```

**AI 会自动**：
- 读取 `meta.yaml`（知道当前在 Proposal 阶段）
- 读取 `CLAUDE.md`/`AGENTS.md`（知道该做什么）
- 读取 `spec.md` 模板
- 根据你的需求填写 Input Intake 和 Proposal
- 完成后告诉你审查

**你需要做什么**：
- 审查 AI 填写的内容
- 确认需求理解正确
- 如果有问题，直接说"XXX 不对，应该是 YYY"
- 如果没问题，说"可以，继续"

#### 步骤 3：推进到 Requirements 阶段

```bash
# 简单告诉 AI：

"继续推进到 Requirements 阶段"
```

**AI 会自动**：
- 创建 `reviews/requirements-review.yaml`（标记 Proposal 审查通过）
- 执行 `codespec start-requirements`
- 在 spec.md 中补充详细需求（REQ-*, ACC-*, VO-*）
- 完成后告诉你审查

**你需要做什么**：
- 审查需求是否完整
- 确认验收标准是否合理
- 如果有遗漏，告诉 AI 补充

#### 步骤 4：推进到 Design 阶段

```bash
# 简单告诉 AI：

"继续推进到 Design 阶段"
```

**AI 会自动**：
- 创建 `reviews/design-review.yaml`（标记 Requirements 审查通过）
- 执行 `codespec start-design`
- 在 design.md 中完成架构设计和工作项拆解
- 完成后告诉你审查

**你需要做什么**：
- 审查架构设计是否合理
- 确认工作项拆解是否合适
- 如果有问题，告诉 AI 调整

#### 步骤 5：推进到 Implementation 阶段

```bash
# 简单告诉 AI：

"开始实现"
```

**AI 会自动**：
- 创建 `reviews/implementation-review.yaml`（标记 Design 审查通过）
- 执行 `codespec add-work-item WI-001`, `WI-002`...
- 填写每个工作项的详细信息（work-items/WI-XXX.yaml）
- 执行 `codespec start-implementation WI-001`
- 如需在同一 Implementation 阶段切换到下一个工作项，继续执行 `codespec start-implementation <next-WI>`
- 编写代码实现工作项
- 完成后告诉你测试

**你需要做什么**：
- 测试功能是否正常
- 如果有问题，告诉 AI 修复

#### 步骤 6：推进到 Testing 和 Deployment

```bash
# 简单告诉 AI：

"继续测试和部署"
```

**AI 会自动**：
- 执行 `codespec start-testing`
- 运行测试，在 testing.md 中记录结果
- 执行 `codespec start-deployment`
- 执行部署步骤，在 deployment.md 中记录
- 执行 `codespec complete-change`
- 完成后告诉你验收

**你需要做什么**：
- 验收最终结果
- 确认部署成功

---

### 场景 2：存量项目（引入框架）

#### 步骤 1：安装框架到存量项目

```bash
# 假设你的存量项目在 /path/to/existing-project
cd /path/to/existing-project

# 克隆框架仓库到临时目录
git clone <codespec-repo-url> /tmp/codespec-framework

# 在当前项目的父目录安装工作区运行时
/tmp/codespec-framework/scripts/install-workspace.sh ..
```

这一步会在项目父目录生成共享文件：
- `../.codespec/`
- `../lessons_learned.md`
- `../phase-review-policy.md`
- `../versions/`

现有项目保持原地不动，不需要 `mv`，也不需要软链。

如果你不想把这些共享文件放在当前父目录，再使用“专用 workspace + 软链”的旧方式。

#### 步骤 2：初始化 Codespec 文档

```bash
# 在当前项目目录初始化 dossier（会创建 spec.md, design.md, meta.yaml 等）
../.codespec/scripts/init-dossier.sh
```

#### 步骤 3：启动 AI，补充文档

```bash
# 简单告诉 AI：

"这是一个存量项目，请帮我补充 Codespec 文档"
```

**AI 会自动**：
- 读取现有代码，理解项目功能
- 在 spec.md 中补充 Input Intake、Proposal、Requirements
- 在 design.md 中补充 Architecture Boundary、模块划分
- 将现有功能映射到需求和设计
- 完成后告诉你审查

**你需要做什么**：
- 审查 AI 补充的文档是否准确
- 补充 AI 不了解的业务背景

#### 步骤 4：定义新需求，使用框架推进

```bash
# 简单告诉 AI：

"我想添加一个新功能：<功能描述>"
```

**AI 会自动**：
- 在 spec.md 中添加新的 Requirements（REQ-XXX）
- 在 design.md 中拆解工作项（WI-XXX）
- 按照 Codespec 流程推进实现
- 完成后告诉你验收

**后续流程**：
- 按照"场景 1"的步骤推进
- AI 会自动使用 Codespec 命令管理新功能的开发

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
# AI 完成所有开发和测试后
codespec complete-change
# 状态变为：phase=Deployment, status=completed
```

**AI 会询问**："项目已完成验收，是否生成项目文档？（建议生成，用于后续版本参考）"

如果你确认生成：

```bash
codespec generate-project-docs v1.0
# 生成项目文档到 ../project-docs/v1.0/
# 包含：系统功能说明书、技术方案设计、接口文档、用户手册、部署记录、测试报告
```

#### 步骤 2：归档当前版本

```bash
codespec promote-version v1.0
# 将完整 dossier 归档到 ../versions/v1.0/
```

#### 步骤 3：开始新版本

**方式 A：原地重置（推荐）**

```bash
# 在同一目录中开始新版本
codespec reset-to-proposal
# 自动重置到 Proposal 阶段
# base_version 设置为 v1.0
# 新 change_id 设置为 v1.0-next
# 保留 CLAUDE.md, AGENTS.md, contracts/
```

`reset-to-proposal` 的前提是：当前 completed dossier 已至少执行过一次 `promote-version`。
它会从 `versions/` 归档记录中解析最近一次 promote 的稳定版本名，而不是要求当前
`meta.yaml.change_id` 与归档目录名完全一致。

首次基线场景示例：

```bash
# 假设当前 live dossier 的 change_id 仍然是 baseline
codespec promote-version v1.0
codespec reset-to-proposal

# reset 后：
# base_version = v1.0
# change_id = v1.0-next
```

**方式 B：新建分支（可选）**

```bash
# 如果你想在新分支中开发
git checkout -b v1.1

# AI 会检测到新分支，询问：
# "检测到新分支，是否新建项目变更（执行 reset-to-proposal）？"

# 你确认后，AI 自动执行：
codespec reset-to-proposal
```

#### 步骤 4：参考上一版本

在新版本的 Proposal 阶段，如果需要参考上一版本：

```bash
# 告诉 AI：
"基于 v1.0 添加新功能：<功能描述>"
```

**AI 会自动**：
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
- **审查决策**：审查 AI 的输出，确认方向正确
- **验收结果**：测试功能，确认符合预期

### AI 的角色
- **补充文档**：根据你的需求填写 spec.md, design.md
- **拆解任务**：将需求拆解为工作项
- **编写代码**：实现工作项
- **推进流程**：使用 `codespec` 命令切换阶段
- **记录过程**：在 testing.md, deployment.md 中记录结果

### 你很少需要手工编辑文件
- AI 会填写所有文档
- 你只需要审查和确认
- 如果有问题，告诉 AI 修改即可

---

## 典型对话示例

```
你: "我想开发一个用户登录功能"

AI: "好的，我已经读取了 meta.yaml，当前在 Proposal 阶段。
     我在 spec.md 中填写了 Input Intake 和 Proposal。
     请审查一下是否符合你的需求。"

你: "看起来不错，继续"

AI: "我已经创建了审查文件，切换到 Requirements 阶段。
     在 spec.md 中补充了详细需求（REQ-001 到 REQ-005）。
     请审查需求是否完整。"

你: "REQ-003 需要支持第三方登录，请补充"

AI: "已补充 REQ-003 的第三方登录需求。
     现在切换到 Design 阶段，完成了架构设计。
     我拆解了 3 个工作项：
     - WI-001: 实现登录表单
     - WI-002: 实现认证逻辑
     - WI-003: 实现第三方登录集成
     请审查工作项拆解是否合理。"

你: "可以，开始实现"

AI: "已开始实现 WI-001，代码已提交。
     请测试登录表单功能。"

你: "测试通过，继续"

AI: "所有工作项实现完成，测试通过，部署完成。
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
| `codespec status` | 查看项目当前状态（阶段、工作项、分支等） |
| `codespec readset [--json]` | 查看推荐阅读的文件列表 |

### 阶段转换命令

| 命令 | 前置条件 | 作用 |
|------|---------|------|
| `codespec start-requirements` | Proposal 成熟，有审查文件 | 切换到 Requirements 阶段 |
| `codespec start-design` | Requirements 完整，有审查文件 | 切换到 Design 阶段 |
| `codespec start-implementation <WI-ID>` | Design 完整或已在 Implementation，工作项存在，有审查文件 | 进入 Implementation 阶段或切换当前 focus WI |
| `codespec start-testing` | 所有工作项实现完成 | 切换到 Testing 阶段 |
| `codespec start-deployment` | 测试覆盖完整且通过 | 切换到 Deployment 阶段 |
| `codespec complete-change` | 部署验证通过 | 完成项目 |

### 版本管理命令

| 命令 | 前置条件 | 作用 |
|------|---------|------|
| `codespec generate-project-docs <version>` | status=completed, phase=Deployment | 生成项目文档到 project-docs/<version>/ |
| `codespec promote-version <version>` | status=completed | 归档 dossier 到 versions/<version>/ |
| `codespec reset-to-proposal [--keep-contracts]` | status=completed, 当前 completed dossier 已至少执行一次 promote-version | 重置 dossier 到 Proposal 阶段，开始新版本 |
| `codespec list-versions [--json]` | - | 列出所有已归档版本 |

### 工作项管理命令

| 命令 | 说明 |
|------|------|
| `codespec add-work-item <WI-ID>` | 创建工作项文件（work-items/WI-XXX.yaml） |
| `codespec set-active-work-items <WI-IDs>` | 设置活跃工作项列表（逗号分隔，如 WI-001,WI-002） |

### 检查和工具命令

| 命令 | 说明 |
|------|------|
| `codespec check-gate <gate-name>` | 手动执行指定的门控检查 |
| `codespec materialize-deployment` | 创建 deployment.md 文件 |

## 门控检查列表

框架内置 15 个门控检查，在阶段转换时自动执行：

| Gate 名称 | 检查内容 | 触发时机 |
|----------|---------|---------|
| `metadata-consistency` | meta.yaml 与文档的一致性 | 所有阶段转换 |
| `review-verdict-present` | 审查文件是否存在且通过 | Requirements/Design/Implementation 转换 |
| `proposal-maturity` | Proposal 是否成熟（无占位符） | Proposal → Requirements |
| `requirements-approval` | Requirements 是否完整 | Requirements → Design |
| `design-structure-complete` | design.md 结构是否完整 | Design → Implementation |
| `implementation-readiness-baseline` | 工作项是否准备就绪 | Design → Implementation |
| `implementation-start` | 工作项文件是否完整 | Design → Implementation |
| `phase-capability` | 当前阶段是否允许修改实现文件 | pre-commit hook |
| `scope` | 修改的文件是否在工作项允许范围内 | pre-commit hook |
| `contract-boundary` | 合约是否被正确使用 | pre-commit hook |
| `trace-consistency` | 追踪关系是否一致 | Implementation → Testing |
| `testing-coverage` | 测试是否覆盖所有验收标准 | Testing → Deployment |
| `verification` | 验证测试是否通过 | Testing → Deployment |
| `deployment-readiness` | 部署文档是否完整 | Deployment 阶段 |
| `promotion-criteria` | 晋升标准是否满足 | Deployment → Completed |

## Git 集成

框架通过 pre-commit hook 在每次提交前执行检查：

```bash
# 自动执行的检查：
1. metadata-consistency  # 元数据一致性
2. phase-capability      # 阶段能力检查（Proposal/Requirements 阶段禁止修改 src/**, Dockerfile）
3. scope                 # 范围检查（Implementation 阶段检查文件是否在工作项的 allowed_paths 内）
4. contract-boundary     # 合约边界检查
```

**注意**：框架**不会**按阶段全局限制文件修改。文件修改限制由工作项的 `allowed_paths` 和 `forbidden_paths` 配置决定。

## 文档模板

框架提供以下模板（位于 `workspace/.codespec/templates/`）：

| 模板文件 | 说明 |
|---------|------|
| `spec.md` | 需求规格文档，包含 Input Intake、Proposal、Requirements、Acceptance Criteria、Verification Objectives |
| `design.md` | 设计文档，包含架构设计、工作项拆解、依赖关系、合约定义 |
| `testing.md` | 测试文档，记录 acceptance tests 和 verification tests |
| `deployment.md` | 部署文档，记录部署步骤和验证结果 |
| `work-item.yaml` | 工作项模板，定义实现目标、允许路径、依赖关系 |
| `contract.md` | 共享契约模板，用于跨工作项的接口定义 |
| `CLAUDE.md` | AI 助手工作指南（会复制到项目的 .claude/ 目录） |
| `AGENTS.md` | AI 助手详细指令（会复制到项目的 .claude/ 目录） |
| `phase-review-policy.md` | 阶段审查规则（工作区级别） |
| `lessons_learned.md` | 经验总结模板（工作区级别） |

## 与 AI 助手协作

Codespec 框架设计为**人机协作**模式：

### 人类的职责
1. **定义需求**：在 spec.md 中填写 Input Intake 和 Proposal
2. **审查设计**：检查 design.md 中的架构设计和工作项拆解
3. **验收结果**：审查代码实现、测试结果、部署验证
4. **创建审查文件**：在每个阶段完成后创建 reviews/*.yaml

### AI 助手的职责
1. **补充文档**：细化 spec.md 中的 Requirements、Acceptance Criteria
2. **拆解任务**：在 design.md 中完成工作项拆解
3. **编写代码**：实现工作项
4. **执行测试**：运行测试并在 testing.md 中记录结果
5. **执行部署**：执行部署步骤并在 deployment.md 中记录
6. **推进流程**：使用 `codespec` 命令切换阶段

### 典型协作流程

以下示例里的 `codespec` 也遵循“命令入口约定”；如果 `codespec` 不在 PATH，请替换为对应的工作区 runtime 路径。

```bash
# 1. 你：创建项目，填写初步需求
vim spec.md

# 2. 你：在项目目录启动 Claude/Codex
# AI 会读取 spec.md，补充详细需求

# 3. AI：切换到 Requirements 阶段
codespec start-requirements

# 4. 你：审查 Requirements，创建审查文件
cat > reviews/design-review.yaml <<EOF
phase: Requirements
verdict: approved
reviewed_by: YourName
reviewed_at: $(date +%F)
EOF

# 5. AI：切换到 Design 阶段，完成设计
codespec start-design

# 6. 你：审查设计，创建审查文件
cat > reviews/implementation-review.yaml <<EOF
phase: Design
verdict: approved
reviewed_by: YourName
reviewed_at: $(date +%F)
EOF

# 7. AI：添加工作项，开始实现
codespec add-work-item WI-001
codespec start-implementation WI-001

# 8. AI：编写代码，提交，切换到 Testing
codespec start-testing

# 9. AI：执行测试，记录结果，切换到 Deployment
codespec start-deployment

# 10. AI：执行部署，验证，完成项目
codespec complete-change
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
- 缺少审查文件（reviews/*.yaml）
- 依赖关系不满足

可以手动执行检查查看详细错误：
```bash
codespec check-gate <gate-name>
```

### Q: 如何跳过某个阶段？
A: 不建议跳过阶段。框架的设计理念是确保每个阶段的工作质量。如果确实需要快速原型，可以：
1. 快速填写必需字段（不留占位符）
2. 创建审查文件标记为 approved
3. 按顺序执行阶段转换命令

### Q: 工作项的 allowed_paths 和 forbidden_paths 如何配置？
A: 在 work-items/WI-XXX.yaml 中配置：
```yaml
allowed_paths:
  - src/feature-x/**
  - tests/feature-x/**
forbidden_paths:
  - spec.md
  - design.md
  - contracts/**  # 如果不需要修改合约
```

### Q: 如何处理多个工作项并行开发？
A: 使用 `set-active-work-items` 命令：
```bash
codespec set-active-work-items WI-001,WI-002,WI-003
```

确保每个工作项的 `allowed_paths` 不重叠，避免冲突。

### Q: 审查文件（reviews/*.yaml）必须手动创建吗？
A: 是的。审查文件代表人类的审查决策，框架不会自动创建。这是有意的设计，确保每个阶段都经过人类审查。

## 许可证

MIT License
