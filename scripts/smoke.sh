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
  log "ok expected failure: $expected"
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  [ "$actual" = "$expected" ] || die "expected '$expected', got '$actual'"
}

# Helper: create a complete design.md for the main test-project
write_complete_design() {
  cat > design.md <<'DESIGNEOF'
# design.md

## 0. AI 阅读契约

- 本文件是 Implementation 阶段的默认权威输入。
- 所有架构决策、模块、接口、数据结构、外部交互和实现计划必须追溯到 REQ-*、ACC-*、VO-*、TC-*。
- 若实现需要越出本文实现边界的范围，必须停止并回写设计或需求，不得隐性扩 scope。

<!-- CODESPEC:DESIGN:OVERVIEW -->
## 1. 设计概览

- solution_summary: 使用最小 bash/git/yq fixture 验证 codespec 生命周期命令。
- minimum_viable_design: 只创建一个可追溯文本实现和测试账本，足以覆盖 smoke 需求。
- non_goals:
  - production deployment

<!-- CODESPEC:DESIGN:TRACE -->
## 2. 需求追溯

- requirement_ref: REQ-001
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  design_response: 通过 SLICE-001 写入 src/test.txt，并通过 testing.md 记录自动化证据。

<!-- CODESPEC:DESIGN:DECISIONS -->
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

<!-- CODESPEC:DESIGN:STRUCTURE -->
## 4. 系统结构

- system_context: codespec lifecycle command fixture
- data_flow:
  - spec.md -> design.md -> testing.md
- external_interactions:
  - name: none
    direction: outbound
    protocol: none
    failure_handling: no external failure path

<!-- CODESPEC:SCOPE_ALLOWED -->
### 可修改路径

- `src/**` — smoke implementation artifacts
- `meta.yaml` — lifecycle metadata
- `testing.md` — test evidence ledger
- `contracts/**` — contract files when authorized
<!-- CODESPEC:SCOPE_ALLOWED_END -->

<!-- CODESPEC:SCOPE_FORBIDDEN -->
### 不可修改路径

- `versions/**` — archived snapshots
- `spec.md` — requirement authority
- `design.md` — design authority (unless in authority repair)
- `deployment.md` — deployment authority
<!-- CODESPEC:SCOPE_FORBIDDEN_END -->

<!-- CODESPEC:DESIGN:CONTRACTS -->
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

<!-- CODESPEC:DESIGN:CROSS_CUTTING -->
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

<!-- CODESPEC:DESIGN:SLICES -->
## 7. 实现计划与验证

### 实现计划

- slice_id: SLICE-001
  goal: implement smoke verification capability
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]

- slice_id: SLICE-002
  goal: implement redeploy loop acceptance capability
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]

### 验证设计

- test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  approach: smoke gates and lifecycle commands pass
  evidence: scripts/smoke.sh completes
  required_stage: testing

### 重开触发器

- if lifecycle gates require duplicate spec/design sections again
- if slice derivation drifts from design.md §7
<!-- CODESPEC:DESIGN:SLICES_END -->

<!-- CODESPEC:DESIGN:IMPLEMENTATION_INPUT -->
## 8. 实现阶段输入

### Runbook（场景如何跑）

- runbook: smoke test runs lifecycle commands and verifies gate outcomes

### Contract（接口与数据结构）

- contract_summary: none required for smoke

### View（各方看到什么）

- view_summary: gate pass/fail output

### Verification（验证证据）

- verification_summary: TC-ACC-001-01 proves gate behavior
DESIGNEOF
}

# Helper: write testing.md TC definition (no work_item_refs)
write_tc_definition() {
  cat > testing.md <<'EOF'
# testing.md

## 0. AI 阅读契约

- 本文件先定义测试用例，再追加执行记录。

## 1. 验收覆盖与测试用例

- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
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
}

# Helper: write testing.md with manual-only TC (for requirement-complete failure test)
write_tc_manual() {
  cat > testing.md <<'EOF'
# testing.md

## 0. AI 阅读契约

- 本文件先定义测试用例，再追加执行记录。

## 1. 验收覆盖与测试用例

- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
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
[ -f ".codespec/templates/gate-map.yaml" ] || die "install-workspace did not copy gate-map.yaml"
[ -f ".codespec/templates/AI_INSTRUCTIONS.md" ] || die "install-workspace did not copy AI_INSTRUCTIONS.md"
[ -d "versions" ] || die "install-workspace did not create versions/"
log "ok workspace installed"

printf 'custom stale policy without legacy gate names\n' > phase-review-policy.md
"$FRAMEWORK_ROOT/scripts/install-workspace.sh" . >/dev/null
assert_contains "$(<phase-review-policy.md)" "Phase Review Policy"
log "ok install-workspace refreshes workspace phase review policy"

help_output=$("$TMP_WORKSPACE/.codespec/codespec" --help)
assert_contains "$help_output" "scaffold-project-docs <version>"
assert_contains "$help_output" "gate-sequence <transition>"
assert_contains "$help_output" "scaffold-review <target-phase>"
assert_contains "$help_output" "migrate-requirement-phase <project_root> [--apply]"
assert_contains "$help_output" "authority-repair <begin|close|status>"
assert_contains "$help_output" "completion-report"
assert_contains "$help_output" "deployment-plan-ready"
assert_contains "$help_output" "semantic-handoff"
assert_contains "$help_output" "scope"
log "ok help exposes scaffold-project-docs, authority-repair, and gates"

gate_sequence_output=$("$TMP_WORKSPACE/.codespec/codespec" gate-sequence start-testing)
assert_contains "$gate_sequence_output" "review-quality"
gate_sequence_json=$("$TMP_WORKSPACE/.codespec/codespec" gate-sequence start-testing --json)
assert_json_eq "$gate_sequence_json" '.transition' '"start-testing"'
assert_json_eq "$gate_sequence_json" '.gates | map(select(.gate == "review-quality")) | length' '1'
log "ok gate-sequence exposes canonical transition gates"

review_fixture="$TMP_WORKSPACE/review-scaffold-project"
git init "$review_fixture" >/dev/null
cd "$review_fixture"
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
"$TMP_WORKSPACE/.codespec/codespec" scaffold-review Design >/dev/null
assert_contains "$(<reviews/design-review.yaml)" "verdict: pending"
assert_contains "$(<reviews/design-review.yaml)" "result: pending"
if grep -q 'verdict: approved' reviews/design-review.yaml; then
  die "scaffold-review must not create approved review verdicts"
fi
cd "$TMP_WORKSPACE"
log "ok scaffold-review creates pending review records only"

agents_body="$(sed '1d' "$TMP_WORKSPACE/.codespec/templates/AGENTS.md")"
claude_body="$(sed '1d' "$TMP_WORKSPACE/.codespec/templates/CLAUDE.md")"
assert_eq "$agents_body" "$claude_body"
assert_contains "$agents_body" "风险分层"
assert_contains "$agents_body" "默认不创建额外 worktree"
assert_contains "$(<"$TMP_WORKSPACE/.codespec/templates/phase-review-policy.md")" "规则权威源"
assert_contains "$(<"$TMP_WORKSPACE/.codespec/templates/phase-review-policy.md")" "审查记录"
log "ok agent templates stay aligned and review policy documents authority semantics"

# Test 1b: Removed command stubs
log "\n=== Test 1b: Removed command stubs ==="
expect_fail_cmd \
  "add-work-item has been removed" \
  "cd '$TMP_WORKSPACE' && '$TMP_WORKSPACE/.codespec/codespec' add-work-item WI-001"

expect_fail_cmd \
  "set-active-work-items has been removed" \
  "cd '$TMP_WORKSPACE' && '$TMP_WORKSPACE/.codespec/codespec' set-active-work-items WI-001"

expect_fail_cmd \
  "set-execution-context has been removed" \
  "cd '$TMP_WORKSPACE' && '$TMP_WORKSPACE/.codespec/codespec' set-execution-context parallel main test-group"
log "ok removed commands output friendly errors"

# Test 1b2: Requirement phase migration command is dry-run by default
log "\n=== Test 1b2: Requirement migration command ==="
migration_project="$TMP_WORKSPACE/migration-project"
git init "$migration_project" >/dev/null
cd "$migration_project"
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
yq eval '.phase = "Requirements"' -i meta.yaml
mkdir -p reviews
cat > reviews/requirements-review.yaml <<'EOF'
phase: Requirements
verdict: approved
reviewed_by: smoke
reviewed_at: 2026-05-09
scope:
  - spec.md
gate_evidence:
  - command: codespec check-gate requirement-complete
    result: pass
findings:
  - severity: none
    summary: fixture
residual_risk: none
decision_notes: fixture
EOF

migration_dry_output="$("$TMP_WORKSPACE/.codespec/codespec" migrate-requirement-phase "$migration_project")"
assert_contains "$migration_dry_output" "DRY RUN"
assert_eq "$(yq eval '.phase' meta.yaml)" "Requirements"
[ -f reviews/requirements-review.yaml ] || die "dry-run should not move requirements review"

"$TMP_WORKSPACE/.codespec/codespec" migrate-requirement-phase "$migration_project" --apply >/dev/null
assert_eq "$(yq eval '.phase' meta.yaml)" "Requirement"
[ -f reviews/design-review.yaml ] || die "apply should move requirements review to design review"
[ -f reviews/requirements-review.yaml ] && die "apply should remove old requirements review path"
[ -f meta.yaml.bak ] || die "apply should back up meta.yaml"
assert_contains "$(<reviews/design-review.yaml)" "phase: Requirement"
cd "$TMP_WORKSPACE"
log "ok migrate-requirement-phase is dry-run by default and applies safely"

# Test 1c: Monorepo project root
log "\n=== Test 1c: Monorepo project root ==="
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
  log "ok monorepo project root resolves to the dossier subdir"
}
run_monorepo_project_root_test

# Test 1d: Monorepo hooks must validate subproject phase transitions
log "\n=== Test 1d: Monorepo pre-commit phase transition ==="
run_monorepo_pre_commit_transition_test() {
  local repo app output status
  repo="$TMP_WORKSPACE/monorepo-phase-hook"
  app="$repo/packages/app"

  git init "$repo" >/dev/null
  cd "$repo"
  git config user.name "Smoke Test"
  git config user.email "smoke@test.local"
  mkdir -p "$app"

  cd "$app"
  "$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
  cd "$repo"
  git add .
  git commit --no-verify -m "docs: init monorepo dossier" >/dev/null

  yq eval '.phase = "Design"' -i "$app/meta.yaml"
  git add "$app/meta.yaml"

  set +e
  output="$(git commit -m "test: manual phase transition should fail" 2>&1)"
  status=$?
  set -e

  [ "$status" -ne 0 ] || die "monorepo pre-commit should reject invalid subproject phase transition"
  assert_contains "$output" "input_owner contains placeholder value"
  cd "$TMP_WORKSPACE"
  log "ok monorepo pre-commit validates subproject phase transitions"
}
run_monorepo_pre_commit_transition_test

