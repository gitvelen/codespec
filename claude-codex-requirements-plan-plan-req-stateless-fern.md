# Proposal 与 Requirements 阶段完全合并方案

## 背景与目标

用户在项目建设中，通常会使用 claude/codex 来启发灵感、扫清思维盲区、厘清项目目标等工作，结束时几乎把需求讨论得差不多了。在这种情况下，Proposal 和 Requirements 两个阶段是人为割裂。

**用户明确要求**：
1. **完全合并** Proposal 和 Requirements 阶段，新阶段名称为 **Requirement**（单数）
2. **精简文档结构**，删除冗余章节，减少上下文长度
3. **严防需求漂移**，从项目全生命周期考虑，确保 Requirement → Design → Implementation → Testing → Deployment 全链路可追溯

**阶段定位澄清**：
- **Requirement 阶段**：专注于需求工作（需求意图、形式化需求、验收标准、验证方法），不涉及设计
- **Design 阶段**：承担架构方案、概要设计、详细设计，是真正的设计阶段

## 当前阶段设计理解

### 现有阶段流程

```
Proposal → Requirements → Design → Implementation → Testing → Deployment → Completed
```

### Proposal 阶段职责
- 在 spec.md 中记录初步需求和意图
- 填充 Summary、Inputs、Intent 章节
- 记录 Problem/Background、Goals、Boundaries
- 可以初步填充 Requirements、Acceptance、Verification（但不要求完整）
- Gate: `proposal-maturity` 检查文档结构完整性、占位符清理、input_refs 有效性

### Requirements 阶段职责
- 在 spec.md 中细化需求（REQ-*）、验收标准（ACC-*）、验证方法（VO-*）
- 填充 Source Coverage（input_refs → REQ-* 的追溯）
- 填充 Functional Requirements（REQ-001, REQ-002...）
- 填充 Acceptance（ACC-001, ACC-002...）
- 填充 Verification（VO-001, VO-002...）
- Gate: `requirements-approval` 检查 REQ/ACC/VO 完整性、追溯链完整性、Open Decisions 状态

### 关键观察

1. **文档载体相同**：Proposal 和 Requirements 都在 spec.md 中工作
2. **内容连续性**：Proposal 可以初步填充 Requirements/Acceptance/Verification，Requirements 阶段是细化
3. **Gate 检查独立**：proposal-maturity 和 requirements-approval 检查的是不同维度
4. **审查节点**：Proposal → Requirements 需要 review-verdict-present（requirements-review.yaml）

## 问题分析

### 用户痛点

用户在与 claude/codex 讨论时，往往会：
1. 讨论目标和边界（Intent）
2. 讨论具体需求（Requirements）
3. 讨论验收标准（Acceptance）
4. 讨论如何验证（Verification）

这个过程是**连续的、迭代的**，不是分阶段的。当讨论结束时，spec.md 的内容已经比较完整，此时再强制分成 Proposal 和 Requirements 两个阶段，会感觉：
- **人为割裂**：需要在 Proposal 阶段"假装"不写完整，留到 Requirements 阶段再补充
- **流程冗余**：需要执行两次阶段切换命令、两次审查
- **认知负担**：需要记住哪些内容属于 Proposal，哪些属于 Requirements

### Plan 阶段的误解

用户提到"plan 阶段"，但当前设计中**没有独立的 plan 阶段**。用户可能是指：
1. **Proposal 阶段**：初步规划需求和意图
2. **与 AI 的讨论过程**：这是一个"规划"过程，但不是正式阶段

所以问题的本质是：**Proposal 和 Requirements 是否应该合并？**

## 不合并的优缺点

### 优点

1. **阶段职责清晰**
   - Proposal：快速记录意图和边界，不要求完整
   - Requirements：细化需求，要求完整和可追溯
   - 适合"先快速启动，再逐步细化"的场景

2. **审查节点明确**
   - Proposal 审查：确认方向正确
   - Requirements 审查：确认需求完整
   - 适合需要多次审查的大型项目

3. **灵活性高**
   - Proposal 阶段可以快速迭代，不受 REQ/ACC/VO 格式约束
   - Requirements 阶段可以专注于形式化需求

4. **符合传统流程**
   - 类似于"概念设计"和"详细设计"的分离
   - 符合一些组织的流程规范

### 缺点

1. **流程冗余**
   - 对于小型项目或需求明确的项目，两个阶段是重复的
   - 需要执行两次阶段切换、两次审查

2. **认知负担**
   - 需要记住哪些内容属于 Proposal，哪些属于 Requirements
   - Proposal 阶段可以"初步填充"Requirements，但不要求完整，边界模糊

3. **与 AI 协作不匹配**
   - 与 AI 讨论时，往往是连续的、迭代的
   - 人为割裂会打断思维流程

