# codespec v2.0

`codespec` 是一个可嵌入到业务项目中的变更规范 runtime。  
它提供工作区级别的共享资源和项目级别的 dossier 管理，支持单分支串行和多分支并行两种工作流。

## v2.0 核心变化

**目录结构改革**：
- 去掉 `change/` 目录，dossier 文件直接在项目根目录
- 工作区（workspace）包含共享资源：`.codespec/`, `lessons_learned.md`, `phase-review-policy.md`, `versions/`
- 项目（project）是独立的 Git clone，包含 dossier 文件：`spec.md`, `design.md`, `meta.yaml`, `work-items/` 等
- 多分支并行时，使用多个独立 Git clone，而不是 `change/container/` 子目录

**命令改革**：
- 新增 `install-workspace`：在工作区根目录安装共享资源
- 新增 `init-dossier`：在项目根目录初始化 dossier
- 删除 `add-container`：用户手工 `git clone` 创建并行工作目录
- 所有生命周期命令去掉 `[container]` 参数，自动从当前目录推断项目根目录

**文件修改规则**：
- 某些文件只能在 parent feature 分支修改：`spec.md`, `design.md`, `work-items/`, `contracts/`, `testing.md`, `deployment.md`
- 执行分支只能修改：`src/**`, `meta.yaml`
- pre-commit hook 自动检查并阻止违规修改

## 框架真实模型

当前版本的 `codespec` 应按四层理解，而不是把所有约束都理解成"runtime 已完整自动化"：

1. **硬门禁（runtime / gate / hooks）**
   - 负责低歧义、可脚本化、误判成本低的约束。
   - 典型内容：阶段基础结构、最小追溯闭合、分支对齐、allowed/forbidden path、冻结 contract 保护、testing / deployment 最低载体存在性。
2. **软审查（phase-review-policy / rfr）**
   - 负责语义充分性，而不是结构存在性。
   - 典型内容：acceptance 是否可判 PASS/FAIL、verification 是否真正可执行、design 是否仍能解释当前实现、是否出现隐性扩 scope。
3. **人工裁决（reviewer / owner）**
   - 负责跨切片、共享边界和例外处理这类很难安全脚本化的问题。
   - 典型内容：shared owner / conflict policy、是否接受 residual risk、是否需要 reopen spec/design、是否允许偏离默认分支计划。
4. **执行便利（install-workspace / init-dossier / readset / agent entry）**
   - 负责提高可用性，不定义语义真值。
   - 典型内容：初始化工作区、初始化 dossier、安装 hooks、给出最小 readset。

一句话说：**`check-gate pass` 只代表最低机器门槛通过，不等于语义审查通过，更不等于人工批准已经完成。**

## 前置条件

- 已安装 `git`、`bash`、`yq`
- 建议目标项目已初始化 Git 仓库

## 工作流

### 单分支工作流（最常见）

适用于大多数变更，所有阶段都在一个分支完成。

```bash
# 1. 创建工作区目录
mkdir -p /home/admin/sanguo
cd /home/admin/sanguo

# 2. 安装共享资源
/home/admin/.codespec/scripts/install-workspace.sh .

# 3. 创建项目 clone
git clone <REPO_URL> main
cd main

# 4. 初始化 dossier
/home/admin/sanguo/.codespec/scripts/init-dossier.sh

# 5. 完成所有阶段
codespec start-requirements
# ... 完成 spec.md
codespec start-design
# ... 完成 design.md
codespec start-implementation WI-001
# ... 实现 WI-001
codespec start-testing
# ... 测试
codespec start-deployment
# ... 部署
codespec complete-change
```

**目录结构**：
```
/home/admin/sanguo/              # 工作区目录
├── .codespec/                   # 共享 runtime
├── lessons_learned.md           # 共享经验教训
├── phase-review-policy.md       # 共享审查策略
├── versions/                    # 共享版本快照
└── main/                        # Git clone
    ├── .git/
    ├── spec.md                  # dossier 文件直接在根目录
    ├── design.md
    ├── meta.yaml
    ├── work-items/
    ├── testing.md
    ├── CLAUDE.md
    ├── AGENTS.md
    └── src/
```

### 多分支并行工作流（复杂项目）

适用于需要并行开发的大型变更。

```bash
# 1. 创建工作区并安装共享资源
mkdir -p /home/admin/sanguo
cd /home/admin/sanguo
/home/admin/.codespec/scripts/install-workspace.sh .

# 2. 在 main clone 完成 Proposal → Requirements → Design
git clone <REPO_URL> main
cd main
git checkout -b feature/add-auth
/home/admin/sanguo/.codespec/scripts/init-dossier.sh

codespec start-requirements
# ... 完成 spec.md
codespec start-design
# ... 完成 design.md，建议开 2 个分支并行

# 3. 提交并推送 design
git add .
git commit -m "docs: complete design for add-auth"
git push -u origin feature/add-auth

# 4. 创建其他 clone 用于并行执行
cd /home/admin/sanguo
git clone <REPO_URL> sanguoA
git clone <REPO_URL> sanguoB

# 5. 在各 clone 创建执行分支
cd sanguoA
git checkout feature/add-auth
git checkout -b group/sanguoA
yq eval '.execution_branch = "group/sanguoA"' -i meta.yaml

cd ../sanguoB
git checkout feature/add-auth
git checkout -b group/sanguoB
yq eval '.execution_branch = "group/sanguoB"' -i meta.yaml

# 6. 并行实现
cd /home/admin/sanguo/sanguoA
codespec start-implementation WI-001
# ... 实现 WI-001

cd /home/admin/sanguo/sanguoB
codespec start-implementation WI-002
# ... 实现 WI-002

# 7. 合并回 feature 分支
cd /home/admin/sanguo/main
git merge group/sanguoA
git merge group/sanguoB

# 8. Testing → Deployment 在 main clone
codespec start-testing
codespec start-deployment
codespec complete-change
```

