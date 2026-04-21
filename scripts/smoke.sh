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
[ -d ".git/hooks" ] || die "init-dossier did not create .git/hooks"
[ -x ".git/hooks/pre-commit" ] || die "init-dossier did not install pre-commit hook"
log "✓ dossier initialized"

# Test 3: Proposal phase
log "\n=== Test 3: Proposal phase ==="
phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Proposal" ] || die "initial phase should be Proposal, got: $phase"

status=$(yq eval '.status' meta.yaml)
[ "$status" = "active" ] || die "initial status should be active, got: $status"
log "✓ initial phase is Proposal"

# Test 4: start-requirements
log "\n=== Test 4: start-requirements ==="

# Create input file
mkdir -p docs
cat > docs/test.md <<'EOF'
# Test Input

## intent
Test input for smoke test.
EOF

# Create minimal spec.md for Proposal
cat > spec.md <<'EOF'
# spec.md

## Default Read Layer

### Intent Summary
- Problem: test problem
- Goals:
  - test goal
- Non-goals:
  - test non-goal
- Must-have Anchors:
  - test anchor
- Prohibition Anchors:
  - test prohibition
- Success Anchors:
  - test success
- Boundary Alerts:
  - test boundary
- Unresolved Decisions:
  - none

### Input Intake Summary
- input_maturity: L1
- input_refs:
  - docs/test.md#intent
- input_owner: smoke-test
- approval_basis: test-approval
- normalization_status: ready-for-requirements

## Intent

### Problem
Test problem description.

### Goals
- test goal

### Non-goals
- test non-goal

## Requirements

### Proposal Coverage Map
- source_ref: docs/test.md#intent
  anchor_ref: test goal
  target_ref: REQ-001
  status: covered
- source_ref: docs/test.md#intent
  anchor_ref: test anchor
  target_ref: REQ-001
  status: covered
- source_ref: docs/test.md#intent
  anchor_ref: test prohibition
  target_ref: REQ-001
  status: covered
- source_ref: docs/test.md#intent
  anchor_ref: test success
  target_ref: REQ-001
  status: covered
- source_ref: docs/test.md#intent
  anchor_ref: test boundary
  target_ref: REQ-001
  status: covered

### Clarification Status
No clarifications needed.

### Functional Requirements
- REQ-001
  - summary: test requirement
  - rationale: for smoke test

### Requirements Detail

- req_id: REQ-001
  description: test requirement
  acceptance_refs:
    - ACC-001
  verification_refs:
    - VO-001
  priority: P0
  status: approved

## Acceptance

- acc_id: ACC-001
  source_ref: REQ-001
  requirement_refs:
    - REQ-001
  expected_outcome: test passes
  description: test acceptance
  priority: P0
  status: approved

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  acceptance_refs:
    - ACC-001
  verification_type: automated
  description: test verification

### Input Intake

#### docs/test.md#intent
Test input.

### Testing Priority Rules
- P0: automated
- P1: automated or manual
- P2: manual acceptable

<!-- SKELETON-END -->
EOF

mkdir -p reviews
cat > reviews/requirements-review.yaml <<'EOF'
phase: Proposal
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
EOF

git add .
git commit -m "feat: initial proposal"

"$TMP_WORKSPACE/.codespec/codespec" start-requirements

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Requirements" ] || die "start-requirements did not set phase to Requirements"
log "✓ start-requirements succeeded"

# Test 5: start-design
log "\n=== Test 5: start-design ==="

cat > reviews/design-review.yaml <<'EOF'
phase: Requirements
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
EOF

git add .
git commit -m "feat: complete requirements"

"$TMP_WORKSPACE/.codespec/codespec" start-design

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Design" ] || die "start-design did not set phase to Design"
[ -f "design.md" ] || die "start-design did not create design.md"
log "✓ start-design succeeded"

# Test 6: add-work-item and start-implementation
log "\n=== Test 6: add-work-item and start-implementation ==="

# Create minimal design.md
cat > design.md <<'EOF'
# design.md

## Default Read Layer

## Goal / Scope Link
- REQ-001 -> WI-001
- REQ-001 -> WI-002

## Architecture Boundary
Test architecture.

## Work Item Execution Strategy
Single branch execution.

## Design Slice Index
- WI-001: test work item
- WI-002: follow-up test work item

## Work Item Derivation
- wi_id: WI-001
  input_refs:
    - docs/test.md#intent
  requirement_refs:
    - REQ-001
  goal: implement smoke verification capability
  covered_acceptance_refs: [ACC-001]
  verification_refs:
    - VO-001
  dependency_refs: []
  contract_needed: false
  notes_on_boundary: smoke verification scope
- wi_id: WI-002
  input_refs:
    - docs/test.md#intent
  requirement_refs:
    - REQ-001
  goal: implement same-phase WI switching capability
  covered_acceptance_refs: [ACC-001]
  verification_refs:
    - VO-001
  dependency_refs: []
  contract_needed: false
  notes_on_boundary: same-phase switching scope

