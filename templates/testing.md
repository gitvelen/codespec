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

**最终验收**：
- 每个 acceptance 至少需要一条 test_scope=full-integration 且 result=PASS 的记录
- branch-local 测试供参考，不作为最终验收依据

---

## Branch-Local Testing (Implementation Phase)

执行分支在 Implementation 阶段的测试记录。

### WI-001 (Branch: group/sanguoA)

#### ACC-001: User can login with email and password

**Unit Tests**:
- test_type: unit
  test_scope: branch-local
  verification_type: automated
  test_command: npm test -- src/auth/login.test.ts
  test_date: 2026-04-16
  artifact_ref: coverage/unit/login.html
  result: PASS
  notes: Tested login logic with valid/invalid credentials
  residual_risk: none
  reopen_required: false

**Integration Tests**:
- test_type: integration
  test_scope: branch-local
  verification_type: automated
  test_command: npm test -- src/auth/integration.test.ts
  test_date: 2026-04-16
  artifact_ref: coverage/integration/auth.html
  result: PASS
  notes: Tested login with database and session management
  residual_risk: none
  reopen_required: false

### WI-002 (Branch: group/sanguoB)

#### ACC-002: User can logout

**Unit Tests**:
- test_type: unit
  test_scope: branch-local
  verification_type: automated
  test_command: npm test -- src/auth/logout.test.ts
  test_date: 2026-04-16
  artifact_ref: coverage/unit/logout.html
  result: PASS
  notes: Tested logout logic and session cleanup
  residual_risk: none
  reopen_required: false

---

## Full Integration Testing (Testing Phase)

在 parent feature 分支的完整集成测试，作为最终验收依据。

### ACC-001: User can login with email and password

**Unit Tests** (re-run after merge):
- test_type: unit
  test_scope: full-integration
  verification_type: automated
  test_command: npm test -- src/auth/login.test.ts
  test_date: 2026-04-17
  artifact_ref: coverage/unit/login.html
  result: PASS
  notes: Re-run after merging all branches
  residual_risk: none
  reopen_required: false

**Integration Tests** (re-run after merge):
- test_type: integration
  test_scope: full-integration
  verification_type: automated
  test_command: npm test -- src/auth/integration.test.ts
  test_date: 2026-04-17
  artifact_ref: coverage/integration/auth.html
  result: PASS
  notes: Verified login works with all merged changes
  residual_risk: none
  reopen_required: false

**E2E Tests**:
- test_type: e2e
  test_scope: full-integration
  verification_type: automated
  test_command: npm run test:e2e -- login.spec.ts
  test_date: 2026-04-17
  artifact_ref: e2e-results/login.html
  result: PASS
  notes: Tested complete login flow in browser
  residual_risk: none
  reopen_required: false

**Manual Tests**:
- test_type: manual
  test_scope: full-integration
  verification_type: manual
  test_command: N/A
  test_date: 2026-04-17
  artifact_ref: manual-test-checklist.md
  result: PASS
  notes: Manually verified UI/UX, error messages, accessibility
  residual_risk: none
  reopen_required: false

### ACC-002: User can logout

**Unit Tests** (re-run after merge):
- test_type: unit
  test_scope: full-integration
  verification_type: automated
  test_command: npm test -- src/auth/logout.test.ts
  test_date: 2026-04-17
  artifact_ref: coverage/unit/logout.html
  result: PASS
  notes: Re-run after merging all branches
  residual_risk: none
  reopen_required: false

**E2E Tests**:
- test_type: e2e
  test_scope: full-integration
  verification_type: automated
  test_command: npm run test:e2e -- logout.spec.ts
  test_date: 2026-04-17
  artifact_ref: e2e-results/logout.html
  result: PASS
  notes: Tested complete logout flow, verified session cleanup
  residual_risk: none
  reopen_required: false

---

## Performance Testing (Optional)

### ACC-001: User can login with email and password

- test_type: performance
  test_scope: full-integration
  verification_type: automated
  test_command: npm run test:perf -- login
  test_date: 2026-04-17
  artifact_ref: perf-results/login.html
  result: PASS
  notes: Login completes in <200ms (p95), meets performance requirement
  residual_risk: none
  reopen_required: false

---

## Security Testing (Optional)

### ACC-001: User can login with email and password

- test_type: security
  test_scope: full-integration
  verification_type: automated
  test_command: npm run test:security -- auth
  test_date: 2026-04-17
  artifact_ref: security-scan/auth.html
  result: PASS
  notes: No SQL injection, XSS, or CSRF vulnerabilities found
  residual_risk: none
  reopen_required: false

---

## Summary

**Final Acceptance Status**:
- ACC-001: ✅ PASS (unit + integration + e2e + manual + performance + security)
- ACC-002: ✅ PASS (unit + e2e)

**Test Coverage**:
- Unit tests: 95%
- Integration tests: 90%
- E2E tests: 100% of critical paths

**Residual Risks**: None