# Test 1e: Multiple dossiers in one repository must be handled deliberately
log "\n=== Test 1e: Multi-dossier hooks ==="
run_multi_dossier_hook_test() {
  local repo app1 app2 output status local_sha
  repo="$TMP_WORKSPACE/multi-dossier-repo"
  app1="$repo/packages/app1"
  app2="$repo/packages/app2"

  git init "$repo" >/dev/null
  cd "$repo"
  git config user.name "Smoke Test"
  git config user.email "smoke@test.local"
  mkdir -p "$app1" "$app2"

  cd "$app1"
  "$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
  cd "$app2"
  "$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
  cd "$repo"
  git add .
  git commit --no-verify -m "docs: init multi dossier repo" >/dev/null

  printf 'single project change\n' > "$app1/local-note.txt"
  git add "$app1/local-note.txt"
  git commit -m "docs: app1 local note" >/dev/null

  printf 'cross project change\n' > "$app1/cross-note.txt"
  printf 'cross project change\n' > "$app2/cross-note.txt"
  git add "$app1/cross-note.txt" "$app2/cross-note.txt"
  set +e
  output="$(git commit -m "docs: cross dossier change should fail" 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || die "pre-commit should reject one commit touching multiple dossiers"
  assert_contains "$output" "multiple codespec dossiers changed"
  git reset HEAD "$app1/cross-note.txt" "$app2/cross-note.txt" >/dev/null 2>&1 || true
  rm -f "$app1/cross-note.txt" "$app2/cross-note.txt"

  local_sha="$(git rev-parse HEAD)"
  set +e
  output="$(printf 'refs/heads/main %s refs/heads/main 0000000000000000000000000000000000000000\n' "$local_sha" | "$TMP_WORKSPACE/.codespec/hooks/pre-push" 2>&1)"
  status=$?
  set -e
  [ "$status" -eq 0 ] || die "pre-push should validate multi-dossier repositories without requiring repo-root meta.yaml: $output"
  assert_contains "$output" "pre-push checks passed"
  cd "$TMP_WORKSPACE"
  log "ok multi-dossier hooks handle project roots deliberately"
}
run_multi_dossier_hook_test

# Test 1f: implementation-ready must prove complete design coverage
log "\n=== Test 1f: Design coverage before Implementation ==="
run_design_coverage_test() {
  local repo output status
  repo="$TMP_WORKSPACE/design-coverage-project"
  git init "$repo" >/dev/null
  cd "$repo"
  git config user.name "Smoke Test"
  git config user.email "smoke@test.local"
  "$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null

  yq eval '.phase = "Design"' -i meta.yaml
  cat > spec.md <<'EOF'
# spec.md

## Requirements

- req_id: REQ-001
  summary: Produce primary and audit outputs.
  source_ref: docs/input.md#intent
  rationale: Both outputs are required.
  priority: P0

## Acceptance

- acc_id: ACC-001
  requirement_ref: REQ-001
  expected_outcome: Primary output is produced.
  priority: P0
  priority_rationale: primary output is core behavior
  status: approved

- acc_id: ACC-002
  requirement_ref: REQ-001
  expected_outcome: Audit output is produced.
  priority: P0
  priority_rationale: audit output prevents drift
  status: approved

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - Verify primary output.
  artifact_expectation: primary log

- vo_id: VO-002
  acceptance_ref: ACC-002
  verification_type: automated
  verification_profile: focused
  obligations:
    - Verify audit output.
  artifact_expectation: audit log
EOF

  cat > testing.md <<'EOF'
# testing.md

## 1. 验收覆盖与测试用例

- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  test_type: integration
  verification_mode: automated
  required_stage: testing
  scenario: primary output is generated
  given: fixture command is available
  when: command runs
  then: primary output exists
  evidence_expectation: primary log
  status: planned

- tc_id: TC-ACC-002-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-002
  verification_ref: VO-002
  test_type: integration
  verification_mode: automated
  required_stage: testing
  scenario: audit output is generated
  given: fixture command is available
  when: command runs
  then: audit output exists
  evidence_expectation: audit log
  status: planned
EOF

  cat > design.md <<'EOF'
# design.md

## 0. AI 阅读契约
- design authority

## 1. 设计概览
- solution_summary: Implement only primary output in this incomplete fixture.
- minimum_viable_design: primary output only
- non_goals:
  - audit output intentionally omitted by this fixture

## 2. 需求追溯
- requirement_ref: REQ-001
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  design_response: primary output only

## 3. 架构决策
- decision_id: ADR-001
  requirement_refs: [REQ-001]
  decision: bash fixture
  alternatives_considered:
    - full output coverage
  rationale: test gate coverage
  consequences:
    - omitted audit output must be caught
- runtime: bash
- storage: none

## 4. 系统结构
- system_context: fixture command
- data_flow: trigger to primary output
- external_interactions:
  - name: none
    failure_handling: none

<!-- CODESPEC:SCOPE_ALLOWED -->
### 可修改路径

- `src/**` — fixture implementation
<!-- CODESPEC:SCOPE_ALLOWED_END -->

<!-- CODESPEC:SCOPE_FORBIDDEN -->
### 不可修改路径

- `spec.md` — requirement authority
- `design.md` — design authority
- `versions/**` — archive
<!-- CODESPEC:SCOPE_FORBIDDEN_END -->

## 5. 契约设计
- api_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: none
- data_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: primary output file
- compatibility_policy:
  - none

## 6. 横切设计
- security_design:
  - none
- environment_config:
  - bash
- reliability_design:
  - command failure stops execution
- observability_design:
  - output log
- performance_design:
  - none

<!-- CODESPEC:DESIGN:SLICES -->
## 7. 实现计划与验证

### 实现计划

- slice_id: SLICE-001
  goal: Produce primary output only.
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]

### 验证设计

- test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  approach: run primary test
  evidence: primary log
  required_stage: testing

### 重开触发器

- audit output is required
<!-- CODESPEC:DESIGN:SLICES_END -->

## 8. 实现阶段输入

### Runbook（场景如何跑）
- runbook: run fixture command

### Contract（接口与数据结构）
- contract_summary: none

### View（各方看到什么）
- view_summary: primary output appears

### Verification（验证证据）
- verification_summary: TC-ACC-001-01 proves primary output
EOF

  mkdir -p reviews
  cat > reviews/implementation-review.yaml <<'EOF'
phase: Design
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-05-09
scope:
  - design.md
  - testing.md
gate_evidence:
  - command: codespec check-gate implementation-ready
    result: pass
findings:
  - severity: none
    summary: no blocking findings
residual_risk: none
decision_notes: approved
EOF

  git add .
  git commit --no-verify -m "docs: incomplete design coverage fixture" >/dev/null

  expect_fail_cmd \
    "ACC-002 is not referenced by any design.md" \
    "cd '$repo' && CODESPEC_TARGET_PHASE=Implementation '$TMP_WORKSPACE/.codespec/codespec' check-gate implementation-ready"

  set +e
  output="$(cd "$repo" && "$TMP_WORKSPACE/.codespec/codespec" start-implementation 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || die "start-implementation should fail when design.md §7 omits ACC/VO/TC coverage"

  cd "$TMP_WORKSPACE"
  log "ok implementation entry rejects incomplete design coverage"
}
run_design_coverage_test

# Test 1g: review-quality must verify objective evidence shape
log "\n=== Test 1g: Review quality evidence ==="
run_review_quality_hardening_test() {
  local repo revision
  repo="$TMP_WORKSPACE/review-quality-project"
  git init "$repo" >/dev/null
  cd "$repo"
  git config user.name "Smoke Test"
  git config user.email "smoke@test.local"
  "$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
  git add .
  git commit --no-verify -m "docs: baseline review quality fixture" >/dev/null
  revision="$(git rev-parse HEAD)"
  mkdir -p reviews

  cat > reviews/design-review.yaml <<EOF
phase: Requirement
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-05-09
scope:
  - missing.md
gate_evidence:
  - gate: requirement-complete
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate requirement-complete
    result: pass
    checked_at: 2026-05-09T00:00:00Z
    checked_revision: $revision
    output_summary: passed
findings:
  - severity: none
    summary: no blocking findings
residual_risk: none
decision_notes: approved
EOF

  expect_fail_cmd \
    "review scope references missing artifact: missing.md" \
    "cd '$repo' && CODESPEC_TARGET_PHASE=Design '$TMP_WORKSPACE/.codespec/codespec' check-gate review-quality"

  yq eval '.scope = ["spec.md"]' -i reviews/design-review.yaml
  expect_fail_cmd \
    "review gate_evidence missing required command: spec-quality" \
    "cd '$repo' && CODESPEC_TARGET_PHASE=Design '$TMP_WORKSPACE/.codespec/codespec' check-gate review-quality"

  cd "$TMP_WORKSPACE"
  log "ok review-quality rejects missing scope artifacts and incomplete gate evidence"
}
run_review_quality_hardening_test

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

# Verify no WI fields in meta.yaml
focus_wi="$(yq eval '.focus_work_item // "absent"' meta.yaml 2>/dev/null)"
[ "$focus_wi" = "absent" ] || [ "$focus_wi" = "null" ] || die "meta.yaml should not have focus_work_item field (got: $focus_wi)"
active_wis="$(yq eval '.active_work_items // "absent"' meta.yaml 2>/dev/null)"
[ "$active_wis" = "absent" ] || [ "$active_wis" = "null" ] || die "meta.yaml should not have active_work_items field (got: $active_wis)"
log "ok dossier initialized without WI fields"

# Test 3: Requirement phase
log "\n=== Test 3: Requirement phase ==="
phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Requirement" ] || die "initial phase should be Requirement, got: $phase"

status=$(yq eval '.status' meta.yaml)
[ "$status" = "active" ] || die "initial status should be active, got: $status"
log "ok initial phase is Requirement"

# Test 4: start-design
log "\n=== Test 4: start-design ==="

mkdir -p docs
cat > docs/test.md <<'EOF'
# Test Input

