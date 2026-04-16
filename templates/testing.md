# Testing Records

## Branch-Local Testing (Optional)
执行分支的单元测试和局部集成测试记录，供参考，不作为最终验收依据。

### WI-XXX (Branch: group/xxx)
- acceptance_ref: ACC-XXX
  test_scope: unit  # or local-integration
  verification_type: automated
  test_command: [command to run test]
  test_date: [YYYY-MM-DD]
  artifact_ref: [test output or coverage report]
  result: [PASS/FAIL/pending]
  notes: [additional context]
  residual_risk: [if result is PASS with known limitations]
  reopen_required: false

## Integration Testing (Required)
在 parent feature 分支的完整集成测试，作为最终验收依据。

### Full Integration Test
- acceptance_ref: ACC-XXX
  test_scope: full-integration
  verification_type: automated
  test_command: [command to run full test suite]
  test_date: [YYYY-MM-DD]
  artifact_ref: [test output or coverage report]
  result: [PASS/FAIL/pending]
  notes: [additional context]
  residual_risk: [if result is PASS with known limitations]
  reopen_required: false

---

**Notes**:
- Branch-local tests (test_scope: unit / local-integration) are recorded during Implementation phase in execution branches
- Full integration tests (test_scope: full-integration) are recorded during Testing phase in parent feature branch
- Final acceptance is based on full-integration results
- If testing.md has merge conflicts, keep all test records from all branches
