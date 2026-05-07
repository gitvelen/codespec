# CLAUDE.md

尽量用简体中文交流（除非涉及专业术语），禁止用 worktree。

---

## 快速通道

用户在会话开始或首次任务中明确要求“本次走快速通道”时，先确认：“是否本会话跳过 Codespec 框架约束，只保留核心原则？”

用户确认后：
- 不主动读取 `meta.yaml`、`codespec readset`、阶段文档、Work Item、review、gate
- 不执行 Codespec 阶段流程、阶段切换检查、提交/PR 节奏
- 只保留“核心原则”、更高优先级指令和用户当前明确要求

快速通道只在当前会话有效，不写入 `meta.yaml`。明显高风险任务先说明风险。

---

## 一、每次启动必读

- `../lessons_learned.md` - 读取快速索引中的全部硬规则
- `./meta.yaml`
- 根据当前阶段执行 `codespec readset --json`，按 `layered_readset.default -> work_item/phase -> on_demand` 分层读取；不要凭记忆决定该读哪些文档
- 读取权威文档时先读 `0. AI 阅读契约`；权威文档为空、冲突或不足以支撑当前任务时，停止并补文档或询问用户。
- 如果项目进入了Implementation阶段，就默认是自动模式，不该停下来向我展示进展或作其他提示（除非有重大安全隐患）
- Implementation / Testing / Deployment 的每轮开发、修复、阶段切换或汇报收口前，先执行 `codespec completion-report`，并确保 `testing.md` 追加对应 `HANDOFF-*`；回复必须主动列未完成项、最高完成等级、证据、阻塞原因和下一步。

---

## 二、什么时候必须停下

**范围越界**：
- 需要修改不在当前 WI 的 `allowed_paths` 中的文件 → 停止
- 需要修改 `forbidden_paths` 中的文件 → 停止
- 需要实现 `out_of_scope` 中的功能 → 停止
- 需要修改 frozen contract → 停止

**目标不清**：
- 目标/边界/验收不清楚 → 先问用户
- `spec.md` / `design.md` / `work-items/*.yaml` 之间描述不一致 → 先对齐
- 需要做产品判断（非纯工程判断）→ 先问用户
- 任何不确定的事情（目标/边界/验收/技术方案）→ 立即停下来问用户，讨论明确后直接写入正式文档

**执行偏离**：
- 连续失败或复杂度超预期 → 停下重新规划
- 发现需要先回写权威文件（spec/design/testing/deployment）→ 停止当前任务，先更新文档
- Implementation/Testing/Deployment 阶段的 gate 发现上游 authority 缺口 → 不要手改 forbidden 文件；先用 `codespec authority-repair begin <gate> --paths <最小路径> --reason "<原因>"` 进入修复态，修完后 `codespec authority-repair close --evidence "<证据>"`
- Implementation/Testing/Deployment 阶段缺少主动未完成清单或语义 handoff → 停止阶段推进；先补 `testing.md` 的 `HANDOFF-*`，并运行 `codespec check-gate semantic-handoff`
- 依赖 Work Item 尚未完成，但当前任务需要其结果 → 停止，等待依赖
- 测试失败且无法在当前 scope 内修复 → 回看 work-item.yaml，可能需要扩大 allowed_paths
- Requirement 阶段在 appendix 中定义正式 REQ/ACC/VO → 停止，只能在主文档中定义
- Requirement 阶段缺少 `TC-*` 测试用例计划 → 停止，先补 `testing.md`
- Implementation 阶段发现当前 WI 没有引用 `TC-*` → 停止，先回写 `design.md` / `work-items/*.yaml`
- P0 验收不能自动化且没有 `automation_exception_reason` → 停止，必须由 review 明确接受

---

## 三、核心原则

**取舍说明**：以下规则默认偏向谨慎而不是速度。

### 1. 先想清楚再动手

**不要想当然，不要掩盖困惑，要把假设和权衡说清楚。**

 - 明确说明你的假设。不确定时就提问。
 - 如果存在多种理解方式，把它们列出来，不要默默自行选择。
 - 如果有更简单的做法，直接指出来；必要时应当提出异议。
 - 如果有任何地方不清楚，就先停下。说清楚困惑点，然后提问。

### 2. 简单优先