## intent
Test input for smoke test.
EOF

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

write_tc_manual

expect_fail_cmd \
  "automation_exception_reason" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate requirement-complete"

write_tc_definition

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

git add docs spec.md testing.md meta.yaml AGENTS.md CLAUDE.md AI_INSTRUCTIONS.md scripts
git commit --no-verify -m "docs: requirement baseline" >/dev/null
design_review_revision="$(git rev-parse HEAD)"

cat > reviews/design-review.yaml <<EOF
phase: Requirement
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
scope:
  - spec.md
  - testing.md
gate_evidence:
  - gate: requirement-complete
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate requirement-complete
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $design_review_revision
    output_summary: passed
  - gate: spec-quality
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate spec-quality
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $design_review_revision
    output_summary: passed
  - gate: test-plan-complete
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate test-plan-complete
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $design_review_revision
    output_summary: passed
findings:
  - severity: none
    summary: no blocking findings
residual_risk: no residual risk identified by review
decision_notes: approved for Design phase entry
EOF

CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate spec-quality
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate test-plan-complete
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" CODESPEC_TARGET_PHASE=Design "$TMP_WORKSPACE/.codespec/codespec" check-gate review-quality

git add reviews/design-review.yaml meta.yaml testing.md
git commit -m "feat: initial proposal"

"$TMP_WORKSPACE/.codespec/codespec" start-design

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Design" ] || die "start-design did not set phase to Design"
log "ok start-design succeeded"

# Test 5: design and start-implementation (no WI parameters)
log "\n=== Test 5: design and start-implementation ==="

write_complete_design

git add design.md meta.yaml
git commit -m "feat: complete design"
implementation_review_revision="$(git rev-parse HEAD)"

cat > reviews/implementation-review.yaml <<EOF
phase: Design
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
scope:
  - design.md
  - testing.md
gate_evidence:
  - gate: design-quality
    command: CODESPEC_TARGET_PHASE=Implementation codespec check-gate design-quality
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $implementation_review_revision
    output_summary: passed
  - gate: implementation-ready
    command: CODESPEC_TARGET_PHASE=Implementation codespec check-gate implementation-ready
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $implementation_review_revision
    output_summary: passed
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

# start-implementation takes no WI-ID parameter
"$TMP_WORKSPACE/.codespec/codespec" start-implementation

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Implementation" ] || die "start-implementation did not set phase"

# No focus_work_item or active_work_items in meta.yaml
yq eval '.focus_work_item // "absent"' meta.yaml 2>/dev/null | grep -q "absent" || die "meta.yaml should not have focus_work_item"

[ -f "testing.md" ] || die "start-implementation did not preserve testing.md"

git add meta.yaml
git commit -m "chore: enter implementation"
log "ok start-implementation succeeded without WI parameters"

# Test 5b: scope gate based on design.md §4
log "\n=== Test 5b: scope gate based on design.md §4 ==="

mkdir -p src
cat > src/test.txt <<'EOF'
test implementation
EOF
git add src/test.txt
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate scope
git commit -m "feat: implement SLICE-001"
log "ok scope gate allows design.md §4 allowed paths"

# Test modifying forbidden path (spec.md)
printf '\nforbidden implementation drift\n' >> spec.md
git add spec.md
expect_fail_cmd \
  "is forbidden by design.md" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate scope"
git reset HEAD spec.md >/dev/null 2>&1 || true
git checkout -- spec.md
log "ok scope gate rejects spec.md drift (design.md §4 forbidden)"

# Test modifying path outside allowed scope
mkdir -p docs
echo "unowned" > docs/unowned.txt
git add docs/unowned.txt
expect_fail_cmd \
  "outside allowed scope" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate scope"
git reset HEAD docs/unowned.txt >/dev/null 2>&1 || true
rm -f docs/unowned.txt
log "ok scope gate rejects paths outside design.md §4 allowed scope"

# Test modifying forbidden path (versions/**)
mkdir -p versions
echo "forbidden" > versions/forbidden.txt
git add versions/forbidden.txt
expect_fail_cmd \
  "forbidden" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate scope"
git reset HEAD versions/forbidden.txt >/dev/null 2>&1 || true
rm -rf versions
log "ok scope gate rejects versions/** (design.md §4 forbidden)"

# Test: design.md forbidden and allowed both match -> forbidden wins
# design.md has spec.md in forbidden, so even if we add it to allowed it should still be rejected
printf '\nforbidden priority test\n' >> deployment.md
git add deployment.md
expect_fail_cmd \
  "forbidden" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate scope"
git reset HEAD deployment.md >/dev/null 2>&1 || true
git checkout -- deployment.md 2>/dev/null || true
rm -f deployment.md
log "ok scope gate forbidden takes priority over allowed"
log "\n=== Test 5c: implementation-span scope ==="
git reset --hard HEAD >/dev/null

# Add RUN record
cat >> testing.md <<'EOF'

- run_id: RUN-001
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  slice_ref: SLICE-001
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

printf '\nforbidden implementation drift\n' >> spec.md
git add spec.md
git commit -q --no-verify -m "introduce forbidden spec drift"
expect_fail_cmd \
  "implementation span file spec.md is forbidden" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' start-testing"
git reset --soft HEAD~1 >/dev/null 2>&1 || true
git restore --staged spec.md >/dev/null 2>&1 || true
git checkout -- spec.md
log "ok start-testing rejects committed forbidden drift across Implementation span"

# Test 5d: authority repair flow
log "\n=== Test 5d: authority repair ==="

if [ "${CODESPEC_AUTHORITY_REPAIR_SMOKE_RUNNING:-}" = '1' ]; then
  log "ok nested authority repair close smoke skips recursive fixture"
else
  "$TMP_WORKSPACE/.codespec/codespec" authority-repair begin design-quality --paths design.md --reason "design-quality gate found missing implementation handoff"
  repair_id="$(yq eval '.active_authority_repair' meta.yaml)"
  [ "$repair_id" != "null" ] || die "authority-repair begin did not set active_authority_repair"
  [ -f "authority-repairs/$repair_id.yaml" ] || die "authority-repair begin did not create repair record"

  printf '\n- authority_repair_note: implementation handoff clarified without changing product scope\n' >> design.md
  git add meta.yaml "authority-repairs/$repair_id.yaml" design.md
  "$TMP_WORKSPACE/.codespec/codespec" check-gate scope
  log "ok active authority repair allows declared design authority edits"

  printf '\n# unauthorized repair spec drift\n' >> spec.md
  git add spec.md
  expect_fail_cmd \
    "outside active authority repair allowed_paths" \
    "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate scope"
  git reset HEAD spec.md >/dev/null 2>&1 || true
  git checkout -- spec.md
  log "ok active authority repair rejects undeclared spec.md edits"

  cp "$TMP_WORKSPACE/.codespec/scripts/smoke.sh" "$TMP_WORKSPACE/.codespec/scripts/smoke.sh.original"
  cat > "$TMP_WORKSPACE/.codespec/scripts/smoke.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${CODESPEC_AUTHORITY_REPAIR_SMOKE_RUNNING:-}" = "1" ]; then
  printf 'nested full smoke should not run during authority repair close\n' >&2
  exit 99
fi
exec "$(dirname "$0")/smoke.sh.original" "$@"
EOF
  chmod +x "$TMP_WORKSPACE/.codespec/scripts/smoke.sh"
  "$TMP_WORKSPACE/.codespec/codespec" authority-repair close --evidence "design-quality passed after clarifying implementation handoff"
  mv "$TMP_WORKSPACE/.codespec/scripts/smoke.sh.original" "$TMP_WORKSPACE/.codespec/scripts/smoke.sh"
  chmod +x "$TMP_WORKSPACE/.codespec/scripts/smoke.sh"
  [ "$(yq eval '.active_authority_repair' meta.yaml)" = "null" ] || die "authority-repair close did not clear active_authority_repair"
  [ "$(yq eval '.status' "authority-repairs/$repair_id.yaml")" = "closed" ] || die "authority-repair close did not close repair record"
  [ "$(yq eval '.gate_result' "authority-repairs/$repair_id.yaml")" = "pass" ] || die "authority-repair close did not record gate pass"
  [ "$(yq eval '.smoke_result' "authority-repairs/$repair_id.yaml")" = "not-run" ] || die "authority-repair close should record smoke_result: not-run"
  git add meta.yaml "authority-repairs/$repair_id.yaml" design.md
  git commit -m "docs: repair implementation authority handoff"
  log "ok authority-repair close does not invoke full framework smoke"
  CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" CODESPEC_SCOPE_MODE=implementation-span "$TMP_WORKSPACE/.codespec/codespec" check-gate scope
  log "ok closed authority repair lets implementation-span scope accept audited design repair"

  "$TMP_WORKSPACE/.codespec/codespec" authority-repair begin trace-consistency --kind source-trace --paths spec.md --reason "trace-consistency gate found source_ref closure metadata drift"
  source_trace_repair_id="$(yq eval '.active_authority_repair' meta.yaml)"
  [ "$(yq eval '.kind' "authority-repairs/$source_trace_repair_id.yaml")" = "source-trace" ] || die "source-trace repair did not record kind"
  sed -i 's/docs\/test.md#intent/docs\/test.md#source-trace/g' spec.md
  git add meta.yaml "authority-repairs/$source_trace_repair_id.yaml" spec.md
  "$TMP_WORKSPACE/.codespec/codespec" check-gate scope
  "$TMP_WORKSPACE/.codespec/codespec" authority-repair close --evidence "source_ref closure metadata repaired without changing requirement semantics"
  [ "$(yq eval '.active_authority_repair' meta.yaml)" = "null" ] || die "source-trace repair close did not clear active_authority_repair"
  git add meta.yaml "authority-repairs/$source_trace_repair_id.yaml" spec.md
  git commit -m "docs: repair source trace metadata"
  log "ok source-trace authority repair allows audited spec trace metadata edits"

  "$TMP_WORKSPACE/.codespec/codespec" authority-repair begin trace-consistency --kind source-trace --paths spec.md --reason "attempt invalid semantic source-trace edit"
  bad_source_trace_repair_id="$(yq eval '.active_authority_repair' meta.yaml)"
  sed -i '0,/summary: test requirement/s//summary: changed requirement semantics/' spec.md
  git add meta.yaml "authority-repairs/$bad_source_trace_repair_id.yaml" spec.md
  expect_fail_cmd \
    "source-trace repair changed spec.md requirement semantics" \
    "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' authority-repair close --evidence 'should fail because summary changed'"
  git reset HEAD meta.yaml "authority-repairs/$bad_source_trace_repair_id.yaml" spec.md >/dev/null 2>&1 || true
  git checkout -- meta.yaml spec.md
  rm -f "authority-repairs/$bad_source_trace_repair_id.yaml"
  log "ok source-trace authority repair rejects spec requirement semantic edits"

  yq eval '.evidence = "tampered after close"' -i "authority-repairs/$repair_id.yaml"
  git add "authority-repairs/$repair_id.yaml"
  expect_fail_cmd \
    "authority repair record authority-repairs/$repair_id.yaml can only be created closed or close a previously open repair" \
    "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate metadata-consistency"
  git reset HEAD "authority-repairs/$repair_id.yaml" >/dev/null 2>&1 || true
  git checkout -- "authority-repairs/$repair_id.yaml"
  log "ok closed authority repair record cannot be silently rewritten"
