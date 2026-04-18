# Codespec

一个基于阶段门控（Phase-Gate）的软件开发流程管理框架，通过结构化文档和自动化检查确保开发质量。

## 核心概念

### 阶段（Phase）
项目生命周期分为 7 个阶段：
- **Proposal**: 需求提出和初步评估
- **Requirements**: 需求分析和确认
- **Design**: 架构设计和工作项拆解
- **Implementation**: 代码实现
- **Testing**: 测试验证
- **Deployment**: 部署上线
- **Completed**: 项目完成

### 工作项（Work Item）
设计阶段将需求拆解为独立的工作项（WI-001, WI-002...），每个工作项包含：
- 实现目标和验收标准
- 依赖关系和执行顺序
- 测试追踪（acceptance tests → verification tests）

### 门控检查（Gate）
每个阶段转换前自动执行检查，确保：
- 文档完整性（必填字段、占位符清理）
- 逻辑一致性（依赖关系、测试覆盖）
- 流程合规性（审查通过、验证完成）

## 快速开始

### 1. 安装框架

```bash
# 创建新项目
./scripts/quick-start.sh /path/to/workspace

# 或 clone 现有项目
./scripts/quick-start.sh /path/to/workspace https://github.com/user/repo.git
```

### 2. 初始化项目

```bash
cd /path/to/workspace/main
codespec init-dossier
```

这会创建：
- `spec.md` - 需求规格文档
- `design.md` - 设计文档
- `meta.yaml` - 项目元数据
- `.claude/` - 工作区配置

### 3. 典型工作流

```bash
# 1. 填写需求规格
vim spec.md

# 2. 开始需求分析阶段
codespec start-requirements

# 3. 需求审查通过后，开始设计
codespec start-design

# 4. 在 design.md 中拆解工作项，然后添加
codespec add-work-item WI-001
codespec add-work-item WI-002

# 5. 开始实现
codespec start-implementation WI-001

# 6. 实现完成后，记录测试
codespec start-testing

# 7. 测试通过后，部署
codespec start-deployment

# 8. 完成项目
codespec complete-change
```

## 核心命令

| 命令 | 说明 |
|------|------|
| `init-dossier` | 初始化项目文档结构 |
| `start-requirements` | 进入需求分析阶段 |
| `start-design` | 进入设计阶段 |
| `add-work-item <WI-ID>` | 添加工作项 |
| `start-implementation <WI-ID>` | 开始实现工作项 |
| `set-active-work-items <WI-IDs>` | 设置活跃工作项（逗号分隔） |
| `start-testing` | 进入测试阶段 |
| `start-deployment` | 进入部署阶段 |
| `complete-change` | 完成项目 |
| `check-gate <gate-name>` | 手动执行门控检查 |
| `readset [--json]` | 查看当前项目状态 |

## 文档模板

框架提供以下模板（位于 `templates/`）：

- **spec.md**: 需求规格文档，包含 Input Intake、Requirements、Constraints
- **design.md**: 设计文档，包含架构设计、工作项拆解、依赖关系
- **testing.md**: 测试文档，记录 acceptance tests 和 verification tests
- **deployment.md**: 部署文档，记录部署步骤和验证结果
- **contract.md**: 共享契约模板，用于跨工作项的接口定义
- **CLAUDE.md / AGENTS.md**: AI 助手工作指南

## Git 集成

框架通过 pre-commit hook 强制执行规则：

- **Proposal 阶段**: 只能修改 `spec.md`
- **Requirements 阶段**: 只能修改 `spec.md`
- **Design 阶段**: 只能修改 `spec.md`, `design.md`, `work-items/`, `contracts/`
- **Implementation 阶段**: 不能修改 `spec.md`, `design.md`（已冻结的合约除外）
- **Testing/Deployment 阶段**: 只能修改 `testing.md`, `deployment.md`

## 门控检查列表

框架内置 15 个门控检查：

| Gate | 检查内容 |
|------|---------|
| `metadata-consistency` | 元数据一致性 |
| `review-verdict-present` | 审查结论存在 |
| `proposal-maturity` | Proposal 成熟度 |
| `requirements-approval` | 需求审批通过 |
| `design-structure-complete` | 设计结构完整 |
| `implementation-readiness-baseline` | 实现准备就绪 |
| `implementation-start` | 实现开始检查 |
| `phase-capability` | 阶段能力检查 |
| `scope` | 范围一致性 |
| `contract-boundary` | 合约边界检查 |
| `trace-consistency` | 追踪一致性 |
| `testing-coverage` | 测试覆盖率 |
| `verification` | 验证完成 |
| `deployment-readiness` | 部署就绪 |
| `promotion-criteria` | 晋升标准 |

## 项目结构

```
workspace/
├── main/                    # 主项目目录
│   ├── spec.md             # 需求规格
│   ├── design.md           # 设计文档
│   ├── testing.md          # 测试文档
│   ├── deployment.md       # 部署文档
│   ├── meta.yaml           # 项目元数据
│   ├── work-items/         # 工作项目录
│   │   ├── WI-001.yaml
│   │   └── WI-002.yaml
│   ├── contracts/          # 共享契约
│   │   └── api-contract.md
│   └── .claude/            # 工作区配置
│       ├── settings.json
│       └── CLAUDE.md
└── .codespec/              # 框架安装目录
    ├── codespec            # 主程序
    ├── scripts/            # 脚本集合
    └── templates/          # 文档模板
```

## 依赖要求

- Bash 4.0+
- Git 2.0+
- yq 4.0+ (YAML 处理工具)

## 许可证

MIT License
