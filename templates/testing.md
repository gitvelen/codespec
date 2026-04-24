# Testing Records

## How to Use This File

testing.md 是测试证据账本，记录所有测试活动。每个 acceptance 可以有多条测试记录，覆盖不同的测试类型。

**测试类型（test_type）**：
- `unit`: 单元测试，测试单个函数/类的逻辑
- `integration`: 集成测试，测试多个模块的交互
- `e2e`: 端到端测试，测试完整的用户流程
- `performance`: 性能测试，测试响应时间/吞吐量
- `security`: 安全测试，测试安全漏洞
- `manual`: 手工测试，人工验证

**测试范围（test_scope）**：
- `branch-local`: 执行分支的局部测试（Implementation 阶段）
- `full-integration`: 完整集成测试（Testing Phase，parent feature 分支）

**测试结果（result）**：
- `pass`: 测试通过，acceptance 得到验证
- `fail`: 测试失败，需要修复实现或重新开启 spec/design

**残留风险（residual_risk）**：
- `none`: 无残留风险
- `low`: 低风险，可接受的小问题
- `medium`: 中等风险，需要监控
- `high`: 高风险，需要立即处理或重新开启 spec/design

**重新开启标记（reopen_required）**：
- `true`: 需要重新开启 spec/design 进行调整
- `false`: 不需要重新开启

**最终验收**：
- 每个 acceptance 至少需要一条 test_scope=full-integration 且 result=pass 的记录
- branch-local 测试供参考，不作为最终验收依据

## Acceptance 到 Testing 的映射

每个 spec.md 中的 acceptance（ACC-ID）可以在 testing.md 中有多条测试记录：
- 同一个 ACC-ID 可以有多个 test_type（unit, integration, e2e, performance, security, manual）
- 同一个 ACC-ID 可以有多个 test_scope（branch-local, full-integration）
- 最终验收要求：每个 ACC-ID 至少有一条 test_scope=full-integration 且 result=pass 的记录

**示例**：
- ACC-001 可以有：unit (branch-local) + integration (branch-local) + unit (full-integration) + e2e (full-integration)
- 只有 full-integration 的测试记录才作为最终验收依据

---

## Branch-Local Testing (Implementation Phase)

执行分支在 Implementation 阶段的测试记录。

### WI-XXX-EXAMPLE (Branch: [branch-name])

**说明**：以下是 branch-local 测试记录格式示例，实际使用时请：
1. 将 WI-XXX-EXAMPLE 替换为真实的 work item ID（如 WI-001）
2. 将 [branch-name] 替换为真实的执行分支名
3. 将 ACC-XXX-EXAMPLE 替换为真实的 acceptance ID
4. 填写真实的测试命令、日期、artifact 路径
5. 删除本说明段落

#### ACC-XXX-EXAMPLE: [Example acceptance criterion]

**Unit Tests**:
- acceptance_ref: ACC-XXX-EXAMPLE
  test_type: unit
  test_scope: branch-local
  verification_type: automated
  test_command: [TODO: actual test command]
  test_date: YYYY-MM-DD
  artifact_ref: [TODO: path to test artifact]
  result: pass
  notes: [TODO: test notes]
  residual_risk: none
  reopen_required: false

**Integration Tests**:
- acceptance_ref: ACC-XXX-EXAMPLE
  test_type: integration
  test_scope: branch-local
  verification_type: automated
  test_command: [TODO: actual test command]
  test_date: YYYY-MM-DD
  artifact_ref: [TODO: path to test artifact]
  result: pass
  notes: [TODO: test notes]
  residual_risk: none
  reopen_required: false


---

## Full Integration Testing (Testing Phase)

在 parent feature 分支的完整集成测试，作为最终验收依据。

### ACC-XXX-EXAMPLE: [Example acceptance criterion]

**说明**：以下是测试记录格式示例，实际使用时请：
1. 将 ACC-XXX-EXAMPLE 替换为真实的 acceptance ID（如 ACC-001）
2. 填写真实的测试命令、日期、artifact 路径
3. 删除本说明段落

**Unit Tests** (re-run after merge):
- acceptance_ref: ACC-XXX-EXAMPLE
  test_type: unit
  test_scope: full-integration
  verification_type: automated
  test_command: [TODO: actual test command]
  test_date: YYYY-MM-DD
  artifact_ref: [TODO: path to test artifact]
  result: pass
  notes: [TODO: test notes]
  residual_risk: none
  reopen_required: false

**Integration Tests** (re-run after merge):
- acceptance_ref: ACC-XXX-EXAMPLE
  test_type: integration
  test_scope: full-integration
  verification_type: automated
  test_command: [TODO: actual test command]
  test_date: YYYY-MM-DD
  artifact_ref: [TODO: path to test artifact]
  result: pass
  notes: [TODO: test notes]
  residual_risk: none
  reopen_required: false

**E2E Tests**:
- acceptance_ref: ACC-XXX-EXAMPLE
  test_type: e2e
  test_scope: full-integration
  verification_type: automated
  test_command: [TODO: actual test command]
  test_date: YYYY-MM-DD
  artifact_ref: [TODO: path to test artifact]
  result: pass
  notes: [TODO: test notes]
  residual_risk: none
  reopen_required: false

**Manual Tests**:
- acceptance_ref: ACC-XXX-EXAMPLE
  test_type: manual
  test_scope: full-integration
  verification_type: manual
  test_command: N/A
  test_date: YYYY-MM-DD
  artifact_ref: [TODO: manual test checklist path]
  result: pass
  notes: [TODO: manual test notes]
  residual_risk: none
  reopen_required: false

---

## Performance Testing (Optional)

### ACC-XXX-EXAMPLE: [Example acceptance criterion]

- acceptance_ref: ACC-XXX-EXAMPLE
  test_type: performance
  test_scope: full-integration
  verification_type: automated
  test_command: [TODO: actual performance test command]
  test_date: YYYY-MM-DD
  artifact_ref: [TODO: path to performance test results]
  result: pass
  notes: [TODO: performance metrics and requirements met]
  residual_risk: none
  reopen_required: false

---

## Security Testing (Optional)

### ACC-XXX-EXAMPLE: [Example acceptance criterion]

- acceptance_ref: ACC-XXX-EXAMPLE
  test_type: security
  test_scope: full-integration
  verification_type: automated
  test_command: [TODO: actual security test command]
  test_date: YYYY-MM-DD
  artifact_ref: [TODO: path to security scan results]
  result: pass
  notes: [TODO: security findings and verification]
  residual_risk: none
  reopen_required: false

---

## Summary

**Final Acceptance Status**:
- ACC-XXX-EXAMPLE: [TODO: status summary]

**Test Coverage**:
- Unit tests: [TODO: coverage %]
- Integration tests: [TODO: coverage %]
- E2E tests: [TODO: coverage description]

**Residual Risks**: [TODO: list any residual risks or "None"]

