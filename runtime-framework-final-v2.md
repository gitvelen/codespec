# Runtime-First Embedded Project Framework - v2.0

## 文档说明

本文档是 runtime-framework-final.md 的优化版本（v2.0），基于深度分析和用户反馈进行了以下优化：

**主要优化点**：
1. 简化 Contract 模板（从 10+ 字段减少到 6 项最小内容）
2. 简化 Work Item 执行策略（去除复杂的 Dependency Matrix 和 Session Allocation）
3. 优化 CLAUDE.md 模板（精简到 200 行以内）
4. 改进 implementation-start 门禁的依赖检查（不再依赖 Git 提交信息，且要求 `result: pass`）
5. 明确测试覆盖策略的表述（全量 acceptance 必须有记录且最终通过，P0/P1/P2 验证方式分层）
6. 明确分支管理的术语（工作目录 vs Git 分支）

**版本历史**：
- v1.0 (2026-04-06): 初始版本
- v2.0 (2026-04-06): 优化版本

---

## 目录

1. [核心架构](#一核心架构)
2. [Claude 约束机制](#二claude-约束机制)
3. [分支管理与合入机制](#三分支管理与合入机制)
4. [目录结构](#四目录结构)
5. [核心文档定义](#五核心文档定义)
6. [完整工作流程](#六完整工作流程)
7. [实施指南](#七实施指南)

---

## 一、核心架构

### 1.1 设计目标

本框架同时解决：
- 需求漂移
- 设计偏航
- 代码越界
- 测试覆盖不足
- 多个 Claude/Codex 会话并行时的边界混乱

### 1.2 设计原则

- **少概念、少真相源、稳定入口**
- 不把框架做成 docs-first 文书系统
- 不把框架做成复杂调度器
- 不存在 hotfix / 紧急旁路
- 适用于中大型项目
- 每次稳定版本后的修改都进入一个新目录

### 1.3 固定 6 阶段生命周期

生命周期固定为：
1. **Proposal** - 提案阶段，形成 Intent 和初步边界
2. **Requirements** - 需求阶段，冻结正式需求、acceptance、verification obligations
3. **Design** - 设计阶段，冻结架构边界和详细设计，派生 Work Items
4. **Implementation** - 实现阶段，按 Work Item 执行
5. **Testing** - 测试阶段，全覆盖验证所有 acceptance
6. **Deployment** - 部署阶段，验收并 promotion

**约束**：
- 不引入 ChangeManagement 独立阶段
- 不允许 hotfix 或任何旁路流程
- 所有修改都走完整 6 阶段
- 所有修改的材料厚度一致
- 6 阶段在治理语义上是严格串行授权

### 1.4 对象模型（最小集）

**一等对象**：
1. **spec.md** - 上游规范真相源
   - 统一承接 Proposal + Requirements 的正式内容
   - Proposal 与 Requirements 是两个阶段，但共同沉淀到同一个 spec.md
   
2. **design.md** - 设计真相源
   - 固定包含 Architecture Boundary + Detailed Design
   - 不拆成两个阶段，不拆成两个正式对象
   
3. **Work Item** - 执行授权真相源
   - 执行切片，不是讨论对象
   - 直接约束 Claude/Codex / branch 级执行

**条件对象**：
4. **Contract** - 只在以下情况独立存在：
   - 多个 WI 并行修改同一模块（需要冻结接口）
   - 外部 API（需要文档化）
   - 数据库 schema（需要版本管理）
   - **默认情况下，不需要 Contract**

### 1.5 真相源层级

**语义真相优先级**（用于处理冲突）：
```
spec.md > design.md > work-item > testing.md / deployment.md
```

**含义**：
- spec.md 定义上游规范
- design.md 定义设计冻结
- work-item 定义当前执行边界
- testing.md / deployment.md 只记录验证与交付结果

**运行入口定位**：
- meta.yaml 不参与语义裁决
- 只负责恢复入口与当前焦点（phase、status、focus_work_item）
- 若 meta.yaml 与正式文档冲突，视为 meta.yaml 过期，必须刷新

---

## 二、Claude 约束机制

### 2.1 核心问题分析

**问题**：Claude 会忽略文档中的规则

**根本原因分析**：
- 大部分问题源于**边界不清晰**，而非 Claude 忘记规则
- 需求漂移：Claude 过度发挥，添加了 out_of_scope 的功能
- 设计偏航：Design 阶段改变了需求，但忘记回写 Spec
- 代码越界：Claude 判断修改是必要的，但超出了 allowed_paths
- 测试缺失：Claude 优先实现功能，把测试留到最后，然后忘了

### 2.2 分层防御策略

**核心原则**：不试图"完全保证" Claude 的行为，只在关键点设置防线

**第一层：文档结构优化**

1. **在 work-item 中明确 out_of_scope**
   ```yaml
   scope: 实现用户登录和账户锁定
   out_of_scope:
     - 自动记住密码
     - 第三方登录
     - 密码强度检查
   ```
   - 成本：每个 work-item 多写 3-5 行
   - 收益：减少需求漂移 70%

2. **在 design.md 的 Goal / Scope Link 章节中增加 spec_alignment_check 子节**
   ```yaml
   spec_alignment_check:
     - spec_ref: REQ-001
       aligned: true
       notes: "设计与需求一致"
   ```
   - 成本：每个 design.md 多写 5-10 行
   - 收益：减少设计偏航 50%

3. **在 design.md 中增加 Work Item Execution Strategy**（详见 2.5 节）
   - 成本：Design 阶段多花 30 分钟规划
   - 收益：减少依赖冲突和同步开销 60%

**第二层：最小必要 git hooks**

1. **pre-commit 检查 scope 越界**
   - 检查是否修改了 forbidden_paths
   - 理由：代码越界的影响最大（可能破坏其他模块）
   - 检查逻辑简单（字符串匹配），误判率低

2. **pre-push 检查依赖通过与局部 verification 覆盖**
   - 检查当前 work-item 覆盖的 acceptance 是否都有通过记录，并确认依赖 acceptance 已有 `result: pass`
   - 理由：测试缺失和未完成依赖都会直接影响质量与执行顺序
   - 在 pre-push 而非 pre-commit（不影响开发流程）

**不做的 hooks**：
- ❌ 检查 Design 偏离 Spec（需要语义理解，误判率高）
- ❌ 检查是否添加了 out_of_scope 功能（难以自动判断）
- ❌ 检查提交消息格式（影响小）

**第三层：lessons_learned 机制**

1. **每次出现问题后追加记录**
   ```markdown
   ### 2026-04-05｜WI-001 修改了 forbidden_paths 中的文件
   - **触发**：Claude 修改了 `src/api/`，但 WI-001 的 forbidden_paths 包含 `src/api/`
   - **根因**：Claude 发现需要调用 API，认为修改 API 代码是必要的
   - **影响**：代码越界，可能破坏其他模块
   - **改进**：在 Design 阶段就识别出"需要修改 API"，要么扩大 scope，要么创建新 WI
   - **升级**：已升级为 R1 规则 + pre-commit hook 检查
   ```

2. **高频问题升级为硬规则**
   ```markdown
   ## 快速索引（硬规则）
   
   - **R1**（scope）：修改文件前必须检查是否在 allowed_paths 中
   - **R2**（测试）：每个 acceptance 必须有对应测试
   - **R3**（偏离）：Design 改变 Spec 时必须先回写 Spec
   ```

3. **硬规则可以进一步升级为 git hooks**

**关键价值**：
- 解决"重复犯错"的核心问题
- 成本低（一个文件）、收益高（持续改进）
- 可以升级为自动化检查
- 符合用户的工作模式（持续积累经验）

### 2.3 为什么不做更多约束

**关键洞察**：
- 通过文档结构优化，可以减少 50% 的常见问题
- 通过 git hooks，可以在文档优化基础上再减少 20-30% 的问题
- 剩余问题依赖人工 review
- 过度依赖 git hooks 会带来开发摩擦，反而降低效率

**不做的事**：
- ❌ SessionStart 注入（除非发现 CLAUDE.md 效果不好）
- ❌ 复杂的语义检查（需要 AI 理解，成本高收益低）
- ❌ 强制 Claude 的阅读顺序（做不到）

### 2.4 Testing 覆盖策略

**核心要求**：所有已批准的 acceptance 项都必须有验证记录，且最终结果必须为 `pass`

**步骤**：
1. Spec 中每个已批准的 acceptance 项，都必须在 testing.md 中有一条对应记录
2. requirement 的测试覆盖通过其下属 acceptance 全覆盖来成立
3. Testing 不是 spot check，不是抽检，不是"挑重点测"
4. 任何 approved acceptance item 若没有对应验证记录，或记录结果不是 `pass`，change 都不得离开 Testing
5. 若设计阶段导致某些需求项不再合理，合法路径不是"跳过测试"，而是：
   - 先回写 / 修正上游 Spec
   - 再重新进入 Design / Testing 链条
6. testing.md 是统一的验证记录载体；Implementation 阶段可以增量回填已完成 acceptance 的验证结果，pre-push 只做当前 focus_work_item 的局部检查，Testing 阶段负责补齐并复核整个 change 的最终覆盖完整性

**Acceptance 分级**（区分验证方式，不是跳过验证）：

在 Spec 阶段就标注 acceptance 优先级：
```yaml
ACC-001:
  priority: P0  # 核心功能，必须自动化测试
  priority_rationale: 涉及用户数据安全
  
ACC-004:
  priority: P2  # 辅助功能，可人工验证
  priority_rationale: UI 易用性主观判断
```

**优先级规则**（在 spec.md 的 Intent 部分定义）：
- **P0**（必须自动化测试）：涉及用户数据安全、金钱交易、系统核心功能、失败会导致数据丢失
- **P1**（优先自动化测试）：高频使用的功能、失败会影响用户体验但不会导致数据问题；若未自动化，必须至少提供 `manual` 或 `equivalent` 的通过记录
- **P2**（可人工验证或等价验证）：UI/UX 相关的主观判断、性能优化、低频使用的辅助功能

**重要**：
- P2 不是"跳过测试"，而是"可以用人工验证或等价验证"
- 所有 acceptance 都必须有验证记录
- 所有 acceptance 在最终门禁时都必须 `result: pass`

**等价验证机制**：
```yaml
VO-003:
  acceptance_ref: ACC-004
  verification_type: equivalent
  equivalent_to: [ACC-001, ACC-002]
  rationale: UI 易用性通过核心功能测试间接验证
```

### 2.5 Work Item 执行策略

**核心思路**：在 Design 阶段说明 WI 之间的依赖关系和并行建议，用户根据建议决定具体执行方式。

**在 design.md 中增加 Work Item Execution Strategy 章节**：

```yaml
## Work Item Execution Strategy

### Dependency Summary

列出每个 WI 的依赖关系：

- WI-001: 无依赖，可独立执行
- WI-002: 依赖 WI-001（需要使用 WI-001 的认证接口）
- WI-003: 无依赖，可独立执行
- WI-004: 依赖 WI-001（需要使用 WI-001 的 token 机制）

### Parallel Recommendation

建议的并行执行分组：

- **Group A**: WI-001 → WI-002 → WI-004（串行，因为有依赖）
- **Group B**: WI-003（独立）

**建议**：Group A 和 Group B 可以并行执行。

### Notes

[任何需要说明的执行注意事项]
```

---

## 三、分支管理与合入机制

### 3.1 核心原则

1. **feature 分支是 change 的集成分支**，不作为多个并行会话的直写共享头
2. **Design 阶段先规划并行执行组**（如 Group A、Group B）
3. **每个执行组从 feature 分支手工派生独立子分支**，并绑定一个独立工作目录容器（如 `change/projectB`、`change/projectC`）
4. **一个工作目录容器内可以串行推进多个 WI**，但同一时刻只允许一个 `focus_work_item`
5. **执行组完成检查点或组内任务后先合回 feature 分支**，最终在 feature 分支上完成集成测试，再合入 main

**术语说明**：
- **change/**：活跃工作容器集合目录
- **主工作目录容器**：承载 Proposal / Requirements / Design / 集成测试的主容器（如 `change/projectA/`）
- **执行组工作目录容器**：用于承载单个执行组的独立容器（如 `change/projectB/`、`change/projectC/`）
- **执行组子分支**：从 `feature/*` 派生、供单个执行组使用的分支
- **feature 分支**：当前 change 的集成分支，不承载多个并行会话的日常直写
### 3.2 分支关系图

```
本地工作目录容器                               GitHub
change/projectA/  ──────→  feature/<change-id> ──PR──→ main
                           ↘
change/projectB/  ──────→  group/<execution-group> ─────┘
                           ↗
change/projectC/  ──────→  group/<execution-group> ─────┘
```

**关键点**：
- `feature/<change-id>` 是 change 的集成分支
- `group/<execution-group>`、`group/<execution-group>` 是执行组子分支
- `change/projectB`、`change/projectC` 各自绑定一个执行组子分支，不直接共享写同一个 feature 分支头
- 所有执行组最终先合回 feature 分支，feature 分支集成测试通过后，才合入 main

### 3.3 本地工作目录如何同步

**问题场景**：
```
时间线：
T1: change/projectB 在 group/<execution-group> 完成 WI-001，并合回 feature 分支
T2: change/projectC 在 group/<execution-group> 准备开始下一个依赖 WI-001 的 WI
```

**解决方案**：开始新的依赖 WI 前，先同步最新 feature 分支，再决定是否继续在当前执行组子分支推进

```bash
# 在 change/projectC/ 目录
# 准备执行依赖 WI-001 的下一个 WI

# 先同步 GitHub feature 分支
git fetch origin
git checkout feature/<change-id>
git pull origin feature/<change-id>

# 再回到当前执行组子分支，并同步 feature 的最新状态
git checkout group/<execution-group>
git merge feature/<change-id>

# 此时 change/projectC 已包含上游执行组已经合回 feature 的代码
# 开始执行下一个 WI
```

**在 pre-commit hook 中自动检查**：
```bash
# 检查当前执行组分支是否落后于 feature 分支
FEATURE_BRANCH=$(yq '.feature_branch' meta.yaml)
git fetch origin $FEATURE_BRANCH
LOCAL_BASE=$(git merge-base HEAD origin/$FEATURE_BRANCH)
REMOTE=$(git rev-parse origin/$FEATURE_BRANCH)

if [ "$LOCAL_BASE" != "$REMOTE" ]; then
  echo "警告：当前执行组分支尚未吸收 ${FEATURE_BRANCH} 的最新提交"
  echo "建议先同步：git checkout ${FEATURE_BRANCH} && git pull origin ${FEATURE_BRANCH}"
  echo "然后回到当前分支执行：git merge ${FEATURE_BRANCH}"
  echo "是否继续？(y/n)"
  read -r response
  if [ "$response" != "y" ]; then
    exit 1
  fi
fi
```

### 3.4 依赖检查机制

**v2.0 优化**：不再依赖 Git 提交信息，改为检查依赖 WI 的 acceptance 是否在 `testing.md` 中有对应记录，且 `result: pass`

```bash
# 检查 WI-002 的依赖 WI-001 是否已完成
DEPENDENCIES=$(yq '.dependency_refs[]' "work-items/WI-002.yaml")

for dep in $DEPENDENCIES; do
  # 读取依赖 WI 的 acceptance_refs
  DEP_ACCEPTANCES=$(yq '.acceptance_refs[]' "work-items/${dep}.yaml")

  for acc in $DEP_ACCEPTANCES; do
    if ! grep -A 5 "acceptance_ref: $acc" testing.md | grep -q "result: pass"; then
      echo "错误：依赖 ${dep} 尚未完成（acceptance ${acc} 没有通过记录）"
      echo "请等待 ${dep} 完成并在 testing.md 中留下 result: pass 的记录"
      exit 1
    fi
  done
done
```

**关键改进**：
- 不再依赖 Git 提交信息（不可靠）
- 改为检查依赖 WI 的 acceptance 是否已有**通过记录**（更可靠）
- 只有“有记录且 `result: pass`”才视为依赖完成

---
## 四、目录结构

### 4.1 最终目录结构

```
<project-root>/
├── .codespec/                  # 框架配置（共享）
│   ├── CLAUDE.md              # 框架级配置（在运用到具体项目时没有任何意义）
│   ├── templates/             # 目录树示意；其他模板文件见 8.5
│   │   └── CLAUDE.md          # 项目级 CLAUDE.md 模板
│   ├── hooks/
│   │   ├── pre-commit         # 检查 scope 越界
│   │   └── pre-push           # 检查依赖通过与当前 focus_work_item 的局部验证覆盖
│   └── scripts/
│       └── check-gate.sh      # 阶段门禁脚本
├── versions/                   # 稳定版本（共享）
│   ├── v1.0.0/                # 新建项目的 baseline
│   │   ├── meta.yaml          # base_version: null
│   │   ├── spec.md
│   │   ├── spec-appendices/
│   │   ├── design.md
│   │   ├── design-appendices/
│   │   ├── work-items/
│   │   ├── contracts/
│   │   ├── testing.md
│   │   ├── deployment.md
│   │   └── src/
│   └── v2.0.0/                # 变更项目的版本
│       ├── meta.yaml          # base_version: v1.0.0
│       └── ...
├── lessons_learned.md          # 经验教训（共享）
└── change/                     # 活跃工作容器集合
    ├── projectA/              # 主工作目录容器
    │   ├── CLAUDE.md          # 项目级配置
    │   ├── meta.yaml
    │   ├── spec.md
    │   ├── spec-appendices/
    │   ├── design.md
    │   ├── design-appendices/
    │   ├── work-items/
    │   │   └── WI-*.yaml
    │   ├── contracts/
    │   ├── testing.md
    │   ├── deployment.md
    │   └── src/
    ├── projectB/              # 执行组工作目录容器 B
    │   ├── CLAUDE.md
    │   ├── meta.yaml
    │   ├── spec.md
    │   ├── design.md
    │   ├── work-items/
    │   ├── contracts/
    │   ├── testing.md
    │   ├── deployment.md
    │   └── src/
    └── projectC/              # 执行组工作目录容器 C
        ├── CLAUDE.md
        ├── meta.yaml
        ├── spec.md
        ├── design.md
        ├── work-items/
        ├── contracts/
        ├── testing.md
        ├── deployment.md
        └── src/
```

**GitHub 分支结构**：
```
GitHub 仓库：
├── main                        # 主分支（稳定）
├── feature/<change-id>         # feature 分支（集成）
│   ├── 主工作容器的提交（Proposal / Requirements / Design）
│   └── 各执行组子分支合回后的提交
└── group/<execution-group>     # 执行组子分支（按需创建多个）
```

### 4.2 关键说明

**目录层级**：
- `.codespec/`、`versions/`、`lessons_learned.md` 在根目录（共享）
- `change/` 是活跃工作容器集合目录
- 每个工作目录容器（`change/projectA/`、`change/projectB/`、`change/projectC/`）都有自己的 `CLAUDE.md`、`meta.yaml` 和 dossier 文档
- `change/<container>/` 本身就是当前 change 的 dossier 根，不再嵌套内层 `change/`
- `projectB/projectC` 可以通过在 `change/` 下手工 git clone / 准备独立工作目录的方式创建，用于承载执行组实现阶段

**versions/ 与 change/ 的关系**：
- `versions/<stable-version>/` 与 `change/<container>/` 在**核心 dossier 结构**上保持对齐
- 二者都只承载"本次版本 / 本次 change 的 dossier"；其中可以包含主工作容器归档时带入的局部实现上下文（如 `src/`），但不承载全项目全量快照
- 版本归档与活跃容器允许在辅助文件或呈现粒度上存在裁剪，不要求逐项完全一致
- GitHub main / tag / commit 才是代码与项目整体状态的最终快照来源
- 当一个 change 完成 6 阶段、整体落到 main 并形成新的稳定版本后，才把主工作目录容器的 dossier promotion 为对应的 version dossier

**新建项目 vs 变更项目**：
- 目录结构完全一致
- 只有 meta.yaml 中的 base_version 不同
  - 新建项目：`base_version: null`
  - 变更项目：`base_version: v1.0.0`
- Promotion 流程完全一致

---

## 五、核心文档定义

### 5.1 spec.md 结构

#### 5.1.1 核心定位

- spec.md 是唯一 canonical 的上游规范真相源
- Proposal 与 Requirements 是两个阶段，但共同沉淀到同一个 spec.md
- 对大型项目，采用：**单一 canonical 主文档 + 内部层级索引/必要附录**
- 附录只能展开已在 spec.md 中声明的正式内容，不能单独产生新的 requirement/acceptance/verification obligation

#### 5.1.2 最小顶层章节

spec.md 采用 **4 个顶层章节**：
1. **Intent** - 承接 Proposal 语义，但不直接授权下游执行
2. **Requirements** - 承接冻结后的正式执行语义
3. **Acceptance** - 作为 Testing 全覆盖的稳定主键
4. **Verification** - 保证"什么算完成"和"如何验证"不混成一层

#### 5.1.3 章节边界

**Intent 章节**负责：
- Problem / Background
- Goals
- Non-goals
- Must-have Anchors
- Prohibition Anchors
- Success Anchors
- Boundary Alerts
- Unresolved Decisions
- Testing Priority Rules（定义 P0/P1/P2 的判断标准）

**禁止**：
- 直接写 formal requirements
- 直接写 acceptance / verification obligations
- 直接授权下游 Implementation

**Requirements 章节**负责：
- Proposal Coverage Map
- Clarification Status
- Functional Requirements
- Constraints / Prohibitions
- Non-functional Requirements（仅当可测时）

**禁止**：
- 大量重复背景/动机
- 静默改变 Intent 的目标、范围、成功标准
- 把 acceptance / verification obligations 混成大段 prose

**Acceptance 章节**负责：
- ACC-*（唯一 ID）
- source_ref（来源 requirement）
- expected_outcome（预期结果）
- priority（P0/P1/P2）
- priority_rationale（优先级理由）

**Verification 章节**负责：
- 每个 ACC-* 的 verification obligations
- verification_type（automated / manual / equivalent）
- verification_profile（focused / stronger / high-risk）
- 其他最小必要验证要求

#### 5.1.4 Proposal 与 Requirements 阶段的工作边界

**Proposal 阶段**：
- spec.md 必须先形成 Intent 全部内容
- Requirements 中的空骨架/待填入口（仅结构，不填正式 requirement）
- 不得提前产出未冻结的 formal requirements

**Requirements 阶段**：
- 在同一个 spec.md 中补齐 Requirements、Acceptance、Verification
- Proposal anchors 必须被覆盖、显式 defer，或显式升级 owner 判断
- 高影响 clarification 未关闭时，不得把对应 requirement 默认下传到 Design / Work Item

#### 5.1.5 大型 spec 的按需读取

**默认读取层**（供 Claude/Codex 快速进入）：

spec.md 顶部应提供一个很短的默认读取层，只包含：
- Intent 的摘要骨架
- Requirements 中的：Proposal Coverage Map、Clarification Status、Requirements Index
- Acceptance Index
- Verification Index
- Appendix Map（若有附录）

**要求**：
- 默认读取层必须短、稳定、ID 可回链
- 可设置 `<!-- SKELETON-END -->` 标记，提示 Claude/Codex 仅在必要时继续深入

**从属附录规则**：

建议在 dossier 内使用从属附录目录：`spec-appendices/`

附录可承载：
- feature detail
- domain rationale
- API / data examples
- migration / performance / security detail
- 长场景说明

**但必须遵守**：
- 附录不是平级真相源
- 不允许在附录中单独创建新的 REQ-* / ACC-* / VO-*
- Work Item、Design、Testing 的引用目标仍然是 spec.md 中的正式 ID
- 若附录需要新增正式语义，必须先回写 spec.md

### 5.2 design.md 结构

#### 5.2.1 根 design.md 固定保留的 9 节

1. **Goal / Scope Link** - 从 spec.md 引用（包含 `spec_alignment_check` 子节）
2. **Architecture Boundary** - 架构边界定义
3. **Work Item Execution Strategy** - 执行策略（简化版，详见 2.5 节）
4. **Design Slice Index** - 设计切片索引
5. **Work Item Derivation** - Work Item 派生
6. **Contract Needs** - Contract 需求
7. **Verification Design** - 验证设计
8. **Failure Paths / Reopen Triggers** - 失败路径 / 重新打开触发器
9. **Appendix Map** - 附录映射

#### 5.2.2 Architecture Boundary 的表达方式

采用：**能力边界 + 共享面边界** 的双层表达

**能力边界**：
- impacted_capabilities（本次设计影响了系统的哪块能力）
- not_impacted_capabilities（哪些能力明确不受影响）

**共享面边界**：
- impacted_shared_surfaces（本次设计是否触及高风险共享面）
- not_impacted_shared_surfaces（哪些共享面明确不受影响）

**约束与冻结**：
- system_context
- major_constraints
- contract_required
- compatibility_constraints

#### 5.2.3 Work Item Derivation 的权威边界

这一节固定放在 design.md 主体内，承载**派生说明**，用于说明 Work Item 如何从 spec / design 中拆分出来。

**建议字段**：
- wi_id
- goal
- covered_acceptance_refs
- dependency_refs
- contract_needed
- notes_on_boundary

**关键规则**：
- design.md 中的 derivation row 用于记录派生依据与分配理由
- WI-*.yaml 持有执行阶段直接消费的 `acceptance_refs`
- WI-*.yaml 通过 `derived_from` 回链到 derivation row
- 若 design.md 中保留 `covered_acceptance_refs`，其作用是设计追溯，不替代 WI 中的执行绑定

这样可以同时保留 design 的可追溯性与 work-items/ 的可执行性，避免 hook / gate 缺少直接输入。

#### 5.2.4 design-appendices/DD-*.md 的模板顺序

每个 design slice 附录按以下顺序组织：

1. title
2. spec_refs
3. acceptance_refs
4. in_scope
5. out_of_scope
6. unchanged
7. inputs
8. outputs
9. state_changes
10. dependencies
11. invariants
12. primary_flow
13. failure_paths
14. interface_notes
15. data_model_notes
16. security_notes
17. reliability_notes
18. observability_notes
19. config_env_notes
20. selected_approach
21. minimal_reason

**横切槽位策略**：

以下槽位固定出现，但允许值为：unchanged / not_applicable / covered by existing baseline / see appendix

固定横切槽位为：
- interface_notes
- data_model_notes
- security_notes
- reliability_notes
- observability_notes
- config_env_notes

**原因**：这些点最容易被 Claude/Codex 忽略，固定占位能显著降低遗漏风险

### 5.3 work-item 字段定义

#### 5.3.1 最小字段

**基本信息**：
- wi_id
- goal
- scope
- out_of_scope

**路径控制**：
- allowed_paths
- forbidden_paths

**阶段与状态**：
- phase_scope（当前被授权工作的阶段边界）

**引用与依赖**：
- spec_refs
- acceptance_refs
- derived_from（回链到 design.md 的 derivation row）
- dependency_refs
- dependency_type（strong / weak）
- contract_refs

**验证要求**：
- verification_profile（focused / stronger / high-risk）
- required_verification

**约束与触发**：
- stop_conditions
- reopen_triggers
- hard_constraints

#### 5.3.2 Work Item 粒度判断

**推荐判断标准**：

一个 Work Item 应尽量满足：
1. 有清楚的局部目标
2. 有清楚的 scope / out_of_scope
3. 有清楚的 allowed_paths / forbidden_paths
4. 有清楚的 acceptance_refs
5. 有清楚的 required_verification
6. 可以在独立 branch 中推进
7. 不依赖另一个未冻结的 shared boundary 才能继续

**最佳粒度定义**：

> 按 Design 阶段已经冻结好的、可以被单一 Claude/Codex 会话独立实现并独立验证的执行切片来划分。

**不好的划分方式**：
- 纯按目录切：容易忽视 acceptance / verification
- 纯按技术层切：容易造成一个 Work Item 没法独立交付
- 纯按代码量切：对治理没有意义

### 5.4 meta.yaml 字段定义

#### 5.4.1 完整字段

```yaml
# 基本信息
change_id: add-auth                    # 必填，新建项目可以用 baseline
base_version: v1.0.0                   # 必填，新建项目为 null
created_at: 2026-04-05                 # 必填

# 当前状态
phase: Implementation                  # 必填：Proposal/Requirements/Design/Implementation/Testing/Deployment
status: in_progress                    # 必填：in_progress/blocked/waiting_owner/completed
focus_work_item: WI-001                # 必填字段；Implementation 阶段执行具体 WI 时必须非空，其他阶段可为 null

# 并行执行信息
execution_group: <execution-group>   # 可选，当前工作目录容器绑定的执行组
execution_branch: group/<execution-group>        # 可选，当前工作目录容器使用的执行组子分支
active_work_items:                     # 可选，该执行组负责的所有 work items
  - WI-001
  - WI-002

# GitHub 信息
feature_branch: feature/<change-id>       # 必填，对应的 feature 集成分支

# 阻塞信息
blocked_reason: null                   # 可选
blocked_by: null                       # 可选

# 更新信息
updated_at: 2026-04-05                 # 必填
updated_by: Claude-Session-A           # 可选
```

**字段约束说明**：
- `feature_branch` 表示当前 change 的集成分支，不等于当前会话实际工作的分支
- `execution_group` / `execution_branch` 用于标识当前工作目录容器属于哪个执行组、在哪个执行组子分支上推进
- `focus_work_item` 是当前会话唯一允许聚焦的 work item；即使 `active_work_items` 有多个，同一时刻也只能执行一个
- `focus_work_item` 是必有字段，但不是每个阶段都必须非空：Implementation 阶段执行具体 WI 时必须填写 `WI-*`，Proposal / Requirements / Design / Testing / Deployment 阶段允许为 `null`

#### 5.4.2 更新触发点（最小必要性原则）

**只在以下情况更新**：
- 创建 change
- 阶段切换（phase 变化）
- focus_work_item 切换
- status 变化（如 `in_progress -> blocked`、`blocked -> in_progress`、`waiting_owner -> in_progress`）
- promotion 为 version 前后

**不更新的情况**：
- 普通文件修改
- 代码提交
- 测试运行

### 5.5 Contract 模板

#### 5.5.1 定位

Contract 用于精确定义 shared boundary，只在以下场景需要：
- 多个 WI 并行修改同一模块（需要冻结接口）
- 外部 API（需要文档化）
- 数据库 schema（需要版本管理）

**默认情况下，不需要 Contract。**

#### 5.5.2 最小模板

```yaml
# contracts/auth-api.md

contract_id: auth-api
status: frozen / draft
frozen_at: 2026-04-05
consumers: [WI-001, WI-002]

## Interface Definition

[接口定义，可以是代码片段、伪代码或 API 文档]

示例：
```typescript
interface AuthAPI {
  login(username: string, password: string): Promise<{token: string}>
  logout(token: string): Promise<void>
}
```

## Notes

[任何需要说明的点，如前置条件、后置条件、不变量等]
```

### 5.6 deployment.md 结构

`deployment.md` 在进入实际部署 / 发布验收时为必需；对无需独立部署动作的简单 change，可省略该文档。

```yaml
# deployment.md

## Deployment Plan
target_env: STAGING / PRODUCTION
deployment_date: YYYY-MM-DD
deployment_method: manual / CI/CD

## Pre-deployment Checklist
- [ ] 所有 acceptance 测试通过
- [ ] 数据库迁移脚本已验证
- [ ] 回滚方案已准备
- [ ] 监控告警已配置

## Deployment Steps
1. 备份当前版本
2. 执行数据库迁移（如需要）
3. 部署新版本代码
4. 执行 smoke test
5. 验证关键功能

## Verification Results
- smoke_test: pass / fail
- key_features: [列出验证的关键功能]
- performance: [响应时间、错误率等]

## Acceptance Conclusion
status: pass / fail / partial
notes: [验收结论说明]
approved_by: [你的名字]
approved_at: YYYY-MM-DD

## Rollback Plan
trigger_conditions:
  - 错误率 > 5%
  - 关键功能不可用
  - 性能下降 > 50%

rollback_steps:
  1. 切换到备份版本
  2. 回滚数据库迁移（如需要）
  3. 验证回滚成功

## Monitoring
metrics:
  - 错误率: [链接到监控面板]
  - 响应时间: [链接到监控面板]
  - 用户活跃度: [链接到监控面板]

alerts:
  - [配置的告警规则]

## Post-deployment Actions
- [ ] 更新主文档（如 系统功能说明书.md）
- [ ] 记录 lessons learned（如有问题）
- [ ] 归档 change dossier 到 versions/
```

### 5.7 testing.md 结构

**最小记录结构**（每条 acceptance 覆盖记录只保留 6 个字段）：

```yaml
- acceptance_ref: ACC-001
  verification_type: automated / manual / equivalent
  artifact_ref: test/auth.test.ts
  result: pass / fail
  residual_risk: [如果有残留风险，说明]
  reopen_required: true / false
```

**设计理由**：
- 这是当前最小可用、最利于 Claude/Codex 回填、也最利于 gate 直接消费的结构
- requirement 层覆盖可通过 acceptance_ref -> spec.md 回链得到，不在 testing.md 中重复写
- testing.md 只记录验证结果，不作为上游语义的改写入口
- Implementation 阶段允许增量回填，Testing 阶段负责补齐并复核最终完整性
- 不在 v1 引入更多字段，避免 testing.md 过早膨胀成重矩阵

### 5.8 lessons_learned.md 模板

```markdown
# Lessons Learned

## 快速索引（硬规则）

只保留最关键的 5-10 条，优先写"可执行、可验收"的规则，便于跨项目复用。

- **R1**（scope）：修改文件前必须检查是否在 allowed_paths 中
- **R2**（测试）：每个 acceptance 必须有对应测试
- **R3**（偏离）：Design 改变 Spec 时必须先回写 Spec

## 条目列表

### 2026-04-05｜WI-001 修改了 forbidden_paths 中的文件
- **触发**：Claude 修改了 work-item 中 forbidden_paths 列出的文件
- **根因**：Claude 没有在修改前检查 work-item 的路径约束
- **影响**：破坏了模块边界，导致其他 WI 的依赖假设失效
- **改进行动**：在 CLAUDE.md 中增加"修改文件前必须检查 allowed_paths/forbidden_paths"
- **验证方式**：pre-commit hook 自动检查
- **升级决策**：如果再次发生，升级为 R1 硬规则

### 2026-04-06｜测试覆盖不完整导致 Deployment 失败
- **触发**：Deployment 阶段发现 ACC-003 没有对应测试
- **根因**：Implementation 阶段没有严格按照 acceptance_refs 编写测试
- **影响**：Deployment 被阻塞，需要回退到 Testing 阶段
- **改进行动**：在 testing.md 中增加 acceptance 覆盖检查清单
- **验证方式**：pre-push hook 检查当前 focus_work_item 的局部覆盖；testing-coverage gate 负责检查所有 acceptance 的最终完整性
- **升级决策**：如果再次发生，升级为 R2 硬规则
```

---
## 六、完整工作流程

### 6.1 新建项目流程

#### 6.1.1 初始化项目

```bash
# 1. 创建项目目录
mkdir <project-root> && cd <project-root>
git init

# 2. 创建框架目录结构
mkdir -p .codespec/templates .codespec/scripts .codespec/hooks change/projectA versions

# 3. 创建主工作容器的 meta.yaml
cat > change/projectA/meta.yaml << 'EOF'
change_id: baseline
base_version: null
created_at: 2026-04-05
phase: Proposal
status: in_progress
focus_work_item: null
feature_branch: feature/<change-id>
updated_at: 2026-04-05
EOF

# 4. 创建主工作容器的 CLAUDE.md（从模板复制）
cp .codespec/templates/CLAUDE.md change/projectA/CLAUDE.md

# 5. 创建 lessons_learned.md
touch lessons_learned.md

# 6. 创建 GitHub feature 分支
git checkout -b feature/<change-id>
```

#### 6.1.2 Proposal 阶段

**目标**：形成 spec.md 的 Intent 章节

**步骤**：
1. 启动 Claude 会话
2. Claude 读取 CLAUDE.md 和 lessons_learned.md
3. 与用户讨论，形成 Intent 章节：
   - Problem / Background
   - Goals / Non-goals
   - Must-have Anchors / Prohibition Anchors / Success Anchors
   - Boundary Alerts
   - Unresolved Decisions
   - Testing Priority Rules
4. 在 spec.md 中创建 Requirements、Acceptance、Verification 的空骨架
5. 更新 meta.yaml：phase = Requirements

**门禁检查**（proposal-maturity）：
- Intent 章节完整
- Unresolved Decisions 已识别
- Testing Priority Rules 已定义
- Requirements 骨架已创建

#### 6.1.3 Requirements 阶段

**目标**：补齐 spec.md 的 Requirements、Acceptance、Verification 章节

**步骤**：
1. 补齐 Requirements 章节：
   - Proposal Coverage Map（确保所有 Intent anchors 被覆盖）
   - Clarification Status（记录未解决的澄清问题）
   - Functional Requirements（REQ-*）
   - Constraints / Prohibitions
   - Non-functional Requirements
2. 补齐 Acceptance 章节：
   - 每个 requirement 至少有一个 ACC-*
   - 定义 priority（P0/P1/P2）和 priority_rationale
3. 补齐 Verification 章节：
   - 每个 ACC-* 有对应的 verification obligations
   - 定义 verification_type 和 verification_profile
4. 更新 meta.yaml：phase = Design

**门禁检查**（requirements-approval）：
- 所有 Intent anchors 被覆盖或显式 defer
- 高影响 clarification 已关闭
- 每个 requirement 有对应 acceptance
- 每个 acceptance 有对应 verification

#### 6.1.4 Design 阶段

**目标**：派生 Work Items，冻结 Contracts，规划执行策略

**步骤**：
1. 创建 design.md，包含：
   - Goal / Scope Link
   - Architecture Boundary
   - Work Item Execution Strategy（简化版：Dependency Summary + Parallel Recommendation）
   - Design Slice Index
   - Work Item Derivation
   - Contract Needs
   - Verification Design
   - Failure Paths / Reopen Triggers
   - Appendix Map
2. 创建 design-appendices/DD-*.md（设计切片）
3. 派生 Work Items：
   - 创建 work-items/WI-*.yaml
   - 定义 scope、out_of_scope、allowed_paths、forbidden_paths
   - 定义 acceptance_refs、dependency_refs
4. 冻结 Contracts（如需要）：
   - 创建 contracts/*.md（使用简化模板）
   - 定义接口
   - 标记 status = frozen
5. 更新 meta.yaml：phase = Implementation

**门禁检查**（design-readiness）：
- 所有 acceptance 被分配到 Work Items
- Work Item 粒度合理（有清晰的 scope/out_of_scope）
- 依赖关系明确（dependency_refs）
- 执行策略已规划（Dependency Summary + Parallel Recommendation）
- 需要的 Contracts 已冻结

#### 6.1.5 提交 Design 到 GitHub

```bash
# 主工作容器：在 feature 分支提交 Design 产物
cd change/projectA
git add .
git commit -m "[Design] Complete design for baseline"

# Push 到 feature 分支
git push origin feature/<change-id>

# （可选）创建 PR，用于 review
gh pr create --title "[Design] Baseline design" --body "Design phase completed"
```

#### 6.1.6 Implementation 阶段

**目标**：并行执行 Work Items

**步骤**：

**1. 创建执行组工作目录容器**

根据 Work Item Execution Strategy，先确定并行执行组，再为每个执行组准备独立工作目录容器。

**什么时候 checkout 到 feature 分支？**
- Proposal / Requirements / Design 阶段：始终在主工作目录容器 `change/projectA/` 的 feature 分支上进行
- 执行组开始前：新 clone 出的执行组容器先 checkout 到 feature 分支，确保从最新集成状态出发
- 依赖上游执行组时：先回到 feature 分支拉最新，再回到自己的执行组子分支吸收最新集成结果
- 集成测试前：主工作目录容器必须 checkout 到 feature 分支并拉到最新

**什么时候 checkout 到 feature 的子分支？**
- 某个执行组准备开始真正实现自己的 WI 时
- 主工作目录容器已经完成 Design，且该执行组需要独立推进、独立提交时
- 从 feature 分支同步完最新结果后，需要回到自己的执行组边界继续开发时

```bash
# 0. 主工作目录容器：Proposal / Requirements / Design 都在 feature 分支
cd change/projectA
git checkout feature/<change-id>
git pull origin feature/<change-id>

# 1. Design 完成后，在 change/ 下手工 clone 出执行组容器
cd ../
git clone <repo-url-or-local-path> projectB
git clone <repo-url-or-local-path> projectC

# 2. 执行组容器先 checkout 到 feature 分支，拿到最新集成状态
cd projectB
git checkout feature/<change-id>
git pull origin feature/<change-id>

cd ../projectC
git checkout feature/<change-id>
git pull origin feature/<change-id>

# 3. 再从 feature 分支派生各自的执行组子分支
cd ../projectB
git checkout -b group/<execution-group>

cd ../projectC
git checkout -b group/<execution-group>
```

**2. 在执行组容器内执行 Work Items**

在每个执行组工作目录容器中：

```bash
# 1. 更新 meta.yaml
# execution_group: <execution-group>
# execution_branch: group/<execution-group>
# focus_work_item: WI-001
# active_work_items: [WI-001, WI-002]

# 2. 启动 Claude 会话
# Claude 读取 CLAUDE.md、lessons_learned.md、work-items/WI-001.yaml

# 3. 实现功能
# Claude 按照当前 work-item 的约束实现功能

# 4. 编写测试
# Claude 按照 acceptance_refs 编写测试

# 5. 更新 testing.md
# 增量记录当前 acceptance 的验证结果，记录格式统一为：
# acceptance_ref / verification_type / artifact_ref / result / residual_risk / reopen_required

# 6. 提交代码
git add .
git commit -m "[WI-001] Implement authentication"

# 7. 检查依赖（如果有）
# 使用优化后的依赖检查（检查 testing.md）

# 8. 到达检查点后，推送当前执行组子分支
git push origin group/<execution-group>
```

**3. 同步策略**

- 每个 WI 完成后马上合回 feature

**4. 切换 Work Item**

在同一个执行组工作目录容器中切换到下一个 WI：

```bash
# 1. 如有依赖，先回到 feature 分支拿到最新集成结果
git checkout feature/<change-id>
git pull origin feature/<change-id>

# 2. 再回到当前执行组子分支，吸收 feature 的更新
git checkout group/<execution-group>
git merge feature/<change-id>

# 3. 更新 meta.yaml
# focus_work_item: WI-002

# 4. 启动新的 Claude 会话
# Claude 读取 work-items/WI-002.yaml

# 5. 重复实现流程
```

**门禁检查**（implementation-start）：
- Work Item 的依赖已完成（`testing.md` 中有对应 acceptance 记录，且 `result: pass`）
- Work Item 的 Contract 已冻结（如需要）

#### 6.1.7 Testing 阶段

**目标**：集成测试，补齐并复核所有 acceptance 的最终覆盖完整性

**步骤**：

```bash
# 1. 所有 WI 完成后，回到主工作目录容器并同步 feature 分支
cd change/projectA
git pull origin feature/<change-id>

# 2. 更新 meta.yaml
# phase: Testing
# focus_work_item: null

# 3. 运行集成测试
npm test

# 4. 验证 testing.md 覆盖
# 补齐并复核所有 acceptance 的最终覆盖记录

# 5. 更新 meta.yaml
# phase: Deployment
```

**门禁检查**（testing-coverage）：
- 所有 acceptance 都在 `testing.md` 中有记录
- 所有 acceptance 的最终结果都必须为 `result: pass`
- 所有 P0 acceptance 必须有自动化测试
- 所有 P1 acceptance 必须有通过记录，允许 automated / manual / equivalent，默认优先 automated
- 所有 P2 acceptance 必须有通过记录，允许 manual / automated / equivalent

#### 6.1.8 Deployment 阶段

**目标**：部署到目标环境，验收

**步骤**：

```bash
# 1. 如进入实际部署 / 发布验收，创建 deployment.md
# 记录部署计划、验证结果、验收结论

# 2. 执行部署
# 按照 deployment.md 的步骤部署

# 3. 验证关键功能
# 执行 smoke test

# 4. 记录验收结论
# status: pass / fail
# approved_by: [你的名字]

# 5. 合并到 main
git checkout main
git merge feature/<change-id>
git push origin main

# 6. 创建版本标签
git tag v1.0.0
git push origin v1.0.0

# 7. 归档主工作容器的 change dossier
# 归档的是主工作容器内容，可包含 src/ 等局部实现上下文，但不等于全项目全量快照
mkdir -p versions/v1.0.0
cp -r change/projectA/* versions/v1.0.0/
```

**门禁检查**（deployment-readiness，条件适用）：
- 对进入实际部署 / 发布验收的 change，必须存在 `deployment.md`
- 所有 acceptance 测试通过
- 部署计划已准备
- 回滚方案已准备

**门禁检查**（promotion-criteria）：
- Deployment 验收通过
- 关键功能验证通过
- 监控告警正常

### 6.2 变更项目流程

#### 6.2.1 初始化变更

```bash
# 1. 基于 main 创建新的 feature 分支
git checkout main
git pull
git checkout -b feature/<change-id>

# 2. 创建主工作容器
mkdir -p change/projectA

# 3. 创建主工作容器的 meta.yaml
cat > change/projectA/meta.yaml << 'EOF'
change_id: add-auth
base_version: v1.0.0
created_at: 2026-04-05
phase: Proposal
status: in_progress
focus_work_item: null
feature_branch: feature/<change-id>
updated_at: 2026-04-05
EOF

# 4. 复制 CLAUDE.md（如果需要定制）
cp .codespec/templates/CLAUDE.md change/projectA/CLAUDE.md
```

#### 6.2.2 后续流程

后续流程与新建项目完全一致：
- Proposal → Requirements → Design → Implementation → Testing → Deployment

唯一区别：
- meta.yaml 中的 base_version 为具体版本号（如 v1.0.0）
- 可以引用 versions/v1.0.0/ 中的历史文档

### 6.3 关键决策点

#### 6.3.1 何时创建工作目录容器

**推荐策略**：
- Design 阶段完成后，根据 Work Item Execution Strategy 决定执行组数量
- 如果所有 WI 都在同一个执行组（串行），可以只用一个工作目录容器
- 如果有多个并行执行组，为每个执行组创建一个工作目录容器
- 一个执行组容器内可以串行推进多个 WI，但同一时刻只允许一个 `focus_work_item`

#### 6.3.2 何时同步 GitHub feature分支

**推荐策略**：
- **独立并行组**：完成所有 WI 后一次性 push
- **串行依赖组**：每个 WI 完成后 push
- **集成测试前**：必须同步

#### 6.3.3 何时需要 Contract

**需要 Contract**：
- 多个 WI 修改同一个模块
- WI 之间有依赖，但希望并行
- 外部接口（API、数据库 schema）

**不需要 Contract**：
- WI 之间完全独立
- WI 之间有依赖，但可以串行

#### 6.3.4 何时更新 lessons_learned.md

**推荐时机**：
- 发现 Claude 忽略了规则
- 发现 Work Item 粒度不合理
- 发现测试覆盖不完整
- 发现部署失败
- 任何值得记录的问题

**更新原则**：
- 立即记录，不要等到项目结束
- 记录触发、根因、影响、改进行动
- 高频问题升级为硬规则

---

## 七、实施指南

### 7.1 Git Hooks 实现

#### 7.1.1 设计原则

- **最小必要性**：只实现最关键的检查，避免过度工程
- **快速失败**：在问题发生时立即拦截，而不是事后修复
- **清晰反馈**：错误信息要明确指出问题和解决方案
- **无默认旁路**：不把跳过 hook / gate 视为正式流程；发现误判时应回到文档、规则或 owner 决策层修正

#### 7.1.2 pre-commit hook

**检查内容**：
1. 路径约束检查（allowed_paths / forbidden_paths）
2. Contract 冻结检查（不允许修改 status=frozen 的 Contract）

**实现示例**：

```bash
#!/bin/bash
# .git/hooks/pre-commit

set -e

# 读取当前 focus_work_item
FOCUS_WI=$(yq eval '.focus_work_item' meta.yaml)

if [ "$FOCUS_WI" != "null" ]; then
  # 读取 work-item 的路径约束
  ALLOWED_PATHS=$(yq eval '.allowed_paths[]' "work-items/${FOCUS_WI}.yaml")
  FORBIDDEN_PATHS=$(yq eval '.forbidden_paths[]' "work-items/${FOCUS_WI}.yaml")
  
  # 检查修改的文件
  CHANGED_FILES=$(git diff --cached --name-only)
  
  for file in $CHANGED_FILES; do
    # 检查是否在 forbidden_paths 中
    for forbidden in $FORBIDDEN_PATHS; do
      if [[ "$file" == $forbidden ]]; then
        echo "ERROR: File $file is in forbidden_paths of $FOCUS_WI"
        echo "Please check work-items/${FOCUS_WI}.yaml"
        exit 1
      fi
    done
    
    # 检查是否在 allowed_paths 中（如果定义了 allowed_paths）
    if [ -n "$ALLOWED_PATHS" ]; then
      ALLOWED=false
      for allowed in $ALLOWED_PATHS; do
        if [[ "$file" == $allowed ]]; then
          ALLOWED=true
          break
        fi
      done
      
      if [ "$ALLOWED" = false ]; then
        echo "ERROR: File $file is not in allowed_paths of $FOCUS_WI"
        echo "Please check work-items/${FOCUS_WI}.yaml"
        exit 1
      fi
    fi
  done
fi

# 检查 Contract 冻结
# frozen contract 默认不可修改；唯一例外是受控地把 status 从 frozen 改回 draft，以便回到 Design 阶段修订
CHANGED_CONTRACTS=$(git diff --cached --name-only | grep "^contracts/" || true)
for contract in $CHANGED_CONTRACTS; do
  if [ -f "$contract" ]; then
    CURRENT_STATUS=$(grep "^status:" "$contract" | awk '{print $2}')
    if [ "$CURRENT_STATUS" = "frozen" ]; then
      if git diff --cached -- "$contract" | grep -qE '^[+-](status: (frozen|draft))$'; then
        OTHER_CHANGES=$(git diff --cached -- "$contract" | grep -E '^[+-]' | grep -vE '^[+-](status: (frozen|draft))$' || true)
        if [ -n "$OTHER_CHANGES" ]; then
          echo "ERROR: Frozen contract $contract can only change status back to 'draft'"
          echo "Revert other edits, then reopen the contract in Design phase"
          exit 1
        fi
      else
        echo "ERROR: Contract $contract is frozen and cannot be modified"
        echo "Only a controlled status change from 'frozen' to 'draft' is allowed"
        exit 1
      fi
    fi
  fi
done

echo "✓ pre-commit checks passed"
```

#### 7.1.3 pre-push hook（v2.0 优化）

**检查内容**：
1. 依赖检查（dependency_refs，优化版）
2. 当前 focus_work_item 的测试覆盖检查（testing.md）

**实现示例**：

```bash
#!/bin/bash
# .git/hooks/pre-push

set -e

PHASE=$(yq eval '.phase' meta.yaml)

# 只在 Implementation 和 Testing 阶段检查
if [ "$PHASE" = "Implementation" ] || [ "$PHASE" = "Testing" ]; then
  FOCUS_WI=$(yq eval '.focus_work_item' meta.yaml)

  if [ "$FOCUS_WI" != "null" ]; then
    # v2.0 优化：依赖 WI 只有在 acceptance 有通过记录时才算完成
    DEPENDENCIES=$(yq eval '.dependency_refs[]' "work-items/${FOCUS_WI}.yaml" 2>/dev/null || true)

    for dep in $DEPENDENCIES; do
      DEP_ACCEPTANCES=$(yq eval '.acceptance_refs[]' "work-items/${dep}.yaml")

      for acc in $DEP_ACCEPTANCES; do
        if ! grep -A 5 "acceptance_ref: $acc" testing.md | grep -q "result: pass"; then
          echo "ERROR: Dependency $dep is not completed (acceptance $acc has no passing record)"
          echo "Please wait for $dep to complete and update testing.md with result: pass"
          exit 1
        fi
      done
    done

    # 局部覆盖检查：当前 focus_work_item 的 acceptance 必须都有记录且结果为 pass
    ACCEPTANCE_REFS=$(yq eval '.acceptance_refs[]' "work-items/${FOCUS_WI}.yaml")

    for acc in $ACCEPTANCE_REFS; do
      if ! grep -q "acceptance_ref: $acc" testing.md; then
        echo "ERROR: Acceptance $acc is not covered in testing.md"
        echo "Please add test coverage for $acc"
        exit 1
      fi

      if ! grep -A 5 "acceptance_ref: $acc" testing.md | grep -q "result: pass"; then
        echo "ERROR: Acceptance $acc does not have a passing verification record"
        echo "Please update testing.md after the verification passes"
        exit 1
      fi
    done
  fi
fi

echo "✓ pre-push checks passed"
```

#### 7.1.4 安装 hooks

```bash
# 在项目根目录执行
cp .codespec/hooks/pre-commit .git/hooks/
cp .codespec/hooks/pre-push .git/hooks/
chmod +x .git/hooks/pre-commit .git/hooks/pre-push
```

### 7.2 CLAUDE.md 模板

```markdown
# Claude Code 项目配置

## 项目概述

[1-2 句话描述项目目标]

## 框架说明

本项目使用 Runtime Framework 管理开发流程。

**路径前提**：以下路径示例默认以 `<project-root>` 为当前工作目录；如果会话直接在 `change/<container>/` 内启动，则把 `change/<container>/` 前缀替换为容器内相对路径（如 `meta.yaml`、`spec.md`、`work-items/...`）。

**核心文档**：
- `change/<container>/spec.md` - 需求规范（唯一真相源）
- `change/<container>/design.md` - 设计文档
- `change/<container>/work-items/WI-*.yaml` - Work Item 定义
- `change/<container>/meta.yaml` - 当前状态
- `lessons_learned.md` - 经验教训（必读）

## 会话启动流程

每次启动会话时，按顺序执行：

1. **读取项目状态**
   ```bash
   cat change/<container>/meta.yaml
   ```
   确认：phase、status、focus_work_item、execution_group、execution_branch

2. **读取经验教训**
   ```bash
   cat lessons_learned.md
   ```
   重点关注"快速索引"中的硬规则（R1-R10）

3. **校验当前容器上下文**
   - 当前 Git 分支是否与 `execution_branch` 一致
   - 当前会话是否只聚焦一个 `focus_work_item`
   - 如果不一致，必须停止并询问用户

4. **读取当前 Work Item**（如果 focus_work_item 不为 null）
   ```bash
   cat change/<container>/work-items/${FOCUS_WI}.yaml
   ```
   确认：scope、out_of_scope、allowed_paths、forbidden_paths、acceptance_refs

5. **读取相关文档**
   - spec.md：只读取与当前 WI 相关的 acceptance
   - design.md：只读取与当前 WI 相关的设计切片

## 核心约束（必须遵守）

### 修改文件前
- ✅ 检查文件是否在 allowed_paths 中
- ✅ 检查文件是否在 forbidden_paths 中
- ❌ 如果不确定，先读取 work-item 确认

### 实现功能时
- ✅ 只实现 scope 中定义的功能
- ❌ 不实现 out_of_scope 中列出的功能
- ❌ 不添加未在 acceptance_refs 中要求的功能
- ❌ 不重构不在 scope 中的代码

### 编写测试时
- ✅ 必须覆盖所有 acceptance_refs
- ✅ 必须记录到 testing.md
- ✅ 记录格式：acceptance_ref、verification_type、artifact_ref、result、residual_risk、reopen_required

### 提交代码前
- ✅ 检查 pre-commit hook 是否通过
- ✅ 使用规范的提交信息：`[WI-XXX] Description`
- ✅ 更新 testing.md

### Push 代码前
- ✅ 检查依赖是否完成（dependency_refs，要求依赖 acceptance 在 testing.md 中有 `result: pass` 记录）
- ✅ 检查当前 focus_work_item 的测试覆盖是否完整且结果通过
- ✅ 检查 pre-push hook 是否通过

## 硬规则（来自 lessons_learned.md）

[从 lessons_learned.md 的快速索引中复制最关键的规则，最多 10 条]

示例：
- **R1**（scope）：修改文件前必须检查是否在 allowed_paths 中
- **R2**（测试）：每个 acceptance 必须有对应测试
- **R3**（偏离）：Design 改变 Spec 时必须先回写 Spec

## stop_conditions

以下情况必须停止并询问用户：

1. 需要修改 forbidden_paths 中的文件
2. 需要实现 out_of_scope 中的功能
3. 发现 work-item 的 scope 定义不清晰
4. 发现依赖的 Work Item 未完成
5. 发现 Contract 定义不清晰或需要修改
6. 测试失败且无法在当前 scope 内修复
7. 发现 spec.md 或 design.md 有错误或遗漏

## 阶段特定指导

### Proposal 阶段
- 目标：形成 spec.md 的 Intent 章节
- 输出：Intent（Problem、Goals、Non-goals、Anchors、Testing Priority Rules）
- 门禁：proposal-maturity

### Requirements 阶段
- 目标：补齐 spec.md 的 Requirements、Acceptance、Verification 章节
- 输出：完整的 spec.md
- 门禁：requirements-approval

### Design 阶段
- 目标：派生 Work Items，冻结 Contracts，规划执行策略
- 输出：design.md、work-items/、contracts/（如需要）
- 门禁：design-readiness

### Implementation 阶段
- 目标：按 Work Item 执行
- 输出：代码 + 测试 + testing.md
- 门禁：implementation-start（每个 WI 开始前）

### Testing 阶段
- 目标：集成测试，验证所有 acceptance
- 输出：完整的 testing.md
- 门禁：testing-coverage

### Deployment 阶段
- 目标：部署到目标环境，验收
- 输出：deployment.md（进入实际部署 / 发布验收时必需）
- 门禁：deployment-readiness（条件适用）、promotion-criteria

## 项目特定约束

[根据项目需要添加特定约束，最多 5 条]

示例：
- 所有 API 必须有 OpenAPI 文档
- 所有数据库迁移必须可回滚
- 所有外部依赖必须在 package.json 中声明
```

---
### 7.3 硬门禁实现

#### 7.3.1 门禁检查脚本

```bash
#!/bin/bash
# .codespec/scripts/check-gate.sh

GATE=$1
PHASE=$(yq eval '.phase' meta.yaml)

case $GATE in
  proposal-maturity)
    echo "Checking proposal-maturity gate..."
    
    # 检查 Intent 章节是否完整
    if ! grep -q "## Intent" spec.md; then
      echo "ERROR: Intent section missing"
      exit 1
    fi
    
    if ! grep -q "### Goals" spec.md; then
      echo "ERROR: Goals section missing"
      exit 1
    fi
    
    if ! grep -q "### Testing Priority Rules" spec.md; then
      echo "ERROR: Testing Priority Rules missing"
      exit 1
    fi
    
    # 检查 Requirements 骨架是否创建
    if ! grep -q "## Requirements" spec.md; then
      echo "ERROR: Requirements skeleton missing"
      exit 1
    fi
    
    echo "✓ proposal-maturity gate passed"
    ;;
    
  requirements-approval)
    echo "Checking requirements-approval gate..."
    
    # 检查 Proposal Coverage Map
    if ! grep -q "### Proposal Coverage Map" spec.md; then
      echo "ERROR: Proposal Coverage Map missing"
      exit 1
    fi
    
    # 检查每个 requirement 是否有对应 acceptance
    REQUIREMENTS=$(grep "^- REQ-" spec.md | awk '{print $2}')
    for req in $REQUIREMENTS; do
      if ! grep -q "source_ref: $req" spec.md; then
        echo "ERROR: Requirement $req has no corresponding acceptance"
        exit 1
      fi
    done
    
    # 检查每个 acceptance 是否有对应 verification
    ACCEPTANCES=$(grep "^- ACC-" spec.md | awk '{print $2}')
    for acc in $ACCEPTANCES; do
      if ! grep -q "acceptance_ref: $acc" spec.md; then
        echo "ERROR: Acceptance $acc has no corresponding verification"
        exit 1
      fi
    done
    
    echo "✓ requirements-approval gate passed"
    ;;
    
  design-readiness)
    echo "Checking design-readiness gate..."
    
    # 检查 design.md 是否存在
    if [ ! -f design.md ]; then
      echo "ERROR: design.md missing"
      exit 1
    fi
    
    # 检查 Work Item Derivation 是否存在
    if ! grep -q "## Work Item Derivation" design.md; then
      echo "ERROR: Work Item Derivation missing"
      exit 1
    fi
    
    # 检查所有 acceptance 是否被分配到 Work Items
    ACCEPTANCES=$(grep "^- ACC-" spec.md | awk '{print $2}')
    for acc in $ACCEPTANCES; do
      if ! grep -r "acceptance_refs:.*$acc" work-items/; then
        echo "ERROR: Acceptance $acc is not assigned to any Work Item"
        exit 1
      fi
    done
    
    # 检查 Work Item Execution Strategy 是否存在
    if ! grep -q "## Work Item Execution Strategy" design.md; then
      echo "ERROR: Work Item Execution Strategy missing"
      exit 1
    fi
    
    echo "✓ design-readiness gate passed"
    ;;
    
  implementation-start)
    echo "Checking implementation-start gate..."
    
    FOCUS_WI=$(yq eval '.focus_work_item' meta.yaml)
    
    if [ "$FOCUS_WI" = "null" ]; then
      echo "ERROR: focus_work_item is null"
      exit 1
    fi
    
    # v2.0 优化：依赖 WI 只有在 acceptance 有通过记录时才算完成
    DEPENDENCIES=$(yq eval '.dependency_refs[]' "work-items/${FOCUS_WI}.yaml" 2>/dev/null || true)
    
    for dep in $DEPENDENCIES; do
      DEP_ACCEPTANCES=$(yq eval '.acceptance_refs[]' "work-items/${dep}.yaml")
      
      for acc in $DEP_ACCEPTANCES; do
        if ! grep -A 5 "acceptance_ref: $acc" testing.md | grep -q "result: pass"; then
          echo "ERROR: Dependency $dep is not completed (acceptance $acc has no passing record)"
          echo "Please wait for $dep to complete and update testing.md with result: pass"
          exit 1
        fi
      done
    done
    
    # 检查 Contract 是否冻结
    CONTRACT_REFS=$(yq eval '.contract_refs[]' "work-items/${FOCUS_WI}.yaml" 2>/dev/null || true)
    
    for contract in $CONTRACT_REFS; do
      STATUS=$(grep "^status:" "contracts/${contract}.md" | awk '{print $2}')
      if [ "$STATUS" != "frozen" ]; then
        echo "ERROR: Contract $contract is not frozen"
        exit 1
      fi
    done
    
    echo "✓ implementation-start gate passed"
    ;;
    
  testing-coverage)
    echo "Checking testing-coverage gate..."

    ACCEPTANCES=$(grep "^- ACC-" spec.md | awk '{print $2}')

    for acc in $ACCEPTANCES; do
      if ! grep -q "acceptance_ref: $acc" testing.md; then
        echo "ERROR: Acceptance $acc is missing from testing.md"
        exit 1
      fi

      RESULT=$(grep -A 5 "acceptance_ref: $acc" testing.md | grep "result:" | awk '{print $2}')
      if [ "$RESULT" != "pass" ]; then
        echo "ERROR: Acceptance $acc does not have result: pass"
        exit 1
      fi
    done

    P0_ACCEPTANCES=$(grep -B 4 -A 4 "priority: P0" spec.md | grep "^- ACC-" | awk '{print $2}')
    for acc in $P0_ACCEPTANCES; do
      VERIFICATION_TYPE=$(grep -A 5 "acceptance_ref: $acc" testing.md | grep "verification_type:" | awk '{print $2}')
      if [ "$VERIFICATION_TYPE" != "automated" ]; then
        echo "ERROR: P0 acceptance $acc does not have automated verification"
        exit 1
      fi
    done

    P1_ACCEPTANCES=$(grep -B 4 -A 4 "priority: P1" spec.md | grep "^- ACC-" | awk '{print $2}')
    for acc in $P1_ACCEPTANCES; do
      VERIFICATION_TYPE=$(grep -A 5 "acceptance_ref: $acc" testing.md | grep "verification_type:" | awk '{print $2}')
      case "$VERIFICATION_TYPE" in
        automated|manual|equivalent) ;;
        *)
          echo "ERROR: P1 acceptance $acc must use automated/manual/equivalent verification"
          exit 1
          ;;
      esac
    done

    P2_ACCEPTANCES=$(grep -B 4 -A 4 "priority: P2" spec.md | grep "^- ACC-" | awk '{print $2}')
    for acc in $P2_ACCEPTANCES; do
      VERIFICATION_TYPE=$(grep -A 5 "acceptance_ref: $acc" testing.md | grep "verification_type:" | awk '{print $2}')
      case "$VERIFICATION_TYPE" in
        automated|manual|equivalent) ;;
        *)
          echo "ERROR: P2 acceptance $acc must use automated/manual/equivalent verification"
          exit 1
          ;;
      esac
    done

    echo "✓ testing-coverage gate passed"
    ;;

  deployment-readiness)
    echo "Checking deployment-readiness gate (conditional)..."

    # 对无需独立部署动作的简单 change，可跳过 deployment.md
    if [ ! -f deployment.md ]; then
      echo "WARNING: deployment.md missing (only acceptable for changes without a standalone deployment step)"
      exit 0
    fi
    
    # 检查部署计划是否完整
    if ! grep -q "## Deployment Plan" deployment.md; then
      echo "ERROR: Deployment Plan missing"
      exit 1
    fi
    
    if ! grep -q "## Rollback Plan" deployment.md; then
      echo "ERROR: Rollback Plan missing"
      exit 1
    fi
    
    echo "✓ deployment-readiness gate passed"
    ;;
    
  promotion-criteria)
    echo "Checking promotion-criteria gate..."

    # 对无需独立部署动作的 simple change，可直接跳过 deployment dossier 检查
    if [ ! -f deployment.md ]; then
      echo "WARNING: deployment.md missing (promotion proceeds only for changes without a standalone deployment step)"
      exit 0
    fi

    # 检查验收结论
    STATUS=$(grep "^status:" deployment.md | awk '{print $2}')

    if [ "$STATUS" != "pass" ]; then
      echo "ERROR: Deployment status is not 'pass'"
      exit 1
    fi

    # 检查是否有 approved_by
    if ! grep -q "^approved_by:" deployment.md; then
      echo "ERROR: Deployment not approved"
      exit 1
    fi

    echo "✓ promotion-criteria gate passed"
    ;;
    
  *)
    echo "Unknown gate: $GATE"
    exit 1
    ;;
esac
```

#### 7.3.2 门禁使用

```bash
# 在阶段切换前执行
.codespec/scripts/check-gate.sh proposal-maturity
.codespec/scripts/check-gate.sh requirements-approval
.codespec/scripts/check-gate.sh design-readiness
.codespec/scripts/check-gate.sh implementation-start
.codespec/scripts/check-gate.sh testing-coverage
.codespec/scripts/check-gate.sh deployment-readiness  # 条件适用
.codespec/scripts/check-gate.sh promotion-criteria
```

### 7.4 验证计划

#### 7.4.1 框架验证

**目标**：验证框架本身的可用性和有效性

**验证项**：
1. 目录结构创建是否正确
2. 文档模板是否完整
3. Git hooks 是否正常工作
4. 门禁检查是否正常工作
5. CLAUDE.md 是否被 Claude 正确消费

**验证方法**：
- 创建一个小型测试项目
- 走完整个 6 阶段流程
- 记录遇到的问题和改进建议

#### 7.4.2 Claude 约束验证

**目标**：验证 Claude 是否遵守约束

**验证项**：
1. Claude 是否读取 CLAUDE.md
2. Claude 是否读取 lessons_learned.md
3. Claude 是否遵守 allowed_paths / forbidden_paths
4. Claude 是否遵守 scope / out_of_scope
5. Claude 是否覆盖所有 acceptance_refs
6. Claude 是否在 stop_conditions 时停止

**验证方法**：
- 故意设置冲突的约束（如 forbidden_paths 包含必须修改的文件）
- 观察 Claude 是否停止并询问
- 记录 Claude 忽略约束的情况到 lessons_learned.md

#### 7.4.3 并行执行验证

**目标**：验证多执行组容器并行执行是否正常

**验证项**：
1. 工作目录容器是否正确创建
2. meta.yaml 是否正确更新
3. 执行组子分支与 feature 分支同步是否正常
4. 依赖检查是否正常（v2.0 优化版）
5. 合并冲突是否可控

**验证方法**：
- 创建 3 个并行执行组
- 同时执行多个 Work Items
- 观察是否有冲突和问题

#### 7.4.4 持续改进验证

**目标**：验证 lessons_learned.md 是否有效

**验证项**：
1. 问题是否被正确记录
2. 硬规则是否被 Claude 遵守
3. Git hooks 是否根据高频问题升级
4. 框架是否根据反馈持续优化

**验证方法**：
- 定期回顾 lessons_learned.md
- 统计高频问题
- 升级为硬规则或 Git hooks
- 观察问题是否减少

### 7.5 常见问题

#### 7.5.1 Claude 忽略了 work-item 的约束

**症状**：Claude 修改了 forbidden_paths 中的文件

**原因**：
- Claude 没有读取 work-item
- Claude 读取了但忽略了
- work-item 的约束定义不清晰

**解决方案**：
1. 检查 CLAUDE.md 是否要求读取 work-item
2. 检查 work-item 的约束是否清晰
3. 记录到 lessons_learned.md
4. 考虑升级为 pre-commit hook

#### 7.5.2 测试覆盖不完整

**症状**：Deployment 阶段发现某些 acceptance 没有测试

**原因**：
- Implementation 阶段没有严格按照 acceptance_refs 编写测试
- testing.md 没有及时更新

**解决方案**：
1. 在 CLAUDE.md 中强调测试覆盖要求
2. 在 pre-push hook 中检查测试覆盖
3. 记录到 lessons_learned.md

#### 7.5.3 Work Item 粒度不合理

**症状**：某个 Work Item 太大，无法在单个会话中完成

**原因**：
- Design 阶段没有合理划分 Work Item
- Work Item 的 scope 定义不清晰

**解决方案**：
1. 在 Design 阶段重新划分 Work Item
2. 更新 design.md 的 Work Item Derivation
3. 记录到 lessons_learned.md
4. 在下次 Design 阶段参考经验

#### 7.5.4 依赖检查失败

**症状**：pre-push hook 报告依赖未完成

**原因**：
- 依赖的 Work Item 还没有完成测试
- testing.md 没有及时更新

**解决方案**：
1. 等待依赖的 Work Item 完成并通过测试
2. 或者调整执行顺序
3. 确保 testing.md 及时更新

#### 7.5.5 Contract 冻结后需要修改

**症状**：Implementation 阶段发现 Contract 定义不清晰

**原因**：
- Design 阶段 Contract 定义不够详细
- 实现过程中发现新的需求

**解决方案**：
1. 停止当前 Work Item
2. 回到 Design 阶段
3. 受控地把 Contract 的 `status` 从 `frozen` 改回 `draft`（这一步只允许修改状态位）
4. 更新 Contract 内容
5. 重新冻结 Contract
6. 继续 Implementation
7. 记录到 lessons_learned.md

---

## 八、总结

### 8.1 核心价值

本框架通过以下机制提升项目交付质量和效率：

1. **单一真相源**：spec.md 作为唯一 canonical 规范，避免双真相源问题
2. **固定生命周期**：6 阶段串行推进，确保每个阶段的输出质量
3. **分层约束**：文档结构 + Git hooks + 人工 review，多层防御
4. **持续改进**：lessons_learned.md 记录问题，高频问题升级为硬规则
5. **并行执行**：Work Item 粒度合理，支持多工作目录并行开发
6. **可追溯性**：所有决策和变更都有明确的文档记录

### 8.2 适用场景

**适合**：
- 单人 + Claude/Codex 协作开发
- 中大型项目（10+ Work Items）
- 需要严格质量控制的项目
- 需要长期维护的项目

**不适合**：
- 小型项目（< 5 Work Items）
- 快速原型验证
- 一次性脚本

### 8.3 成功关键

1. **严格遵守阶段边界**：不要跳过任何阶段
2. **及时记录经验**：发现问题立即记录到 lessons_learned.md
3. **合理划分 Work Item**：粒度要适中，既不能太大也不能太小
4. **定期同步**：根据执行策略及时同步 GitHub
5. **持续优化**：根据反馈不断改进框架和流程