4. **文档重复编辑**
   - Proposal 阶段填充 spec.md
   - Requirements 阶段再次编辑 spec.md
   - 同一文件被编辑两次

## 合并的优缺点

### 优点

1. **流程简化**
   - 减少一个阶段，减少一次阶段切换
   - 减少一次审查节点

2. **认知负担降低**
   - 不需要区分 Proposal 和 Requirements
   - 一次性完成 spec.md 的填充

3. **与 AI 协作匹配**
   - 与 AI 讨论时，自然地完成 spec.md 的填充
   - 不需要人为割裂

4. **文档编辑效率高**
   - spec.md 只需要编辑一次
   - 减少上下文切换

### 缺点

1. **阶段职责模糊**
   - 合并后的阶段既要"快速启动"又要"细化需求"
   - 可能导致阶段目标不清晰

2. **审查节点减少**
   - 只有一次审查机会
   - 如果需求不明确，可能需要返工

3. **灵活性降低**
   - 不能"先快速启动，再逐步细化"
   - 必须一次性完成 spec.md

4. **不符合传统流程**
   - 一些组织可能要求"概念设计"和"详细设计"分离
   - 可能不符合流程规范

## 合并方案设计

### 方案 A：完全合并（激进）

**阶段流程**：
```
Specification → Design → Implementation → Testing → Deployment → Completed
```

**Specification 阶段职责**：
- 在 spec.md 中完成需求规格（Summary、Inputs、Intent、Requirements、Acceptance、Verification）
- 一次性填充所有内容
- Gate: `specification-complete` 检查文档完整性、REQ/ACC/VO 完整性、追溯链完整性

**优点**：
- 流程最简化
- 认知负担最低
- 与 AI 协作最匹配

**缺点**：
- 阶段职责最模糊
- 灵活性最低
- 不符合传统流程

### 方案 B：可选合并（温和）

**阶段流程**：
```
Proposal → [Requirements] → Design → Implementation → Testing → Deployment → Completed
```

**设计思路**：
- 保留 Proposal 和 Requirements 两个阶段
- 但允许在 Proposal 阶段直接完成 Requirements 的内容
- 如果 Proposal 阶段已经完成 REQ/ACC/VO，可以跳过 Requirements 阶段

**实现方式**：
1. **Proposal 阶段**：
   - 允许填充 Requirements、Acceptance、Verification
   - Gate: `proposal-maturity` 检查基本完整性（Summary、Inputs、Intent）
   - 如果 REQ/ACC/VO 已完整，自动通过 `requirements-approval` gate

2. **Requirements 阶段**：
   - 如果 Proposal 阶段已完成 REQ/ACC/VO，直接跳过
   - 如果未完成，继续细化

3. **阶段切换逻辑**：
   - `codespec start-requirements`：检查 `proposal-maturity`
   - `codespec start-design`：检查 `requirements-approval`（无论是否经过 Requirements 阶段）

**优点**：
- 保留灵活性：可以"先快速启动，再逐步细化"，也可以"一次性完成"
- 认知负担适中：阶段职责清晰，但不强制分离
- 与 AI 协作匹配：可以连续讨论，也可以分阶段讨论
- 向后兼容：不破坏现有流程

**缺点**：
- 实现复杂度高：需要修改 gate 检查逻辑
- 可能引入混淆：用户可能不清楚何时跳过 Requirements 阶段

### 方案 C：软合并（保守）

**阶段流程**：
```
Proposal → Requirements → Design → Implementation → Testing → Deployment → Completed
```

**设计思路**：
- 保留 Proposal 和 Requirements 两个阶段
- 但简化阶段切换流程，减少认知负担

**实现方式**：
1. **Proposal 阶段**：
   - 明确允许填充 Requirements、Acceptance、Verification
   - 文档模板中明确说明"可以在 Proposal 阶段完成 REQ/ACC/VO"
   - Gate: `proposal-maturity` 只检查基本完整性

2. **Requirements 阶段**：
   - 如果 Proposal 阶段已完成 REQ/ACC/VO，只需要审查
   - 如果未完成，继续细化
   - Gate: `requirements-approval` 检查 REQ/ACC/VO 完整性

3. **简化阶段切换**：
   - 提供快捷命令：`codespec fast-forward-to-design`
   - 自动执行：`start-requirements` + 审查 + `start-design`

**优点**：
- 保留现有流程：不破坏现有设计
- 认知负担降低：明确说明可以在 Proposal 阶段完成 REQ/ACC/VO
- 实现简单：只需要修改文档和提供快捷命令
- 向后兼容：不影响现有项目

**缺点**：
- 流程仍然冗余：仍需要两次阶段切换
- 灵活性有限：不能真正跳过 Requirements 阶段

## 完全合并方案设计

### 核心思路

1. **阶段合并**：Proposal + Requirements → **Specification**
2. **文档精简**：删除冗余章节，保留核心内容
3. **防漂移机制**：强化追溯链、变更控制、审查机制