## Contract Needs
No contracts needed.

## Verification Design
Automated tests.

## Failure Paths / Reopen Triggers
None identified.

## Implementation Readiness Baseline

### Environment Configuration Matrix
- dev: local development environment with hot reload
- staging: pre-production environment for integration testing
- prod: production environment with monitoring and alerting

### Security Baseline
- Authentication: JWT-based authentication required for all endpoints
- Authorization: role-based access control with admin/user roles
- Data encryption: TLS 1.3 for transport, AES-256 for data at rest

### Data / Migration Strategy
- No data migration needed for smoke test
- All test data is ephemeral and generated at runtime
- No schema changes required

### Operability / Health Checks
- Basic health endpoint available at /health
- Returns 200 OK when service is running
- Includes uptime and version information

### Backup / Restore
- Not applicable for smoke test
- No persistent data to backup
- Test data is regenerated on each run

## Appendix Map
No appendices.
EOF

git add design.md
git commit -m "feat: complete design"

"$TMP_WORKSPACE/.codespec/codespec" add-work-item WI-001
"$TMP_WORKSPACE/.codespec/codespec" add-work-item WI-002

[ -f "work-items/WI-001.yaml" ] || die "add-work-item did not create WI-001.yaml"
[ -f "work-items/WI-002.yaml" ] || die "add-work-item did not create WI-002.yaml"

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
  yq eval '.input_refs = ["docs/test.md#intent"]' -i "work-items/$wi.yaml"
  yq eval '.requirement_refs = ["REQ-001"]' -i "work-items/$wi.yaml"
  yq eval '.acceptance_refs = ["ACC-001"]' -i "work-items/$wi.yaml"
  yq eval '.verification_refs = ["VO-001"]' -i "work-items/$wi.yaml"
  yq eval '.branch_execution.owned_paths = ["src/**", "testing.md", "meta.yaml"]' -i "work-items/$wi.yaml"
  yq eval '.branch_execution.shared_paths = []' -i "work-items/$wi.yaml"
  yq eval '.branch_execution.merge_order = 1' -i "work-items/$wi.yaml"
  yq eval '.required_verification = ["unit tests pass"]' -i "work-items/$wi.yaml"
  yq eval '.stop_conditions = ["scope expansion"]' -i "work-items/$wi.yaml"
  yq eval '.reopen_triggers = ["architecture change"]' -i "work-items/$wi.yaml"
  yq eval '.hard_constraints = ["no breaking changes"]' -i "work-items/$wi.yaml"
done

log "✓ add-work-item succeeded"

cat > reviews/implementation-review.yaml <<'EOF'
phase: Design
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
EOF

git add reviews/implementation-review.yaml
git commit -m "docs: approve design"

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
expect_fail_cmd "focus work item WI-003 is missing from design work item derivation" "\"$TMP_WORKSPACE/.codespec/codespec\" start-implementation WI-003"

"$TMP_WORKSPACE/.codespec/codespec" start-implementation WI-001
"$TMP_WORKSPACE/.codespec/codespec" set-active-work-items WI-001

focus_wi=$(yq eval '.focus_work_item' meta.yaml)
[ "$focus_wi" = "WI-001" ] || die "same-phase start-implementation did not switch focus back to WI-001"

active_wis=$(yq eval -o=json '.active_work_items' meta.yaml)
assert_json_eq "$active_wis" '. | length' '1'
assert_json_eq "$active_wis" '.[0]' '"WI-001"'
log "✓ active_work_items can be narrowed after same-phase switching"

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
- acceptance_ref: ACC-001
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

"$TMP_WORKSPACE/.codespec/codespec" start-testing

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Testing" ] || die "start-testing did not set phase"
log "✓ start-testing succeeded"

# Test 8: Deployment
log "\n=== Test 8: Deployment ==="

# Update testing.md with full-integration test
cat > testing.md <<'EOF'
- acceptance_ref: ACC-001
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

- acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: full-integration
  verification_type: automated
  artifact_ref: src/test.txt
  result: pass
  tested_at: 2026-04-16
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false
EOF

git add testing.md
git commit -m "test: add full-integration test"

"$TMP_WORKSPACE/.codespec/codespec" start-deployment

phase=$(yq eval '.phase' meta.yaml)
[ "$phase" = "Deployment" ] || die "start-deployment did not set phase"
[ -f "deployment.md" ] || die "start-deployment did not create deployment.md"
log "✓ start-deployment succeeded"

# Test 9: Complete change
log "\n=== Test 9: Complete change ==="

# Fill deployment.md
cat > deployment.md <<'EOF'
# deployment.md

## Deployment Plan
Test deployment.

## Pre-deployment Checklist
- [x] Tests pass
- [x] Code reviewed

## Deployment Steps
1. Deploy test

## Verification Results
smoke_test: pass
All tests pass.

