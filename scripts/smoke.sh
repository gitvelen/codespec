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

help_output=$("$TMP_WORKSPACE/.codespec/codespec" --help)
assert_contains "$help_output" "scaffold-project-docs <version>"
log "✓ help exposes scaffold-project-docs"

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

## Requirements

- REQ-001
  - summary: test requirement
  - rationale: for smoke test
  - source_ref: docs/test.md#intent

## Acceptance

- acc_id: ACC-001
  source_ref: REQ-001
  expected_outcome: test passes
  priority: P0

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - smoke requirement can advance to next phase
  artifact_expectation: gate check passes

<!-- SKELETON-END -->
EOF

mkdir -p reviews
cat > reviews/design-review.yaml <<'EOF'
phase: Requirement
verdict: approved
reviewed_by: smoke-test
reviewed_at: 2026-04-16
EOF

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

## Summary

Smoke design summary.

## Technical Approach

Keep the smoke implementation minimal and tied to one requirement.

## Boundaries & Impacted Surfaces

- impacted_surfaces:
  - src/**
- out_of_scope:
  - production deployment

## Execution Model

- mode: single-branch
- rationale: smoke test does not need parallelism

## Work Item Mapping

- wi_id: WI-001
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  summary: implement smoke verification capability
- wi_id: WI-002
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  summary: implement same-phase WI switching capability

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

## Verification Design

- ACC-001:
  - approach: smoke gates and lifecycle commands pass
  - evidence: scripts/smoke.sh completes

## Reopen Triggers

- if lifecycle gates require duplicate spec/design sections again

## Failure Paths / Reopen Triggers

- if work item derivation drifts from work-items/*.yaml
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
  if [ "$wi" = "WI-001" ]; then
    yq eval '.allowed_paths = ["src/**", "meta.yaml", "testing.md", "contracts/**"]' -i "work-items/$wi.yaml"
    yq eval '.forbidden_paths = ["versions/**", "spec.md", "design.md", "work-items/**", "deployment.md"]' -i "work-items/$wi.yaml"
  fi
  yq eval '.branch_execution.owned_paths = ["src/**", "testing.md", "meta.yaml"]' -i "work-items/$wi.yaml"
  yq eval '.branch_execution.shared_paths = []' -i "work-items/$wi.yaml"
  yq eval '.branch_execution.merge_order = 1' -i "work-items/$wi.yaml"
  yq eval '.required_verification = ["unit tests pass"]' -i "work-items/$wi.yaml"
  yq eval '.stop_conditions = ["scope expansion"]' -i "work-items/$wi.yaml"
  yq eval '.reopen_triggers = ["architecture change"]' -i "work-items/$wi.yaml"
  yq eval '.hard_constraints = ["no breaking changes"]' -i "work-items/$wi.yaml"
done

log "✓ add-work-item succeeded"

git add work-items
git commit -m "docs: finalize work items"

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
rm -f work-items/WI-003.yaml

"$TMP_WORKSPACE/.codespec/codespec" start-implementation WI-001
"$TMP_WORKSPACE/.codespec/codespec" set-active-work-items WI-001

focus_wi=$(yq eval '.focus_work_item' meta.yaml)
[ "$focus_wi" = "WI-001" ] || die "same-phase start-implementation did not switch focus back to WI-001"

active_wis=$(yq eval -o=json '.active_work_items' meta.yaml)
assert_json_eq "$active_wis" '. | length' '1'
assert_json_eq "$active_wis" '.[0]' '"WI-001"'
log "✓ active_work_items can be narrowed after same-phase switching"

printf '\nforbidden implementation drift\n' >> spec.md
git add spec.md
git commit --no-verify -m "test: introduce committed forbidden drift"

expect_fail_cmd \
  "implementation span file spec.md is forbidden by active work items" \
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

# Fill deployment.md and provide a project deploy script
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

"$TMP_WORKSPACE/.codespec/codespec" deploy
"$TMP_WORKSPACE/.codespec/codespec" check-gate deployment-readiness

assert_contains "$(<deployment.md)" "execution_ref: smoke-run-001"
assert_contains "$(<deployment.md)" "status: pending"
log "✓ deploy writes execution evidence and readiness data"

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
log "✓ reopen-implementation re-enters Implementation for failed manual verification"

"$TMP_WORKSPACE/.codespec/codespec" start-testing
"$TMP_WORKSPACE/.codespec/codespec" start-deployment
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

git add deployment.md
git commit -m "docs: record manual acceptance"

"$TMP_WORKSPACE/.codespec/codespec" complete-change smoke-v1

status=$(yq eval '.status' meta.yaml)
[ "$status" = "completed" ] || die "complete-change did not set status to completed"
[ "$(yq eval '.stable_version' meta.yaml)" = "smoke-v1" ] || die "complete-change did not set stable_version in workspace meta"
[ "$(yq eval -o=json '.active_work_items' meta.yaml)" = "[]" ] || die "workspace completed dossier should clear active_work_items"
[ -f "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml" ] || die "complete-change did not archive stable version"
log "✓ complete-change archived the accepted stable version"

# Completed dossiers should remain re-verifiable
"$TMP_WORKSPACE/.codespec/codespec" check-gate verification
"$TMP_WORKSPACE/.codespec/codespec" check-gate promotion-criteria
log "✓ completed dossier remains re-verifiable"

"$TMP_WORKSPACE/.codespec/codespec" start-deployment
[ "$(yq eval '.phase' meta.yaml)" = "Deployment" ] || die "completed reopen should return to Deployment phase"
[ "$(yq eval '.status' meta.yaml)" = "active" ] || die "completed reopen should reactivate the dossier"
reopened_active_wis=$(yq eval -o=json '.active_work_items' meta.yaml)
assert_json_eq "$reopened_active_wis" '. | length' '1'
assert_json_eq "$reopened_active_wis" '.[0]' '"WI-001"'
log "✓ start-deployment restores archived active_work_items for completed reopen"

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
log "✓ deployment-readiness requires runtime readiness"

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

promoted_status=$(yq eval '.status' "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml")
[ "$promoted_status" = "completed" ] || die "complete-change did not preserve completed status in archived meta"
promoted_active_wis=$(yq eval -o=json '.active_work_items' "$TMP_WORKSPACE/versions/smoke-v1/meta.yaml")
assert_json_eq "$promoted_active_wis" '. | length' '1'
assert_json_eq "$promoted_active_wis" '.[0]' '"WI-001"'
log "✓ complete-change preserves active work item snapshot in archive"

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

expect_fail_cmd \
  "full-integration pass record for ACC-001" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' check-gate verification"
log "✓ verification rejects a later full-integration failure after an earlier pass"

# Test 11: File modification rules
log "\n=== Test 11: File modification rules ==="

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

# Test 13: promotion trace consistency
log "\n=== Test 13: promotion trace consistency ==="

CURRENT_HEAD="$(git rev-parse HEAD)"
CURRENT_HEAD="$CURRENT_HEAD" yq eval '.phase = "Deployment" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001"] | .implementation_base_revision = strenv(CURRENT_HEAD)' -i meta.yaml
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

git add work-items/WI-001.yaml work-items/WI-002.yaml
git commit --no-verify -m "test: break trace before promotion"

expect_fail_cmd \
  "trace gap: VO-001 is not referenced by any work item verification_refs" \
  "cd '$TMP_WORKSPACE/test-project' && '$TMP_WORKSPACE/.codespec/codespec' complete-change smoke-v2.9"

git reset --soft HEAD~1 >/dev/null 2>&1 || true
git restore --staged work-items/WI-001.yaml work-items/WI-002.yaml >/dev/null 2>&1 || true
yq eval '.verification_refs = ["VO-001"]' -i work-items/WI-001.yaml
yq eval '.verification_refs = ["VO-001"]' -i work-items/WI-002.yaml
log "✓ complete-change should re-check trace consistency"

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
assert_json_eq "$readset_json" '.phase_capabilities.allowed[0]' '"authoritative dossier edits"'
assert_json_eq "$readset_json" '.phase_capabilities.forbidden[0]' '"src/** and Dockerfile only"'
log "✓ readset JSON output correct"

# Test 14: reset-to-requirement resolves promoted version from archived baseline metadata
log "\n=== Test 14: reset-to-requirement ==="

yq eval '.change_id = "baseline" | .base_version = null | .phase = "Deployment" | .status = "active" | .focus_work_item = null | .active_work_items = ["WI-001"] | .execution_group = null | .execution_branch = null' -i meta.yaml

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

log "\n=== All tests passed ==="
