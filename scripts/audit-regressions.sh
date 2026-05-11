#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$(mktemp -d /tmp/codespec-audit-XXXXXX)"
WORKSPACE="$TMP_ROOT/workspace"
CODESPEC="$WORKSPACE/.codespec/codespec"
INIT_DOSSIER="$WORKSPACE/.codespec/scripts/init-dossier.sh"
FAILURES=0

cleanup() {
  if [ "${CODESPEC_AUDIT_KEEP_TMP:-}" = '1' ]; then
    printf 'keeping audit temp dir: %s\n' "$TMP_ROOT" >&2
    return
  fi
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '%s\n' "$*"
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

run_case() {
  local name="$1"
  shift
  log "=== $name ==="
  if "$@"; then
    log "ok $name"
  else
    log "FAIL $name" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) return 0 ;;
    *) printf 'expected output to contain: %s\nactual output:\n%s\n' "$needle" "$haystack" >&2; return 1 ;;
  esac
}

assert_json_eq() {
  local json="$1"
  local expr="$2"
  local expected="$3"
  local actual
  actual="$(printf '%s\n' "$json" | yq eval -o=json "$expr" -)"
  [ "$actual" = "$expected" ] || {
    printf 'expected %s == %s, got %s\n' "$expr" "$expected" "$actual" >&2
    return 1
  }
}

bootstrap_workspace() {
  mkdir -p "$WORKSPACE"
  "$FRAMEWORK_ROOT/scripts/install-workspace.sh" "$WORKSPACE" >/dev/null
}

