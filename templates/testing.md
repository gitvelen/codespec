# testing.md

<!-- CODESPEC:TESTING:READING -->
## 0. AI 阅读契约

- 本文件不是测试说明书模板，而是“测试用例计划 + 测试执行证据”的权威账本。
- `TC-*` 在需求确认后生成，用于说明每条验收如何被证明；`RUN-*` 在实际执行后追加，用于记录证据。
- `HANDOFF-*` 在 Implementation / Testing / Deployment 阶段性收口前追加，用于主动披露语义未完成项、最高完成等级、阻塞原因和下一步；测试绿灯不能替代 handoff。
- `spec.md` 的 `VO-*` 定义必须验证什么和证据类型；本文件的 `TC-*` 定义如何用场景、fixture、命令、步骤和 `RUN-*` 证据执行验证。
- 复杂流程的 `TC-*` 应引用或复现 `spec.md` 中的流程叙事，覆盖 happy path、失败/降级路径和关键产物链；不能只扫描字段或禁用入口。
- 若页面或 API 用 fallback/fixture 替代真实失败态，handoff 必须列为未完成，直到加载、空、错、stale、trace/retry、冲突和真实 API 数据路径都有证据。
- Testing 阶段不得临时发明覆盖口径；若发现缺少必要测试用例，应回到 Requirement/Design 补齐。
- 人工测试不是豁免测试，必须写明人工原因、步骤、预期结果和证据形状。

<!-- CODESPEC:TESTING:LEVELS -->
## 0.1 测试层级定义

- `branch-local`: 在当前分支本地运行，验证 WI 级别的功能正确性。允许使用 fixture / mock。
- `full-integration`: 必须在集成环境中运行，覆盖完整链路。最低要求：
  - 真实外部依赖已连接（非 fixture / mock）
  - 数据已持久化（非仅内存）
  - 端到端流程可复现（command_or_steps 可重复执行）
  - artifact_ref 指向可复核的持久化证据
  - RUN 记录的 completion_level 必须 >= integrated_runtime
- `deployment`: 在目标环境部署后执行，验证运行时行为。
- completion_level 枚举（由浅到深）：fixture_contract / in_memory_domain / api_connected / db_persistent / integrated_runtime / owner_verified

<!-- CODESPEC:TESTING:CASES -->
## 1. 验收覆盖与测试用例

- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  work_item_refs: [WI-001]
  test_type: integration
  verification_mode: automated
  required_stage: testing
  required_completion_level: integrated_runtime  # fixture_contract / in_memory_domain / api_connected / db_persistent / integrated_runtime / owner_verified
  scenario: [要验证的用户场景或系统行为]
  given: [前置条件]
  when: [触发动作]
  then: [可观察结果]
  evidence_expectation: [命令输出、日志、截图、报告或人工确认]
  automation_exception_reason: none
  manual_steps:
    - none
  status: planned

<!-- CODESPEC:TESTING:RUNS -->
## 2. 测试执行记录

- run_id: RUN-001
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: branch-local
  verification_type: automated
  completion_level: fixture_contract  # fixture_contract / in_memory_domain / api_connected / db_persistent / integrated_runtime / owner_verified
  command_or_steps: [真实命令或人工步骤]  # 必填：记录实际执行的命令或人工步骤，不得留空或使用占位符
  artifact_ref: [可复核证据路径或链接]
  result: pass/fail
  tested_at: YYYY-MM-DD
  tested_by: [执行者]
  residual_risk: none/low/medium/high
  reopen_required: false

<!-- CODESPEC:TESTING:RISKS -->
## 3. 残留风险与返工判断

- residual_risk: [none/low/medium/high]
- reopen_required: false
- notes:
  - [仍需关注的风险；没有则写 none]

<!-- CODESPEC:TESTING:HANDOFFS -->
## 4. 主动未完成清单与语义验收

- handoff_id: HANDOFF-001
  phase: Implementation  # Implementation / Testing / Deployment
  work_item_refs: [WI-001]
  highest_completion_level: fixture_contract  # fixture_contract / in_memory_domain / api_connected / db_persistent / integrated_runtime / owner_verified
  evidence_refs:
    - testing.md#RUN-001
  unfinished_items:
    - source_ref: testing.md#TC-ACC-001-01
      priority: P0
      current_completion_level: fixture_contract
      target_completion_level: integrated_runtime
      blocker: [为什么还不能称为完成]
      next_step: [下一步修复或验证动作]
  fixture_or_fallback_paths:
    - surface: [页面/API/流程]
      completion_level: fixture_contract
      real_api_verified: false
      visible_failure_state: false
      trace_retry_verified: false
  wording_guard: "只能报告当前完成等级；不得把 fixture/api_connected/branch-local 说成 integrated_runtime 或 owner_verified"