fi

if ! git diff --quiet -- meta.yaml; then
  git add meta.yaml
  git commit -m "chore: enter implementation"
else
  log "ok implementation phase metadata already committed"
fi

# Test 6: semantic handoff with slice_refs
log "\n=== Test 6: semantic handoff with slice_refs ==="

expect_fail_cmd \
  "semantic handoff missing for phase Implementation" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate semantic-handoff"

cat >> testing.md <<'EOF'

## 4. 主动未完成清单与语义验收

- handoff_id: HANDOFF-001
  phase: Implementation
  slice_refs: [SLICE-001]
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
  slice_refs: [SLICE-001, SLICE-002]
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
handoff_template="$("$TMP_WORKSPACE/.codespec/codespec" completion-report --handoff-template)"
assert_contains "$handoff_template" "handoff_id: HANDOFF-"
assert_contains "$handoff_template" "unfinished_items:"
git add testing.md
git commit -m "docs: record implementation semantic handoff"
log "ok semantic handoff with slice_refs passed"

cd "$TMP_WORKSPACE"
git init report-project >/dev/null
cd report-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
write_complete_design
write_tc_definition
yq eval '.phase = "Implementation" | .status = "active"' -i meta.yaml
cat >> testing.md <<'EOF'

- run_id: RUN-REPORT-001
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  slice_ref: SLICE-001
  test_type: integration
  test_scope: branch-local
  verification_type: automated
  artifact_ref: src/test.txt
  result: pass
  completion_level: integrated_runtime
  tested_at: 2026-04-16
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false
EOF
completion_report="$("$TMP_WORKSPACE/.codespec/codespec" completion-report)"
assert_contains "$completion_report" "highest_completion_level: integrated_runtime"
handoff_template="$("$TMP_WORKSPACE/.codespec/codespec" completion-report --handoff-template)"
assert_contains "$handoff_template" "current_completion_level: integrated_runtime"
log "ok completion-report parses list-style testing ledger and renders handoff template"

cd "$TMP_WORKSPACE/test-project"

# Test 6b: HANDOFF without slice_refs fails
log "\n=== Test 6b: HANDOFF without slice_refs fails ==="

# We already know HANDOFF-001 and HANDOFF-002 have slice_refs, so the gate passes.
# Test that missing slice_refs in Implementation is caught:
cat >> testing.md <<'EOF'

- handoff_id: HANDOFF-BAD
  phase: Implementation
  highest_completion_level: fixture_contract
  evidence_refs:
    - testing.md#RUN-001
  unfinished_items:
    - source_ref: testing.md#TC-ACC-001-01
      priority: P0
      current_completion_level: fixture_contract
      target_completion_level: integrated_runtime
      blocker: test
      next_step: test
  fixture_or_fallback_paths:
    - surface: test
      completion_level: fixture_contract
      real_api_verified: false
      visible_failure_state: false
      trace_retry_verified: false
  wording_guard: "test"
EOF

expect_fail_cmd \
  "semantic handoff missing slice_refs" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate semantic-handoff"

# Remove the bad handoff entry
git checkout -- testing.md
git commit --allow-empty -m "chore: cleanup" >/dev/null
log "ok HANDOFF without slice_refs is rejected"

# Test 7: Implementation -> Testing transition
log "\n=== Test 7: Implementation -> Testing ==="

# Prepare full transition handoff
cat >> testing.md <<'EOF'

- handoff_id: HANDOFF-003
  phase: Implementation
  slice_refs: [SLICE-001, SLICE-002]
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
testing_review_revision="$(git rev-parse HEAD)"

cat > reviews/testing-review.yaml <<EOF
phase: Implementation
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
scope:
  - testing.md
  - meta.yaml
gate_evidence:
  - gate: metadata-consistency
    command: codespec check-gate metadata-consistency
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $testing_review_revision
    output_summary: passed
  - gate: scope
    command: CODESPEC_SCOPE_MODE=implementation-span codespec check-gate scope
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $testing_review_revision
    output_summary: passed
  - gate: contract-boundary
    command: CODESPEC_CONTRACT_BOUNDARY_MODE=implementation-span codespec check-gate contract-boundary
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $testing_review_revision
    output_summary: passed
  - gate: verification
    command: codespec check-gate verification
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $testing_review_revision
    output_summary: passed
  - gate: semantic-handoff
    command: codespec check-gate semantic-handoff
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $testing_review_revision
    output_summary: passed
findings:
  - severity: none
    summary: no blocking findings
residual_risk: no residual risk identified by review
decision_notes: approved for Testing phase entry
EOF

git add reviews/testing-review.yaml
git commit -m "docs: approve testing review"

"$TMP_WORKSPACE/.codespec/codespec" start-testing

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Testing" ] || die "start-testing did not set phase"
git add meta.yaml
git commit -m "chore: enter testing"
log "ok start-testing succeeded"

# Test: Testing phase blocks implementation artifact edits
echo "testing-phase-drift" >> src/test.txt
git add src/test.txt