### 新阶段流程

```
Requirement → Design → Implementation → Testing → Deployment → Completed
```

### Requirement 阶段职责

**一次性完成需求工作**，包括：
- 需求意图（Intent）：问题背景、目标、边界
- 形式化需求（REQ-*）：可验证的需求条目
- 验收标准（ACC-*）：可判定的验收条件
- 验证方法（VO-*）：如何验证验收标准
- 追溯关系（Inputs → REQ → ACC → VO）

**不包括**：
- 架构设计（属于 Design 阶段）
- 技术方案（属于 Design 阶段）
- 工作项拆解（属于 Design 阶段）

### spec.md 文档结构精简

#### 当前结构（69 行模板）

```
## Summary                    # 3-5 行概述
## Inputs                     # 输入来源和成熟度
## Intent                     # 问题背景、目标、边界
  ### Problem / Background
  ### Goals
  ### Boundaries
## Open Decisions             # 未决策项
## Requirements               # 需求
  ### Source Coverage         # 输入追溯
  ### Functional              # 功能需求
  ### Constraints             # 约束
  ### Non-functional          # 非功能需求
## Acceptance                 # 验收标准
## Verification               # 验证方法
```

#### 精简后结构（目标：40-50 行模板）

```markdown
## Summary
[用 3-5 行说明这次变更的目标、边界和成败标准]

## Inputs
- source_refs:
  - [稳定的 repo 文件引用，禁止 conversation://]
- source_owner: [需求提出人]
- maturity: L0/L1/L2/L3
- normalization_note: [如何把原始输入整理成当前规格]
- approval_basis: [谁基于什么确认了当前方向]

## Scope
- goal: [目标]
- boundary: [边界]
- out_of_scope: [明确不做]

## Requirements
- REQ-001
  - summary: [需求描述]
  - source_ref: [追溯到 Inputs]
  - rationale: [为什么需要]

## Acceptance
- ACC-001
  - source_ref: REQ-001
  - expected_outcome: [可观测结果]
  - priority: P0/P1/P2
  - priority_rationale: [为什么是这个优先级]
  - status: approved

## Verification
- VO-001
  - acceptance_ref: ACC-001
  - verification_type: automated/manual/equivalent
  - verification_profile: focused/comprehensive
  - obligations: [验证义务]
  - artifact_expectation: [测试路径、命令或证据形式]
```

**删除的章节及理由**：
1. **Intent 章节**：合并到 Scope，更简洁
   - Problem/Background → 合并到 Summary 或 Requirements.rationale
   - Goals/Boundaries → 提升为 Scope 章节

2. **Open Decisions 章节**：完全删除
   - AI 应该在写完 spec.md 后自检并澄清，不应该留下未决策项
   - 带着歧义进入 Design 阶段会导致返工

3. **Source Coverage 子章节**：简化为 Requirements 中的 source_ref 字段
   - 追溯关系通过字段内联，不需要单独章节

4. **Constraints/Non-functional 子章节**：合并到 Requirements
   - 不单独分类，统一用 REQ-* 编号

**保留的核心章节**：
- Summary：快速索引
- Inputs：追溯源头
- Scope：目标和边界
- Requirements：形式化需求
- Acceptance：验收标准
- Verification：验证方法

**行数对比**：
- 当前模板：69 行
- 精简后：约 45 行（减少 35%）

### 防漂移机制设计（全生命周期视角）

#### 问题：精简文档后如何防止需求漂移？

**需求漂移的根源**：
1. **追溯链断裂**：不知道需求从哪来，设计/实现/测试无法追溯到需求
2. **变更无记录**：需求悄悄改了，下游不知道
3. **审查缺失**：没有检查点，随意修改
4. **生命周期割裂**：需求、设计、实现、测试各自为政，缺乏一致性

#### 防漂移机制（全生命周期）

**1. 强化追溯链（Traceability Chain）**

**完整追溯链**：
```
Inputs (source_refs: 原始需求来源)
  ↓ [Requirement 阶段]
Requirements (source_ref: input_ref) - 形式化需求
  ↓
Acceptance (source_ref: REQ-*) - 验收标准
  ↓
Verification (acceptance_ref: ACC-*) - 验证方法
  ↓ [Design 阶段]
Work Items (requirement_refs, acceptance_refs, verification_refs) - 工作项拆解
  ↓
Design Slices (对应 Work Items) - 设计切片
  ↓ [Implementation 阶段]
Code Changes (在 allowed_paths 内) - 代码变更
  ↓ [Testing 阶段]
Testing Records (acceptance_ref: ACC-*) - 测试记录
  ↓ [Deployment 阶段]
Deployment Evidence (验证所有 ACC 通过) - 部署证据
```