**只写解决当前问题所需的最少代码，不预埋未来需求。**

- 不做未被请求的功能
- 不为一次性代码提前抽象
- 不引入未被要求的“灵活性”或“可配置性”
- 不为事实上不可能发生的场景补错误处理
- 如果 200 行能压到 50 行且不损失可读性，就重写到足够简单

问问自己：“一位资深工程师会不会认为这实现过于复杂？”如果会，就继续简化。

### 3. 手术式改动

**只改必须改的地方，只清理自己引入的问题。**

编辑既有代码时：
- 不顺手“改进”相邻代码、注释或格式
- 不重构没有坏掉的部分
- 尽量贴合现有风格，即使你的做法不同
- 发现无关的死代码时可以提示，但不要擅自删除

如果你的改动产生了遗留物：
- 删除因你的修改而不再使用的导入项、变量、函数
- 不要顺带清理既有的死代码，除非用户明确要求

判断标准：每一行修改后的代码都应当能直接追溯到用户的请求。

### 4. 以目标驱动执行

**先定义可验证的成功标准，再循环执行直到验证通过。**

- “加校验”应落实为：编写针对非法输入的测试案例，确保程序能高质量地通过测试
- “修 bug”应落实为：先写能复现问题的测试，再修到通过
- “重构 X”应落实为：改前改后都验证相关测试通过

多步骤任务先给出一个简短计划，并把每一步的验证方式写出来，例如：

```text
1. [步骤] -> verify: [检查项]
2. [步骤] -> verify: [检查项]
3. [步骤] -> verify: [检查项]
```

成功标准越强，越能独立闭环推进；像“把它弄好”这种弱目标会导致反复澄清和返工。

**这些规则生效的表现**：diff 中无关改动更少、因过度设计导致的返工更少、澄清问题发生在实现之前而不是出错之后。

### 5. 主动披露未完成项

Implementation / Testing / Deployment 阶段不能只汇报“测试通过”或“本轮完成”。每次阶段性回复必须包含：已完成证据、未完成清单、当前最高 completion_level、阻塞原因、下一步。`fixture_contract` 只能说 fixture/契约通过，`api_connected` 只能说 API 连接级通过，`integrated_runtime` 才能说运行时集成完成，`owner_verified` 才能说用户验收完成。存在 fallback/fixture、dirty gate、缺 report artifact 或缺 owner_verified 时，禁止使用“全部完成”“收口完成”“可进入下一阶段”等措辞。

---

## 四、阶段切换前检查

- Requirement->Design、Design->Implementation，这两种阶段切换必须向人类显示确认
- 不要凭记忆推进，统一以 `../phase-review-policy.md` 为准
- 先确认人工审查是否满足；`check-gate` 只是最低机器门槛，不替代语义审查
- 命令入口优先使用 `codespec <cmd>`；如果当前 shell 不可调用，再使用工作区runtime（默认布局下常见为 `../.codespec/codespec <cmd>`）
- 需要查看机器门槛时，执行 `codespec check-gate <gate-name>`；支持的 gate 名称与命令列表以 `codespec --help` 为准
- 若只是确认当前任务的最小必读上下文，执行 `codespec readset`
- 若处于 authority repair mode，提交前确认 `authority-repairs/*.yaml`、`meta.yaml` 和修复的最小 authority 文件同批暂存；未关闭 repair 不得推进阶段

---

## 五、提交与 PR 节奏

- 一个 commit 只承载一个可独立审查的事实边界，不要把实现、测试证据、人工验收、最终收口混在一起
- `testing.md` 的验证证据单独提交；`deployment.md` 的人工验收结论也单独提交
- 若人工验收已通过且当前分支不是默认分支，优先使用 `codespec submit-pr <stable-version>` 做最终交接
- `submit-pr` 之前必须保证工作树干净；不要一边保留未提交改动，一边创建最终 PR
- 不要在 execution branch 上直接提 PR；并行模式下只允许在 `feature_branch` 上执行 `submit-pr`

---

## 六、Compact Instructions 保留优先级

1. 架构决策，不得摘要
2. 已修改文件和关键变更
3. 验证状态，pass/fail
4. 未解决的 TODO 和回滚笔记
5. 工具输出，可删，只保留 pass/fail 结论

---