set +e
output=$(git commit -m "test: should fail in Testing phase" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "Testing phase should block src/** modifications"
assert_contains "$output" "Testing forbids phase-frozen artifacts: src/test.txt"
log "ok Testing phase blocks implementation artifact edits"

git reset HEAD src/test.txt >/dev/null 2>&1 || true
git checkout -- src/test.txt

# Test 8: Deployment
log "\n=== Test 8: Deployment ==="

cat > testing.md <<'EOF'
- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
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
  slice_ref: SLICE-001
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
  slice_ref: SLICE-001
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

yq eval '.phase = "Deployment" | .status = "active"' -i meta.yaml
git add meta.yaml

set +e
output=$(git commit -m "test: should fail missing semantic handoff manual Deployment transition" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "pre-commit should block manual Deployment phase transition without semantic handoff"
assert_contains "$output" "semantic handoff missing for phase Testing"
log "ok pre-commit blocks manual Deployment transition without semantic handoff"

git reset HEAD meta.yaml >/dev/null 2>&1 || true
git checkout -- meta.yaml

expect_fail_cmd \
  "semantic handoff missing for phase Testing" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' start-deployment"

cat >> testing.md <<'EOF'

## 4. 主动未完成清单与语义验收

- handoff_id: HANDOFF-004
  phase: Testing
  slice_refs: [SLICE-001, SLICE-002]
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
log "ok start-deployment succeeded"

expect_fail_cmd \
  "deployment.md target_env must be set before deploy" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' deploy"
log "ok deploy refuses to run before deployment plan is ready"

# Test: Deployment phase blocks design.md edits
printf '\n# deployment phase drift\n' >> design.md
git add design.md

set +e
output=$(git commit -m "test: should fail in Deployment phase" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "Deployment phase should block design.md modifications"
assert_contains "$output" "Deployment forbids phase-frozen artifacts: design.md"
log "ok Deployment phase blocks authority file edits"

git reset HEAD design.md >/dev/null 2>&1 || true
git checkout -- design.md

# Test 9: Complete change
log "\n=== Test 9: Complete change ==="

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
log "ok deploy rejects Chinese placeholder result values"

mv scripts/codespec-deploy.good scripts/codespec-deploy
chmod +x scripts/codespec-deploy

"$TMP_WORKSPACE/.codespec/codespec" deploy
"$TMP_WORKSPACE/.codespec/codespec" check-gate deployment-readiness

assert_contains "$(<deployment.md)" "execution_ref: smoke-run-001"
assert_contains "$(<deployment.md)" "status: pending"
log "ok deploy writes execution evidence and readiness data"

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

# reopen-implementation no longer accepts WI-ID
"$TMP_WORKSPACE/.codespec/codespec" reopen-implementation

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Implementation" ] || die "reopen-implementation did not set phase to Implementation"
git checkout -- deployment.md
git add meta.yaml
git commit -m "chore: reopen implementation after failed acceptance"
log "ok reopen-implementation re-enters Implementation for failed manual verification (no WI-ID parameter)"

cat >> testing.md <<'EOF'

- handoff_id: HANDOFF-006
  phase: Implementation
  slice_refs: [SLICE-001, SLICE-002]
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
cat >> testing.md <<'EOF'

- handoff_id: HANDOFF-007
  phase: Testing
  slice_refs: [SLICE-001, SLICE-002]
  highest_completion_level: integrated_runtime
  evidence_refs:
    - testing.md#RUN-001
    - deployment.md#Acceptance-Conclusion
  unfinished_items:
    - source_ref: deployment.md#Acceptance-Conclusion
      priority: P0
      current_completion_level: integrated_runtime
      target_completion_level: owner_verified
      blocker: redeploy acceptance has not passed yet
      next_step: re-enter Deployment, deploy, and record manual acceptance
  fixture_or_fallback_paths: none
  wording_guard: "Testing re-entry has integrated evidence only; do not report owner_verified before redeploy acceptance"
EOF
git add testing.md
git commit -m "docs: record testing handoff after failed acceptance"
"$TMP_WORKSPACE/.codespec/codespec" start-deployment
git add meta.yaml deployment.md
git commit -m "chore: re-enter deployment after failed acceptance"
"$TMP_WORKSPACE/.codespec/codespec" deploy

assert_contains "$(<deployment.md)" "notes: pending manual acceptance"
log "ok redeploy resets manual acceptance conclusion to pending"

replace_markdown_section deployment.md "## Acceptance Conclusion" "$(cat <<'EOF'
status: pass
notes: manual acceptance passed after redeploy
approved_by: smoke-test
approved_at: 2026-04-16
EOF
)"

git add meta.yaml deployment.md
git commit -m "docs: record manual acceptance"

yq eval '.status = "completed" | .stable_version = "manual-bypass"' -i meta.yaml
git add meta.yaml

set +e
output=$(git commit -m "test: should fail missing semantic handoff manual completion" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "pre-commit should block manual Deployment completion without semantic handoff"
assert_contains "$output" "semantic handoff missing for phase Deployment"
log "ok pre-commit blocks manual Deployment completion without semantic handoff"

git reset HEAD meta.yaml >/dev/null 2>&1 || true
git checkout -- meta.yaml

expect_fail_cmd \
  "semantic handoff missing for phase Deployment" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' complete-change smoke-v1"

cat >> testing.md <<'EOF'

- handoff_id: HANDOFF-005
  phase: Deployment
  slice_refs: [SLICE-001, SLICE-002]
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
[ -f "$TMP_WORKSPACE/test-project/versions/smoke-v1/meta.yaml" ] || die "complete-change did not archive stable version"
git add meta.yaml versions/smoke-v1
git commit -m "chore: complete smoke-v1"
log "ok complete-change archived the accepted stable version"

"$TMP_WORKSPACE/.codespec/codespec" scaffold-project-docs smoke-v1
assert_contains "$(<"$TMP_WORKSPACE/project-docs/smoke-v1/系统功能说明书.md")" "| 状态 | Draft |"
log "ok scaffold-project-docs creates draft project document shells"

# Completed dossiers should remain re-verifiable
"$TMP_WORKSPACE/.codespec/codespec" check-gate verification
"$TMP_WORKSPACE/.codespec/codespec" check-gate promotion-criteria
log "ok completed dossier remains re-verifiable"

# Reopen from completed state
"$TMP_WORKSPACE/.codespec/codespec" start-deployment
[ "$(yq eval '.phase' meta.yaml)" = "Deployment" ] || die "completed reopen should return to Deployment phase"
[ "$(yq eval '.status' meta.yaml)" = "active" ] || die "completed reopen should reactivate the dossier"
git add meta.yaml
git commit -m "chore: reopen completed deployment"
log "ok start-deployment reactivates completed dossier"

bad_reopen_base="$(git rev-parse HEAD)"
yq eval '.phase = "Deployment" | .status = "completed" | .stable_version = "smoke-v1"' -i meta.yaml
cat >> testing.md <<'EOF'

- run_id: RUN-BAD-REOPEN
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  slice_ref: SLICE-001
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
log "ok completed Deployment reopen re-runs verification gates"

# Deployment readiness checks
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
log "ok deployment-readiness requires runtime readiness"

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
log "ok deployment-readiness requires runtime readiness evidence"

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
log "ok deployment-readiness blocks handoff before manual verification is ready"

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
log "ok deployment-readiness requires restart evidence when restart is required"

# Artifact release mode
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
log "ok deployment-readiness supports artifact release mode"

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
log "ok deploy supports artifact release mode"

# Test 10: testing ledger selection semantics
log "\n=== Test 10: testing ledger selection semantics ==="
git reset --hard HEAD >/dev/null

yq eval '.phase = "Testing" | .status = "active"' -i meta.yaml

cat > testing.md <<'EOF'
- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
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
  slice_ref: SLICE-001
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
  slice_ref: SLICE-001
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
log "ok verification uses the latest matching pass record without duplicating extracted fields"

cat > testing.md <<'EOF'
- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
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
  slice_ref: SLICE-001
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
  slice_ref: SLICE-001
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
log "ok verification rejects a later full-integration failure after an earlier pass"

# Test 11: File modification rules (no execution branch context)
log "\n=== Test 11: File modification rules ==="

git reset --hard HEAD >/dev/null 2>&1 || true

yq eval '.phase = "Implementation" | .status = "active"' -i meta.yaml
git add meta.yaml
git commit --no-verify -m "chore: set implementation file rule fixture" >/dev/null

# spec.md cannot be modified in Implementation phase
echo "# test" >> spec.md
git add spec.md

set +e
output=$(git commit -m "test: should fail" 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "pre-commit should block spec.md modification in Implementation phase"
assert_contains "$output" "forbids"
log "ok pre-commit blocks spec.md modification in Implementation phase"

git reset HEAD spec.md
git checkout -- spec.md

# testing.md can be modified in Implementation phase
echo "# test" >> testing.md
git add testing.md
git commit -m "test: testing.md modification allowed"
log "ok pre-commit allows testing.md modification in Implementation phase"

# src/** can be modified in Implementation phase (allowed in design.md §4)
echo "test" >> src/test.txt
git add src/test.txt
git commit -m "feat: src modification allowed"
log "ok pre-commit allows src/** modification in Implementation phase"

# Test 12: Gate checks
log "\n=== Test 12: Gate checks ==="

git checkout master 2>/dev/null || git checkout main 2>/dev/null || true
cd "$TMP_WORKSPACE/test-project"

# metadata-consistency gate: no WI-related checks
yq eval '.phase = "UnknownPhase" | .status = "active" | .implementation_base_revision = null' -i meta.yaml
set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate metadata-consistency 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "metadata-consistency gate should reject invalid phase values"
assert_contains "$output" "phase"
log "ok metadata-consistency rejects invalid phase enum"

yq eval '.phase = "Requirement" | .status = "completed" | .implementation_base_revision = null' -i meta.yaml
set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate metadata-consistency 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "metadata-consistency gate should reject completed status outside Deployment"
assert_contains "$output" "completed status requires Deployment phase"
log "ok metadata-consistency rejects completed status outside Deployment"

# metadata-consistency: no focus_work_item/active_work_items to check
yq eval '.phase = "Implementation" | .status = "active"' -i meta.yaml
CURRENT_HEAD="$(git rev-parse HEAD)"
CURRENT_HEAD="$CURRENT_HEAD" yq eval ".implementation_base_revision = strenv(CURRENT_HEAD)" -i meta.yaml
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate metadata-consistency
log "ok metadata-consistency passes without WI fields"

# phase-capability gate
yq eval '.phase = "Requirement" | .implementation_base_revision = null' -i meta.yaml
echo "test" > src/forbidden.txt
git add src/forbidden.txt

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate phase-capability 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "phase-capability gate should fail when src/** exists in Requirement phase"
log "ok phase-capability gate works"

git reset HEAD src/forbidden.txt
rm -f src/forbidden.txt

yq eval '.phase = "Design" | .status = "active" | .implementation_base_revision = null' -i meta.yaml
echo "design drift" > src/design-forbidden.txt
git add src/design-forbidden.txt

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate phase-capability 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "phase-capability gate should fail when src/** is staged in Design phase"
assert_contains "$output" "Design forbids implementation artifacts"
log "ok phase-capability blocks implementation artifacts in Design phase"

git reset HEAD src/design-forbidden.txt
rm -f src/design-forbidden.txt

yq eval '.phase = "Testing" | .status = "active"' -i meta.yaml
printf '\n# testing phase deployment drift\n' >> deployment.md
git add deployment.md

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate phase-capability 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "phase-capability gate should fail when deployment.md is staged in Testing phase"
assert_contains "$output" "deployment.md"
log "ok phase-capability blocks deployment.md in Testing phase"

git reset HEAD deployment.md
git checkout -- deployment.md

yq eval '.phase = "Deployment" | .status = "completed"' -i meta.yaml
CURRENT_HEAD="$(git rev-parse HEAD)"
cat > authority-repairs/REPAIR-SMOKE-LEGACY.yaml <<EOF
repair_id: REPAIR-SMOKE-LEGACY
status: closed
phase: Implementation
gate: verification
reason: Legacy closed repair from the removed work-items model
allowed_paths:
  - design.md
  - work-items/WI-001.yaml
opened_at: 2026-04-16T00:00:00Z
opened_revision: $CURRENT_HEAD
closed_at: 2026-04-16T00:00:00Z
closed_revision: $CURRENT_HEAD
evidence: historical record
gate_result: pass
smoke_result: pass
EOF
cat > authority-repairs/REPAIR-SMOKE-DESIGN.yaml <<EOF
repair_id: REPAIR-SMOKE-DESIGN
status: closed
phase: Deployment
gate: design-quality
reason: Valid closed design repair for changed-files phase-capability lookup
allowed_paths:
  - design.md
opened_at: 2026-04-16T00:00:00Z
opened_revision: $CURRENT_HEAD
closed_at: 2026-04-16T00:00:00Z
closed_revision: $CURRENT_HEAD
evidence: historical record
gate_result: pass
smoke_result: pass
EOF
printf '\n# deployment closed repair drift\n' >> design.md

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" CODESPEC_PHASE_CAPABILITY_MODE=changed-files CODESPEC_CHANGED_FILES=design.md "$TMP_WORKSPACE/.codespec/codespec" check-gate phase-capability 2>&1)
status=$?
set -e

[ "$status" -eq 0 ] || die "phase-capability should ignore unrelated legacy closed repairs when a matching closed repair allows the file: $output"
log "ok phase-capability ignores unrelated legacy closed repairs"

rm -f authority-repairs/REPAIR-SMOKE-LEGACY.yaml authority-repairs/REPAIR-SMOKE-DESIGN.yaml
git checkout -- design.md meta.yaml

# Test 13: promotion trace consistency
log "\n=== Test 13: promotion trace consistency ==="

git reset --hard HEAD >/dev/null
trace_consistency_base="$(git rev-parse HEAD)"
CURRENT_HEAD="$trace_consistency_base" yq eval '.phase = "Deployment" | .status = "active" | .implementation_base_revision = strenv(CURRENT_HEAD)' -i meta.yaml

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

git add meta.yaml deployment.md
git commit --no-verify -m "test: prepare trace consistency fixture"

# Break trace: change design.md §7 verification_refs to VO-999
perl -0pi -e 's/verification_refs: \[VO-001\]/verification_refs: [VO-999]/g' design.md
git add design.md
git commit --no-verify -m "test: break trace before promotion"

expect_fail_cmd \
  "trace gap: VO-001 is not referenced by any design.md" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' complete-change smoke-v2.9"

git reset --hard "$trace_consistency_base" >/dev/null
log "ok complete-change re-checks trace consistency"

cat >> spec.md <<'EOF'

## Requirements

- req_id: REQ-002
  - summary: orphan requirement used to test strict REQ to ACC trace
  - rationale: source_ref must not be accepted as an ACC mapping
  - source_ref: REQ-002
  - priority: P1
EOF

expect_fail_cmd \
  "trace gap: REQ-002 has no ACC" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate trace-consistency"

git checkout -- spec.md
log "ok trace-consistency rejects REQ without ACC even when source_ref mentions the REQ"

# Test 14: Readset
log "\n=== Test 14: Readset ==="

yq eval '.phase = "Requirement" | .status = "active" | .implementation_base_revision = null' -i meta.yaml

readset_output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" readset)

assert_contains "$readset_output" "AGENTS.md"
assert_contains "$readset_output" "meta.yaml"
assert_contains "$readset_output" "spec.md"
log "ok readset output correct"

readset_json=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" readset --json)

assert_json_eq "$readset_json" '.entry_files[0].path' '"AGENTS.md"'
assert_json_eq "$readset_json" '.minimal_readset | map(select(.path == "meta.yaml")) | length' '1'
assert_json_eq "$readset_json" '.layered_readset.default | map(select(.path == "meta.yaml")) | length' '1'
assert_json_eq "$readset_json" '.phase_capabilities.allowed[0]' '"authoritative dossier edits"'
assert_json_eq "$readset_json" '.phase_capabilities.forbidden[0]' '"src/** and Dockerfile only"'
CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate policy-consistency
log "ok readset JSON output correct"

git reset --hard HEAD >/dev/null

# Test 15: reset-to-requirement
log "\n=== Test 15: reset-to-requirement ==="

CURRENT_HEAD="$(git rev-parse HEAD)"
CURRENT_HEAD="$CURRENT_HEAD" yq eval ".change_id = \"baseline\" | .base_version = null | .phase = \"Deployment\" | .status = \"active\" | .implementation_base_revision = strenv(CURRENT_HEAD)" -i meta.yaml

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
source_revision: HEAD
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
  slice_refs: [SLICE-001, SLICE-002]
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

[ -f "$TMP_WORKSPACE/test-project/versions/smoke-v2.8/meta.yaml" ] || die "promote-version did not archive baseline version"
promoted_version=$(yq eval '.promoted_version' "$TMP_WORKSPACE/test-project/versions/smoke-v2.8/meta.yaml")
[ "$promoted_version" = "smoke-v2.8" ] || die "promoted_version metadata missing from archived meta"
promoted_at=$(yq eval '.promoted_at' "$TMP_WORKSPACE/test-project/versions/smoke-v2.8/meta.yaml")
[ "$promoted_at" != "null" ] || die "promoted_at metadata missing from archived meta"

list_versions_output=$("$TMP_WORKSPACE/.codespec/codespec" list-versions)
assert_contains "$list_versions_output" "Promoted Version"
assert_contains "$list_versions_output" "Promoted At"
assert_contains "$list_versions_output" "smoke-v2.8"
log "ok list-versions text output includes promoted metadata"

list_versions_json=$("$TMP_WORKSPACE/.codespec/codespec" list-versions --json)
assert_json_eq "$list_versions_json" 'map(select(.version == "smoke-v2.8"))[0].promoted_version' '"smoke-v2.8"'
assert_json_eq "$list_versions_json" 'map(select(.version == "smoke-v2.8"))[0].promoted_at | length > 0' 'true'
log "ok list-versions JSON output includes promoted metadata"

git add meta.yaml versions/smoke-v2.8
git commit --no-verify -m "chore: complete promoted baseline fixture" >/dev/null
"$TMP_WORKSPACE/.codespec/codespec" reset-to-requirement

reset_phase=$(yq eval '.phase' meta.yaml)
[ "$reset_phase" = "Requirement" ] || die "reset-to-requirement did not return to Requirement phase"
reset_status=$(yq eval '.status' meta.yaml)
[ "$reset_status" = "active" ] || die "reset-to-requirement did not reactivate dossier"
reset_base_version=$(yq eval '.base_version' meta.yaml)
[ "$reset_base_version" = "smoke-v2.8" ] || die "reset-to-requirement did not carry promoted version into base_version"
reset_change_id=$(yq eval '.change_id' meta.yaml)
[ "$reset_change_id" = "smoke-v2.8-next" ] || die "reset-to-requirement did not derive next change_id from promoted version"
log "ok reset-to-requirement resolves promoted baseline version"

# Legacy compatibility: same-name archive should still reset through the direct path.
mkdir -p "$TMP_WORKSPACE/test-project/versions/release-1"
cp "$TMP_WORKSPACE/test-project/versions/smoke-v2.8/meta.yaml" "$TMP_WORKSPACE/test-project/versions/release-1/meta.yaml"
yq eval '.change_id = "release-1" | .promoted_version = "release-1"' -i "$TMP_WORKSPACE/test-project/versions/release-1/meta.yaml"
yq eval '.change_id = "release-1" | .base_version = null | .phase = "Deployment" | .status = "completed" | .stable_version = "release-1"' -i meta.yaml

"$TMP_WORKSPACE/.codespec/codespec" reset-to-requirement --force

legacy_base_version=$(yq eval '.base_version' meta.yaml)
[ "$legacy_base_version" = "release-1" ] || die "reset-to-requirement should preserve direct same-name archive compatibility"
legacy_change_id=$(yq eval '.change_id' meta.yaml)
[ "$legacy_change_id" = "release-1-next" ] || die "legacy same-name archive should derive release-1-next change_id"
log "ok reset-to-requirement preserves same-name archive compatibility"

expect_fail_cmd \
  "current completed dossier has not been promoted yet" \
  "cd '$TMP_WORKSPACE/test-project' && yq eval '.change_id = \"unpromoted\" | .base_version = null | .phase = \"Deployment\" | .status = \"completed\"' -i meta.yaml && '$TMP_WORKSPACE/.codespec/codespec' reset-to-requirement --force"

# Test 16: submit-pr
log "\n=== Test 16: submit-pr ==="

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
git remote add origin "$TMP_WORKSPACE/test-remote.git" 2>/dev/null || true
git push --no-verify -u origin "$current_branch" >/dev/null
git -C "$TMP_WORKSPACE/test-remote.git" symbolic-ref HEAD "refs/heads/$current_branch"
git fetch origin >/dev/null
git remote set-head origin -a >/dev/null

# Commit authority files on master before branching so pre-push won't reject them
cat > spec.md <<'EOF'
# spec.md

## 0. AI 阅读契约
- authority

## 1. 需求概览
- change_goal: submit-pr smoke test
- success_standard: lifecycle passes
- primary_users:
  - smoke-test
- in_scope:
  - submit-pr flow
- out_of_scope:
  - none

## 2. 决策与来源
- source_refs:
  - docs/test.md#intent
- source_owner: smoke-test
- rigor_profile: standard
- normalization_note: normalized
- approval_basis: test-approval

### 已确认决策
- decision_id: DEC-001
  source_refs:
    - docs/test.md#intent
  decision: smoke test submit-pr
  rationale: coverage

### 待澄清事项
- clarification_id: CLAR-001
  question: none
  impact_if_unresolved: none

## 3. 场景、流程与运行叙事
submit-pr flow test.

## 4. 需求与验收
- req_id: REQ-001
  summary: submit-pr smoke
  source_ref: docs/test.md#intent
  rationale: coverage
  priority: P0

- acc_id: ACC-001
  requirement_ref: REQ-001
  expected_outcome: gates pass
  priority: P0
  priority_rationale: P0
  status: approved

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - gates pass
  artifact_expectation: smoke output

## 5. 运行约束
- environment_constraints:
  - git, yq, bash
- security_constraints:
  - none
- reliability_constraints:
  - none
- performance_constraints:
  - none
- compatibility_constraints:
  - none

## 6. 业务契约
- terminology:
  - term: submit-pr
    definition: create PR for completed change
- invariants:
  - none
- prohibitions:
  - none

## 7. 设计交接
- design_must_address:
  - submit-pr flow
- narrative_handoff:
  - submit-pr flow
- suggested_slices:
  - none
- reopen_triggers:
  - none
EOF

cat > design.md <<'EOF'
# design.md

## 0. AI 阅读契约

- authority

<!-- CODESPEC:DESIGN:OVERVIEW -->
## 1. 设计概览

- solution_summary: minimal bash fixture for submit-pr smoke test
- minimum_viable_design: create a traceable text implementation and testing ledger
- non_goals:
  - production deployment

<!-- CODESPEC:DESIGN:TRACE -->
## 2. 需求追溯

- requirement_ref: REQ-001
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  design_response: submit-pr smoke test fixture

<!-- CODESPEC:DESIGN:DECISIONS -->
## 3. 架构决策

- decision_id: ADR-001
  requirement_refs: [REQ-001]
  decision: use bash fixture and file evidence
  alternatives_considered:
    - none
  rationale: smoke only validates framework behavior
  consequences:
    - evidence in git commits and testing.md

### 技术栈选择

- runtime: bash smoke fixture
- storage: none
- external_dependencies:
  - none
- tooling:
  - git
  - yq
  - bash

<!-- CODESPEC:DESIGN:STRUCTURE -->
## 4. 系统结构

- system_context: codespec lifecycle command fixture
- data_flow:
  - spec.md -> design.md -> testing.md
- external_interactions:
  - name: none
    direction: outbound
    protocol: none
    failure_handling: no external failure path

<!-- CODESPEC:SCOPE_ALLOWED -->
### 可修改路径

- `src/**` — smoke implementation artifacts
- `meta.yaml` — lifecycle metadata
- `testing.md` — test evidence ledger
- `contracts/**` — contract files when authorized
<!-- CODESPEC:SCOPE_ALLOWED_END -->

<!-- CODESPEC:SCOPE_FORBIDDEN -->
### 不可修改路径

- `versions/**` — archived snapshots
- `spec.md` — requirement authority
- `design.md` — design authority (unless in authority repair)
- `deployment.md` — deployment authority
<!-- CODESPEC:SCOPE_FORBIDDEN_END -->

<!-- CODESPEC:DESIGN:CONTRACTS -->
## 5. 外部契约依赖

- contract_ref: none
  interaction: none
  boundary_check: none

<!-- CODESPEC:DESIGN:SLICES -->
## 7. 实现计划与验证

- slice_id: SLICE-001
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  description: submit-pr smoke test
  files:
    - src/test.txt
  test_plan: verify submit-pr completes change and archives version

- slice_id: SLICE-002
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  description: secondary slice
  files:
    - src/test.txt
  test_plan: secondary coverage
<!-- CODESPEC:DESIGN:SLICES_END -->
EOF

cat > testing.md <<'EOF'
# testing.md

## 1. 验收覆盖与测试用例

- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  test_type: integration
  verification_mode: automated
  required_stage: testing
  required_completion_level: integrated_runtime
  scenario: submit-pr lifecycle
  given: deployment dossier is complete
  when: submit-pr runs
  then: change is archived and PR created
  evidence_expectation: smoke output
  automation_exception_reason: none
  manual_steps:
    - none
  status: planned

## 2. 测试执行记录

- run_id: RUN-016
  test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  slice_ref: SLICE-001
  test_type: integration
  test_scope: full-integration
  verification_type: automated
  completion_level: integrated_runtime
  command_or_steps: bash scripts/smoke.sh
  artifact_ref: src/test.txt
  result: pass
  tested_at: 2026-04-16
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false

## 4. 主动未完成清单与语义验收

- handoff_id: HANDOFF-016
  phase: Deployment
  slice_refs: [SLICE-001, SLICE-002]
  highest_completion_level: owner_verified
  evidence_refs:
    - deployment.md#Execution-Evidence
    - deployment.md#Acceptance-Conclusion
  unfinished_items: none
  fixture_or_fallback_paths: none
  wording_guard: "Deployment runtime and manual acceptance are recorded for submit-pr flow"
EOF

git add spec.md design.md testing.md
git commit --no-verify -m "docs: prepare authority files for submit-pr" >/dev/null
git push --no-verify origin "$current_branch" >/dev/null
git fetch origin >/dev/null

git checkout -b feature/submit-pr >/dev/null

# Prepare deployment-ready dossier for submit-pr
cat > deployment.md <<'DEPLOYESCAPE'
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
source_revision: __SUBMIT_PR_HEAD__
status: pass
execution_ref: smoke-run-submit-pr
deployment_method: automated
deployed_at: 2026-04-16T10:00:00Z
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
DEPLOYESCAPE

CURRENT_HEAD="$(git rev-parse HEAD)"
CURRENT_HEAD="$CURRENT_HEAD" yq eval ".change_id = \"submit-pr-change\" | .base_version = \"smoke-v2.8\" | .phase = \"Deployment\" | .status = \"active\" | .stable_version = null | .implementation_base_revision = strenv(CURRENT_HEAD)" -i meta.yaml
sed -i "s/__SUBMIT_PR_HEAD__/$CURRENT_HEAD/" deployment.md

git add -A
git commit --no-verify -m "docs: prepare submit-pr flow" >/dev/null

mkdir -p src
echo "undeployed source drift" > src/undeployed-after-deploy.txt
git add src/undeployed-after-deploy.txt
git commit --no-verify -m "test: undeployed source drift" >/dev/null
expect_fail_cmd \
  "submit-pr includes source changes after deployed source_revision" \
  "cd '$TMP_WORKSPACE/test-project' && PATH='$TMP_WORKSPACE/bin:$PATH' TMP_GH_LOG='$TMP_WORKSPACE/gh.log' '$TMP_WORKSPACE/.codespec/codespec' submit-pr smoke-v3"
git reset --hard HEAD^ >/dev/null
log "ok submit-pr rejects source changes made after deployment evidence"

echo "# dirty" >> deployment.md
expect_fail_cmd \
  "submit-pr requires a clean git working tree" \
  "cd '$TMP_WORKSPACE/test-project' && PATH='$TMP_WORKSPACE/bin:$PATH' TMP_GH_LOG='$TMP_WORKSPACE/gh.log' '$TMP_WORKSPACE/.codespec/codespec' submit-pr smoke-v3"
git reset --hard HEAD >/dev/null

rm -f "$TMP_WORKSPACE/gh.log"
submit_output="$(PATH="$TMP_WORKSPACE/bin:$PATH" TMP_GH_LOG="$TMP_WORKSPACE/gh.log" "$TMP_WORKSPACE/.codespec/codespec" submit-pr smoke-v3)"
assert_contains "$submit_output" "https://example.test/pr/123"
[ -f "$TMP_WORKSPACE/test-project/versions/smoke-v3/meta.yaml" ] || die "submit-pr did not archive the submitted version"
assert_eq "$(yq eval '.status' meta.yaml)" "completed"
assert_eq "$(yq eval '.stable_version' meta.yaml)" "smoke-v3"
assert_eq "$(git log -1 --pretty=%s)" "chore: complete change smoke-v3"
assert_contains "$(<"$TMP_WORKSPACE/gh.log")" "pr create --base $current_branch --head feature/submit-pr"
log "ok submit-pr completes change, pushes branch, and creates PR"

submit_retry_output="$(PATH="$TMP_WORKSPACE/bin:$PATH" TMP_GH_LOG="$TMP_WORKSPACE/gh.log" "$TMP_WORKSPACE/.codespec/codespec" submit-pr smoke-v3)"
assert_contains "$submit_retry_output" "https://example.test/pr/123"
gh_pr_calls="$(grep -c '^pr create' "$TMP_WORKSPACE/gh.log")"
assert_eq "$gh_pr_calls" "2"
log "ok submit-pr can retry PR creation from a completed dossier"

rm -f "$TMP_WORKSPACE/body-path.log"
set +e
output=$(PATH="$TMP_WORKSPACE/bin:$PATH" TMP_GH_LOG="$TMP_WORKSPACE/gh.log" TMP_GH_FAIL_PR_CREATE=1 TMP_GH_BODY_PATH_FILE="$TMP_WORKSPACE/body-path.log" "$TMP_WORKSPACE/.codespec/codespec" submit-pr smoke-v3 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "submit-pr should fail when gh pr create fails"
assert_contains "$output" "forced pr create failure"
body_file="$(<"$TMP_WORKSPACE/body-path.log")"
[ ! -e "$body_file" ] || die "submit-pr leaked PR body temp file after gh failure: $body_file"
log "ok submit-pr cleans PR body temp file when gh pr create fails"

# submit-pr rejects default branch
git reset --hard HEAD >/dev/null
git checkout "$current_branch" >/dev/null
yq eval '.phase = "Deployment" | .status = "completed" | .stable_version = "smoke-v3"' -i meta.yaml
expect_fail_cmd \
  "submit-pr must not run on the default branch" \
  "cd '$TMP_WORKSPACE/test-project' && PATH='$TMP_WORKSPACE/bin:$PATH' TMP_GH_LOG='$TMP_WORKSPACE/gh.log' '$TMP_WORKSPACE/.codespec/codespec' submit-pr smoke-v3"
log "ok submit-pr rejects default branch execution"

# Test 17: hardening regressions
log "\n=== Test 17: hardening regressions ==="

cd "$TMP_WORKSPACE"
git init hardening-project >/dev/null
cd hardening-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null

expect_fail_cmd \
  "Invalid stable version" \
  "cd '$TMP_WORKSPACE/hardening-project' && yq eval '.phase = \"Deployment\" | .status = \"completed\"' -i meta.yaml && cp '$TMP_WORKSPACE/.codespec/templates/deployment.md' deployment.md && '$TMP_WORKSPACE/.codespec/codespec' scaffold-project-docs ../escaped"
rm -f deployment.md
yq eval '.phase = "Requirement" | .status = "active" | .stable_version = null | .implementation_base_revision = null' -i meta.yaml
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
log "ok spec-quality does not treat Verification as runtime constraints"

mkdir -p spec-appendices
cat > spec-appendices/smoke-appendix.md <<'EOF'
# Smoke Appendix

Appendix content without formal IDs.
EOF
expect_fail_cmd \
  "spec.md AI reading contract must define appendix reading matrix" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate spec-quality"
rm -rf spec-appendices
log "ok spec-quality requires an appendix reading matrix when spec appendices exist"

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

# design.md with slice-based §7 (no WI)
cat > design.md <<'EOF'
# design.md

## 0. AI 阅读契约
- authority

## 1. 设计概览
- solution_summary: hardening fixture
- minimum_viable_design: minimal
- non_goals:
  - production

## 2. 需求追溯
- trace_note: this design is not for REQ-001

## 3. 架构决策
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

## 4. 系统结构
- system_context: hardening fixture
- data_flow: none
- external_interactions:
  - name: none
    failure_handling: none

<!-- CODESPEC:SCOPE_ALLOWED -->
### 可修改路径

- `src/**` — hardening fixture
<!-- CODESPEC:SCOPE_ALLOWED_END -->

<!-- CODESPEC:SCOPE_FORBIDDEN -->
### 不可修改路径

- `versions/**` — archived
- `spec.md` — requirement authority
<!-- CODESPEC:SCOPE_FORBIDDEN_END -->

## 5. 契约设计
- api_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture
- data_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture data
- compatibility_policy:
  - none

## 6. 横切设计
- security_design:
  - no sensitive data
- environment_config:
  - none
- reliability_design:
  - fail fast
- observability_design:
  - none
- performance_design:
  - none

<!-- CODESPEC:DESIGN:SLICES -->
## 7. 实现计划与验证

### 实现计划

- slice_id: SLICE-001
  goal: hardening design fixture
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]

### 验证设计

- test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  approach: fixture
  evidence: fixture
  required_stage: testing

### 重开触发器

- none
<!-- CODESPEC:DESIGN:SLICES_END -->

## 8. 实现阶段输入

### Runbook（场景如何跑）

- runbook: fixture runbook

### Contract（接口与数据结构）

- contract_summary: fixture contract

### View（各方看到什么）

- view_summary: fixture view

### Verification（验证证据）

- verification_summary: fixture verification
EOF

expect_fail_cmd \
  "design.md does not reference requirement REQ-001" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate design-quality"
log "ok design-quality requires structured Requirements Trace references"

perl -0pi -e 's/## 6\. 横切设计/## 6. Cross-Cutting Design/' design.md
expect_fail_cmd \
  "design.md does not reference requirement REQ-001" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate design-quality"

# Fix the trace to properly reference REQ-001
perl -0pi -e 's/- trace_note: this design is not for REQ-001/- requirement_ref: REQ-001\n  acceptance_refs: [ACC-001]\n  verification_refs: [VO-001]\n  test_case_refs: [TC-ACC-001-01]\n  design_response: fixture satisfies requirement/' design.md
perl -0pi -e 's/## 6\. Cross-Cutting Design/## 6. 横切设计/' design.md

mkdir -p design-appendices
cat > design-appendices/smoke-appendix.md <<'EOF'
# Smoke Design Appendix

Appendix content without formal IDs.
EOF
expect_fail_cmd \
  "design.md AI reading contract must define appendix reading matrix" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate design-quality"
rm -rf design-appendices
log "ok design-quality requires an appendix reading matrix when design appendices exist"

design_quality_output="$("$TMP_WORKSPACE/.codespec/codespec" check-gate design-quality 2>&1)"
[[ "$design_quality_output" != *"awk: warning"* ]] || die "design-quality output should not contain awk warnings"
log "ok design-quality passes with slice-based §7"

# Test: removed command stubs output friendly errors
expect_fail_cmd \
  "add-work-item has been removed" \
  "cd '$TMP_WORKSPACE/hardening-project' && '$TMP_WORKSPACE/.codespec/codespec' add-work-item WI-001"
log "ok removed add-work-item stub in hardening project"

cp "$TMP_WORKSPACE/.codespec/templates/design.md" design.md

cd "$TMP_WORKSPACE"
# pre-push phase-capability drift check (no WI context)
git init push-project >/dev/null
cd push-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
mkdir -p src
git add .
git commit --no-verify -m "docs: initialize push fixture" >/dev/null
PUSH_BASE="$(git rev-parse HEAD)"
PUSH_BASE="$PUSH_BASE" yq eval '.phase = "Testing" | .status = "active" | .implementation_base_revision = strenv(PUSH_BASE)' -i meta.yaml
git add meta.yaml
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
log "ok pre-push checks committed phase-capability drift"

cd "$TMP_WORKSPACE"
git init push-snapshot-project >/dev/null
cd push-snapshot-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null
git add .
git commit --no-verify -m "docs: initialize push snapshot fixture" >/dev/null
printf '\n- snapshot push fixture\n' >> spec.md
git add spec.md
git commit --no-verify -m "docs: update pushed requirement snapshot" >/dev/null
printf 'live dirty file outside pushed commit\n' > dirty-live.txt
PUSH_LOCAL="$(git rev-parse HEAD)"
PUSH_REMOTE="$(git rev-parse HEAD^)"
set +e
output="$(printf 'refs/heads/feature %s refs/heads/feature %s\n' "$PUSH_LOCAL" "$PUSH_REMOTE" | .git/hooks/pre-push 2>&1)"
status=$?
set -e
[ "$status" -eq 0 ] || die "pre-push should validate pushed snapshot without live dirty worktree: $output"
assert_contains "$output" "pre-push checks passed"
log "ok pre-push validates pushed snapshot instead of live dirty worktree"

cd "$TMP_WORKSPACE/hardening-project"

mkdir -p reviews
hardening_review_revision="$(git rev-parse HEAD)"
cat > reviews/design-review.yaml <<EOF
phase: Requirement
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
scope:
  - spec.md
  - testing.md
gate_evidence:
  - gate: requirement-complete
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate requirement-complete
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $hardening_review_revision
    output_summary: passed
  - gate: spec-quality
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate spec-quality
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $hardening_review_revision
    output_summary: passed
  - gate: test-plan-complete
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate test-plan-complete
    result: pass
    checked_at: 2026-04-16T00:00:00Z
    checked_revision: $hardening_review_revision
    output_summary: passed
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
log "ok pre-commit validates staged dossier content, not unstaged working tree content"

# Test 18: design.md §4/§7 gate validations
log "\n=== Test 18: design.md §4/§7 gate validations ==="

# Test: §4 empty SCOPE_ALLOWED -> implementation-ready rejects
cd "$TMP_WORKSPACE"
git init scope-empty-project >/dev/null
cd scope-empty-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null

cat > design.md <<'EOF'
# design.md

## 0. AI 阅读契约
- authority

## 1. 设计概览
- solution_summary: fixture
- minimum_viable_design: fixture
- non_goals:
  - none

## 2. 需求追溯
- requirement_ref: REQ-001
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  design_response: fixture

## 3. 架构决策
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

## 4. 系统结构
- system_context: fixture
- data_flow: none
- external_interactions:
  - name: none
    failure_handling: none

<!-- CODESPEC:SCOPE_ALLOWED -->
### 可修改路径

<!-- CODESPEC:SCOPE_ALLOWED_END -->

<!-- CODESPEC:SCOPE_FORBIDDEN -->
### 不可修改路径

- `versions/**` — archived
<!-- CODESPEC:SCOPE_FORBIDDEN_END -->

## 5. 契约设计
- api_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture
- data_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture
- compatibility_policy:
  - none

## 6. 横切设计
- security_design:
  - none
- environment_config:
  - none
- reliability_design:
  - none
- observability_design:
  - none
- performance_design:
  - none

<!-- CODESPEC:DESIGN:SLICES -->
## 7. 实现计划与验证

### 实现计划

- slice_id: SLICE-001
  goal: fixture
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]

### 验证设计

- test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  approach: fixture
  evidence: fixture
  required_stage: testing

### 重开触发器

- none
<!-- CODESPEC:DESIGN:SLICES_END -->

## 8. 实现阶段输入

### Runbook（场景如何跑）

- runbook: fixture

### Contract（接口与数据结构）

- contract_summary: fixture

### View（各方看到什么）

- view_summary: fixture

### Verification（验证证据）

- verification_summary: fixture
EOF

git add .
git commit -m "docs: scope-empty fixture" >/dev/null

expect_fail_cmd \
  "SCOPE_ALLOWED section has no glob entries" \
  "cd '$TMP_WORKSPACE/scope-empty-project' && CODESPEC_TARGET_PHASE=Implementation '$TMP_WORKSPACE/.codespec/codespec' check-gate implementation-ready"
log "ok implementation-ready rejects empty §4 SCOPE_ALLOWED"

# Test: §7 duplicate slice_id -> implementation-ready rejects
cd "$TMP_WORKSPACE"
git init duplicate-slice-project >/dev/null
cd duplicate-slice-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null

cat > design.md <<'EOF'
# design.md

## 0. AI 阅读契约
- authority

## 1. 设计概览
- solution_summary: fixture
- minimum_viable_design: fixture
- non_goals:
  - none

## 2. 需求追溯
- requirement_ref: REQ-001
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  design_response: fixture

## 3. 架构决策
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

## 4. 系统结构
- system_context: fixture
- data_flow: none
- external_interactions:
  - name: none
    failure_handling: none

<!-- CODESPEC:SCOPE_ALLOWED -->
### 可修改路径

- `src/**` — fixture
<!-- CODESPEC:SCOPE_ALLOWED_END -->

<!-- CODESPEC:SCOPE_FORBIDDEN -->
### 不可修改路径

- `versions/**` — archived
<!-- CODESPEC:SCOPE_FORBIDDEN_END -->

## 5. 契约设计
- api_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture
- data_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture
- compatibility_policy:
  - none

## 6. 横切设计
- security_design:
  - none
- environment_config:
  - none
- reliability_design:
  - none
- observability_design:
  - none
- performance_design:
  - none

<!-- CODESPEC:DESIGN:SLICES -->
## 7. 实现计划与验证

### 实现计划

- slice_id: SLICE-001
  goal: first slice
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]

- slice_id: SLICE-001
  goal: duplicate slice
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]

### 验证设计

- test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  approach: fixture
  evidence: fixture
  required_stage: testing

### 重开触发器

- none
<!-- CODESPEC:DESIGN:SLICES_END -->

## 8. 实现阶段输入

### Runbook（场景如何跑）

- runbook: fixture

### Contract（接口与数据结构）

- contract_summary: fixture

### View（各方看到什么）

- view_summary: fixture

### Verification（验证证据）

- verification_summary: fixture
EOF

git add .
git commit -m "docs: duplicate slice fixture" >/dev/null

expect_fail_cmd \
  "duplicate slice_id entries" \
  "cd '$TMP_WORKSPACE/duplicate-slice-project' && CODESPEC_TARGET_PHASE=Implementation '$TMP_WORKSPACE/.codespec/codespec' check-gate implementation-ready"
log "ok implementation-ready rejects duplicate slice_id in §7"

# Test: §7 missing verification_refs -> implementation-ready rejects
cd "$TMP_WORKSPACE"
git init missing-vo-slice-project >/dev/null
cd missing-vo-slice-project
git config user.name "Smoke Test"
git config user.email "smoke@test.local"
"$TMP_WORKSPACE/.codespec/scripts/init-dossier.sh" >/dev/null

cat > design.md <<'EOF'
# design.md

## 0. AI 阅读契约
- authority

## 1. 设计概览
- solution_summary: fixture
- minimum_viable_design: fixture
- non_goals:
  - none

## 2. 需求追溯
- requirement_ref: REQ-001
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  design_response: fixture

## 3. 架构决策
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

## 4. 系统结构
- system_context: fixture
- data_flow: none
- external_interactions:
  - name: none
    failure_handling: none

<!-- CODESPEC:SCOPE_ALLOWED -->
### 可修改路径

- `src/**` — fixture
<!-- CODESPEC:SCOPE_ALLOWED_END -->

<!-- CODESPEC:SCOPE_FORBIDDEN -->
### 不可修改路径

- `versions/**` — archived
<!-- CODESPEC:SCOPE_FORBIDDEN_END -->

## 5. 契约设计
- api_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture
- data_contracts:
  - contract_ref: none
    requirement_refs: [REQ-001]
    summary: fixture
- compatibility_policy:
  - none

## 6. 横切设计
- security_design:
  - none
- environment_config:
  - none
- reliability_design:
  - none
- observability_design:
  - none
- performance_design:
  - none

<!-- CODESPEC:DESIGN:SLICES -->
## 7. 实现计划与验证

### 实现计划

- slice_id: SLICE-001
  goal: missing VO slice
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  test_case_refs: [TC-ACC-001-01]

### 验证设计

- test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  approach: fixture
  evidence: fixture
  required_stage: testing

### 重开触发器

- none
<!-- CODESPEC:DESIGN:SLICES_END -->

## 8. 实现阶段输入

### Runbook（场景如何跑）

- runbook: fixture

### Contract（接口与数据结构）

- contract_summary: fixture

### View（各方看到什么）

- view_summary: fixture

### Verification（验证证据）

- verification_summary: fixture
EOF

git add .
git commit -m "docs: missing vo slice fixture" >/dev/null

expect_fail_cmd \
  "missing verification_refs" \
  "cd '$TMP_WORKSPACE/missing-vo-slice-project' && CODESPEC_TARGET_PHASE=Implementation '$TMP_WORKSPACE/.codespec/codespec' check-gate implementation-ready"
log "ok implementation-ready rejects slice missing verification_refs"

log "\n=== All tests passed ==="
