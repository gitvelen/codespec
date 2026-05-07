#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_WORKSPACE="$(mktemp -d /tmp/codespec-smoke-XXXXXX)"

cleanup() {
  rm -rf "$TMP_WORKSPACE"
}
trap cleanup EXIT

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || die "expected output to contain: $needle"
}

assert_json_eq() {
  local json="$1"
  local expression="$2"
  local expected="$3"
  local actual
  actual="$(printf '%s' "$json" | yq eval -o=json "$expression" -)"
  [ "$actual" = "$expected" ] || die "expected JSON expression $expression to equal $expected, got: $actual"
}

expect_fail_cmd() {
  local expected="$1"
  local command="$2"
  local output status

  set +e
  output="$(bash -lc "$command" 2>&1)"
  status=$?
  set -e

  [ "$status" -ne 0 ] || die "expected failure for command: $command"
  [[ "$output" == *"$expected"* ]] || die "expected failure output to contain '$expected', got: $output"
  log "✓ expected failure: $expected"
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  [ "$actual" = "$expected" ] || die "expected '$expected', got '$actual'"
}

run_scope_aggregation_regression() {
  local project clean_head base output status
  project="$TMP_WORKSPACE/scope-aggregation-project"
  mkdir -p "$project/work-items"
  (
    cd "$project"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    mkdir -p frontend
    cat > spec.md <<'EOF'
# spec
EOF
    cat > design.md <<'EOF'
# design
EOF
    cat > testing.md <<'EOF'
# testing
EOF
    cat > meta.yaml <<'EOF'
phase: Design
status: active
focus_work_item: null
active_work_items: []
implementation_base_revision: null
EOF
    cat > work-items/WI-001.yaml <<'EOF'
allowed_paths:
  - frontend/**
forbidden_paths:
  - versions/**
  - spec.md
  - design.md
  - work-items/**
  - deployment.md
completion_level: fixture_contract
EOF
    cat > work-items/WI-002.yaml <<'EOF'
allowed_paths:
  - backend/**
forbidden_paths:
  - versions/**
  - spec.md
  - design.md
  - work-items/**
  - deployment.md
  - frontend/**
completion_level: fixture_contract
EOF
    git add .
    git commit -q -m "base"
    base="$(git rev-parse HEAD)"

    cat > meta.yaml <<EOF
phase: Implementation
status: active
focus_work_item: WI-001
active_work_items: [WI-001, WI-002]
implementation_base_revision: $base
EOF
    git add meta.yaml
    git commit -q -m "enter implementation"

    cat >> testing.md <<'EOF'

- run_id: RUN-001
  result: pass
EOF
    git add testing.md
    git commit -q -m "add evidence"

    cat > frontend/index.html <<'EOF'
frontend change
EOF
    git add frontend/index.html
    git commit -q -m "implement frontend slice"

    CODESPEC_PROJECT_ROOT="$project" CODESPEC_SCOPE_MODE=implementation-span "$FRAMEWORK_ROOT/scripts/check-gate.sh" scope >/dev/null
    clean_head="$(git rev-parse HEAD)"

    printf '\nforbidden implementation drift\n' >> spec.md
    git add spec.md
    git commit -q --no-verify -m "introduce forbidden spec drift"
    set +e
    output="$(CODESPEC_PROJECT_ROOT="$project" CODESPEC_SCOPE_MODE=implementation-span "$FRAMEWORK_ROOT/scripts/check-gate.sh" scope 2>&1)"
    status=$?
    set -e
    [ "$status" -ne 0 ] || die "implementation-span scope should reject spec.md drift"
    assert_contains "$output" "implementation span file spec.md is forbidden"
    git reset -q --hard "$clean_head"

    mkdir -p docs
    echo "unowned" > docs/unowned.txt
    git add docs/unowned.txt
    git commit -q --no-verify -m "introduce unowned file"
    set +e
    output="$(CODESPEC_PROJECT_ROOT="$project" CODESPEC_SCOPE_MODE=implementation-span "$FRAMEWORK_ROOT/scripts/check-gate.sh" scope 2>&1)"
    status=$?
    set -e
    [ "$status" -ne 0 ] || die "implementation-span scope should reject unowned file"
    assert_contains "$output" "implementation span file docs/unowned.txt is outside allowed_paths"
  )
  log "✓ implementation-span scope uses per-WI ownership semantics"
}

run_monorepo_project_root_test() {
  local repo app status_output expected_root
  repo="$TMP_WORKSPACE/monorepo-project"
  app="$repo/packages/app"
  expected_root="$app"

  git init "$repo" >/dev/null
  cd "$repo"
  git config user.name "Smoke Test"
  git config user.email "smoke@test.local"
  mkdir -p "$app"

  cd "$app"
  "$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
  [ -f "$app/meta.yaml" ] || die "monorepo init should create dossier in current project subdir"
  [ ! -f "$repo/meta.yaml" ] || die "monorepo init should not create dossier at git top-level"

  status_output="$("$TMP_WORKSPACE/.codespec/codespec" status)"
  assert_contains "$status_output" "project_root: $expected_root"

  cd "$repo"
  status_output="$("$TMP_WORKSPACE/.codespec/codespec" status)"
  assert_contains "$status_output" "project_root: $expected_root"

  cd "$TMP_WORKSPACE"
  log "✓ monorepo project root resolves to the dossier subdir"
}

run_scope_path_coverage_test() {
  local project base
  project="$TMP_WORKSPACE/scope-coverage-project"
  mkdir -p "$project/work-items"
  (
    cd "$project"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    cat > spec.md <<'EOF'
# spec

## Requirements
- req_id: REQ-001
  summary: test requirement
  source_ref: fixture
  rationale: test
  priority: P0

## Acceptance
- acc_id: ACC-001
  requirement_ref: REQ-001
  expected_outcome: pass
  priority: P0
  priority_rationale: test
  status: approved

## Verification
- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - verify pass
  artifact_expectation: output

## 5. 运行约束
none
EOF
    cat > design.md <<'EOF'
# design

## 0. AI 阅读契约
- authority

## Summary
- solution_summary: coverage fixture
- minimum_viable_design: minimal
- non_goals:
  - production

## Requirements Trace
- trace_note: covers REQ-001

## Technical Approach
- decision_id: ADR-001
  requirement_refs: [REQ-001]
  decision: fixture
  alternatives_considered:
    - none
  rationale: test
  consequences:
    - none
- runtime: bash
- storage: none

## Boundaries & Impacted Surfaces
- impacted_surfaces:
  - src/**
- external_interactions:
  - name: none
    failure_handling: none

## Data & Storage Design
- data_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture

## Cross-Cutting Design
- security_design:
  - no sensitive data
- environment_config:
  - none
- reliability_design:
  - fail fast

## 8. 实现阶段输入
- runbook: fixture runbook
- contract_summary: fixture contract
- view_summary: fixture view
- verification_summary: fixture verification

## Work Item Derivation
- wi_id: WI-001
  goal: test goal
  input_refs: []
  requirement_refs: [REQ-001]
  covered_acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  dependency_refs: []
  contract_refs: []
  contract_needed: false
  notes_on_boundary: test
EOF
    cat > testing.md <<'EOF'
# testing

## 1. 验收覆盖与测试用例
- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  work_item_refs: [WI-001]
  test_type: integration
  verification_mode: automated
  required_stage: testing
  scenario: test coverage
  given: fixture
  when: gate runs
  then: coverage check works
  evidence_expectation: output
  status: planned

## 2. 测试执行记录

## 3. 残留风险与返工判断
- residual_risk: none
EOF
    cat > meta.yaml <<'EOF'
phase: Implementation
status: active
focus_work_item: WI-001
active_work_items: [WI-001]
implementation_base_revision: null
EOF

    # Test A: uncovered surface → implementation-start fails
    cat > work-items/WI-001.yaml <<'EOF'
goal: test goal
scope:
  - implement DB schema
phase_scope: Implementation
derived_from: design.md
requirement_refs: [REQ-001]
acceptance_refs: [ACC-001]
verification_refs: [VO-001]
test_case_refs: [TC-ACC-001-01]
out_of_scope:
  - production
allowed_paths:
  - src/**
forbidden_paths:
  - versions/**
required_surfaces:
  - src/**
  - alembic.ini
  - migrations/**
required_verification:
  - unit tests pass
stop_conditions:
  - scope expansion
reopen_triggers:
  - architecture change
completion_level: fixture_contract
EOF
    git add .
    git commit -q -m "base"
    base="$(git rev-parse HEAD)"
    yq eval ".implementation_base_revision = \"$base\"" -i meta.yaml

    set +e
    output="$(CODESPEC_PROJECT_ROOT="$project" "$FRAMEWORK_ROOT/scripts/check-gate.sh" implementation-start 2>&1)"
    status=$?
    set -e
    [ "$status" -ne 0 ] || die "implementation-start should reject uncovered required_surfaces"
    assert_contains "$output" "required_surfaces not covered by allowed_paths"
    log "✓ uncovered surface correctly blocked"

    # Test B: no required_surfaces → warn but pass
    yq eval 'del(.required_surfaces)' -i work-items/WI-001.yaml
    output="$(CODESPEC_PROJECT_ROOT="$project" "$FRAMEWORK_ROOT/scripts/check-gate.sh" implementation-start 2>&1)"
    assert_contains "$output" "WARNING"
    assert_contains "$output" "no required_surfaces"
    log "✓ missing required_surfaces correctly warned"

    # Test C: covered surfaces → pass
    yq eval '.required_surfaces = ["src/**", "meta.yaml"]' -i work-items/WI-001.yaml
    yq eval '.allowed_paths += ["meta.yaml"]' -i work-items/WI-001.yaml
    CODESPEC_PROJECT_ROOT="$project" "$FRAMEWORK_ROOT/scripts/check-gate.sh" implementation-start >/dev/null
    log "✓ covered surfaces correctly passed"
  )
}

replace_markdown_section() {
  local file="$1"
  local header="$2"
  local content="$3"
  local tmp
  tmp="$(mktemp)"

  awk -v header="$header" -v replacement="$content" '
    BEGIN {
      in_section = 0
      replaced = 0
      section_lines = split(replacement, lines, /\n/)
    }
    $0 == header {
      print
      for (i = 1; i <= section_lines; i++) {
        print lines[i]
      }
      in_section = 1
      replaced = 1
      next
    }
    in_section && /^## / {
      in_section = 0
    }
    !in_section {
      print
    }
    END {
      if (!replaced) {
        exit 2
      }
    }
  ' "$file" > "$tmp" || die "failed to replace section $header in $file"

  mv "$tmp" "$file"
}

log "smoke workspace: $TMP_WORKSPACE"

# Test 1: Install workspace
log "\n=== Test 1: Install workspace ==="
cd "$TMP_WORKSPACE"
"$FRAMEWORK_ROOT/scripts/install-workspace.sh" .

[ -d ".codespec" ] || die "install-workspace did not create .codespec/"
[ -f "lessons_learned.md" ] || die "install-workspace did not create lessons_learned.md"
[ -f "phase-review-policy.md" ] || die "install-workspace did not create phase-review-policy.md"
[ -d "versions" ] || die "install-workspace did not create versions/"
log "✓ workspace installed"

printf 'custom stale policy without legacy gate names\n' > phase-review-policy.md
"$FRAMEWORK_ROOT/scripts/install-workspace.sh" . >/dev/null
assert_contains "$(<phase-review-policy.md)" "Phase Review Policy"
log "✓ install-workspace refreshes workspace phase review policy"

run_scope_aggregation_regression

help_output=$("$TMP_WORKSPACE/.codespec/codespec" --help)
assert_contains "$help_output" "scaffold-project-docs <version>"
assert_contains "$help_output" "authority-repair <begin|close|status>"
assert_contains "$help_output" "completion-report"
assert_contains "$help_output" "active-work-items-complete"
assert_contains "$help_output" "deployment-plan-ready"
assert_contains "$help_output" "semantic-handoff"
log "✓ help exposes scaffold-project-docs, authority-repair, and hardening gates"

log "\n=== Test 1b: Monorepo project root ==="
run_monorepo_project_root_test

# Test 2: Initialize project and dossier
log "\n=== Test 2: Initialize project and dossier ==="
git init test-project
cd test-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"

"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh"

[ -f "meta.yaml" ] || die "init-dossier did not create meta.yaml"
[ -f "spec.md" ] || die "init-dossier did not create spec.md"
[ -f "AGENTS.md" ] || die "init-dossier did not create AGENTS.md"
[ -f "CLAUDE.md" ] || die "init-dossier did not create CLAUDE.md"
[ -x "scripts/codespec-deploy" ] || die "init-dossier did not create executable scripts/codespec-deploy"
[ -d ".git/hooks" ] || die "init-dossier did not create .git/hooks"
[ -x ".git/hooks/pre-commit" ] || die "init-dossier did not install pre-commit hook"
grep -q -- "- rigor_profile: standard" spec.md || die "spec.md template should default rigor_profile to standard"
log "✓ dossier initialized"

# Test 3: Requirement phase
log "\n=== Test 3: Requirement phase ==="
phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Requirement" ] || die "initial phase should be Requirement, got: $phase"

status=$(yq eval '.status' meta.yaml)
[ "$status" = "active" ] || die "initial status should be active, got: $status"
log "✓ initial phase is Requirement"

# Test 4: start-design
log "\n=== Test 4: start-design ==="

# Create input file
mkdir -p docs
cat > docs/test.md <<'EOF'
# Test Input

## intent
Test input for smoke test.
EOF

# Create minimal spec.md for Requirement phase
cat > spec.md <<'EOF'
# spec.md

## 0. AI 阅读契约

- spec.md is the requirement authority for this smoke fixture.
- downstream phases must trace work through REQ-001, ACC-001, and VO-001.

## Summary

Test summary for smoke test.

## Inputs

- source_refs:
  - docs/test.md#intent
- source_owner: smoke-test
- maturity: L1
- normalization_note: normalized into minimal smoke requirement set
- approval_basis: test-approval

## Scope

### In Scope
- Basic smoke test functionality

### Out of Scope
- Advanced features beyond smoke test

## 3. 场景、流程与运行叙事

Smoke 流程从一个稳定输入文档开始，生成最小需求、验收和验证义务。
设计阶段只需要读取当前 spec 与 testing 账本，就能知道这个变更要证明阶段门禁、追溯链和测试计划能闭合。
用户运行 lifecycle 命令时，系统依次检查 requirement-complete、spec-quality、test-plan-complete 和 review-quality gate。
如果所有 gate 通过，phase 切换写入 meta.yaml；否则阻断并报告具体失败原因。
测试执行阶段验证每个 TC 的 RUN 记录有真实证据，部署阶段确认运行时行为与设计一致。

### 场景索引

- scenario_id: SCN-001
  actor: smoke tester
  trigger: run lifecycle gates
  behavior: validate requirement, design, implementation, testing, and deployment transitions
  expected_outcome: lifecycle gates pass only when required evidence is present
  requirement_refs: [REQ-001]

## Requirements

- req_id: REQ-001
  - summary: test requirement
  - rationale: for smoke test
  - source_ref: docs/test.md#intent
  - priority: P0

## Acceptance

- acc_id: ACC-001
  requirement_ref: REQ-001
  expected_outcome: test passes
  priority: P0
  priority_rationale: lifecycle phase transition is critical
  status: approved

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - smoke requirement can advance to next phase
  artifact_expectation: gate check passes

## Constraints

- environment_constraints:
  - git, yq, and bash are available
- security_constraints:
  - no sensitive data is used
- reliability_constraints:
  - smoke failures stop the script
- performance_constraints:
  - none
- compatibility_constraints:
  - none

<!-- SKELETON-END -->
EOF

expect_fail_cmd \
  "test case" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate requirement-complete"

cat > testing.md <<'EOF'
# testing.md

## 0. AI 阅读契约

- 本文件先定义测试用例，再追加执行记录。

## 1. 验收覆盖与测试用例

- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  work_item_refs: [WI-001]
  test_type: manual
  verification_mode: manual
  required_stage: deployment
  scenario: smoke requirement requires manual-only verification
  given: minimal smoke dossier is prepared
  when: lifecycle commands run
  then: gates pass with traceable evidence
  evidence_expectation: manual evidence
  status: planned

## 2. 测试执行记录

## 3. 残留风险与返工判断

- residual_risk: none
EOF

expect_fail_cmd \
  "automation_exception_reason" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate requirement-complete"

cat > testing.md <<'EOF'
# testing.md

## 0. AI 阅读契约

- 本文件先定义测试用例，再追加执行记录。

## 1. 验收覆盖与测试用例

- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  work_item_refs: [WI-001]
  test_type: integration
  verification_mode: automated
  required_stage: testing
  scenario: smoke requirement can advance through the lifecycle
  given: minimal smoke dossier is prepared
  when: lifecycle commands run
  then: gates pass with traceable evidence
  evidence_expectation: scripts/smoke.sh output
  status: planned

## 2. 测试执行记录

## 3. 残留风险与返工判断

- residual_risk: none
EOF

mkdir -p reviews
cat > reviews/design-review.yaml <<'EOF'
phase: Requirement
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
EOF

expect_fail_cmd \
  "review scope must list at least one reviewed artifact" \
  "cd '$TMP_WORKSPACE/test-project' && CODESPEC_TARGET_PHASE=Design '$TMP_WORKSPACE/.codespec/codespec' check-gate review-quality"

cat > reviews/design-review.yaml <<'EOF'
phase: Requirement
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
scope:
  - spec.md
  - testing.md
gate_evidence:
  - command: codespec check-gate requirement-complete
    result: pass
  - command: codespec check-gate spec-quality
    result: pass
  - command: codespec check-gate test-plan-complete
    result: pass
findings:
  - severity: none
    summary: no blocking findings
residual_risk: no residual risk identified by review
decision_notes: approved for Design phase entry
EOF

CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate spec-quality
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate test-plan-complete
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" CODESPEC_TARGET_PHASE=Design "$TMP_WORKSPACE/.codespec/codespec" check-gate review-quality

git add .
git commit -m "feat: initial proposal"

"$TMP_WORKSPACE/.codespec/codespec" start-design

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Design" ] || die "start-design did not set phase to Design"
log "✓ start-design succeeded"

# Test 6: add-work-item and start-implementation
log "\n=== Test 6: add-work-item and start-implementation ==="

# Create minimal design.md
cat > design.md <<'EOF'
# design.md

## 0. AI 阅读契约

- 本文件与 work-items/*.yaml 是 Implementation 阶段的默认权威输入。
- 实现阶段默认不读取原始材料；需求冲突或设计无法解释实现时才回读 spec.md。
- 所有工作项必须追溯到 REQ-001、ACC-001、VO-001、TC-ACC-001-01。

## 1. 设计概览

- solution_summary: 使用最小 bash/git/yq fixture 验证 codespec 生命周期命令。
- minimum_viable_design: 只创建一个可追溯文本实现和测试账本，足以覆盖 smoke 需求。
- non_goals:
  - production deployment

## 2. 需求追溯

- requirement_ref: REQ-001
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  design_response: 通过 WI-001 写入 src/test.txt，并通过 testing.md 记录自动化证据。

## 3. 架构决策

- decision_id: ADR-001
  requirement_refs: [REQ-001]
  decision: 使用 bash fixture 和文件证据完成生命周期验证。
  alternatives_considered:
    - 引入应用框架会增加 smoke 成本，已放弃。
  rationale: smoke 只验证框架行为，不需要业务运行时。
  consequences:
    - 验证证据集中在 git commit 与 testing.md。

### 技术栈选择

- runtime: bash smoke fixture
- storage: none
- external_dependencies:
  - none
- tooling:
  - git
  - yq
  - bash

## 4. 系统结构

- system_context: codespec lifecycle command fixture
- impacted_surfaces:
  - src/**
- unchanged_surfaces:
  - spec.md after Implementation starts
  - design.md after Implementation starts
- data_flow:
  - spec.md -> design.md -> work-items/WI-001.yaml -> testing.md
- external_interactions:
  - name: none
    direction: outbound
    protocol: none
    failure_handling: no external failure path

## 5. 契约设计

- api_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: no API contract in smoke fixture
- data_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: src/test.txt is the only implementation artifact
- compatibility_policy:
  - no compatibility migration needed

## 6. 横切设计

- environment_config:
  - git, yq, bash must be available
- security_design:
  - no sensitive data or external credentials are used
- reliability_design:
  - lifecycle failures stop the smoke script immediately
- observability_design:
  - command output and testing.md records provide evidence
- performance_design:
  - none

## 7. 工作项与验证

### 工作项映射

- wi_id: WI-001
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  summary: implement smoke verification capability
- wi_id: WI-002
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  summary: implement same-phase WI switching capability

### 工作项派生

- wi_id: WI-001
  requirement_refs:
    - REQ-001
  goal: implement smoke verification capability
  covered_acceptance_refs: [ACC-001]
  verification_refs:
    - VO-001
  test_case_refs:
    - TC-ACC-001-01
  dependency_refs: []
  contract_refs: []
  notes_on_boundary: smoke verification scope
- wi_id: WI-002
  requirement_refs:
    - REQ-001
  goal: implement same-phase WI switching capability
  covered_acceptance_refs: [ACC-001]
  verification_refs:
    - VO-001
  test_case_refs:
    - TC-ACC-001-01
  dependency_refs: []
  contract_refs: []
  notes_on_boundary: same-phase switching scope

### 验证设计

- test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  approach: smoke gates and lifecycle commands pass
  evidence: scripts/smoke.sh completes
  required_stage: testing

### 重开触发器

- if lifecycle gates require duplicate spec/design sections again
- if work item derivation drifts from work-items/*.yaml

## 8. 实现阶段输入

### Runbook（场景如何跑）

- wi_id: WI-001
  runbook: smoke test runs lifecycle commands and verifies gate outcomes
- wi_id: WI-002
  runbook: same-phase WI switching preserves active_work_items consistency

### Contract（API/schema/error code 如何实现）

- wi_id: WI-001
  contract_summary: none required for smoke
- wi_id: WI-002
  contract_summary: none required for smoke

### View（各方看到什么）

- wi_id: WI-001
  view_summary: gate pass/fail output
- wi_id: WI-002
  view_summary: meta.yaml state transitions

### Verification（用什么 TC/fixture 证明）

- wi_id: WI-001
  verification_summary: TC-ACC-001-01 proves gate behavior
- wi_id: WI-002
  verification_summary: TC-ACC-001-01 proves WI switching
EOF

git add design.md meta.yaml
git commit -m "feat: complete design"

"$TMP_WORKSPACE/.codespec/codespec" add-work-item WI-001
"$TMP_WORKSPACE/.codespec/codespec" add-work-item WI-002

[ -f "work-items/WI-001.yaml" ] || die "add-work-item did not create WI-001.yaml"
[ -f "work-items/WI-002.yaml" ] || die "add-work-item did not create WI-002.yaml"

expect_fail_cmd \
  "goal contains placeholder value" \
  "\"$TMP_WORKSPACE/.codespec/codespec\" start-implementation WI-001"

# Update work item files with actual values from design.md
for wi in WI-001 WI-002; do
  if [ "$wi" = "WI-001" ]; then
    goal="implement smoke verification capability"
    scope_item="add smoke verification"
  else
    goal="implement same-phase WI switching capability"
    scope_item="allow switching focus within Implementation"
  fi

  yq eval ".goal = \"$goal\"" -i "work-items/$wi.yaml"
  yq eval ".scope = [\"$scope_item\"]" -i "work-items/$wi.yaml"
  yq eval '.out_of_scope = ["production deployment"]' -i "work-items/$wi.yaml"
  yq eval '.requirement_refs = ["REQ-001"]' -i "work-items/$wi.yaml"
  yq eval '.acceptance_refs = ["ACC-001"]' -i "work-items/$wi.yaml"
  yq eval '.verification_refs = ["VO-001"]' -i "work-items/$wi.yaml"
  yq eval '.test_case_refs = ["TC-ACC-001-01"]' -i "work-items/$wi.yaml"
  yq eval '.allowed_paths = ["src/**", "meta.yaml", "testing.md", "contracts/**"]' -i "work-items/$wi.yaml"
  yq eval '.forbidden_paths = ["versions/**", "spec.md", "design.md", "work-items/**", "deployment.md"]' -i "work-items/$wi.yaml"
  yq eval '.branch_execution.owned_paths = ["src/**", "testing.md", "meta.yaml"]' -i "work-items/$wi.yaml"
  yq eval '.branch_execution.shared_paths = []' -i "work-items/$wi.yaml"
  yq eval '.branch_execution.merge_order = 1' -i "work-items/$wi.yaml"
  yq eval '.required_verification = ["unit tests pass"]' -i "work-items/$wi.yaml"
  yq eval '.stop_conditions = ["scope expansion"]' -i "work-items/$wi.yaml"
  yq eval '.reopen_triggers = ["architecture change"]' -i "work-items/$wi.yaml"
done

log "✓ add-work-item succeeded"

git add work-items
git commit -m "docs: finalize work items"

cat > reviews/implementation-review.yaml <<'EOF'
phase: Design
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
scope:
  - design.md
  - testing.md
  - work-items/WI-001.yaml
  - work-items/WI-002.yaml
gate_evidence:
  - command: codespec check-gate design-quality
    result: pass
  - command: CODESPEC_TARGET_PHASE=Implementation codespec check-gate implementation-ready
    result: pass
findings:
  - severity: none
    summary: no blocking findings
residual_risk: no residual risk identified by review
decision_notes: approved for Implementation phase entry
EOF

git add reviews/implementation-review.yaml
git commit -m "docs: approve design"

CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate design-quality
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" CODESPEC_TARGET_PHASE=Implementation "$TMP_WORKSPACE/.codespec/codespec" check-gate review-quality

"$TMP_WORKSPACE/.codespec/codespec" start-implementation WI-001

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Implementation" ] || die "start-implementation did not set phase"

focus_wi=$(yq eval '.focus_work_item' meta.yaml)
[ "$focus_wi" = "WI-001" ] || die "start-implementation did not set focus_work_item"

active_wis=$(yq eval -o=json '.active_work_items' meta.yaml)
assert_json_eq "$active_wis" '. | length' '1'
assert_json_eq "$active_wis" '.[0]' '"WI-001"'

[ -f "testing.md" ] || die "start-implementation did not create testing.md"
log "✓ start-implementation succeeded"

"$TMP_WORKSPACE/.codespec/codespec" start-implementation WI-002

focus_wi=$(yq eval '.focus_work_item' meta.yaml)
[ "$focus_wi" = "WI-002" ] || die "same-phase start-implementation did not switch focus_work_item"

active_wis=$(yq eval -o=json '.active_work_items' meta.yaml)
assert_json_eq "$active_wis" '. | length' '2'
assert_json_eq "$active_wis" '.[0]' '"WI-001"'
assert_json_eq "$active_wis" '.[1]' '"WI-002"'
log "✓ same-phase WI switch succeeded"

"$TMP_WORKSPACE/.codespec/codespec" start-implementation WI-002

active_wis=$(yq eval -o=json '.active_work_items' meta.yaml)
assert_json_eq "$active_wis" '. | length' '2'
assert_json_eq "$active_wis" '.[0]' '"WI-001"'
assert_json_eq "$active_wis" '.[1]' '"WI-002"'
log "✓ same-phase WI switch is idempotent"

"$TMP_WORKSPACE/.codespec/codespec" add-work-item WI-003
yq eval '.goal = "implement orphan work item for missing design derivation check"' -i work-items/WI-003.yaml
yq eval '.scope = ["orphan work item check"]' -i work-items/WI-003.yaml
yq eval '.out_of_scope = ["production deployment"]' -i work-items/WI-003.yaml
yq eval '.allowed_paths = ["src/**", "meta.yaml", "testing.md"]' -i work-items/WI-003.yaml
yq eval '.forbidden_paths = ["versions/**", "spec.md", "design.md", "work-items/**", "contracts/**", "deployment.md"]' -i work-items/WI-003.yaml
yq eval '.required_verification = ["unit tests pass"]' -i work-items/WI-003.yaml
yq eval '.required_surfaces = ["src/**"]' -i work-items/WI-003.yaml
expect_fail_cmd "focus work item WI-003 is missing from design work item derivation" "\"$TMP_WORKSPACE/.codespec/codespec\" start-implementation WI-003"
rm -f work-items/WI-003.yaml

"$TMP_WORKSPACE/.codespec/codespec" start-implementation WI-001
"$TMP_WORKSPACE/.codespec/codespec" set-active-work-items WI-001

focus_wi=$(yq eval '.focus_work_item' meta.yaml)
[ "$focus_wi" = "WI-001" ] || die "same-phase start-implementation did not switch focus back to WI-001"

active_wis=$(yq eval -o=json '.active_work_items' meta.yaml)
assert_json_eq "$active_wis" '. | length' '1'
assert_json_eq "$active_wis" '.[0]' '"WI-001"'
log "✓ active_work_items can be narrowed after same-phase switching"

expect_fail_cmd \
  "active_work_items missing design work item" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' start-testing"

"$TMP_WORKSPACE/.codespec/codespec" set-active-work-items WI-001,WI-002
active_wis=$(yq eval -o=json '.active_work_items' meta.yaml)
assert_json_eq "$active_wis" '. | length' '2'
assert_json_eq "$active_wis" '.[0]' '"WI-001"'
assert_json_eq "$active_wis" '.[1]' '"WI-002"'
log "✓ start-testing requires every design-derived work item to stay active"

yq eval '.allowed_paths += ["work-items/WI-001.yaml"]' -i work-items/WI-001.yaml
yq eval '.forbidden_paths = ["versions/**", "spec.md", "design.md", "contracts/**", "deployment.md"]' -i work-items/WI-001.yaml
git add work-items/WI-001.yaml
"$TMP_WORKSPACE/.codespec/codespec" check-gate scope
log "✓ scope gate allows explicitly owned active work item authority file edits"
git reset HEAD work-items/WI-001.yaml >/dev/null 2>&1 || true
git checkout -- work-items/WI-001.yaml

printf '\n# unauthorized work item drift\n' >> work-items/WI-002.yaml
git add work-items/WI-002.yaml
expect_fail_cmd \
  "work-items/WI-002.yaml is forbidden" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate scope"
git reset HEAD work-items/WI-002.yaml >/dev/null 2>&1 || true
git checkout -- work-items/WI-002.yaml
log "✓ scope gate still rejects unowned work item authority file edits"

printf '\n# unauthorized design repair drift\n' >> design.md
git add design.md
expect_fail_cmd \
  "changed file design.md is forbidden by WI-001" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate scope"
git reset HEAD design.md >/dev/null 2>&1 || true
git checkout -- design.md
log "✓ scope gate rejects design.md edits without authority repair mode"

if [ "${CODESPEC_AUTHORITY_REPAIR_SMOKE_RUNNING:-}" = '1' ]; then
  log "✓ nested authority repair close smoke skips recursive R14 fixture"
else
"$TMP_WORKSPACE/.codespec/codespec" authority-repair begin design-quality --paths design.md,work-items/WI-001.yaml --reason "design-quality gate found missing implementation handoff"
repair_id="$(yq eval '.active_authority_repair' meta.yaml)"
[ "$repair_id" != "null" ] || die "authority-repair begin did not set active_authority_repair"
[ -f "authority-repairs/$repair_id.yaml" ] || die "authority-repair begin did not create repair record"

printf '\n- authority_repair_note: implementation handoff clarified without changing product scope\n' >> design.md
yq eval '.authority_repair_note = "design handoff clarified without changing product scope"' -i work-items/WI-001.yaml
git add meta.yaml "authority-repairs/$repair_id.yaml" design.md work-items/WI-001.yaml
"$TMP_WORKSPACE/.codespec/codespec" check-gate scope
log "✓ active authority repair allows declared design/current-WI authority edits"

printf '\n# unauthorized repair work item drift\n' >> work-items/WI-002.yaml
git add work-items/WI-002.yaml
expect_fail_cmd \
  "outside active authority repair allowed_paths" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate scope"
git reset HEAD work-items/WI-002.yaml >/dev/null 2>&1 || true
git checkout -- work-items/WI-002.yaml
log "✓ active authority repair rejects undeclared work item authority edits"

printf '\n# unauthorized repair spec drift\n' >> spec.md
git add spec.md
expect_fail_cmd \
  "outside active authority repair allowed_paths" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate scope"
git reset HEAD spec.md >/dev/null 2>&1 || true
git checkout -- spec.md
log "✓ active authority repair rejects undeclared spec.md edits"

"$TMP_WORKSPACE/.codespec/codespec" authority-repair close --evidence "design-quality passed after clarifying implementation handoff"
[ "$(yq eval '.active_authority_repair' meta.yaml)" = "null" ] || die "authority-repair close did not clear active_authority_repair"
[ "$(yq eval '.status' "authority-repairs/$repair_id.yaml")" = "closed" ] || die "authority-repair close did not close repair record"
[ "$(yq eval '.gate_result' "authority-repairs/$repair_id.yaml")" = "pass" ] || die "authority-repair close did not record gate pass"
[ "$(yq eval '.smoke_result' "authority-repairs/$repair_id.yaml")" = "pass" ] || die "authority-repair close did not record smoke pass"
git add meta.yaml "authority-repairs/$repair_id.yaml" design.md work-items/WI-001.yaml
git commit -m "docs: repair implementation authority handoff"
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" CODESPEC_SCOPE_MODE=implementation-span "$TMP_WORKSPACE/.codespec/codespec" check-gate scope
log "✓ closed authority repair lets implementation-span scope accept audited design repair"

yq eval '.evidence = "tampered after close"' -i "authority-repairs/$repair_id.yaml"
git add "authority-repairs/$repair_id.yaml"
expect_fail_cmd \
  "authority repair record authority-repairs/$repair_id.yaml can only be created closed or close a previously open repair" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate metadata-consistency"
git reset HEAD "authority-repairs/$repair_id.yaml" >/dev/null 2>&1 || true
git checkout -- "authority-repairs/$repair_id.yaml"
log "✓ closed authority repair record cannot be silently rewritten"
fi

if ! git diff --quiet -- meta.yaml; then
  git add meta.yaml
  git commit -m "chore: enter implementation"
else
  log "✓ implementation phase metadata already committed"
fi

expect_fail_cmd \
  "semantic handoff missing for phase Implementation" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate semantic-handoff"

cat >> testing.md <<'EOF'

## 4. 主动未完成清单与语义验收

- handoff_id: HANDOFF-001
  phase: Implementation
  work_item_refs: [WI-001]
  highest_completion_level: fixture_contract
  evidence_refs:
    - testing.md#RUN-001
  unfinished_items: none
  fixture_or_fallback_paths:
    - surface: frontend smoke fixture
      completion_level: fixture_contract
      real_api_verified: false
      visible_failure_state: false
      trace_retry_verified: false
  wording_guard: "branch-local fixture only; do not report integrated_runtime"
EOF

expect_fail_cmd \
  "semantic handoff must list unfinished_items" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate semantic-handoff"

cat >> testing.md <<'EOF'

- handoff_id: HANDOFF-002
  phase: Implementation
  work_item_refs: [WI-001]
  highest_completion_level: fixture_contract
  evidence_refs:
    - testing.md#RUN-001
  unfinished_items:
    - source_ref: testing.md#TC-ACC-001-01
      priority: P0
      current_completion_level: fixture_contract
      target_completion_level: integrated_runtime
      blocker: full-integration evidence has not run yet
      next_step: run full-integration in Testing and record RUN evidence
  fixture_or_fallback_paths:
    - surface: frontend smoke fixture
      completion_level: fixture_contract
      real_api_verified: false
      visible_failure_state: false
      trace_retry_verified: false
  wording_guard: "branch-local fixture only; do not report integrated_runtime or owner_verified"
EOF

"$TMP_WORKSPACE/.codespec/codespec" check-gate semantic-handoff
completion_report="$("$TMP_WORKSPACE/.codespec/codespec" completion-report)"
assert_contains "$completion_report" "phase: Implementation"
assert_contains "$completion_report" "highest_completion_level: fixture_contract"
assert_contains "$completion_report" "unfinished_items.required: yes"
git add testing.md
git commit -m "docs: record implementation semantic handoff"
log "✓ semantic handoff requires active unfinished disclosure before implementation handoff"

printf '\nforbidden implementation drift\n' >> spec.md
git add spec.md
git commit --no-verify -m "test: introduce committed forbidden drift"

expect_fail_cmd \
  "implementation span file spec.md is forbidden" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' start-testing"

git reset --soft HEAD~1 >/dev/null 2>&1 || true
git restore --staged spec.md >/dev/null 2>&1 || true
git checkout -- spec.md
log "✓ start-testing should reject committed forbidden drift across Implementation span"

mkdir -p contracts
cat > contracts/shared.md <<'EOF'
# Shared Contract

contract_id: CONTRACT-001
status: draft
frozen_at: null
freeze_review_ref: null
consumers: []

## Interface Definition
shared interface
EOF

git add contracts/shared.md
git commit --no-verify -m "test: add draft contract"

python3 - <<'PY'
from pathlib import Path
path = Path("contracts/shared.md")
text = path.read_text()
text = text.replace("status: draft", "status: frozen")
text = text.replace("frozen_at: null", "frozen_at: 2026-04-16")
path.write_text(text)
PY
git add contracts/shared.md
git commit --no-verify -m "test: freeze contract without explicit review"

expect_fail_cmd \
  "requires explicit review" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' start-testing"

git reset --soft HEAD~2 >/dev/null 2>&1 || true
git restore --staged contracts/shared.md >/dev/null 2>&1 || true
rm -f contracts/shared.md
log "✓ start-testing should reject draft-to-frozen contract changes without review"

# Test 7: Implementation and testing
log "\n=== Test 7: Implementation and testing ==="

mkdir -p src
cat > src/test.txt <<'EOF'
test implementation
EOF

git add src/
git commit -m "feat: implement WI-001"

# Add test record
cat > testing.md <<'EOF'
- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  work_item_refs: [WI-001]
  test_type: integration
  verification_mode: automated
  required_stage: testing
  scenario: smoke requirement can advance through the lifecycle
  given: minimal smoke dossier is prepared
  when: lifecycle commands run
  then: gates pass with traceable evidence
  evidence_expectation: scripts/smoke.sh output
  status: planned

- run_id: RUN-001
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: unit
  test_scope: branch-local
  verification_type: automated
  artifact_ref: src/test.txt
  result: pass
  tested_at: 2026-04-16
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false
EOF

git add testing.md
git commit -m "test: add test record"

mkdir -p docs
echo "dirty verification drift" > docs/dirty-verification.txt
expect_fail_cmd \
  "dirty worktree: uncommitted files detected" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate verification"
expect_fail_cmd \
  "dirty worktree: uncommitted files detected" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate contract-boundary"
rm -f docs/dirty-verification.txt
log "✓ verification and contract-boundary reject unrelated dirty worktree files"

yq eval '.phase = "Testing" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001", "WI-002"]' -i meta.yaml
git add meta.yaml

set +e
output=$(git commit -m "test: should fail missing semantic handoff manual Testing transition" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "pre-commit should block manual Testing phase transition without semantic handoff"
assert_contains "$output" "semantic handoff missing for phase Implementation"
log "✓ pre-commit blocks manual Testing transition without semantic handoff"

git reset HEAD meta.yaml >/dev/null 2>&1 || true
git checkout -- meta.yaml

yq eval '.phase = "Testing" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001"]' -i meta.yaml
git add meta.yaml

set +e
output=$(git commit -m "test: should fail incomplete manual Testing transition" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "pre-commit should block manual Testing phase transition with incomplete active_work_items"
assert_contains "$output" "active_work_items missing design work item: WI-002"
log "✓ pre-commit blocks manual Testing transition with incomplete active_work_items"

git reset HEAD meta.yaml >/dev/null 2>&1 || true
git checkout -- meta.yaml

expect_fail_cmd \
  "semantic handoff missing for phase Implementation" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' start-testing"

cat >> testing.md <<'EOF'

## 4. 主动未完成清单与语义验收

- handoff_id: HANDOFF-003
  phase: Implementation
  work_item_refs: [WI-001, WI-002]
  highest_completion_level: fixture_contract
  evidence_refs:
    - testing.md#RUN-001
  unfinished_items:
    - source_ref: testing.md#TC-ACC-001-01
      priority: P0
      current_completion_level: fixture_contract
      target_completion_level: integrated_runtime
      blocker: only branch-local evidence exists before Testing
      next_step: run full-integration and record RUN evidence in Testing
  fixture_or_fallback_paths:
    - surface: smoke branch-local fixture
      completion_level: fixture_contract
      real_api_verified: false
      visible_failure_state: false
      trace_retry_verified: false
  wording_guard: "Implementation branch-local pass only; do not report integrated_runtime"
EOF
git add testing.md
git commit -m "docs: record implementation transition handoff"

"$TMP_WORKSPACE/.codespec/codespec" start-testing

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Testing" ] || die "start-testing did not set phase"
git add meta.yaml
git commit -m "chore: enter testing"
log "✓ start-testing succeeded"

echo "testing-phase-drift" >> src/test.txt
git add src/test.txt

set +e
output=$(git commit -m "test: should fail in Testing phase" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "Testing phase should block src/** modifications"
assert_contains "$output" "Testing forbids phase-frozen artifacts: src/test.txt"
log "✓ Testing phase blocks implementation artifact edits"

git reset HEAD src/test.txt >/dev/null 2>&1 || true
git checkout -- src/test.txt

# Test 8: Deployment
log "\n=== Test 8: Deployment ==="

# Update testing.md with full-integration test
cat > testing.md <<'EOF'
- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  work_item_refs: [WI-001]
  test_type: integration
  verification_mode: automated
  required_stage: testing
  scenario: smoke requirement can advance through the lifecycle
  given: minimal smoke dossier is prepared
  when: lifecycle commands run
  then: gates pass with traceable evidence
  evidence_expectation: scripts/smoke.sh output
  status: planned

- run_id: RUN-001
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: unit
  test_scope: branch-local
  verification_type: automated
  completion_level: fixture_contract
  command_or_steps: pytest tests/ -x
  artifact_ref: src/test.txt
  result: pass
  tested_at: 2026-04-16
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false

- run_id: RUN-002
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: full-integration
  verification_type: automated
  completion_level: integrated_runtime
  command_or_steps: pytest tests/integration/ -x
  artifact_ref: src/test.txt
  result: pass
  tested_at: 2026-04-16
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false
EOF

git add testing.md
git commit -m "test: add full-integration test"

yq eval '.phase = "Deployment" | .status = "active" | .focus_work_item = null' -i meta.yaml
git add meta.yaml

set +e
output=$(git commit -m "test: should fail missing semantic handoff manual Deployment transition" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "pre-commit should block manual Deployment phase transition without semantic handoff"
assert_contains "$output" "semantic handoff missing for phase Testing"
log "✓ pre-commit blocks manual Deployment transition without semantic handoff"

git reset HEAD meta.yaml >/dev/null 2>&1 || true
git checkout -- meta.yaml

expect_fail_cmd \
  "semantic handoff missing for phase Testing" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' start-deployment"

cat >> testing.md <<'EOF'

## 4. 主动未完成清单与语义验收

- handoff_id: HANDOFF-004
  phase: Testing
  work_item_refs: [WI-001, WI-002]
  highest_completion_level: integrated_runtime
  evidence_refs:
    - testing.md#RUN-002
  unfinished_items: none
  fixture_or_fallback_paths: none
  wording_guard: "full-integration pass only; do not report owner_verified before Deployment acceptance"
EOF
git add testing.md
git commit -m "docs: record testing semantic handoff"

"$TMP_WORKSPACE/.codespec/codespec" start-deployment

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Deployment" ] || die "start-deployment did not set phase"
[ -f "deployment.md" ] || die "start-deployment did not create deployment.md"
git add meta.yaml deployment.md
git commit -m "chore: enter deployment"
log "✓ start-deployment succeeded"

expect_fail_cmd \
  "deployment.md target_env must be set before deploy" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' deploy"
log "✓ deploy refuses to run before deployment plan is ready"

echo "# deployment-phase-drift" >> work-items/WI-001.yaml
git add work-items/WI-001.yaml

set +e
output=$(git commit -m "test: should fail in Deployment phase" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "Deployment phase should block work-items/** modifications"
assert_contains "$output" "Deployment forbids phase-frozen artifacts: work-items/WI-001.yaml"
log "✓ Deployment phase blocks authority file edits"

git reset HEAD work-items/WI-001.yaml >/dev/null 2>&1 || true
sed -i '$d' work-items/WI-001.yaml

# Test 9: Complete change
log "\n=== Test 9: Complete change ==="

# Fill deployment.md and provide a project deploy script
cat > deployment.md <<EOF
# deployment.md

## Deployment Plan
target_env: test
deployment_date: 2026-04-16

## Pre-deployment Checklist
- [x] Tests pass
- [x] Code reviewed

## Deployment Steps
1. Deploy test
2. Restart service

## Execution Evidence
status: pending
execution_ref: pending
deployment_method: pending
deployed_at: pending
deployed_revision: pending
restart_required: pending
restart_reason: pending
runtime_observed_revision: pending
runtime_ready_evidence: pending

## Verification Results
smoke_test: pending
runtime_ready: pending
manual_verification_ready: pending

## Acceptance Conclusion
status: pending
notes: pending manual acceptance
approved_by: pending
approved_at: pending

## Rollback Plan
trigger_conditions:
  - smoke checks fail
rollback_steps:
  1. rollback to previous revision

## Monitoring
metrics:
  - error_rate
alerts:
  - deployment smoke failure

## Post-deployment Actions
- [ ] update related docs
- [ ] archive stable version after manual acceptance
EOF

cat > scripts/codespec-deploy <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cat > "${CODESPEC_DEPLOY_RESULT_FILE:?}" <<'RESULT'
status: pass
execution_ref: smoke-run-001
deployment_method: automated
deployed_at: 2026-04-16T09:30:00Z
deployed_revision: build=test-2026-04-16
restart_required: yes
restart_reason: application code changed and running process must reload new code
smoke_test: pass
runtime_ready: pass
runtime_observed_revision: build=test-2026-04-16
runtime_ready_evidence: build=test-2026-04-16 pid=12345 /health revision=test-2026-04-16; service restarted and new revision observed in process health output
manual_verification_ready: pass
RESULT
EOF
chmod +x scripts/codespec-deploy

git add deployment.md scripts/codespec-deploy
git commit -m "docs: prepare deployment flow"

cp scripts/codespec-deploy scripts/codespec-deploy.good
cat > scripts/codespec-deploy <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cat > "${CODESPEC_DEPLOY_RESULT_FILE:?}" <<'RESULT'
status: pass
execution_ref: 待填写
deployment_method: automated
deployed_at: 2026-04-16T09:30:00Z
deployed_revision: build=test-2026-04-16
restart_required: yes
restart_reason: application code changed and running process must reload new code
smoke_test: pass
runtime_ready: pass
runtime_observed_revision: build=test-2026-04-16
runtime_ready_evidence: build=test-2026-04-16 pid=12345 /health revision=test-2026-04-16; service restarted and new revision observed in process health output
manual_verification_ready: pass
RESULT
EOF
chmod +x scripts/codespec-deploy

expect_fail_cmd \
  "deploy result execution_ref is missing" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' deploy"
log "✓ deploy rejects Chinese placeholder result values"

mv scripts/codespec-deploy.good scripts/codespec-deploy
chmod +x scripts/codespec-deploy

"$TMP_WORKSPACE/.codespec/codespec" deploy
"$TMP_WORKSPACE/.codespec/codespec" check-gate deployment-readiness

assert_contains "$(<deployment.md)" "execution_ref: smoke-run-001"
assert_contains "$(<deployment.md)" "status: pending"
log "✓ deploy writes execution evidence and readiness data"

git add deployment.md
git commit -m "docs: record deployment execution evidence"

expect_fail_cmd \
  "acceptance conclusion status must be pass" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' complete-change smoke-v1"

replace_markdown_section deployment.md "## Acceptance Conclusion" "$(cat <<'EOF'
status: fail
notes: manual verification found a regression
approved_by: pending
approved_at: pending
EOF
)"

"$TMP_WORKSPACE/.codespec/codespec" reopen-implementation WI-001

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Implementation" ] || die "reopen-implementation did not set phase to Implementation"
focus_wi=$(yq eval '.focus_work_item' meta.yaml)
[ "$focus_wi" = "WI-001" ] || die "reopen-implementation did not set focus_work_item"
git checkout -- deployment.md
git add meta.yaml
git commit -m "chore: reopen implementation after failed acceptance"
log "✓ reopen-implementation re-enters Implementation for failed manual verification"

cat >> testing.md <<'EOF'

- handoff_id: HANDOFF-006
  phase: Implementation
  work_item_refs: [WI-001, WI-002]
  highest_completion_level: integrated_runtime
  evidence_refs:
    - deployment.md#Acceptance-Conclusion
    - testing.md#RUN-001
  unfinished_items:
    - source_ref: deployment.md#Acceptance-Conclusion
      priority: P0
      current_completion_level: integrated_runtime
      target_completion_level: owner_verified
      blocker: manual acceptance failed and required a redeploy loop
      next_step: rerun Testing and Deployment evidence before reporting owner_verified
  fixture_or_fallback_paths: none
  wording_guard: "reopened Implementation after failed acceptance; do not report completion until redeploy acceptance passes"
EOF
git add testing.md
git commit -m "docs: record reopened implementation semantic handoff"

"$TMP_WORKSPACE/.codespec/codespec" start-testing
git add meta.yaml
git commit -m "chore: re-enter testing after failed acceptance"
"$TMP_WORKSPACE/.codespec/codespec" start-deployment
git add meta.yaml deployment.md
git commit -m "chore: re-enter deployment after failed acceptance"
"$TMP_WORKSPACE/.codespec/codespec" deploy

assert_contains "$(<deployment.md)" "notes: pending manual acceptance"
log "✓ redeploy resets manual acceptance conclusion to pending"

replace_markdown_section deployment.md "## Acceptance Conclusion" "$(cat <<'EOF'
status: pass
notes: manual acceptance passed after redeploy
approved_by: smoke-test
approved_at: 2026-04-16
EOF
)"

git add meta.yaml deployment.md
git commit -m "docs: record manual acceptance"

yq eval '.status = "completed" | .stable_version = "manual-bypass" | .active_work_items = []' -i meta.yaml
git add meta.yaml

set +e
output=$(git commit -m "test: should fail missing semantic handoff manual completion" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "pre-commit should block manual Deployment completion without semantic handoff"
assert_contains "$output" "semantic handoff missing for phase Deployment"
log "✓ pre-commit blocks manual Deployment completion without semantic handoff"

git reset HEAD meta.yaml >/dev/null 2>&1 || true
git checkout -- meta.yaml

expect_fail_cmd \
  "semantic handoff missing for phase Deployment" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' complete-change smoke-v1"

cat >> testing.md <<'EOF'

- handoff_id: HANDOFF-005
  phase: Deployment
  work_item_refs: [WI-001, WI-002]
  highest_completion_level: owner_verified
  evidence_refs:
    - deployment.md#Execution-Evidence
    - deployment.md#Acceptance-Conclusion
  unfinished_items: none
  fixture_or_fallback_paths: none
  wording_guard: "Deployment runtime and manual acceptance are recorded; report owner_verified only for this accepted smoke change"
EOF
git add testing.md
git commit -m "docs: record deployment semantic handoff"

"$TMP_WORKSPACE/.codespec/codespec" complete-change smoke-v1

status=$(yq eval '.status' meta.yaml)
[ "$status" = "completed" ] || die "complete-change did not set status to completed"
[ "$(yq eval '.stable_version' meta.yaml)" = "smoke-v1" ] || die "complete-change did not set stable_version in workspace meta"
[ "$(yq eval -o=json '.active_work_items' meta.yaml)" = "[]" ] || die "workspace completed dossier should clear active_work_items"
[ -f "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml" ] || die "complete-change did not archive stable version"
git add meta.yaml
git commit -m "chore: complete smoke-v1"
log "✓ complete-change archived the accepted stable version"

"$TMP_WORKSPACE/.codespec/codespec" scaffold-project-docs smoke-v1
assert_contains "$(<"$TMP_WORKSPACE/project-docs/smoke-v1/系统功能说明书.md")" "| 状态 | Draft |"
log "✓ scaffold-project-docs creates draft project document shells"

# Completed dossiers should remain re-verifiable
"$TMP_WORKSPACE/.codespec/codespec" check-gate verification
"$TMP_WORKSPACE/.codespec/codespec" check-gate promotion-criteria
log "✓ completed dossier remains re-verifiable"

cp meta.yaml meta.before-reopen.yaml
mkdir -p "$TMP_WORKSPACE/versions/mismatched-reopen"
cp "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml" "$TMP_WORKSPACE/versions/mismatched-reopen/meta.yaml"
yq eval '.change_id = "different-change" | .active_work_items = ["WI-999"]' -i "$TMP_WORKSPACE/versions/mismatched-reopen/meta.yaml"
yq eval '.change_id = "mismatched-reopen" | .stable_version = null | .phase = "Deployment" | .status = "completed" | .focus_work_item = null | .active_work_items = []' -i meta.yaml
expect_fail_cmd \
  "archived meta change_id mismatch" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' start-deployment"
mv meta.before-reopen.yaml meta.yaml

"$TMP_WORKSPACE/.codespec/codespec" start-deployment
[ "$(yq eval '.phase' meta.yaml)" = "Deployment" ] || die "completed reopen should return to Deployment phase"
[ "$(yq eval '.status' meta.yaml)" = "active" ] || die "completed reopen should reactivate the dossier"
reopened_active_wis=$(yq eval -o=json '.active_work_items' meta.yaml)
assert_json_eq "$reopened_active_wis" '. | length' '2'
assert_json_eq "$reopened_active_wis" '.[0]' '"WI-001"'
assert_json_eq "$reopened_active_wis" '.[1]' '"WI-002"'
git add meta.yaml
git commit -m "chore: reopen completed deployment"
log "✓ start-deployment restores archived active_work_items for completed reopen"

bad_reopen_base="$(git rev-parse HEAD)"
yq eval '.phase = "Deployment" | .status = "completed" | .stable_version = "smoke-v1" | .focus_work_item = null | .active_work_items = []' -i meta.yaml
cat >> testing.md <<'EOF'

- run_id: RUN-BAD-REOPEN
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: full-integration
  verification_type: automated
  artifact_ref: reports/bad-reopen.txt
  result: fail
  tested_at: 2026-04-17
  tested_by: smoke-test
  residual_risk: medium
  reopen_required: true
EOF
git add meta.yaml testing.md
git commit --no-verify -m "test: add bad completed reopen fixture"
expect_fail_cmd \
  "full-integration pass record for ACC-001" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' start-deployment"
git reset --hard "$bad_reopen_base" >/dev/null
log "✓ completed Deployment reopen re-runs verification gates"

cat > deployment.md <<EOF
# deployment.md

## Deployment Plan
target_env: test
deployment_date: 2026-04-16

## Pre-deployment Checklist
- [x] Tests pass
- [x] Code reviewed

## Deployment Steps
1. Deploy test
2. Restart service

## Execution Evidence
status: pass
execution_ref: smoke-run-002
deployment_method: automated
deployed_at: 2026-04-16T09:30:00Z
deployed_revision: build=test-2026-04-16
restart_required: yes
restart_reason: application code changed and running process must reload new code
runtime_observed_revision: build=test-2026-04-16
runtime_ready_evidence: build=test-2026-04-16 pid=12345 /health revision=test-2026-04-16; service restarted and new revision observed in process health output

## Verification Results
smoke_test: pass
runtime_ready: pending
manual_verification_ready: pass

## Acceptance Conclusion
status: pending
notes: pending manual acceptance
approved_by: pending
approved_at: pending

## Rollback Plan
trigger_conditions:
  - smoke checks fail
rollback_steps:
  1. rollback to previous revision

## Monitoring
metrics:
  - error_rate
alerts:
  - deployment smoke failure

## Post-deployment Actions
- [ ] update related docs
- [ ] archive stable version after manual acceptance
EOF

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate deployment-readiness 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "deployment-readiness should fail when runtime readiness is missing"
assert_contains "$output" "runtime_ready: pass"
log "✓ deployment-readiness requires runtime readiness"

cat > deployment.md <<EOF
# deployment.md

## Deployment Plan
target_env: test
deployment_date: 2026-04-16

## Pre-deployment Checklist
- [x] Tests pass
- [x] Code reviewed

## Deployment Steps
1. Deploy test
2. Restart service

## Execution Evidence
status: pass
execution_ref: smoke-run-003
deployment_method: automated
deployed_at: 2026-04-16T09:30:00Z
deployed_revision: build=test-2026-04-16
restart_required: yes
restart_reason: application code changed and running process must reload new code
runtime_observed_revision: build=test-2026-04-16

## Verification Results
smoke_test: pass
runtime_ready: pass

## Acceptance Conclusion
status: pending
notes: pending manual acceptance
approved_by: pending
approved_at: pending

## Rollback Plan
trigger_conditions:
  - smoke checks fail
rollback_steps:
  1. rollback to previous revision

## Monitoring
metrics:
  - error_rate
alerts:
  - deployment smoke failure

## Post-deployment Actions
- [ ] update related docs
- [ ] archive stable version after manual acceptance
EOF

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate deployment-readiness 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "deployment-readiness should fail when runtime readiness evidence is missing"
log "✓ deployment-readiness requires runtime readiness evidence"

cat > deployment.md <<'EOF'
# deployment.md

## Deployment Plan
target_env: test
deployment_date: 2026-04-16

## Pre-deployment Checklist
- [x] Tests pass
- [x] Code reviewed

## Deployment Steps
1. Deploy test
2. Restart service

## Execution Evidence
status: pass
execution_ref: smoke-run-004
deployment_method: automated
deployed_at: 2026-04-16T09:30:00Z
deployed_revision: build=test-2026-04-16
restart_required: yes
restart_reason: application code changed and running process must reload new code
runtime_observed_revision: build=test-2026-04-16
runtime_ready_evidence: build=test-2026-04-16 pid=12345 /health revision=test-2026-04-16; service restarted and new revision observed in process health output

## Verification Results
smoke_test: pass
runtime_ready: pass

## Acceptance Conclusion
status: pending
notes: pending manual acceptance
approved_by: pending
approved_at: pending

## Rollback Plan
trigger_conditions:
  - smoke checks fail
rollback_steps:
  1. rollback to previous revision

## Monitoring
metrics:
  - error_rate
alerts:
  - deployment smoke failure

## Post-deployment Actions
- [ ] update related docs
- [ ] archive stable version after manual acceptance
EOF

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate deployment-readiness 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "deployment-readiness should fail when manual verification readiness is missing"
assert_contains "$output" "manual_verification_ready: pass"
log "✓ deployment-readiness blocks handoff before manual verification is ready"

cat > deployment.md <<'EOF'
# deployment.md

## Deployment Plan
target_env: test
deployment_date: 2026-04-16

## Pre-deployment Checklist
- [x] Tests pass
- [x] Code reviewed

## Deployment Steps
1. Deploy test
2. Restart service

## Execution Evidence
status: pass
execution_ref: smoke-run-005
deployment_method: automated
deployed_at: 2026-04-16T09:30:00Z
deployed_revision: build=test-2026-04-16
restart_required: yes
restart_reason: application code changed and running process must reload new code
runtime_observed_revision: build=test-2026-04-16
runtime_ready_evidence: build=test-2026-04-16 pid=12345 /health revision=test-2026-04-16

## Verification Results
smoke_test: pass
runtime_ready: pass
manual_verification_ready: pass

## Acceptance Conclusion
status: pending
notes: pending manual acceptance
approved_by: pending
approved_at: pending

## Rollback Plan
trigger_conditions:
  - smoke checks fail
rollback_steps:
  1. rollback to previous revision

## Monitoring
metrics:
  - error_rate
alerts:
  - deployment smoke failure

## Post-deployment Actions
- [ ] update related docs
- [ ] archive stable version after manual acceptance
EOF

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate deployment-readiness 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "deployment-readiness should fail when runtime evidence does not show restart for restart-required deployment"
assert_contains "$output" "restart-required deployment"
log "✓ deployment-readiness requires restart evidence when restart is required"

cat > deployment.md <<'EOF'
# deployment.md

## 1. 发布对象与环境

release_mode: artifact
target_env: artifact-store
deployment_date: 2026-04-16
design_environment_ref: design.md#6-横切设计
release_artifact: dist/smoke-package.tar.gz

## 2. 发布前条件
- [x] Tests pass

## 3. 执行证据
status: pass
execution_ref: artifact-build-001
deployment_method: packaged artifact
deployed_at: 2026-04-16T09:30:00Z
deployed_revision: build=test-2026-04-16
restart_required: not-applicable
restart_reason: not-applicable
runtime_observed_revision: not-applicable
runtime_ready_evidence: artifact checksum verified

## 4. 运行验证
smoke_test: pass
runtime_ready: not-applicable
manual_verification_ready: pass

## 5. 回滚与监控
rollback_trigger_conditions:
  - artifact verification fails
rollback_steps:
  1. restore previous artifact
monitoring_metrics:
  - artifact_checksum
monitoring_alerts:
  - artifact verification failure

## 6. 人工验收与收口
status: pending
notes: pending manual acceptance
approved_by: pending
approved_at: pending
EOF

CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate deployment-readiness
log "✓ deployment-readiness supports artifact release mode"

cat > scripts/codespec-deploy <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cat > "${CODESPEC_DEPLOY_RESULT_FILE:?}" <<'RESULT'
status: pass
execution_ref: artifact-run-001
deployment_method: packaged artifact
deployed_at: 2026-04-16T09:30:00Z
deployed_revision: build=test-2026-04-16
restart_required: not-applicable
restart_reason: not-applicable
smoke_test: pass
runtime_ready: not-applicable
runtime_observed_revision: not-applicable
runtime_ready_evidence: artifact checksum verified
manual_verification_ready: pass
RESULT
EOF
chmod +x scripts/codespec-deploy

"$TMP_WORKSPACE/.codespec/codespec" deploy
assert_contains "$(<deployment.md)" "execution_ref: artifact-run-001"
assert_contains "$(<deployment.md)" "runtime_ready: not-applicable"
log "✓ deploy supports artifact release mode"

promoted_status=$(yq eval '.status' "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml")
[ "$promoted_status" = "completed" ] || die "complete-change did not preserve completed status in archived meta"
promoted_active_wis=$(yq eval -o=json '.active_work_items' "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml")
assert_json_eq "$promoted_active_wis" '. | length' '2'
assert_json_eq "$promoted_active_wis" '.[0]' '"WI-001"'
assert_json_eq "$promoted_active_wis" '.[1]' '"WI-002"'
log "✓ complete-change preserves active work item snapshot in archive"

# Test 10: testing ledger selection semantics
log "\n=== Test 10: testing ledger selection semantics ==="
git reset --hard HEAD >/dev/null

yq eval '.phase = "Testing" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001", "WI-002"] | .execution_group = null | .execution_branch = null' -i meta.yaml

cat > testing.md <<'EOF'
- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  work_item_refs: [WI-001]
  test_type: integration
  verification_mode: automated
  required_stage: testing
  scenario: smoke requirement can advance through the lifecycle
  given: minimal smoke dossier is prepared
  when: lifecycle commands run
  then: gates pass with traceable evidence
  evidence_expectation: scripts/smoke.sh output
  status: planned

- run_id: RUN-001
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: full-integration
  verification_type: manual
  completion_level: integrated_runtime
  command_or_steps: manual smoke test
  artifact_ref: reports/older-pass.txt
  result: pass
  tested_at: 2026-04-16
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false

- run_id: RUN-002
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: full-integration
  verification_type: automated
  completion_level: integrated_runtime
  command_or_steps: pytest integration/ -x
  artifact_ref: reports/newer-pass.txt
  result: pass
  tested_at: 2026-04-17
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false
EOF

git add meta.yaml testing.md
git commit --no-verify -m "test: add ledger selection pass fixture"
ledger_selection_base="$(git rev-parse HEAD)"
"$TMP_WORKSPACE/.codespec/codespec" check-gate verification
log "✓ verification uses the latest matching pass record without duplicating extracted fields"

cat > testing.md <<'EOF'
- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  work_item_refs: [WI-001]
  test_type: integration
  verification_mode: automated
  required_stage: testing
  scenario: smoke requirement can advance through the lifecycle
  given: minimal smoke dossier is prepared
  when: lifecycle commands run
  then: gates pass with traceable evidence
  evidence_expectation: scripts/smoke.sh output
  status: planned

- run_id: RUN-001
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: full-integration
  verification_type: automated
  completion_level: integrated_runtime
  command_or_steps: pytest integration/ -x
  artifact_ref: reports/pass-before-fail.txt
  result: pass
  tested_at: 2026-04-18
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false

- run_id: RUN-002
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: manual
  test_scope: full-integration
  verification_type: manual
  artifact_ref: reports/fail-after-pass.txt
  result: fail
  tested_at: 2026-04-19
  tested_by: smoke-test
  residual_risk: medium
  reopen_required: true
EOF

git add testing.md
git commit --no-verify -m "test: add ledger selection fail fixture"
expect_fail_cmd \
  "full-integration pass record for ACC-001" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate verification"
git reset --hard "$ledger_selection_base" >/dev/null
log "✓ verification rejects a later full-integration failure after an earlier pass"

# Test 11: File modification rules
log "\n=== Test 11: File modification rules ==="

# deployment/contract tests left dirty files; restore working tree before phase reset
git reset --hard HEAD >/dev/null 2>&1 || true

# Reset to Implementation phase for testing
yq eval '.phase = "Implementation" | .status = "active" | .focus_work_item = "WI-001" | .active_work_items = ["WI-001"]' -i meta.yaml

git checkout -b test-execution-branch

"$TMP_WORKSPACE/.codespec/codespec" set-execution-context parallel main test-group
git add meta.yaml
git commit -m "chore: set execution context"

# Test: execution branch cannot modify spec.md
echo "# test" >> spec.md
git add spec.md

set +e
output=$(git commit -m "test: should fail" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "pre-commit should block spec.md modification in execution branch"
assert_contains "$output" "Cannot modify spec.md in execution branch"
log "✓ pre-commit blocks spec.md modification in execution branch"

git reset HEAD spec.md
git checkout -- spec.md

# Test: execution branch can modify testing.md
echo "# test" >> testing.md
git add testing.md
git commit -m "test: testing.md modification allowed"
log "✓ pre-commit allows testing.md modification in execution branch"

# Test: execution branch can modify src/**
echo "test" >> src/test.txt
git add src/test.txt
git commit -m "feat: src modification allowed"
log "✓ pre-commit allows src/** modification in execution branch"

# Test 12: Gate checks
log "\n=== Test 12: Gate checks ==="

git checkout master
cd "$TMP_WORKSPACE/test-project"

# Test metadata-consistency gate
yq eval '.phase = "Implementation" | .focus_work_item = "WI-001" | .active_work_items = []' -i meta.yaml

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate metadata-consistency 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "metadata-consistency gate should fail when focus_work_item not in active_work_items"
log "✓ metadata-consistency gate works"

yq eval '.phase = "Implementation" | .status = "in_progress" | .focus_work_item = "WI-001" | .active_work_items = ["WI-001"]' -i meta.yaml
set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate metadata-consistency 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "metadata-consistency gate should reject invalid status values"
assert_contains "$output" "status"
log "✓ metadata-consistency rejects invalid status enum"

yq eval '.status = "active" | .active_work_items = ["WI-001"]' -i meta.yaml

yq eval '.phase = "UnknownPhase" | .status = "active" | .focus_work_item = null | .active_work_items = [] | .implementation_base_revision = null' -i meta.yaml
set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate metadata-consistency 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "metadata-consistency gate should reject invalid phase values"
assert_contains "$output" "phase"
log "✓ metadata-consistency rejects invalid phase enum"

yq eval '.phase = "Requirement" | .status = "completed" | .focus_work_item = null | .active_work_items = [] | .implementation_base_revision = null' -i meta.yaml
set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate metadata-consistency 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "metadata-consistency gate should reject completed status outside Deployment"
assert_contains "$output" "completed status requires Deployment phase"
log "✓ metadata-consistency rejects completed status outside Deployment"

# Test: active Deployment still requires active_work_items until completed
yq eval '.phase = "Deployment" | .status = "active" | .focus_work_item = null | .active_work_items = []' -i meta.yaml
set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate metadata-consistency 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "metadata-consistency gate should fail for active Deployment with empty active_work_items"
log "✓ active Deployment still requires active_work_items"

# Test phase-capability gate
yq eval '.phase = "Requirement"' -i meta.yaml
mkdir -p src
echo "test" > src/forbidden.txt
git add src/forbidden.txt

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate phase-capability 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "phase-capability gate should fail when src/** exists in Requirement phase"
log "✓ phase-capability gate works"

git reset HEAD src/forbidden.txt
rm -f src/forbidden.txt

yq eval '.phase = "Design" | .status = "active" | .focus_work_item = null | .active_work_items = [] | .implementation_base_revision = null' -i meta.yaml
echo "design drift" > src/design-forbidden.txt
git add src/design-forbidden.txt

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate phase-capability 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "phase-capability gate should fail when src/** is staged in Design phase"
assert_contains "$output" "Design forbids implementation artifacts"
log "✓ phase-capability blocks implementation artifacts in Design phase"

git reset HEAD src/design-forbidden.txt
rm -f src/design-forbidden.txt

yq eval '.phase = "Testing" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001"]' -i meta.yaml
printf '\n# testing phase deployment drift\n' >> deployment.md
git add deployment.md

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate phase-capability 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "phase-capability gate should fail when deployment.md is staged in Testing phase"
assert_contains "$output" "deployment.md"
log "✓ phase-capability blocks deployment.md in Testing phase"

git reset HEAD deployment.md
git checkout -- deployment.md

# Test 13: promotion trace consistency
log "\n=== Test 13: promotion trace consistency ==="

git reset --hard HEAD >/dev/null
trace_consistency_base="$(git rev-parse HEAD)"
CURRENT_HEAD="$trace_consistency_base" yq eval '.phase = "Deployment" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001", "WI-002"] | .implementation_base_revision = strenv(CURRENT_HEAD)' -i meta.yaml
yq eval '.verification_refs = ["VO-999"]' -i work-items/WI-001.yaml
yq eval '.verification_refs = ["VO-999"]' -i work-items/WI-002.yaml
cat > deployment.md <<'EOF'
# deployment.md

## Deployment Plan
target_env: test
deployment_date: 2026-04-16

## Pre-deployment Checklist
- [x] Tests pass
- [x] Code reviewed

## Deployment Steps
1. Deploy test
2. Restart service

## Execution Evidence
status: pass
execution_ref: smoke-run-trace
deployment_method: automated
deployed_at: 2026-04-16T09:30:00Z
deployed_revision: build=test-2026-04-16
restart_required: yes
restart_reason: application code changed and running process must reload new code
runtime_observed_revision: build=test-2026-04-16
runtime_ready_evidence: build=test-2026-04-16 pid=12345 /health revision=test-2026-04-16; service restarted and new revision observed in process health output

## Verification Results
smoke_test: pass
runtime_ready: pass
manual_verification_ready: pass

## Acceptance Conclusion
status: pass
notes: manual acceptance passed for trace consistency regression test
approved_by: smoke-test
approved_at: 2026-04-16

## Rollback Plan
trigger_conditions:
  - smoke checks fail
rollback_steps:
  1. rollback to previous revision

## Monitoring
metrics:
  - error_rate
alerts:
  - deployment smoke failure

## Post-deployment Actions
- [ ] update related docs
- [ ] archive stable version after manual acceptance
EOF

git add meta.yaml deployment.md work-items/WI-001.yaml work-items/WI-002.yaml
git commit --no-verify -m "test: break trace before promotion"

expect_fail_cmd \
  "trace gap: VO-001 is not referenced by any work item verification_refs" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' complete-change smoke-v2.9"

git reset --hard "$trace_consistency_base" >/dev/null
yq eval '.verification_refs = ["VO-001"]' -i work-items/WI-001.yaml
yq eval '.verification_refs = ["VO-001"]' -i work-items/WI-002.yaml
log "✓ complete-change should re-check trace consistency"

cat >> spec.md <<'EOF'

## Requirements

- req_id: REQ-002
  - summary: orphan requirement used to test strict REQ to ACC trace
  - rationale: source_ref must not be accepted as an ACC mapping
  - source_ref: REQ-002
  - priority: P1
EOF
yq eval '.requirement_refs += ["REQ-002"]' -i work-items/WI-001.yaml
yq eval '.requirement_refs += ["REQ-002"]' -i work-items/WI-002.yaml

expect_fail_cmd \
  "trace gap: REQ-002 has no ACC" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate trace-consistency"

git checkout -- spec.md work-items/WI-001.yaml work-items/WI-002.yaml
log "✓ trace-consistency rejects REQ without ACC even when source_ref mentions the REQ"

# Test 14: Readset
log "\n=== Test 13: Readset ==="

yq eval '.phase = "Requirement" | .status = "active"' -i meta.yaml

readset_output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" readset)

assert_contains "$readset_output" "AGENTS.md"
assert_contains "$readset_output" "meta.yaml"
assert_contains "$readset_output" "spec.md"
log "✓ readset output correct"

readset_json=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" readset --json)

assert_json_eq "$readset_json" '.entry_files[0].path' '"AGENTS.md"'
assert_json_eq "$readset_json" '.minimal_readset | map(select(.path == "meta.yaml")) | length' '1'
assert_json_eq "$readset_json" '.layered_readset.default | map(select(.path == "meta.yaml")) | length' '1'
assert_json_eq "$readset_json" '.phase_capabilities.allowed[0]' '"authoritative dossier edits"'
assert_json_eq "$readset_json" '.phase_capabilities.forbidden[0]' '"src/** and Dockerfile only"'
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate policy-consistency
log "✓ readset JSON output correct"

git reset --hard HEAD >/dev/null

# Test 14: reset-to-requirement resolves promoted version from archived baseline metadata
log "\n=== Test 14: reset-to-requirement ==="

yq eval '.change_id = "baseline" | .base_version = null | .phase = "Deployment" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001", "WI-002"] | .execution_group = null | .execution_branch = null' -i meta.yaml

cat > deployment.md <<'EOF'
# deployment.md

## Deployment Plan
target_env: test
deployment_date: 2026-04-16

## Pre-deployment Checklist
- [x] Tests pass
- [x] Code reviewed

## Deployment Steps
1. Deploy test
2. Restart service

## Execution Evidence
status: pass
execution_ref: smoke-run-006
deployment_method: automated
deployed_at: 2026-04-16T10:00:00Z
deployed_revision: build=test-2026-04-16
source_revision: $CURRENT_HEAD
restart_required: yes
restart_reason: application code changed and running process must reload new code
runtime_observed_revision: build=test-2026-04-16
runtime_ready_evidence: build=test-2026-04-16 pid=12345 /health revision=test-2026-04-16; service restarted and new revision observed in process health output

## Verification Results
smoke_test: pass
runtime_ready: pass
manual_verification_ready: pass

## Acceptance Conclusion
status: pass
notes: manual acceptance passed for alias flow
approved_by: smoke-test
approved_at: 2026-04-16

## Rollback Plan
trigger_conditions:
  - smoke checks fail
rollback_steps:
  1. rollback to previous revision

## Monitoring
metrics:
  - error_rate
alerts:
  - deployment smoke failure

## Post-deployment Actions
- [ ] update related docs
- [ ] archive stable version after manual acceptance
EOF

cat >> testing.md <<'EOF'

- handoff_id: HANDOFF-014
  phase: Deployment
  work_item_refs: [WI-001, WI-002]
  highest_completion_level: owner_verified
  evidence_refs:
    - deployment.md#Execution-Evidence
    - deployment.md#Acceptance-Conclusion
  unfinished_items: none
  fixture_or_fallback_paths: none
  wording_guard: "Deployment runtime and manual acceptance are recorded for promoted baseline reset coverage"
EOF

git add meta.yaml deployment.md testing.md
git commit --no-verify -m "test: prepare promoted baseline fixture"

"$TMP_WORKSPACE/.codespec/codespec" promote-version smoke-v2.8

[ -f "$TMP_WORKSPACE/versions/smoke-v2.8/meta.yaml" ] || die "promote-version did not archive baseline version"
promoted_version=$(yq eval '.promoted_version' "$TMP_WORKSPACE/versions/smoke-v2.8/meta.yaml")
[ "$promoted_version" = "smoke-v2.8" ] || die "promoted_version metadata missing from archived meta"
promoted_at=$(yq eval '.promoted_at' "$TMP_WORKSPACE/versions/smoke-v2.8/meta.yaml")
[ "$promoted_at" != "null" ] || die "promoted_at metadata missing from archived meta"

list_versions_output=$("$TMP_WORKSPACE/.codespec/codespec" list-versions)
assert_contains "$list_versions_output" "Promoted Version"
assert_contains "$list_versions_output" "Promoted At"
assert_contains "$list_versions_output" "smoke-v2.8"
log "✓ list-versions text output includes promoted metadata"

list_versions_json=$("$TMP_WORKSPACE/.codespec/codespec" list-versions --json)
assert_json_eq "$list_versions_json" 'map(select(.version == "smoke-v2.8"))[0].promoted_version' '"smoke-v2.8"'
assert_json_eq "$list_versions_json" 'map(select(.version == "smoke-v2.8"))[0].promoted_at | length > 0' 'true'
log "✓ list-versions JSON output includes promoted metadata"

"$TMP_WORKSPACE/.codespec/codespec" reset-to-requirement

reset_phase=$(yq eval '.phase' meta.yaml)
[ "$reset_phase" = "Requirement" ] || die "reset-to-requirement did not return to Requirement phase"
reset_status=$(yq eval '.status' meta.yaml)
[ "$reset_status" = "active" ] || die "reset-to-requirement did not reactivate dossier"
reset_base_version=$(yq eval '.base_version' meta.yaml)
[ "$reset_base_version" = "smoke-v2.8" ] || die "reset-to-requirement did not carry promoted version into base_version"
reset_change_id=$(yq eval '.change_id' meta.yaml)
[ "$reset_change_id" = "smoke-v2.8-next" ] || die "reset-to-requirement did not derive next change_id from promoted version"
log "✓ reset-to-requirement resolves promoted baseline version"

# Legacy compatibility: same-name archive should still reset through the direct path.
mkdir -p "$TMP_WORKSPACE/versions/release-1"
cp "$TMP_WORKSPACE/versions/smoke-v2.8/meta.yaml" "$TMP_WORKSPACE/versions/release-1/meta.yaml"
yq eval '.change_id = "release-1" | .promoted_version = "release-1"' -i "$TMP_WORKSPACE/versions/release-1/meta.yaml"
yq eval '.change_id = "release-1" | .base_version = null | .phase = "Deployment" | .status = "completed" | .focus_work_item = null | .active_work_items = [] | .execution_group = null | .execution_branch = null' -i meta.yaml

"$TMP_WORKSPACE/.codespec/codespec" reset-to-requirement

legacy_base_version=$(yq eval '.base_version' meta.yaml)
[ "$legacy_base_version" = "release-1" ] || die "reset-to-requirement should preserve direct same-name archive compatibility"
legacy_change_id=$(yq eval '.change_id' meta.yaml)
[ "$legacy_change_id" = "release-1-next" ] || die "legacy same-name archive should derive release-1-next change_id"
log "✓ reset-to-requirement preserves same-name archive compatibility"

expect_fail_cmd \
  "current completed dossier has not been promoted yet" \
  "cd '$TMP_WORKSPACE/test-project' && yq eval '.change_id = \"unpromoted\" | .base_version = null | .phase = \"Deployment\" | .status = \"completed\" | .focus_work_item = null | .active_work_items = [] | .execution_group = null | .execution_branch = null' -i meta.yaml && '$TMP_WORKSPACE/.codespec/codespec' reset-to-requirement"

# Test 15: submit-pr
log "\n=== Test 15: submit-pr ==="

current_branch="$(git branch --show-current)"
[ -n "$current_branch" ] || die "expected a current branch before submit-pr test"

mkdir -p "$TMP_WORKSPACE/bin"
cat > "$TMP_WORKSPACE/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${TMP_GH_LOG:?}"

if [ "${1:-}" = "auth" ] && [ "${2:-}" = "status" ]; then
  printf 'auth ok\n' >>"$log_file"
  exit 0
fi

if [ "${1:-}" = "pr" ] && [ "${2:-}" = "create" ]; then
  shift 2
  printf 'pr create' >>"$log_file"
  body_file=""
  previous_arg=""
  for arg in "$@"; do
    printf ' %s' "$arg" >>"$log_file"
    if [ "$previous_arg" = "--body-file" ]; then
      body_file="$arg"
    fi
    previous_arg="$arg"
  done
  printf '\n' >>"$log_file"
  if [ -n "${TMP_GH_BODY_PATH_FILE:-}" ] && [ -n "$body_file" ]; then
    printf '%s\n' "$body_file" >"$TMP_GH_BODY_PATH_FILE"
  fi
  if [ "${TMP_GH_FAIL_PR_CREATE:-}" = "1" ]; then
    printf 'forced pr create failure\n' >&2
    exit 42
  fi
  printf 'https://example.test/pr/123\n'
  exit 0
fi

printf 'unexpected gh invocation: %s\n' "$*" >&2
exit 1
EOF
chmod +x "$TMP_WORKSPACE/bin/gh"

git init --bare "$TMP_WORKSPACE/test-remote.git" >/dev/null
git remote add origin "$TMP_WORKSPACE/test-remote.git"
git push --no-verify -u origin "$current_branch" >/dev/null
git -C "$TMP_WORKSPACE/test-remote.git" symbolic-ref HEAD "refs/heads/$current_branch"
git fetch origin >/dev/null
git remote set-head origin -a >/dev/null

git checkout -b feature/submit-pr >/dev/null

cp "$TMP_WORKSPACE/versions/smoke-v2.8/spec.md" spec.md
cp "$TMP_WORKSPACE/versions/smoke-v2.8/design.md" design.md
cp "$TMP_WORKSPACE/versions/smoke-v2.8/testing.md" testing.md
cp "$TMP_WORKSPACE/versions/smoke-v2.8/deployment.md" deployment.md
rm -rf work-items
cp -R "$TMP_WORKSPACE/versions/smoke-v2.8/work-items" work-items

CURRENT_HEAD="$(git rev-parse HEAD)"
CURRENT_HEAD="$CURRENT_HEAD" yq eval '.change_id = "submit-pr-change" | .base_version = "smoke-v2.8" | .phase = "Deployment" | .status = "active" | .stable_version = null | .focus_work_item = null | .active_work_items = ["WI-001"] | .feature_branch = "feature/submit-pr" | .execution_group = null | .execution_branch = null | .implementation_base_revision = strenv(CURRENT_HEAD)' -i meta.yaml

cat > deployment.md <<EOF
# deployment.md

## Deployment Plan
target_env: test
deployment_date: 2026-04-16

## Pre-deployment Checklist
- [x] Tests pass
- [x] Code reviewed

## Deployment Steps
1. Deploy test
2. Restart service

## Execution Evidence
status: pass
execution_ref: smoke-run-submit-pr
deployment_method: automated
deployed_at: 2026-04-16T10:00:00Z
deployed_revision: build=test-2026-04-16
source_revision: $CURRENT_HEAD
restart_required: yes
restart_reason: application code changed and running process must reload new code
runtime_observed_revision: build=test-2026-04-16
runtime_ready_evidence: build=test-2026-04-16 pid=12345 /health revision=test-2026-04-16; service restarted and new revision observed in process health output

## Verification Results
smoke_test: pass
runtime_ready: pass
manual_verification_ready: pass

## Acceptance Conclusion
status: pass
notes: manual acceptance passed for submit-pr flow
approved_by: smoke-test
approved_at: 2026-04-16

## Rollback Plan
trigger_conditions:
  - smoke checks fail
rollback_steps:
  1. rollback to previous revision

## Monitoring
metrics:
  - error_rate
alerts:
  - deployment smoke failure

## Post-deployment Actions
- [ ] update related docs
- [ ] archive stable version after manual acceptance
EOF

git add -A
git commit -m "docs: prepare submit-pr flow" >/dev/null

mkdir -p src
echo "undeployed source drift" > src/undeployed-after-deploy.txt
git add src/undeployed-after-deploy.txt
git commit --no-verify -m "test: undeployed source drift" >/dev/null
expect_fail_cmd \
  "submit-pr includes source changes after deployed source_revision" \
  "cd '$TMP_WORKSPACE/test-project' && PATH='$TMP_WORKSPACE/bin:$PATH' TMP_GH_LOG='$TMP_WORKSPACE/gh.log' '$TMP_WORKSPACE/.codespec/codespec' submit-pr smoke-v3"
git reset --hard HEAD^ >/dev/null
log "✓ submit-pr rejects source changes made after deployment evidence"

echo "# dirty" >> deployment.md
expect_fail_cmd \
  "submit-pr requires a clean git working tree" \
  "cd '$TMP_WORKSPACE/test-project' && PATH='$TMP_WORKSPACE/bin:$PATH' TMP_GH_LOG='$TMP_WORKSPACE/gh.log' '$TMP_WORKSPACE/.codespec/codespec' submit-pr smoke-v3"
git reset --hard HEAD >/dev/null

rm -f "$TMP_WORKSPACE/gh.log"
submit_output="$(PATH="$TMP_WORKSPACE/bin:$PATH" TMP_GH_LOG="$TMP_WORKSPACE/gh.log" "$TMP_WORKSPACE/.codespec/codespec" submit-pr smoke-v3)"
assert_contains "$submit_output" "https://example.test/pr/123"
[ -f "$TMP_WORKSPACE/versions/smoke-v3/meta.yaml" ] || die "submit-pr did not archive the submitted version"
assert_eq "$(yq eval '.status' meta.yaml)" "completed"
assert_eq "$(yq eval '.stable_version' meta.yaml)" "smoke-v3"
assert_eq "$(git log -1 --pretty=%s)" "chore: complete change smoke-v3"
assert_contains "$(<"$TMP_WORKSPACE/gh.log")" "pr create --base $current_branch --head feature/submit-pr"
log "✓ submit-pr completes change, pushes branch, and creates PR"

submit_retry_output="$(PATH="$TMP_WORKSPACE/bin:$PATH" TMP_GH_LOG="$TMP_WORKSPACE/gh.log" "$TMP_WORKSPACE/.codespec/codespec" submit-pr smoke-v3)"
assert_contains "$submit_retry_output" "https://example.test/pr/123"
gh_pr_calls="$(grep -c '^pr create' "$TMP_WORKSPACE/gh.log")"
assert_eq "$gh_pr_calls" "2"
log "✓ submit-pr can retry PR creation from a completed dossier"

rm -f "$TMP_WORKSPACE/body-path.log"
set +e
output=$(PATH="$TMP_WORKSPACE/bin:$PATH" TMP_GH_LOG="$TMP_WORKSPACE/gh.log" TMP_GH_FAIL_PR_CREATE=1 TMP_GH_BODY_PATH_FILE="$TMP_WORKSPACE/body-path.log" "$TMP_WORKSPACE/.codespec/codespec" submit-pr smoke-v3 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "submit-pr should fail when gh pr create fails"
assert_contains "$output" "forced pr create failure"
body_file="$(<"$TMP_WORKSPACE/body-path.log")"
[ ! -e "$body_file" ] || die "submit-pr leaked PR body temp file after gh failure: $body_file"
log "✓ submit-pr cleans PR body temp file when gh pr create fails"

yq eval '.execution_group = "parallel-group" | .execution_branch = "feature/submit-pr" | .feature_branch = "'"$current_branch"'"' -i meta.yaml
expect_fail_cmd \
  "submit-pr must run from feature_branch" \
  "cd '$TMP_WORKSPACE/test-project' && PATH='$TMP_WORKSPACE/bin:$PATH' TMP_GH_LOG='$TMP_WORKSPACE/gh.log' '$TMP_WORKSPACE/.codespec/codespec' submit-pr smoke-v3"
log "✓ submit-pr rejects execution branches"

git reset --hard HEAD >/dev/null
git checkout "$current_branch" >/dev/null
yq eval '.phase = "Deployment" | .status = "completed" | .stable_version = "smoke-v3" | .focus_work_item = null | .active_work_items = [] | .feature_branch = "'"$current_branch"'" | .execution_group = null | .execution_branch = null' -i meta.yaml
expect_fail_cmd \
  "submit-pr must not run on the default branch" \
  "cd '$TMP_WORKSPACE/test-project' && PATH='$TMP_WORKSPACE/bin:$PATH' TMP_GH_LOG='$TMP_WORKSPACE/gh.log' '$TMP_WORKSPACE/.codespec/codespec' submit-pr smoke-v3"
log "✓ submit-pr rejects default branch execution"

log "\n=== Test 16: hardening regressions ==="

cd "$TMP_WORKSPACE"
git init hardening-project >/dev/null
cd hardening-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null

expect_fail_cmd \
  "Invalid work item ID format" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' add-work-item ../escape"

expect_fail_cmd \
  "Invalid stable version" \
  "cd '$TMP_WORKSPACE/hardening-project' && yq eval '.phase = \"Deployment\" | .status = \"completed\"' -i meta.yaml && cp '$TMP_WORKSPACE/.codespec/templates/deployment.md' deployment.md && '$TMP_WORKSPACE/.codespec/codespec' scaffold-project-docs ../escaped"
rm -f deployment.md
yq eval '.phase = "Requirement" | .status = "active" | .stable_version = null | .focus_work_item = null | .active_work_items = [] | .implementation_base_revision = null' -i meta.yaml
git add .
git commit -m "docs: initial template dossier" >/dev/null

cat > docs-source.md <<'EOF'
# Source
intent
EOF
cat > spec.md <<'EOF'
# spec.md

## 0. AI 阅读契约
- authority

## Summary
summary

## Inputs
- source_refs:
  - docs-source.md#intent
- source_owner: owner
- maturity: L1
- normalization_note: normalized
- approval_basis: approved

## Scope
scope

## Requirements
- req_id: REQ-001
  - summary: req
  - source_ref: docs-source.md#intent
  - rationale: why
  - priority: P0

## Acceptance
- acc_id: ACC-001
  requirement_ref: REQ-001
  expected_outcome: pass
  priority: P0
  priority_rationale: critical
  status: approved

## Verification
- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - verify pass
  artifact_expectation: output

## 5. 运行约束
none
EOF

cat > testing.md <<'EOF'
# testing.md

## 0. AI 阅读契约
- ledger

## 1. 验收覆盖与测试用例
- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  work_item_refs: [WI-001]
  test_type: integration
  verification_mode: automated
  required_stage: testing
  scenario: scenario
  given: given
  when: when
  then: then
  evidence_expectation: evidence
  status: planned

## 2. 测试执行记录

## 3. 残留风险与返工判断
- residual_risk: none
EOF

expect_fail_cmd \
  "spec.md missing scenario narrative section" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate spec-quality"

perl -0pi -e 's/## Requirements/## 3. 场景、流程与运行叙事\n\n本需求描述一个最小 smoke 场景：用户触发变更后，系统基于稳定输入生成可追溯需求、验收和验证计划。\n设计阶段无需回读聊天记录即可继续展开。系统在收到触发后验证输入完整性，通过后生成正式 REQ 和 ACC。\n验证阶段检查每个 TC 的证据是否可复核。部署阶段确认运行时行为与设计一致。\n如果任何 gate 失败，系统阻断并报告具体原因，不允许继续推进。\n所有 gate 通过后，归档完成版本并生成项目文档壳。\n\n### 场景索引\n\n- scenario_id: SCN-001\n  actor: smoke tester\n  trigger: run requirement gate\n  behavior: validate structured requirement and planned test case\n  expected_outcome: gate can distinguish narrative-ready specs from bare scope skeletons\n  requirement_refs: [REQ-001]\n\n## Requirements/' spec.md

cp spec.md spec.before-missing-constraints.md
perl -0pi -e 's/\n## 5\. 运行约束\nnone\n//s' spec.md
expect_fail_cmd \
  "spec.md missing constraints/verification section" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate spec-quality"
mv spec.before-missing-constraints.md spec.md
log "✓ spec-quality does not treat Verification as runtime constraints"

mkdir -p spec-appendices
cat > spec-appendices/smoke-appendix.md <<'EOF'
# Smoke Appendix

Appendix content without formal IDs.
EOF
expect_fail_cmd \
  "spec.md AI reading contract must define appendix reading matrix" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate spec-quality"
rm -rf spec-appendices
log "✓ spec-quality requires an appendix reading matrix when spec appendices exist"

cp spec.md spec.before-bare-id.md
cat >> spec.md <<'EOF'

## Requirements
- REQ-999
  summary: invalid bare requirement ID
  source_ref: docs-source.md#intent
  rationale: exercise strict formal ID syntax
  priority: P2
EOF

expect_fail_cmd \
  "formal requirement IDs must use req_id" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate spec-quality"
expect_fail_cmd \
  "formal requirement IDs must use req_id" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate test-plan-complete"
mv spec.before-bare-id.md spec.md

mkdir -p work-items
cat > work-items/WI-001.yaml <<'EOF'
wi_id: WI-001
goal: hardening design fixture
phase_scope: Implementation
derived_from: design.md
requirement_refs:
  - REQ-001
acceptance_refs:
  - ACC-001
verification_refs:
  - VO-001
test_case_refs:
  - TC-ACC-001-01
allowed_paths:
  - src/**
forbidden_paths:
  - spec.md
scope:
  - hardening fixture
out_of_scope:
  - production
required_verification:
  - smoke passes
completion_level: fixture_contract
stop_conditions:
  - scope expansion
reopen_triggers:
  - design mismatch
dependency_refs: []
contract_refs: []
branch_execution:
  owned_paths:
    - src/**
  shared_paths: []
  merge_order: 1
EOF

cat > design.md <<'EOF'
# design.md

## 0. AI 阅读契约
- authority

## Summary
- solution_summary: hardening fixture
- minimum_viable_design: minimal
- non_goals:
  - production

## Requirements Trace
- trace_note: this design is not for REQ-001

## Technical Approach
- decision_id: ADR-001
  requirement_refs: [REQ-001]
  decision: use fixture
  alternatives_considered:
    - none
  rationale: smoke
  consequences:
    - none
- runtime: bash
- storage: none

## Boundaries & Impacted Surfaces
- impacted_surfaces:
  - src/**
- external_interactions:
  - name: none
    failure_handling: none

## Data & Storage Design
- data_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture data

## Security Design
- security_design:
  - no sensitive data
- environment_config:
  - none
- reliability_design:
  - fail fast

## 8. 实现阶段输入
- runbook: fixture runbook
- contract_summary: fixture contract
- view_summary: fixture view
- verification_summary: fixture verification

## Work Item Derivation
- wi_id: WI-001
  requirement_refs:
    - REQ-001
  goal: hardening design fixture
  covered_acceptance_refs: [ACC-001]
  verification_refs:
    - VO-001
  test_case_refs:
    - TC-ACC-001-01
  dependency_refs: []
  contract_refs: []
  notes_on_boundary: fixture
EOF

expect_fail_cmd \
  "design.md missing cross-cutting design section" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate design-quality"
log "✓ design-quality does not treat Security Design as the full cross-cutting section"

perl -0pi -e 's/## Security Design/## Cross-Cutting Design/' design.md
expect_fail_cmd \
  "design.md does not reference requirement REQ-001" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate design-quality"
log "✓ design-quality requires structured Requirements Trace references"

perl -0pi -e 's/- trace_note: this design is not for REQ-001/- requirement_ref: REQ-001\n  acceptance_refs: [ACC-001]\n  verification_refs: [VO-001]\n  test_case_refs: [TC-ACC-001-01]\n  design_response: fixture satisfies requirement/' design.md
mkdir -p design-appendices
cat > design-appendices/smoke-appendix.md <<'EOF'
# Smoke Design Appendix

Appendix content without formal IDs.
EOF
expect_fail_cmd \
  "design.md AI reading contract must define appendix reading matrix" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate design-quality"
rm -rf design-appendices
log "✓ design-quality requires an appendix reading matrix when design appendices exist"

perl -0pi -e 's/covered_acceptance_refs: \[ACC-001\]/covered_acceptance_refs:\n    - ACC-001/' design.md
"$TMP_WORKSPACE/.codespec/codespec" check-gate design-quality >/dev/null
log "✓ design work item parser supports block-style covered_acceptance_refs"

rm -rf work-items
cp "$TMP_WORKSPACE/.codespec/templates/design.md" design.md

cd "$TMP_WORKSPACE"
git init push-project >/dev/null
cd push-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
mkdir -p work-items src
cat > work-items/WI-001.yaml <<'EOF'
wi_id: WI-001
completion_level: fixture_contract
EOF
git add .
git commit --no-verify -m "docs: initialize push fixture" >/dev/null
PUSH_BASE="$(git rev-parse HEAD)"
PUSH_BASE="$PUSH_BASE" yq eval '.phase = "Testing" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001"] | .implementation_base_revision = strenv(PUSH_BASE)' -i meta.yaml
git add meta.yaml work-items/WI-001.yaml
git commit --no-verify -m "docs: enter testing fixture" >/dev/null
echo "forbidden testing drift" > src/push-drift.txt
git add src/push-drift.txt
git commit --no-verify -m "test: bypass testing phase capability" >/dev/null
PUSH_LOCAL="$(git rev-parse HEAD)"
PUSH_REMOTE="$(git rev-parse HEAD^)"
set +e
output="$(printf 'refs/heads/feature %s refs/heads/feature %s\n' "$PUSH_LOCAL" "$PUSH_REMOTE" | .git/hooks/pre-push 2>&1)"
status=$?
set -e
[ "$status" -ne 0 ] || die "pre-push should reject committed Testing phase source drift"
assert_contains "$output" "phase-capability gate failed"
assert_contains "$output" "src/push-drift.txt"
log "✓ pre-push checks committed phase-capability drift"

cd "$TMP_WORKSPACE"
git init push-scope-project >/dev/null
cd push-scope-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
mkdir -p work-items docs
cat > work-items/WI-001.yaml <<'EOF'
wi_id: WI-001
allowed_paths:
  - testing.md
forbidden_paths:
  - versions/**
  - spec.md
  - design.md
  - work-items/**
  - contracts/**
  - deployment.md
completion_level: fixture_contract
EOF
git add .
git commit --no-verify -m "docs: initialize push scope fixture" >/dev/null
PUSH_SCOPE_BASE="$(git rev-parse HEAD)"
PUSH_SCOPE_BASE="$PUSH_SCOPE_BASE" yq eval '.phase = "Testing" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001"] | .implementation_base_revision = strenv(PUSH_SCOPE_BASE)' -i meta.yaml
git add meta.yaml
git commit --no-verify -m "docs: enter testing push scope fixture" >/dev/null
echo "unowned testing drift" > docs/unowned.txt
git add docs/unowned.txt
git commit --no-verify -m "test: bypass testing WI scope" >/dev/null
PUSH_SCOPE_LOCAL="$(git rev-parse HEAD)"
PUSH_SCOPE_REMOTE="$(git rev-parse HEAD^)"
set +e
output="$(printf 'refs/heads/feature %s refs/heads/feature %s\n' "$PUSH_SCOPE_LOCAL" "$PUSH_SCOPE_REMOTE" | .git/hooks/pre-push 2>&1)"
status=$?
set -e
[ "$status" -ne 0 ] || die "pre-push should reject committed Testing phase WI scope drift"
assert_contains "$output" "outside allowed_paths of active work items"
assert_contains "$output" "docs/unowned.txt"
log "✓ pre-push checks committed Testing phase WI scope drift"

cd "$TMP_WORKSPACE/hardening-project"

mkdir -p reviews
cat > reviews/design-review.yaml <<'EOF'
phase: Requirement
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
scope:
  - spec.md
  - testing.md
gate_evidence:
  - command: codespec check-gate requirement-complete
    result: pass
  - command: codespec check-gate spec-quality
    result: pass
  - command: codespec check-gate test-plan-complete
    result: pass
findings:
  - severity: none
    summary: no blocking findings
residual_risk: no residual risk identified by review
decision_notes: approved for Design phase entry
EOF
git add .
git restore --staged spec.md
git commit -m "docs: stage supporting requirement artifacts only" >/dev/null

"$TMP_WORKSPACE/.codespec/codespec" start-design
git add meta.yaml
set +e
output=$(git commit -m "test: phase-only commit should fail" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "pre-commit should reject staged phase transition when staged dossier is incomplete"
assert_contains "$output" "input_owner contains placeholder value"
log "✓ pre-commit validates staged dossier content, not unstaged working tree content"

# Test required_surfaces coverage gate
log "\n=== Test: required_surfaces scope-path coverage ==="
run_scope_path_coverage_test
log "✓ required_surfaces coverage gate validated"

log "\n=== All tests passed ==="