**关键追溯点**：
- **Requirement → Design**：每个 REQ 必须被至少一个 Work Item 引用
- **Design → Implementation**：每个 Work Item 必须有对应的代码变更
- **Implementation → Testing**：每个 ACC 必须有测试记录
- **Testing → Deployment**：所有 ACC 必须有 full-integration pass 记录

**Gate 检查（全生命周期）**：
- `requirement-complete` gate（Requirement 阶段结束）：
  - 每个 REQ 都有 source_ref 指向 Inputs
  - 每个 ACC 都有 source_ref 指向 REQ
  - 每个 VO 都有 acceptance_ref 指向 ACC
  - 所有 input_refs 都被 Requirements 覆盖（闭包检查）

- `design-structure-complete` gate（Design 阶段结束）：
  - 每个 REQ 都被至少一个 Work Item 引用
  - 每个 ACC 都被至少一个 Work Item 引用
  - Work Items 的 requirement_refs/acceptance_refs 与 Design 中的 Work Item Derivation 一致

- `implementation-start` gate（Implementation 阶段开始）：
  - 当前 Work Item 的 requirement_refs/acceptance_refs 在 spec.md 中存在
  - 当前 Work Item 的 allowed_paths 明确

- `verification` gate（Testing/Deployment 阶段）：
  - 所有 ACC 都有测试记录
  - 所有 active_work_items 的 ACC 都有 pass 记录

- `promotion-criteria` gate（Deployment 阶段结束）：
  - 所有 ACC 都有 full-integration pass 记录
  - deployment.md 中的 Acceptance Conclusion 为 pass

**2. 输入快照（Input Snapshot）**

**问题**：Inputs 中的 source_refs 可能指向会话记录（conversation://），会话结束后无法追溯。

**解决方案**：
- 在 Requirement 阶段结束时，强制将 conversation:// 引用转换为 repo 文件引用
- Gate 检查：`requirement-complete` 必须验证所有 source_refs 都是稳定的 repo 文件引用
- 这确保了需求的"源头"永久可追溯，即使在多个版本迭代后

**实现**：
```bash
# check-gate.sh 中的 validate_input_evidence_refs 函数
validate_input_evidence_refs() {
  local source_refs=("$@")
  for source_ref in "${source_refs[@]}"; do
    is_stable_repo_input_ref "$source_ref" || \
      die "input_refs must reference stable repo artifacts; conversation:// is not allowed"
    target_path="${source_ref%%#*}"
    [ -f "$PROJECT_ROOT/$target_path" ] || \
      die "input_refs references missing repo artifact: ${target_path}"
  done
}
```

**3. 变更审查机制（Change Review）**

**审查节点**：
- Requirement → Design 需要审查（`design-review.yaml`，审查的是 Requirement 阶段的产出）
- 审查内容：
  - 需求是否完整？
  - 追溯链是否完整？
  - 边界是否清晰？
  - 验收标准是否可判定？

**审查文件格式**：
```yaml
phase: Requirement
verdict: approved
reviewed_by: [reviewer]
reviewed_at: 2026-04-24
review_notes: |
  - 需求完整，追溯链清晰
  - 边界明确，验收标准可判定
  - 批准进入 Design 阶段
```

**注意**：审查文件名为 `design-review.yaml`（表示"批准进入 Design 阶段"），但 phase 字段为 `Requirement`（表示"审查的是 Requirement 阶段的产出"）。这与现有的命名约定一致（`requirements-review.yaml` 审查的是 Proposal 阶段的产出）。

**4. 需求变更控制（Change Control）**

**规则**：
- Requirement 阶段结束后，spec.md 进入"冻结"状态
- 如果需要修改 spec.md，必须：
  1. 记录变更原因（在 spec.md 顶部添加 Change Log）
  2. 重新执行 `requirement-complete` gate
  3. 重新审查（创建新的 `design-review-v2.yaml`）
  4. **关键**：通知下游（Design/Implementation/Testing）需求已变更

**Change Log 格式**：
```markdown
## Change Log

### 2026-04-25: 修改 REQ-003
- 原因：实现过程中发现技术约束
- 变更：REQ-003 从"支持 1000 QPS"改为"支持 500 QPS"
- 影响：ACC-003 验收标准相应调整
- 下游影响：WI-002 需要重新设计，已有测试记录需要更新
- 审查：已通过（design-review-v2.yaml）
```

**下游影响分析**：
- 如果 REQ 变更，检查哪些 Work Items 引用了它（通过 requirement_refs）
- 如果 ACC 变更，检查哪些 Work Items 引用了它（通过 acceptance_refs）
- 如果 ACC 变更，检查是否已有测试记录（testing.md）
- 提供命令：`codespec analyze-requirement-change REQ-003`，自动分析影响范围

**5. Open Decisions 处理原则**

**核心原则**：**Open Decisions 不应该存在**。