## Acceptance Conclusion
status: pass
approved_by: smoke-test
approved_at: 2026-04-16

## Rollback Plan
Revert commit.

## Monitoring
Monitor logs.

## Post-deployment Actions
None.

## Deployment Plan
target_env: test
deployment_date: 2026-04-16
deployment_method: automated
EOF

git add deployment.md
git commit -m "docs: complete deployment"

"$TMP_WORKSPACE/.codespec/codespec" complete-change

status=$(yq eval '.status' meta.yaml)
[ "$status" = "completed" ] || die "complete-change did not set status to completed"
log "✓ complete-change succeeded"

# Completed dossiers should remain re-verifiable
"$TMP_WORKSPACE/.codespec/codespec" check-gate verification
"$TMP_WORKSPACE/.codespec/codespec" check-gate promotion-criteria
log "✓ completed dossier remains re-verifiable"

"$TMP_WORKSPACE/.codespec/codespec" promote-version smoke-v1

[ -f "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml" ] || die "promote-version did not create versioned meta.yaml"
promoted_status=$(yq eval '.status' "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml")
[ "$promoted_status" = "completed" ] || die "promote-version did not preserve completed status"
promoted_active_wis=$(yq eval -o=json '.active_work_items' "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml")
assert_json_eq "$promoted_active_wis" '. | length' '0'
log "✓ promote-version preserves completed metadata semantics"

# Test 10: testing ledger selection semantics
log "\n=== Test 10: testing ledger selection semantics ==="

yq eval '.phase = "Testing" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001"] | .execution_group = null | .execution_branch = null' -i meta.yaml

cat > testing.md <<'EOF'
- acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: full-integration
  verification_type: manual
  artifact_ref: reports/older-pass.txt
  result: pass
  tested_at: 2026-04-16
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false

- acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: full-integration
  verification_type: automated
  artifact_ref: reports/newer-pass.txt
  result: pass
  tested_at: 2026-04-17
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false
EOF

"$TMP_WORKSPACE/.codespec/codespec" check-gate verification
log "✓ verification uses the latest matching pass record without duplicating extracted fields"

cat > testing.md <<'EOF'
- acceptance_ref: ACC-001
  work_item_ref: WI-001
  test_type: integration
  test_scope: full-integration
  verification_type: automated
  artifact_ref: reports/pass-before-fail.txt
  result: pass
  tested_at: 2026-04-18
  tested_by: smoke-test
  residual_risk: none
  reopen_required: false

- acceptance_ref: ACC-001
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

"$TMP_WORKSPACE/.codespec/codespec" check-gate verification
log "✓ verification still recognizes an earlier full-integration pass record when a later failure exists"

# Test 11: File modification rules
log "\n=== Test 11: File modification rules ==="

# Reset to Implementation phase for testing
yq eval '.phase = "Implementation" | .status = "in_progress" | .focus_work_item = "WI-001" | .active_work_items = ["WI-001"]' -i meta.yaml
yq eval '.feature_branch = "main"' -i meta.yaml

git checkout -b test-execution-branch

yq eval '.execution_group = "test-group" | .execution_branch = "test-execution-branch"' -i meta.yaml
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

yq eval '.active_work_items = ["WI-001"]' -i meta.yaml

# Test: active Deployment still requires active_work_items until completed
yq eval '.phase = "Deployment" | .status = "active" | .focus_work_item = null | .active_work_items = []' -i meta.yaml
set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate metadata-consistency 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "metadata-consistency gate should fail for active Deployment with empty active_work_items"
assert_contains "$output" "Deployment phase requires active_work_items to be non-empty"
log "✓ active Deployment still requires active_work_items"

# Test phase-capability gate
yq eval '.phase = "Proposal"' -i meta.yaml
mkdir -p src
echo "test" > src/forbidden.txt
git add src/forbidden.txt

set +e
output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" check-gate phase-capability 2>&1)
status=$?
set -e

[ "$status" -ne 0 ] || die "phase-capability gate should fail when src/** exists in Proposal phase"
log "✓ phase-capability gate works"

git reset HEAD src/forbidden.txt
rm -f src/forbidden.txt

# Test 13: Readset
log "\n=== Test 13: Readset ==="

yq eval '.phase = "Requirements" | .status = "in_progress"' -i meta.yaml

readset_output=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" readset)

assert_contains "$readset_output" "AGENTS.md"
assert_contains "$readset_output" "meta.yaml"
assert_contains "$readset_output" "spec.md"
log "✓ readset output correct"

readset_json=$(CODESPEC_PROJECT_ROOT="$TMP_WORKSPACE/test-project" "$TMP_WORKSPACE/.codespec/codespec" readset --json)

assert_json_eq "$readset_json" '.entry_files[0].path' '"AGENTS.md"'
assert_json_eq "$readset_json" '.minimal_readset | map(select(.path == "meta.yaml")) | length' '1'
log "✓ readset JSON output correct"

log "\n=== All tests passed ==="