**目录结构**：
```
/home/admin/sanguo/              # 工作区目录
├── .codespec/                   # 共享 runtime
├── lessons_learned.md
├── phase-review-policy.md
├── versions/
├── main/                        # Git clone（parent feature 分支）
│   ├── .git/
│   ├── spec.md
│   ├── design.md
│   └── src/
├── sanguoA/                     # Git clone（执行分支 A）
│   ├── .git/
│   ├── spec.md
│   ├── design.md
│   └── src/
└── sanguoB/                     # Git clone（执行分支 B）
    ├── .git/
    └── src/
```

## 文件修改规则

**重要**：为避免 Git 合并冲突，某些文件只能在 parent feature 分支修改。

| 文件 | 修改规则 | 原因 |
|------|---------|------|
| `spec.md` | 只在 parent feature 分支修改 | 需求和验收标准是全局的 |
| `design.md` | 只在 parent feature 分支修改 | 架构设计是全局的 |
| `work-items/*.yaml` | 只在 parent feature 分支修改 | WI 定义是全局的 |
| `contracts/*.md` | 只在 parent feature 分支修改 | 契约是全局的 |
| `testing.md` | 只在 parent feature 分支修改 | 集成测试记录是全局的 |
| `deployment.md` | 只在 parent feature 分支修改 | 部署计划是全局的 |
| `meta.yaml` | 各执行分支可以修改 | 记录当前执行上下文 |
| `src/**` | 各执行分支可以修改 | 业务代码，各分支独立开发 |

**工作流**：
1. 在 parent feature 分支（main/ 目录）修改 spec.md, design.md
2. 提交并推送到远程仓库
3. 各执行分支（sanguoA/, sanguoB/）通过 `git pull origin feature/xxx` 同步
4. 执行分支只修改 src/** 和 meta.yaml
5. 执行分支完成后，合并回 parent feature 分支
6. 如果执行分支修改了受限文件，pre-commit hook 会报错

## 常用命令

### 工作区管理
```bash
# 安装工作区共享资源
/path/to/.codespec/scripts/install-workspace.sh /home/admin/sanguo

# 在项目根目录初始化 dossier
cd /home/admin/sanguo/main
/home/admin/sanguo/.codespec/scripts/init-dossier.sh
```

### 生命周期命令
```bash
# 所有命令都在项目根目录执行，自动推断上下文
cd /home/admin/sanguo/main

codespec start-requirements
codespec start-design
codespec add-work-item WI-001
codespec start-implementation WI-001
codespec set-active-work-items WI-001,WI-002
codespec start-testing
codespec start-deployment
codespec complete-change
```

### 状态查询
```bash
codespec status
codespec readset
codespec readset --json
codespec check-gate proposal-maturity
```

### 版本管理
```bash
codespec promote-version v1.0.0
```

## design.md 的分支策略建议

v2.0 的 `design.md` 包含以下新章节，帮助你决定是否需要多分支并行：

### Dependency Analysis
纯依赖分析，标注 WI 之间的依赖关系和置信度：
```yaml
dependency_graph:
  WI-001:
    depends_on: []
    blocks: [WI-002, WI-003]
    confidence: high
  WI-002:
    depends_on: [WI-001]
    blocks: []
    confidence: medium
```

### Parallel Recommendation
基于依赖拓扑的并行分组建议：
```yaml
parallel_groups:
  - group: G1
    work_items: [WI-001]
    can_parallel: false
    rationale: 是其他 WI 的前置依赖
  - group: G2
    work_items: [WI-002, WI-003]
    can_parallel: true
    rationale: 都依赖 WI-001，彼此独立
```

### Branch Strategy Recommendation
Claude 生成的分支策略建议（仅供参考）：
```yaml
recommended_branch_count: 1
rationale: |
  建议单分支串行执行，原因：
  1. WI-002 和 WI-003 虽然可以并行，但都修改 src/auth/
  2. 依赖关系可能在执行中才暴露
  3. 单分支合并成本为零

alternative_if_parallel_needed: |
  如果时间紧迫，可以考虑 2 个分支：
  - Branch A: WI-001（必须先完成并合并）
  - Branch B: WI-002, WI-003（等 Branch A 合并后开始）
```

### Shared Surface Analysis
分析哪些文件可能被多个 WI 修改，提前识别潜在冲突：
```yaml
potentially_conflicting_files:
  - path: src/types/user.go
    reason: WI-001 定义 User 结构体，WI-003 添加 Session 字段
    recommendation: 在 parent feature 分支先定义接口
```

### Pre-work for Parent Feature Branch
建议在开分支之前，先在 parent feature 分支做这些事：
```yaml
tasks:
  - task: 定义 src/types/user.go 的基础结构
    content: |
      type User struct {
          ID       string
          Username string
          // WI-001 will add: Email, Password
          // WI-003 will add: SessionID, LastLogin
      }
    rationale: 避免多个分支同时修改同一个结构体定义
```

**重要**：以上所有建议仅供参考，不做强校验。最终是否采用多分支并行，完全由你决定。

## 手动补装/重装 Git hooks

```bash
cd /home/admin/sanguo/main
codespec install-hooks
```

## 框架回归验证（可选）

```bash
bash /home/admin/.codespec/scripts/smoke.sh
```

## 从 v1.x 迁移到 v2.0

参见 [MIGRATION.md](MIGRATION.md)。