**理由**：
- Requirement 阶段的目标是**明确需求**，不是"记录未决策项"
- 带着歧义进入 Design 阶段，会导致设计方向不明确，返工成本高
- AI（claude/codex）应该在写完 spec.md 后**自检**，发现未决策项立即与用户澄清

**实施方式**：

1. **删除 Open Decisions 章节**：
   - spec.md 模板中不再包含 `## Open Decisions` 章节
   - 如果 AI 发现有未决策项，应该：
     - 立即停下，不继续填充 spec.md
     - 明确列出未决策项，向用户提问
     - 等待用户明确后，再继续填充 spec.md

2. **Gate 检查调整**：
   - `requirement-complete` gate **不再检查** Open Decisions
   - 删除以下检查项：
     ```bash
     # 删除这些检查
     local high_open=()
     mapfile -t high_open < <(open_decision_high_open_items)
     [ "${#high_open[@]}" -eq 0 ] || die "high-impact open decision remains: ${high_open[0]}"
     
     local deferred_missing_target=()
     mapfile -t deferred_missing_target < <(open_decision_deferred_missing_target_phase_items)
     [ "${#deferred_missing_target[@]}" -eq 0 ] || die "${deferred_missing_target[0]} deferred requires target_phase"
     ```

3. **AI 自检机制**：
   - 在 CLAUDE.md 中明确说明：
     ```markdown
     **Requirement 阶段自检规则**：
     - 写完 spec.md 后，必须自检是否有未决策项
     - 如果发现有歧义、不确定、需要用户判断的地方，立即停下
     - 明确列出问题，向用户提问，等待明确后再继续
     - 不要在 spec.md 中留下"待定"、"TBD"、"待讨论"等占位符
     - 不要带着歧义进入 Design 阶段
     ```

4. **用户澄清流程**：
   - AI 发现未决策项 → 列出问题 → 用户回答 → AI 更新 spec.md
   - 如果用户无法立即回答，AI 应该：
     - 提供建议方案（基于技术可行性、成本、风险）
     - 说明不同方案的影响
     - 帮助用户做决策

**示例**：

**错误做法**（带着歧义进入 Design）：
```markdown
## Requirements

- REQ-001
  - summary: 用户登录支持多种方式
  - source_ref: inputs/user-story.md#login
  - rationale: 提升用户体验
  - open_decision: 
    - decision_id: DEC-001
    - question: 是否支持微信登录？
    - impact: high
    - status: open
```

**正确做法**（立即澄清）：
```
AI: 我在填充 REQ-001 时发现一个未决策项：

**问题**：用户登录是否支持微信登录？

**影响**：
- 如果支持：需要接入微信 OAuth，增加开发成本，但提升用户体验
- 如果不支持：只支持邮箱/手机号登录，开发简单，但用户体验一般

**建议**：
- 如果目标用户主要在微信生态，建议支持
- 如果目标用户是企业内部，可以不支持

请明确：是否支持微信登录？

用户: 支持微信登录

AI: 好的，我已更新 REQ-001：
- REQ-001
  - summary: 用户登录支持邮箱、手机号、微信三种方式
  - source_ref: inputs/user-story.md#login
  - rationale: 提升用户体验，覆盖微信生态用户
```

**关键点**：
- AI 不应该"记录"未决策项，而应该"解决"未决策项
- 用户的职责是"做决策"，AI 的职责是"提供决策依据"
- Requirement 阶段结束时，spec.md 应该是**完全明确**的，没有任何歧义

### Gate 检查调整

#### 删除 gate

- `proposal-maturity`：删除
- `requirements-approval`：删除

#### 新增 gate

- `requirement-complete`：合并 `proposal-maturity` 和 `requirements-approval` 的检查项

#### requirement-complete gate 检查项

