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

### 1. 安装框架到工作区

```bash
# 克隆框架仓库
git clone <codespec-repo-url> /path/to/codespec-framework
cd /path/to/codespec-framework

# 创建工作区（会在工作区中安装 .codespec/）
./scripts/quick-start.sh /path/to/workspace

# 进入项目目录（默认名称为 main）
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

### 2. 典型工作流程

#### 阶段 1：Proposal（需求提出）

```bash
# 项目初始化后，默认处于 Proposal 阶段
# 在 spec.md 中填写初步需求

vim spec.md
# 填写：
# - Input Intake: 需求来源和背景
# - Proposal: 初步的解决方案
# - Constraints: 约束条件
```

#### 阶段 2：Requirements（需求分析）

```bash
# 在 spec.md 中补充详细需求后，切换到 Requirements 阶段
codespec start-requirements

# 此命令会检查：
# - spec.md 的 Proposal 部分是否成熟（无占位符）
# - 是否存在 reviews/requirements-review.yaml（审查通过）

# 在 spec.md 中继续细化：
# - Requirements: 详细需求（REQ-001, REQ-002...）
# - Acceptance Criteria: 验收标准（ACC-001, ACC-002...）
# - Verification Objectives: 验证目标（VO-001, VO-002...）
# - Proposal Coverage Map: 需求与 Proposal 的映射
# - Clarification Status: 澄清记录
```

#### 阶段 3：Design（架构设计）

```bash
# 创建审查文件（Requirements 阶段的审查）
mkdir -p reviews
cat > reviews/design-review.yaml <<EOF
phase: Requirements
verdict: approved
reviewed_by: $(git config user.name)
reviewed_at: $(date +%F)
EOF

# 切换到 Design 阶段
codespec start-design

# 此命令会检查：
# - spec.md 是否有完整的 Requirements 内容（REQ-*, ACC-*, VO-*）
# - Proposal Coverage Map 是否完整
# - reviews/design-review.yaml 是否存在

# 在 design.md 中完成设计：
# - Architecture Boundary: 架构边界
# - Work Item Execution Strategy: 工作项执行策略
# - Work Item Derivation: 工作项拆解（WI-001, WI-002...）
# - Contract Needs: 共享契约定义
# - Verification Design: 验证设计
```

#### 阶段 4：Implementation（代码实现）

```bash
# 将 design.md 中的工作项添加到系统
codespec add-work-item WI-001
codespec add-work-item WI-002

# 编辑工作项文件，填写详细信息
vim work-items/WI-001.yaml
# 填写：
# - goal: 实现目标
# - acceptance_refs: 关联的验收标准
# - verification_refs: 关联的验证目标
# - allowed_paths: 允许修改的文件
# - forbidden_paths: 禁止修改的文件
# - depends_on: 依赖的其他工作项

# 创建审查文件（Design 阶段的审查）
cat > reviews/implementation-review.yaml <<EOF
phase: Design
verdict: approved
reviewed_by: $(git config user.name)
reviewed_at: $(date +%F)
EOF

# 开始实现第一个工作项
codespec start-implementation WI-001

# 此命令会检查：
# - design.md 是否有完整的结构（10+ 个必需章节）
# - work-items/WI-001.yaml 是否存在且完整
# - reviews/implementation-review.yaml 是否存在

# 编写代码实现 WI-001
# ...

# 如果有多个工作项并行，可以设置活跃工作项列表
codespec set-active-work-items WI-001,WI-002
```

#### 阶段 5：Testing（测试验证）

```bash
# 所有工作项实现完成后，切换到 Testing 阶段
codespec start-testing

# 此命令会检查：
# - 所有活跃工作项的代码是否已提交
# - testing.md 是否存在

# 在 testing.md 中记录测试：
# - Acceptance Test Records: 验收测试记录
# - Verification Test Records: 验证测试记录
# - 每个测试关联到 spec.md 中的 ACC-* 和 VO-*
```

#### 阶段 6：Deployment（部署上线）

```bash
# 测试通过后，切换到 Deployment 阶段
codespec start-deployment

# 此命令会检查：
# - testing.md 中的测试是否覆盖所有 ACC-* 和VO-*
# - 所有测试是否通过

# 在 deployment.md 中记录部署：
# - Deployment Steps: 部署步骤
# - Verification Results: 部署后验证结果
```

#### 阶段 7：Completed（项目完成）

```bash
# 部署验证通过后，完成项目
codespec complete-change

# 此命令会检查：
# - deployment.md 中的验证是否通过
# - 所有文档是否完整
```

### 3. 查看项目状态

```bash
# 查看当前阶段、活跃工作项等信息
codespec status

# 查看推荐阅读的文件列表（根据当前阶段）
codespec readset

# 以 JSON 格式输出（方便 AI 解析）
codespec readset --json
```

## 命令参考

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
| `codespec start-implementation <WI-ID>` | Design 完整，工作项存在，有审查文件 | 切换到 Implementation 阶段 |
| `codespec start-testing` | 所有工作项实现完成 | 切换到 Testing 阶段 |
| `codespec start-deployment` | 测试覆盖完整且通过 | 切换到 Deployment 阶段 |
| `codespec complete-change` | 部署验证通过 | 完成项目 |

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