write_requirement_docs() {
  local project="$1"
  local second_source="${2:-docs/source.md#intent}"
  local verification_mode="${3:-automated}"

  mkdir -p "$project/docs"
  printf 'source intent\n' > "$project/docs/source.md"
  printf 'other intent\n' > "$project/docs/other.md"
  printf 'decision evidence\n' > "$project/docs/decision.md"

  cat > "$project/spec.md" <<EOF
# spec.md

## 0. AI 阅读契约

- 本文件是需求阶段的权威文档；进入设计阶段时，不得默认依赖原始材料才能理解需求。

| 附件类型 | 读取触发 | 权威边界 | 冲突处理 |
|---|---|---|---|
| spec-appendices/*.md | 命中细节时读取 | 只展开正文需求 | 冲突时回写 spec.md |

## 1. 需求概览

- change_goal: deliver the audited capability
- success_standard: both accepted outcomes are observable
- primary_users:
  - reviewer
- in_scope:
  - audited flow
- out_of_scope:
  - unrelated flow

## 2. 决策与来源

- source_refs:
  - docs/source.md#intent
- source_owner: owner
- rigor_profile: standard
- normalization_note: normalized into stable requirements
- approval_basis: owner approved current wording

### 已确认决策

- decision_id: DEC-001
  source_refs:
    - docs/source.md#intent
  decision: use the approved path
  rationale: keeps scope narrow

### 待澄清事项

- clarification_id: CLAR-001
  question: none
  impact_if_unresolved: none

## 3. 场景、流程与运行叙事

### 核心流程叙事

The user starts the audited command from the project root.
The system loads the stable source list from the requirements document.
The system validates every formal requirement against that declared source list.
If validation passes, the transition records reviewable gate evidence.
If validation fails, the command stops before mutating authority files and reports the exact missing evidence.

### 正向形态最低覆盖

- [x] 系统在正常使用中如何启动
- [x] 核心流程如何推进
- [x] 各参与方看到什么
- [x] 流程在哪里结束
- [x] 失败/降级路径如何处理
- [x] 关键业务术语在业务契约章节中有唯一定义

### 场景索引

- scenario_id: SCN-001
  actor: reviewer
  trigger: audited command runs
  behavior: system validates source and records evidence
  expected_outcome: reviewer sees pass or exact failure
  requirement_refs: [REQ-001, REQ-002]

## 4. 需求与验收

### 需求

- req_id: REQ-001
  summary: The system validates declared source evidence.
  source_ref: docs/source.md#intent
  rationale: Reviewers need stable traceability.
  priority: P0

- req_id: REQ-002
  summary: The system rejects source drift outside declared source_refs.
  source_ref: $second_source
  rationale: Hidden source authority creates review ambiguity.
  priority: P1

### 验收

- acc_id: ACC-001
  requirement_ref: REQ-001
  expected_outcome: Declared source evidence is accepted.
  priority: P0
  priority_rationale: This protects the main transition.
  status: approved

- acc_id: ACC-002
  requirement_ref: REQ-002
  expected_outcome: Undeclared source evidence is rejected.
  priority: P1
  priority_rationale: This prevents hidden authority drift.
  status: approved

### 验证义务

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: $verification_mode
  verification_profile: focused
  obligations:
    - Validate declared source evidence.
  artifact_expectation: command output

- vo_id: VO-002
  acceptance_ref: ACC-002
  verification_type: automated
  verification_profile: focused
  obligations:
    - Reject undeclared source evidence.
  artifact_expectation: command output

## 5. 运行约束

- environment_constraints:
  - local shell with git
- security_constraints:
  - do not read undeclared authority
- reliability_constraints:
  - stop before mutation on gate failure
- performance_constraints:
  - none
- compatibility_constraints:
  - none

## 6. 业务契约

- terminology:
  - term: authority source
    definition: stable repo artifact listed in source_refs
- invariants:
  - all source_refs used by formal requirements are declared
- prohibitions:
  - hidden source authority is not allowed

## 7. 设计交接

- design_must_address:
  - gate evidence generation
- narrative_handoff:
  - command flow and failure handling
- suggested_slices:
  - source validation
- reopen_triggers:
  - source authority changes
EOF

  cat > "$project/testing.md" <<EOF
# testing.md

## 0. AI 阅读契约

- 本文件记录测试用例和执行证据。

## 0.1 测试层级定义

- branch-local: local command evidence
- full-integration: integrated command evidence
- deployment: deployed evidence
- completion_level: fixture_contract / in_memory_domain / api_connected / db_persistent / integrated_runtime / owner_verified

## 1. 验收覆盖与测试用例

- tc_id: TC-ACC-001-01
  requirement_refs: [REQ-001]
  acceptance_ref: ACC-001
  verification_ref: VO-001
  test_type: integration
  verification_mode: $verification_mode
  required_stage: testing
  required_completion_level: integrated_runtime
  scenario: declared source validation
  given: declared source exists
  when: gate runs
  then: gate passes
  evidence_expectation: command output
  automation_exception_reason: owner manual signoff required
  manual_steps:
    - inspect command output
  status: planned

- tc_id: TC-ACC-002-01
  requirement_refs: [REQ-002]
  acceptance_ref: ACC-002
  verification_ref: VO-002
  test_type: integration
  verification_mode: automated
  required_stage: testing
  required_completion_level: integrated_runtime
  scenario: undeclared source validation
  given: undeclared source exists
  when: gate runs
  then: gate rejects it
  evidence_expectation: command output
  automation_exception_reason: none
  manual_steps:
    - none
  status: planned

## 2. 测试执行记录

## 3. 残留风险与返工判断

- residual_risk: none
- reopen_required: false
- notes:
  - none

## 4. 主动未完成清单与语义验收
EOF
}

write_design_with_contract() {
  local project="$1"
  mkdir -p "$project/contracts"
  cat > "$project/contracts/api.md" <<'EOF'
# API Contract

status: draft
owner: reviewer
EOF
  cat > "$project/design.md" <<'EOF'
# design.md

## 0. AI 阅读契约

- 本文件是 Implementation 阶段的默认权威输入。

## 1. 设计概览

- solution_summary: validate the transition through one small shell path
- minimum_viable_design: one gate helper and one evidence writer are enough
- non_goals:
  - unrelated refactor

## 2. 需求追溯

- requirement_ref: REQ-001
  acceptance_refs: [ACC-001]
  verification_refs: [VO-001]
  test_case_refs: [TC-ACC-001-01]
  design_response: run declared source validation

- requirement_ref: REQ-002
  acceptance_refs: [ACC-002]
  verification_refs: [VO-002]
  test_case_refs: [TC-ACC-002-01]
  design_response: reject undeclared source validation

## 3. 架构决策

- decision_id: ADR-001
  requirement_refs: [REQ-001, REQ-002]
  decision: keep checks in existing shell gates
  alternatives_considered:
    - new service was rejected as too broad
  rationale: local validation is enough
  consequences:
    - gate output remains shell-oriented

### 技术栈选择

- runtime: bash
- storage: files
- external_dependencies:
  - none
- tooling:
  - yq

## 4. 系统结构

- system_context: local codespec CLI
- data_flow: dossier files flow into gate checks
- external_interactions:
  - name: none
    direction: both
    protocol: none
    failure_handling: no external failure

### 可修改路径

- `src/**` - implementation files

### 不可修改路径

- `versions/**` - archive snapshots

## 5. 契约设计

- api_contracts:
  - contract_ref: contracts/api.md
    requirement_refs: [REQ-001]
    summary: gate evidence schema
- data_contracts:
  - contract_ref: none
    requirement_refs: [REQ-002]
    summary: no data contract
- compatibility_policy:
  - no migration

## 6. 横切设计

- environment_config:
  - local shell
- security_design:
  - no secret access
- reliability_design:
  - fail before mutation
- observability_design:
  - gate output
- performance_design:
  - none

## 7. 实现计划与验证

### 实现计划

- slice_id: SLICE-001
  goal: enforce source closure
  requirement_refs: [REQ-001, REQ-002]
  acceptance_refs: [ACC-001, ACC-002]
  verification_refs: [VO-001, VO-002]
  test_case_refs: [TC-ACC-001-01, TC-ACC-002-01]

### 验证设计

- test_case_ref: TC-ACC-001-01
  acceptance_ref: ACC-001
  approach: run gate
  evidence: command output
  required_stage: testing

- test_case_ref: TC-ACC-002-01
  acceptance_ref: ACC-002
  approach: run negative gate
  evidence: command output
  required_stage: testing

### 重开触发器

- source authority changes

## 8. 实现阶段输入

### Runbook（场景如何跑）

- runbook: run codespec gate command and inspect output

### Contract（接口与数据结构）

- contract_summary: contracts/api.md

### View（各方看到什么）

- view_summary: command pass or failure

### Verification（验证证据）

- verification_summary: TC-ACC-001-01 and TC-ACC-002-01 prove behavior
EOF
}

write_structured_testing_ledger() {
  local project="$1"
  cat > "$project/testing.md" <<'EOF'
# testing.md

## 0. AI 阅读契约

- 本文件记录测试用例、执行证据和语义 handoff。

<!-- CODESPEC:TESTING:LEDGER -->
```yaml
schema_version: 1
test_cases:
  TC-ACC-001-01:
    requirement_refs: [REQ-001]
    acceptance_ref: ACC-001
    verification_ref: VO-001
    test_type: integration
    verification_mode: automated
    required_stage: testing
    required_completion_level: integrated_runtime
    scenario: declared source validation
    given: declared source exists
    when: gate runs
    then: gate passes
    evidence_expectation: command output
    automation_exception_reason: none
    manual_steps: [none]
    status: planned
  TC-ACC-002-01:
    requirement_refs: [REQ-002]
    acceptance_ref: ACC-002
    verification_ref: VO-002
    test_type: integration
    verification_mode: automated
    required_stage: testing
    required_completion_level: integrated_runtime
    scenario: undeclared source validation
    given: undeclared source exists
    when: gate runs
    then: gate rejects it
    evidence_expectation: command output
    automation_exception_reason: none
    manual_steps: [none]
    status: planned
runs:
  RUN-001:
    test_case_ref: TC-ACC-001-01
    acceptance_ref: ACC-001
    slice_ref: SLICE-001
    test_type: integration
    test_scope: branch-local
    verification_type: automated
    completion_level: fixture_contract
    command_or_steps: ./run-declared-source-test
    artifact_ref: artifacts/declared-source.txt
    result: pass
    tested_at: 2026-05-10
    tested_by: audit
    residual_risk: none
    reopen_required: false
  RUN-002:
    test_case_ref: TC-ACC-002-01
    acceptance_ref: ACC-002
    slice_ref: SLICE-001
    test_type: integration
    test_scope: branch-local
    verification_type: automated
    completion_level: fixture_contract
    command_or_steps: ./run-undeclared-source-test
    artifact_ref: artifacts/undeclared-source.txt
    result: pass
    tested_at: 2026-05-10
    tested_by: audit
    residual_risk: none
    reopen_required: false
handoffs:
  HANDOFF-001:
    phase: Implementation
    slice_refs: [SLICE-001]
    highest_completion_level: fixture_contract
    evidence_refs:
      - testing.md#RUN-001
      - testing.md#RUN-002
    unfinished_items:
      - source_ref: testing.md#TC-ACC-001-01
        priority: P0
        current_completion_level: fixture_contract
        target_completion_level: integrated_runtime
        blocker: only branch-local evidence exists
        next_step: run full integration evidence
    fixture_or_fallback_paths:
      - surface: audit structured ledger fixture
        completion_level: fixture_contract
        real_api_verified: false
        visible_failure_state: false
        trace_retry_verified: false
    wording_guard: "Only branch-local fixture evidence is available."
```
<!-- CODESPEC:TESTING:LEDGER_END -->
EOF
}

new_project() {
  local name="$1"
  local project="$WORKSPACE/$name"
  mkdir -p "$project"
  git -C "$project" init -q
  git -C "$project" config user.email codespec@example.invalid
  git -C "$project" config user.name codespec
  (cd "$project" && "$INIT_DOSSIER" >/dev/null)
  printf '%s\n' "$project"
}

commit_project() {
  local project="$1"
  git -C "$project" add .
  git -C "$project" commit --no-verify -m baseline >/dev/null
}

test_spec_rejects_undeclared_source_refs() {
  local project output status
  project="$(new_project source-closure)"
  write_requirement_docs "$project" 'docs/other.md#intent' automated
  commit_project "$project"
  set +e
  output="$(CODESPEC_PROJECT_ROOT="$project" "$CODESPEC" check-gate spec-quality 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || {
    printf 'spec-quality accepted an undeclared REQ source_ref\n' >&2
    return 1
  }
  assert_contains "$output" 'source_ref'
}

test_readset_includes_design_contract_refs() {
  local project json
  project="$(new_project readset-contract)"
  write_requirement_docs "$project" 'docs/source.md#intent' automated
  write_design_with_contract "$project"
  yq eval '.phase = "Implementation"' -i "$project/meta.yaml"
  json="$(CODESPEC_PROJECT_ROOT="$project" "$CODESPEC" readset --json)"
  assert_json_eq "$json" '.contract_refs | map(select(.path == "contracts/api.md")) | length' '1'
  assert_json_eq "$json" '.minimal_readset | map(select(.path == "contracts/api.md")) | length' '1'
}

test_reset_requires_clean_worktree_by_default() {
  local project output status
  project="$(new_project dirty-reset)"
  write_requirement_docs "$project" 'docs/source.md#intent' automated
  yq eval '.phase = "Deployment" | .status = "completed" | .change_id = "release-change" | .stable_version = "stable-v1"' -i "$project/meta.yaml"
  mkdir -p "$WORKSPACE/versions/stable-v1"
  cp "$project/meta.yaml" "$WORKSPACE/versions/stable-v1/meta.yaml"
  yq eval '.promoted_at = "2026-05-10T00:00:00Z" | .promoted_version = "stable-v1"' -i "$WORKSPACE/versions/stable-v1/meta.yaml"
  commit_project "$project"
  printf '\nUNCOMMITTED_MARKER\n' >> "$project/spec.md"
  set +e
  output="$(CODESPEC_PROJECT_ROOT="$project" "$CODESPEC" reset-to-requirement 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || {
    printf 'reset-to-requirement overwrote dirty authority files without --force\n' >&2
    return 1
  }
  grep -q 'UNCOMMITTED_MARKER' "$project/spec.md" || {
    printf 'dirty spec.md marker was lost\n' >&2
    return 1
  }
  assert_contains "$output" '--force'
}

test_install_workspace_appends_missing_lessons_rules() {
  local other_workspace="$TMP_ROOT/partial-lessons"
  mkdir -p "$other_workspace"
  cat > "$other_workspace/lessons_learned.md" <<'EOF'
# Lessons Learned

## 硬规则

**R1**：保留已有规则。
EOF
  "$FRAMEWORK_ROOT/scripts/install-workspace.sh" "$other_workspace" >/dev/null
  grep -q '\*\*R15\*\*' "$other_workspace/lessons_learned.md" || {
    printf 'install-workspace did not append missing R15 rule\n' >&2
    return 1
  }
}

test_install_hooks_uses_target_git_hooks_dir() {
  local project outside
  project="$(new_project install-hooks-target)"
  outside="$TMP_ROOT/outside-install-hooks"
  mkdir -p "$outside"
  rm -f "$project/.git/hooks/pre-commit" "$project/.git/hooks/pre-push"

  (cd "$outside" && "$WORKSPACE/.codespec/scripts/install-hooks.sh" "$project" >/dev/null)

  cmp -s "$WORKSPACE/.codespec/hooks/pre-commit" "$project/.git/hooks/pre-commit" || {
    printf 'install-hooks did not write target pre-commit hook\n' >&2
    return 1
  }
  cmp -s "$WORKSPACE/.codespec/hooks/pre-push" "$project/.git/hooks/pre-push" || {
    printf 'install-hooks did not write target pre-push hook\n' >&2
    return 1
  }
  [ ! -e "$outside/.git/hooks/pre-commit" ] || {
    printf 'install-hooks wrote hooks relative to caller cwd\n' >&2
    return 1
  }
}

test_review_quality_rejects_unverifiable_gate_evidence() {
  local project output status
  project="$(new_project legacy-review-evidence)"
  write_requirement_docs "$project" 'docs/source.md#intent' automated
  mkdir -p "$project/reviews"
  cat > "$project/reviews/design-review.yaml" <<'EOF'
phase: Requirement
verdict: approved
reviewed_by: reviewer
reviewed_at: 2026-05-10
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
    summary: no findings
residual_risk: none
decision_notes: approved after semantic review
EOF
  commit_project "$project"
  set +e
  output="$(CODESPEC_PROJECT_ROOT="$project" CODESPEC_TARGET_PHASE=Design "$CODESPEC" check-gate review-quality 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || {
    printf 'review-quality accepted hand-written pass evidence without checked_revision\n' >&2
    return 1
  }
  assert_contains "$output" 'checked_revision'
}

test_review_quality_requires_p0_manual_exception_acceptance() {
  local project revision output status
  project="$(new_project p0-manual-review)"
  write_requirement_docs "$project" 'docs/source.md#intent' manual
  commit_project "$project"
  revision="$(git -C "$project" rev-parse HEAD)"
  mkdir -p "$project/reviews"
  cat > "$project/reviews/design-review.yaml" <<EOF
phase: Requirement
verdict: approved
reviewed_by: reviewer
reviewed_at: 2026-05-10
scope:
  - spec.md
  - testing.md
gate_evidence:
  - gate: requirement-complete
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate requirement-complete
    result: pass
    checked_at: 2026-05-10T00:00:00Z
    checked_revision: $revision
    output_summary: passed
  - gate: spec-quality
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate spec-quality
    result: pass
    checked_at: 2026-05-10T00:00:00Z
    checked_revision: $revision
    output_summary: passed
  - gate: test-plan-complete
    command: CODESPEC_TARGET_PHASE=Design codespec check-gate test-plan-complete
    result: pass
    checked_at: 2026-05-10T00:00:00Z
    checked_revision: $revision
    output_summary: passed
findings:
  - severity: none
    summary: no findings
residual_risk: none
decision_notes: approved after semantic review
EOF
  git -C "$project" add reviews/design-review.yaml
  git -C "$project" commit --no-verify -m review >/dev/null
  set +e
  output="$(CODESPEC_PROJECT_ROOT="$project" CODESPEC_TARGET_PHASE=Design "$CODESPEC" check-gate review-quality 2>&1)"
  status=$?
  set -e
  [ "$status" -ne 0 ] || {
    printf 'review-quality accepted P0 manual TC without accepted_automation_exceptions\n' >&2
    return 1
  }
  assert_contains "$output" 'accepted_automation_exceptions'
}

test_review_gates_write_records_structured_evidence() {
  local project review_file
  project="$(new_project review-gates-write)"
  write_requirement_docs "$project" 'docs/source.md#intent' automated
  commit_project "$project"
  CODESPEC_PROJECT_ROOT="$project" "$CODESPEC" review-gates Design --write >/dev/null
  review_file="$project/reviews/design-review.yaml"
  [ -f "$review_file" ] || {
    printf 'review-gates --write did not create design review\n' >&2
    return 1
  }
  assert_json_eq "$(yq eval -o=json '.' "$review_file")" '.gate_evidence | map(select(.gate == "spec-quality" and .checked_revision != null and .result == "pass")) | length' '1'
}

test_structured_testing_ledger_drives_gates() {
  local project report revision
  project="$(new_project structured-ledger)"
  write_requirement_docs "$project" 'docs/source.md#intent' automated
  write_design_with_contract "$project"
  write_structured_testing_ledger "$project"
  commit_project "$project"
  revision="$(git -C "$project" rev-parse HEAD)"
  REVISION="$revision" yq eval '.phase = "Implementation" | .implementation_base_revision = strenv(REVISION)' -i "$project/meta.yaml"
  commit_project "$project"

  CODESPEC_PROJECT_ROOT="$project" "$CODESPEC" check-gate verification >/dev/null || return 1
  CODESPEC_PROJECT_ROOT="$project" "$CODESPEC" check-gate semantic-handoff >/dev/null || return 1
  report="$(CODESPEC_PROJECT_ROOT="$project" "$CODESPEC" completion-report)"
  assert_contains "$report" 'highest_completion_level: fixture_contract'
}

test_migrate_testing_ledger_writes_structured_block() {
  local project
  project="$(new_project migrate-ledger)"
  write_requirement_docs "$project" 'docs/source.md#intent' automated
  commit_project "$project"

  CODESPEC_PROJECT_ROOT="$project" "$CODESPEC" migrate-testing-ledger --write >/dev/null || return 1
  grep -q '<!-- CODESPEC:TESTING:LEDGER -->' "$project/testing.md" || {
    printf 'migrate-testing-ledger did not write structured ledger marker\n' >&2
    return 1
  }
  grep -q '^test_cases:' "$project/testing.md" || {
    printf 'migrate-testing-ledger did not write test_cases\n' >&2
    return 1
  }
  CODESPEC_PROJECT_ROOT="$project" "$CODESPEC" check-gate test-plan-complete >/dev/null
}

main() {
  require_tool git
  require_tool yq
  require_tool python3
  bootstrap_workspace

  run_case 'spec rejects undeclared source refs' test_spec_rejects_undeclared_source_refs
  run_case 'readset includes design contract refs' test_readset_includes_design_contract_refs
  run_case 'reset-to-requirement requires clean worktree by default' test_reset_requires_clean_worktree_by_default
  run_case 'install-workspace appends missing lessons rules' test_install_workspace_appends_missing_lessons_rules
  run_case 'install-hooks uses target git hooks directory' test_install_hooks_uses_target_git_hooks_dir
  run_case 'review-quality rejects unverifiable gate evidence' test_review_quality_rejects_unverifiable_gate_evidence
  run_case 'review-quality requires P0 manual exception acceptance' test_review_quality_requires_p0_manual_exception_acceptance
  run_case 'review-gates --write records structured evidence' test_review_gates_write_records_structured_evidence
  run_case 'structured testing ledger drives gates' test_structured_testing_ledger_drives_gates
  run_case 'migrate-testing-ledger writes structured block' test_migrate_testing_ledger_writes_structured_block

  if [ "$FAILURES" -ne 0 ]; then
    printf '\n%d audit regression(s) failed\n' "$FAILURES" >&2
    exit 1
  fi
  printf '\nall audit regressions passed\n'
}

main "$@"