```bash
gate_requirement_complete() {
  check_appendix_authority
  
  # 1. 文档结构完整性
  grep -q '^## Summary$' "$SPEC_FILE" || die 'spec.md missing Summary'
  grep -q '^## Inputs$' "$SPEC_FILE" || die 'spec.md missing Inputs'
  grep -q '^## Scope$' "$SPEC_FILE" || die 'spec.md missing Scope'
  grep -q '^## Requirements$' "$SPEC_FILE" || die 'spec.md missing Requirements'
  grep -q '^## Acceptance$' "$SPEC_FILE" || die 'spec.md missing Acceptance'
  grep -q '^## Verification$' "$SPEC_FILE" || die 'spec.md missing Verification'
  
  # 2. Inputs 完整性
  local input_maturity normalization_note input_owner approval_basis source_refs
  input_maturity="$(input_intake_scalar maturity)"
  normalization_note="$(input_intake_scalar normalization_note)"
  input_owner="$(input_intake_scalar source_owner)"
  approval_basis="$(input_intake_scalar approval_basis)"
  mapfile -t source_refs < <(input_intake_refs)
  
  case "$input_maturity" in
    L0|L1|L2|L3) ;;
    *) die "input_maturity must be one of L0/L1/L2/L3" ;;
  esac
  
  is_placeholder_token "$input_owner" && die 'input_owner contains placeholder'
  is_placeholder_token "$approval_basis" && die 'approval_basis contains placeholder'
  is_placeholder_token "$normalization_note" && die 'normalization_note contains placeholder'
  [ "${#source_refs[@]}" -gt 0 ] || die 'input_refs must contain at least one source'
  
  validate_input_evidence_refs "${source_refs[@]}"
  
  # 3. REQ/ACC/VO 完整性
  local reqs=() accs=() vos=()
  mapfile -t reqs < <(collect_spec_ids 'REQ')
  mapfile -t accs < <(collect_spec_ids 'ACC')
  mapfile -t vos < <(collect_spec_ids 'VO')
  
  [ "${#reqs[@]}" -gt 0 ] || die 'no REQ-* entries found'
  [ "${#accs[@]}" -gt 0 ] || die 'no ACC-* entries found'
  [ "${#vos[@]}" -gt 0 ] || die 'no VO-* entries found'
  
  # 4. 追溯链完整性（Requirement 阶段内部）
  local req acc vo
  for req in "${reqs[@]}"; do
    grep -q "source_ref:.*${req}" "$SPEC_FILE" || die "${req} has no acceptance mapping"
  done
  
  for acc in "${accs[@]}"; do
    grep -q "acceptance_ref: ${acc}" "$SPEC_FILE" || die "${acc} has no verification mapping"
    is_placeholder_token "$(acceptance_expected_outcome "$acc")" && die "${acc} expected_outcome contains placeholder"
  done
  
  # 5. Inputs 闭包检查（确保所有输入都被需求覆盖）
  local intake_refs=() closure_refs=()
  mapfile -t intake_refs < <(input_intake_refs)
  mapfile -t closure_refs < <(requirements_source_refs)
  
  for intake_ref in "${intake_refs[@]}"; do
    contains_exact_line "$intake_ref" "${closure_refs[@]}" || \
      die "input_ref not covered by Requirements: ${intake_ref}"
  done
  
  # 6. 删除 Open Decisions 检查（不再需要）
  # Open Decisions 不应该存在，AI 应该在写完 spec.md 后自检并澄清
  
  log '✓ requirement-complete gate passed'
}
```

**关键变更**：
- 删除了 Open Decisions 相关的检查项
- 保留所有追溯链检查
- 保留占位符检查

### 阶段切换命令调整

#### 删除命令

- `codespec start-requirements`：删除（Proposal 和 Requirements 已合并）

#### 修改命令

- `codespec start-design`：
  - 检查 `requirement-complete` gate（替代原来的 `requirements-approval`）
  - 检查 `review-verdict-present` gate（要求 `design-review.yaml`，phase 字段为 `Requirement`）

#### 新增命令

- `codespec reopen-requirement`：
  - 从 Design/Implementation/Testing/Deployment 阶段返回 Requirement 阶段
  - 用于需求变更场景
  - 自动在 spec.md 顶部添加 Change Log 条目
  - 提示用户分析下游影响（提供 `analyze-requirement-change` 命令）

- `codespec analyze-requirement-change <REQ-ID|ACC-ID>`：
  - 分析需求变更的下游影响
  - 输出：
    - 哪些 Work Items 引用了该 REQ/ACC
    - 哪些测试记录关联了该 ACC
    - 建议的修复步骤

### 实施步骤总结

#### 第一步：文档结构精简

1. **修改 `/home/admin/.codespec/templates/spec.md`**：
   - 删除 `Intent` 章节，合并到 `Scope`
   - 删除 `Open Decisions` 章节（内联到 Requirements 或移到 appendix）
   - 删除 `Source Coverage` 子章节（简化为 Requirements 中的 source_ref）
   - 删除 `Constraints`/`Non-functional` 子章节（合并到 Requirements）
   - 新增 `## Change Log` 章节（用于需求变更记录）
   - 目标：从 69 行压缩到 40-50 行

2. **修改 `/home/admin/.codespec/templates/CLAUDE.md`**：
   - 删除 Proposal 阶段说明
   - 删除 Requirements 阶段说明
   - 新增 Requirement 阶段说明（单数）
   - 更新阶段读取规则
   - 强调全生命周期追溯

3. **修改 `/home/admin/.codespec/templates/AGENTS.md`**：
   - 同步更新阶段说明

#### 第二步：Gate 检查调整

1. **修改 `/home/admin/.codespec/scripts/check-gate.sh`**：
   - 删除 `gate_proposal_maturity()` 函数
   - 删除 `gate_requirements_approval()` 函数
   - 新增 `gate_requirement_complete()` 函数（合并两者的检查项）
   - 保留并强化 `gate_design_structure_complete()`（检查 REQ → WI 追溯）
   - 保留并强化 `gate_verification()`（检查 ACC → Testing 追溯）
   - 更新 `main()` 函数的 case 分支

#### 第三步：阶段切换命令调整

1. **修改 `/home/admin/.codespec/codespec`**：
   - 删除 `start_requirements()` 函数
   - 修改 `start_design()` 函数：
     - 检查 `requirement-complete` gate（替代 `requirements-approval`）
     - 检查 `review-verdict-present` gate（要求 `design-review.yaml`，phase 为 `Requirement`）
   - 新增 `reopen_requirement()` 函数（用于需求变更）
   - 新增 `analyze_requirement_change()` 函数（分析下游影响）
   - 修改 `assert_phase_transition()` 函数：
     - 删除 Proposal/Requirements 相关的转换规则
     - 新增 Requirement 相关的转换规则

#### 第四步：文档更新

1. **修改 `/home/admin/.codespec/README.md`**：
   - 更新阶段流程图（Requirement → Design → ...）
   - 更新快速开始示例
   - 更新命令表格
   - 新增"需求变更管理"章节

2. **修改 `/home/admin/.codespec/templates/phase-review-policy.md`**：
   - 删除 Proposal 和 Requirements 审查规则
   - 新增 Requirement 审查规则
   - 强调全生命周期追溯检查

#### 第五步：防漂移机制实施

1. **强化 `validate_input_evidence_refs()` 函数**：
   - 禁止 conversation:// 引用
   - 强制使用稳定的 repo 文件引用

2. **新增 Change Log 机制**：
   - 在 spec.md 顶部添加 `## Change Log` 章节
   - `reopen_requirement` 命令自动添加变更记录
   - 变更记录必须包含：原因、变更内容、下游影响、审查状态

3. **新增下游影响分析**：
   - `analyze_requirement_change` 命令分析 REQ/ACC 变更的影响
   - 输出：影响的 Work Items、测试记录、建议的修复步骤

4. **强化审查机制**：
   - `design-review.yaml` 必须包含 review_notes
   - 需求变更后必须重新审查（`design-review-v2.yaml`）
   - 审查必须包含全生命周期追溯检查

## 需要修改的文件清单

### 核心文件（必须修改）

1. **`/home/admin/.codespec/templates/spec.md`**
   - 精简文档结构（Intent → Scope，删除 Source Coverage 等）
   - 新增 Change Log 章节
   - 目标：从 69 行 → 40-50 行

2. **`/home/admin/.codespec/scripts/check-gate.sh`**
   - 删除 `gate_proposal_maturity()`
   - 删除 `gate_requirements_approval()`
   - 新增 `gate_requirement_complete()`
   - 强化 `gate_design_structure_complete()`（检查 REQ → WI 追溯）
   - 强化 `gate_verification()`（检查 ACC → Testing 追溯）
   - 更新 `main()` 函数

3. **`/home/admin/.codespec/codespec`**
   - 删除 `start_requirements()`
   - 修改 `start_design()`（检查 `requirement-complete` gate）
   - 新增 `reopen_requirement()`（需求变更）
   - 新增 `analyze_requirement_change()`（下游影响分析）
   - 修改 `assert_phase_transition()`

4. **`/home/admin/.codespec/templates/CLAUDE.md`**
   - 删除 Proposal/Requirements 阶段说明
   - 新增 Requirement 阶段说明（单数）
   - 更新阶段读取规则
   - 强调全生命周期追溯

5. **`/home/admin/.codespec/templates/meta.yaml`**
   - 更新 phase 字段注释（Requirement → Design → ...）

### 文档文件（需要更新）

6. **`/home/admin/.codespec/README.md`**
   - 更新阶段流程图
   - 更新快速开始示例
   - 更新命令表格

7. **`/home/admin/.codespec/templates/AGENTS.md`**
   - 同步更新阶段说明

8. **`/home/admin/.codespec/templates/phase-review-policy.md`**
   - 删除 Proposal/Requirements 审查规则
   - 新增 Specification 审查规则

## 风险评估与缓解

### 风险 1：向后兼容性

**风险**：现有项目（处于 Proposal 或 Requirements 阶段）无法继续推进。

**缓解**：
1. 提供迁移脚本：`codespec migrate-to-requirement`
   - 自动检测当前阶段
   - 如果是 Proposal 或 Requirements，自动转换为 Requirement
   - 保留原有内容，不丢失数据
   - 更新 meta.yaml 的 phase 字段

2. 保留兼容性检查：
   - `check-gate.sh` 中保留 `proposal-maturity` 和 `requirements-approval` 的别名
   - 指向 `requirement-complete`
   - 提供友好的废弃提示

### 风险 2：需求漂移（全生命周期）

**风险**：精简文档后，追溯链可能断裂，需求悄悄改变，下游不知道。

**缓解**：
1. **强化 gate 检查（全链路）**：
   - `requirement-complete` gate：检查 Inputs → REQ → ACC → VO 追溯链
   - `design-structure-complete` gate：检查 REQ → WI、ACC → WI 追溯链
   - `verification` gate：检查 ACC → Testing 追溯链
   - `promotion-criteria` gate：检查所有 ACC 都有 full-integration pass 记录

2. **Change Log 机制**：
   - 需求变更必须记录在 spec.md 顶部
   - `reopen_requirement` 命令自动添加变更记录
   - 变更记录必须包含下游影响分析

3. **下游影响分析**：
   - `analyze-requirement-change` 命令自动分析影响范围
   - 输出：影响的 Work Items、测试记录、建议的修复步骤
   - 强制用户确认下游影响后才能继续

4. **审查机制**：
   - 需求变更后必须重新审查
   - 审查文件必须包含 review_notes
   - 审查必须包含全生命周期追溯检查

5. **禁止 conversation:// 引用**：
   - `requirement-complete` gate 强制检查所有 source_refs 都是稳定的 repo 文件引用
   - 确保需求的"源头"永久可追溯

### 风险 3：文档过于精简

**风险**：删除章节后，信息丢失，上下文不足。

**缓解**：
1. **保留核心章节**：
   - Summary、Inputs、Scope、Requirements、Acceptance、Verification
   - 这些是追溯链的核心节点，不能删除

2. **使用 appendix**：
   - 详细的背景信息、技术调研、决策过程等，移到 `spec-appendices/`
   - 主文档保持简洁，appendix 提供深度

3. **内联关键信息**：
   - Requirements 中的 rationale 字段，说明"为什么需要"
   - Acceptance 中的 priority_rationale 字段，说明"为什么是这个优先级"

### 风险 4：用户认知负担

**风险**：用户不理解新的阶段流程，不知道如何使用。

**缓解**：
1. **更新文档**：
   - README 中提供清晰的快速开始示例
   - CLAUDE.md 中提供详细的阶段说明

2. **提供迁移指南**：
   - 在 README 中添加"从旧版本迁移"章节
   - 说明 Proposal + Requirements → Specification 的对应关系

3. **保留命令别名**：
   - `codespec start-requirements` → 提示"该命令已废弃，请使用 start-design"
   - 提供友好的错误信息

## 实施优先级

### P0（必须完成）

1. 修改 `check-gate.sh`：新增 `gate_specification_complete()`
2. 修改 `codespec`：删除 `start_requirements()`，修改 `start_design()`
3. 修改 `templates/spec.md`：精简文档结构
4. 修改 `templates/CLAUDE.md`：更新阶段说明

### P1（重要）

5. 修改 `README.md`：更新流程说明
6. 新增 `reopen_specification()` 函数
7. 新增迁移脚本：`codespec migrate-to-specification`

### P2（可选）

8. 修改 `templates/AGENTS.md`：同步更新
9. 修改 `templates/phase-review-policy.md`：更新审查规则
10. 提供命令别名和友好错误信息

## 总结

**完全合并方案的核心价值**：
1. **流程简化**：7 个阶段 → 6 个阶段（Requirement → Design → Implementation → Testing → Deployment → Completed）
2. **文档精简**：spec.md 从 69 行 → 40-50 行，减少 30% 上下文长度
3. **认知负担降低**：不需要区分 Proposal 和 Requirements，一次性完成需求工作
4. **与 AI 协作匹配**：连续讨论，自然推进，不人为割裂
5. **阶段定位清晰**：Requirement 专注需求，Design 专注设计（架构、概要、详细）

**防漂移机制的核心保障（全生命周期）**：
1. **追溯链强化**：Inputs → REQ → ACC → VO → WI → Testing → Deployment，全链路可追溯
2. **输入快照**：禁止 conversation:// 引用，强制使用稳定的 repo 文件引用
3. **变更控制**：Change Log 机制 + 下游影响分析 + 重新审查机制
4. **Gate 检查（全链路）**：
   - `requirement-complete`：检查 Inputs → REQ → ACC → VO 追溯链
   - `design-structure-complete`：检查 REQ → WI、ACC → WI 追溯链
   - `verification`：检查 ACC → Testing 追溯链
   - `promotion-criteria`：检查所有 ACC 都有 full-integration pass 记录
5. **下游影响分析**：`analyze-requirement-change` 命令自动分析 REQ/ACC 变更的影响范围

**实施建议**：
- 先完成 P0 任务（gate 检查、阶段切换、文档精简），确保核心功能可用
- 提供迁移脚本（`migrate-to-requirement`），确保向后兼容
- 逐步完成 P1/P2 任务（下游影响分析、审查机制），完善用户体验
- 重点关注全生命周期追溯，确保需求变更不会导致下游失控
