#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_REPO="$(mktemp -d /tmp/codespec-smoke-XXXXXX)"

cleanup() {
  rm -rf "$TMP_REPO"
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

write_implementation_state() {
  cat > "$TMP_REPO/change/demo/meta.yaml" <<'EOF'
change_id: add-auth
base_version: null
created_at: 2026-04-07

phase: Implementation
status: in_progress
focus_work_item: WI-001

execution_group: null
execution_branch: null
active_work_items:
  - WI-001

feature_branch: feature/add-auth

blocked_reason: null
blocked_by: null

updated_at: 2026-04-07
updated_by: smoke
EOF

  cat > "$TMP_REPO/change/demo/spec.md" <<'EOF'
# spec.md

## Default Read Layer

### Intent Summary
- Problem: auth entrypoint is missing
- Goals:
  - Provide a stable login boundary
- Non-goals:
  - Add extra auth flows
- Must-have Anchors:
  - login(token) returns ok
- Prohibition Anchors:
  - no contract churn during implementation
- Success Anchors:
  - ACC-001 passes
- Boundary Alerts:
  - auth contract is frozen
- Unresolved Decisions:
  - none

### Input Intake Summary
- input_maturity: L1
- input_refs:
  - docs/inputs/add-auth.md#intent
- input_owner: human
- approval_basis: owner approved intake for auth scope
- normalization_status: anchored

### Requirements Quick Index
- Proposal Coverage Map: maintain in `## Requirements`
- Clarification Status: maintain in `## Requirements`
- Requirements Index:
  - REQ-001: login validates token

### Acceptance Index
- ACC-001 -> REQ-001

### Verification Index
- VO-001 -> ACC-001

### Appendix Map
- none: never

<!-- SKELETON-END -->

## Intent

### Problem / Background
Need a minimal auth entrypoint.

### Goals
- Add a stable login boundary.

### Non-goals
- Add logout or profile flows.

### Must-have Anchors
- login(token) returns ok.

### Prohibition Anchors
- Do not expand auth scope.

### Success Anchors
- ACC-001 has pass evidence.

### Boundary Alerts
- Shared auth contract is frozen.

### Unresolved Decisions
- none

### Input Intake
- input_maturity: L1
- input_refs:
  - docs/inputs/add-auth.md#intent
- input_owner: human
- approval_basis: owner approved intake for auth scope
- normalization_status: anchored

### Testing Priority Rules
- P0: must be automated for safety, money, data integrity, or core flow
- P1: prefer automated; otherwise must have manual or equivalent pass evidence
- P2: may use manual or equivalent verification, but still requires a pass result

## Requirements

### Proposal Coverage Map
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Add a stable login boundary.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: login(token) returns ok.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Do not expand auth scope.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: ACC-001 has pass evidence.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Shared auth contract is frozen.
  target_ref: REQ-001
  status: covered

### Clarification Status
- clr_id: CLR-001
  source_ref: docs/inputs/add-auth.md#intent
  status: resolved
  impact: medium
  owner: human
  next_action: keep current scope

### Functional Requirements
- REQ-001
  - summary: login(token) returns ok for a valid token
  - rationale: provide a canonical auth entrypoint

### Constraints / Prohibitions
- auth contract must remain stable during implementation

### Non-functional Requirements
- [Only include if measurable]

## Acceptance

- acc_id: ACC-001
  source_ref: REQ-001
  expected_outcome: login(token) returns ok
  priority: P0
  priority_rationale: core auth flow
  status: approved

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - login(token) returns ok
  artifact_expectation: testing.md pass record for ACC-001
EOF

  cat > "$TMP_REPO/change/demo/design.md" <<'EOF'
# design.md

## Default Read Layer

### Goal / Scope Link
- requirement_refs:
  - REQ-001
- acceptance_refs:
  - ACC-001
- verification_refs:
  - VO-001
- spec_alignment_check:
  - spec_ref: REQ-001
    aligned: true
    notes: login stays within approved auth scope

### Architecture Boundary
- impacted_capabilities:
  - auth login
- not_impacted_capabilities:
  - profile
- impacted_shared_surfaces:
  - auth-api
- not_impacted_shared_surfaces:
  - billing
- major_constraints:
  - contract stays frozen during implementation
- contract_required: true
- compatibility_constraints:
  - login signature remains stable

### Work Item Execution Strategy
- dependency_summary:
  - WI-001: no dependency
- parallel_recommendation:
  - Group A: WI-001
- notes:
  - single-slice smoke path

### Design Slice Index
- DS-001 -> auth login slice

### Work Item Derivation
- wi_id: WI-001
  goal: implement auth login boundary
  covered_acceptance_refs: [ACC-001]
  dependency_refs: []
  contract_needed: true
  notes_on_boundary: src may change; contract is frozen

### Contract Needs
- auth-api gates the shared login boundary

### Failure Paths / Reopen Triggers
- contract shape must change

### Appendix Map
- DD-001.md -> never for smoke

## Goal / Scope Link

### Scope Summary
- add a minimal auth login path

### spec_alignment_check
- spec_ref: REQ-001
  aligned: true
  notes: design matches the login requirement

## Architecture Boundary
- system_context: smoke repo
- impacted_capabilities:
  - auth login
- not_impacted_capabilities:
  - profile
- impacted_shared_surfaces:
  - auth-api
- not_impacted_shared_surfaces:
  - billing
- major_constraints:
  - keep the contract stable
- contract_required: true
- compatibility_constraints:
  - login signature remains stable

## Work Item Execution Strategy

### Dependency Summary
- WI-001: no dependency

### Parallel Recommendation
- Group A: WI-001

### Notes
- single-slice smoke path

## Design Slice Index
- DS-001:
  - appendix_ref: design-appendices/DD-001.md
  - scope: auth login slice
  - requirement_refs: [REQ-001]
  - acceptance_refs: [ACC-001]
  - verification_refs: [VO-001]

## Work Item Derivation
- wi_id: WI-001
  input_refs:
    - docs/inputs/add-auth.md#intent
  requirement_refs:
    - REQ-001
  goal: implement auth login boundary
  covered_acceptance_refs: [ACC-001]
  verification_refs:
    - VO-001
  dependency_refs: []
  contract_needed: true
  notes_on_boundary: src changes allowed; contract stays frozen

## Contract Needs
- contract_id: auth-api
  required: true
  reason: login boundary is shared
  consumers: [WI-001]

## Verification Design
- ACC-001:
  - approach: verify pass record exists
  - evidence: testing.md

## Failure Paths / Reopen Triggers
- contract shape must change
- goal or acceptance changes

## Appendix Map
- design-appendices/DD-001.md: never for smoke
EOF

  cat > "$TMP_REPO/change/demo/work-items/WI-001.yaml" <<'EOF'
wi_id: WI-001
goal: implement auth login boundary
scope:
  - update auth source files
out_of_scope:
  - add logout flow

allowed_paths:
  - change/demo/contracts/**
  - src/**
forbidden_paths:
  - versions/**

phase_scope: Implementation

input_refs:
  - docs/inputs/add-auth.md#intent
requirement_refs:
  - REQ-001
acceptance_refs:
  - ACC-001
verification_refs:
  - VO-001
derived_from: design.md#work-item-derivation
dependency_refs: []
dependency_type: strong
contract_refs:
  - contracts/auth-api.md

evidence_refs: []

verification_profile: focused
required_verification:
  - ACC-001 pass record in testing.md

stop_conditions:
  - contract must change
reopen_triggers:
  - spec or design must change
hard_constraints:
  - frozen contract must not be edited
EOF

  cat > "$TMP_REPO/change/demo/testing.md" <<'EOF'
- acceptance_ref: ACC-001
  verification_type: automated
  artifact_ref: smoke/test/login
  result: pass
  residual_risk: none
  reopen_required: false
EOF

  mkdir -p "$TMP_REPO/change/demo/contracts" "$TMP_REPO/src"

  cat > "$TMP_REPO/change/demo/contracts/auth-api.md" <<'EOF'
contract_id: auth-api
status: frozen
frozen_at: 2026-04-07
consumers: [WI-001]

## Interface Definition
login(token): ok

## Notes
- invariant: stable
EOF

  cat > "$TMP_REPO/src/index.js" <<'EOF'
module.exports = {
  login(token) {
    return token ? 'ok' : 'ok'
  },
}
EOF

  mkdir -p "$TMP_REPO/change/demo/spec-appendices" "$TMP_REPO/change/demo/design-appendices"
}

write_testing_state_with_pending_acceptance() {
  cat > "$TMP_REPO/change/demo/meta.yaml" <<'EOF'
change_id: add-auth
base_version: null
created_at: 2026-04-07

phase: Testing
status: in_progress
focus_work_item: null

execution_group: null
execution_branch: null
active_work_items: []

feature_branch: feature/add-auth

blocked_reason: null
blocked_by: null

updated_at: 2026-04-07
updated_by: smoke
EOF

  cat > "$TMP_REPO/change/demo/spec.md" <<'EOF'
# spec.md

## Default Read Layer

### Intent Summary
- Problem: auth entrypoint is missing
- Goals:
  - Provide a stable login boundary
- Non-goals:
  - Add extra auth flows
- Must-have Anchors:
  - login(token) returns ok
- Prohibition Anchors:
  - no contract churn during implementation
- Success Anchors:
  - ACC-001 passes
- Boundary Alerts:
  - auth contract is frozen
- Unresolved Decisions:
  - ACC-002 is not approved yet

### Input Intake Summary
- input_maturity: L1
- input_refs:
  - docs/inputs/add-auth.md#intent
- input_owner: human
- approval_basis: owner approved intake for auth scope
- normalization_status: anchored

### Requirements Quick Index
- Proposal Coverage Map: maintain in `## Requirements`
- Clarification Status: maintain in `## Requirements`
- Requirements Index:
  - REQ-001: login validates token

### Acceptance Index
- ACC-001 -> REQ-001
- ACC-002 -> REQ-001

### Verification Index
- VO-001 -> ACC-001
- VO-002 -> ACC-002

### Appendix Map
- none: never

<!-- SKELETON-END -->

## Intent

### Problem / Background
Need a minimal auth entrypoint.

### Goals
- Add a stable login boundary.

### Non-goals
- Add logout or profile flows.

### Must-have Anchors
- login(token) returns ok.

### Prohibition Anchors
- Do not expand auth scope.

### Success Anchors
- Approved acceptance has pass evidence.

### Boundary Alerts
- Shared auth contract is frozen.

### Unresolved Decisions
- ACC-002 is still pending approval.

### Input Intake
- input_maturity: L1
- input_refs:
  - docs/inputs/add-auth.md#intent
- input_owner: human
- approval_basis: owner approved intake for auth scope
- normalization_status: anchored

### Testing Priority Rules
- P0: must be automated for safety, money, data integrity, or core flow
- P1: prefer automated; otherwise must have manual or equivalent pass evidence
- P2: may use manual or equivalent verification, but still requires a pass result

## Requirements

### Proposal Coverage Map
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Add a stable login boundary.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: login(token) returns ok.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Do not expand auth scope.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Approved acceptance has pass evidence.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Shared auth contract is frozen.
  target_ref: REQ-001
  status: covered

### Clarification Status
- clr_id: CLR-001
  source_ref: docs/inputs/add-auth.md#intent
  status: deferred
  impact: medium
  owner: human
  next_action: revisit when ACC-002 is approved

### Functional Requirements
- REQ-001
  - summary: login(token) returns ok for a valid token
  - rationale: provide a canonical auth entrypoint

### Constraints / Prohibitions
- auth contract must remain stable during implementation

### Non-functional Requirements
- [Only include if measurable]

## Acceptance

- acc_id: ACC-001
  source_ref: REQ-001
  expected_outcome: login(token) returns ok
  priority: P0
  priority_rationale: core auth flow
  status: approved

- acc_id: ACC-002
  source_ref: REQ-001
  expected_outcome: login(token) exposes extra metadata
  priority: P2
  priority_rationale: optional future behavior
  status: pending

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - login(token) returns ok
  artifact_expectation: testing.md pass record for ACC-001

- vo_id: VO-002
  acceptance_ref: ACC-002
  verification_type: manual
  verification_profile: focused
  obligations:
    - extra metadata behavior is verified after approval
  artifact_expectation: testing.md pass record only after approval
EOF

  cat > "$TMP_REPO/change/demo/design.md" <<'EOF'
# design.md

## Default Read Layer

### Goal / Scope Link
- requirement_refs:
  - REQ-001
- acceptance_refs:
  - ACC-001
  - ACC-002
- verification_refs:
  - VO-001
  - VO-002
- spec_alignment_check:
  - spec_ref: REQ-001
    aligned: true
    notes: login stays within approved auth scope

### Architecture Boundary
- impacted_capabilities:
  - auth login
- not_impacted_capabilities:
  - profile
- impacted_shared_surfaces:
  - auth-api
- not_impacted_shared_surfaces:
  - billing
- major_constraints:
  - contract stays frozen during implementation
- contract_required: true
- compatibility_constraints:
  - login signature remains stable

### Work Item Execution Strategy
- dependency_summary:
  - WI-001: no dependency
- parallel_recommendation:
  - Group A: WI-001
- notes:
  - single-slice smoke path with pending future acceptance

### Design Slice Index
- DS-001 -> auth login slice

### Work Item Derivation
- wi_id: WI-001
  goal: implement auth login boundary
  covered_acceptance_refs: [ACC-001, ACC-002]
  dependency_refs: []
  contract_needed: true
  notes_on_boundary: src may change; contract is frozen

### Contract Needs
- auth-api gates the shared login boundary

### Failure Paths / Reopen Triggers
- contract shape must change

### Appendix Map
- DD-001.md -> never for smoke

## Goal / Scope Link

### Scope Summary
- add a minimal auth login path
- keep ACC-002 pending until approval

### spec_alignment_check
- spec_ref: REQ-001
  aligned: true
  notes: design matches the login requirement and pending future acceptance

## Architecture Boundary
- system_context: smoke repo
- impacted_capabilities:
  - auth login
- not_impacted_capabilities:
  - profile
- impacted_shared_surfaces:
  - auth-api
- not_impacted_shared_surfaces:
  - billing
- major_constraints:
  - keep the contract stable
- contract_required: true
- compatibility_constraints:
  - login signature remains stable

## Work Item Execution Strategy

### Dependency Summary
- WI-001: no dependency

### Parallel Recommendation
- Group A: WI-001

### Notes
- ACC-001 ships now; ACC-002 remains planned but unapproved

## Design Slice Index
- DS-001:
  - appendix_ref: design-appendices/DD-001.md
  - scope: auth login slice
  - requirement_refs: [REQ-001]
  - acceptance_refs: [ACC-001, ACC-002]
  - verification_refs: [VO-001, VO-002]

## Work Item Derivation
- wi_id: WI-001
  input_refs:
    - docs/inputs/add-auth.md#intent
  requirement_refs:
    - REQ-001
  goal: implement auth login boundary
  covered_acceptance_refs: [ACC-001, ACC-002]
  verification_refs:
    - VO-001
    - VO-002
  dependency_refs: []
  contract_needed: true
  notes_on_boundary: src changes allowed; contract stays frozen

## Contract Needs
- contract_id: auth-api
  required: true
  reason: login boundary is shared
  consumers: [WI-001]

## Verification Design
- ACC-001:
  - approach: verify pass record exists
  - evidence: testing.md
- ACC-002:
  - approach: verify only after approval
  - evidence: no testing obligation before approval

## Failure Paths / Reopen Triggers
- contract shape must change
- goal or acceptance changes

## Appendix Map
- design-appendices/DD-001.md: never for smoke
EOF

  cat > "$TMP_REPO/change/demo/work-items/WI-001.yaml" <<'EOF'
wi_id: WI-001
goal: implement auth login boundary
scope:
  - update auth source files
out_of_scope:
  - add logout flow

allowed_paths:
  - change/demo/contracts/**
  - src/**
forbidden_paths:
  - versions/**

phase_scope: Implementation

input_refs:
  - docs/inputs/add-auth.md#intent
requirement_refs:
  - REQ-001
acceptance_refs:
  - ACC-001
  - ACC-002
verification_refs:
  - VO-001
  - VO-002
derived_from: design.md#work-item-derivation
dependency_refs: []
dependency_type: strong
contract_refs:
  - contracts/auth-api.md

evidence_refs: []

verification_profile: focused
required_verification:
  - approved acceptance must have pass evidence

stop_conditions:
  - contract must change
reopen_triggers:
  - spec or design must change
hard_constraints:
  - frozen contract must not be edited
EOF

  cat > "$TMP_REPO/change/demo/testing.md" <<'EOF'
- acceptance_ref: ACC-001
  verification_type: automated
  artifact_ref: smoke/test/login
  result: pass
  residual_risk: none
  reopen_required: false
EOF
}

write_deployment_state() {
  cat > "$TMP_REPO/change/demo/meta.yaml" <<'EOF'
change_id: add-auth
base_version: null
created_at: 2026-04-07

phase: Deployment
status: in_progress
focus_work_item: null

execution_group: null
execution_branch: null
active_work_items: []

feature_branch: feature/add-auth

blocked_reason: null
blocked_by: null

updated_at: 2026-04-07
updated_by: smoke
EOF

  "$TMP_REPO/.codespec/codespec" materialize-deployment demo >/dev/null
  cat > "$TMP_REPO/change/demo/deployment.md" <<'EOF'
# deployment.md

## Deployment Plan
target_env: STAGING
deployment_date: 2026-04-07
deployment_method: manual

## Pre-deployment Checklist
- [x] all acceptance items passed
- [x] required migrations verified
- [x] rollback plan prepared
- [x] smoke checks prepared

## Deployment Steps
1. deploy the release artifact
2. run smoke validation

## Verification Results
- smoke_test: pass
- key_features: [login]
- performance: [within baseline]

## Acceptance Conclusion
status: pass
notes: deployment accepted
approved_by: smoke
approved_at: 2026-04-07

## Rollback Plan
trigger_conditions:
  - login flow fails
rollback_steps:
  1. restore previous release

## Monitoring
metrics:
  - auth login success rate
alerts:
  - auth login failure spike

## Post-deployment Actions
- [x] update related docs
- [x] record lessons learned if needed
- [x] archive change dossier to versions/
EOF
}

write_execution_group_state() {
  cat > "$TMP_REPO/change/demo/meta.yaml" <<'EOF'
change_id: add-auth
base_version: null
created_at: 2026-04-07

phase: Implementation
status: in_progress
focus_work_item: WI-001

execution_group: demo
execution_branch: group/demo
active_work_items:
  - WI-001

feature_branch: feature/add-auth

blocked_reason: null
blocked_by: null

updated_at: 2026-04-07
updated_by: smoke
EOF
}

log "smoke repo: $TMP_REPO"

git -C "$TMP_REPO" init -q
"$FRAMEWORK_ROOT/codespec" install "$TMP_REPO" demo add-auth null >/dev/null
"$TMP_REPO/.codespec/codespec" add-work-item WI-001 demo >/dev/null
work_item_template_output="$(<"$TMP_REPO/change/demo/work-items/WI-001.yaml")"
assert_contains "$work_item_template_output" 'goal: [one execution goal]'

cat > "$TMP_REPO/change/demo/work-items/WI-001.yaml" <<'EOF'
wi_id: WI-001
goal: implement auth login boundary
scope:
  - update auth source files
out_of_scope:
  - add logout flow

allowed_paths:
  - change/demo/contracts/**
  - src/**
forbidden_paths:
  - versions/**

phase_scope: Implementation

input_refs:
  - docs/inputs/add-auth.md#intent
requirement_refs:
  - REQ-001
acceptance_refs:
  - ACC-001
verification_refs:
  - VO-001
derived_from: design.md#work-item-derivation
dependency_refs: []
dependency_type: strong
contract_refs:
  - contracts/auth-api.md

evidence_refs: []

verification_profile: focused
required_verification:
  - ACC-001 pass record in testing.md

stop_conditions:
  - contract must change
reopen_triggers:
  - spec or design must change
hard_constraints:
  - frozen contract must not be edited
EOF
spec_template_output="$(<"$TMP_REPO/change/demo/spec.md")"
assert_contains "$spec_template_output" '### Input Intake Summary'
assert_contains "$spec_template_output" '### Input Intake'

design_template_output="$(<"$TMP_REPO/change/demo/design.md")"
assert_contains "$design_template_output" '- requirement_refs:'
assert_contains "$design_template_output" '- verification_refs:'

work_item_template_output="$(<"$TMP_REPO/change/demo/work-items/WI-001.yaml")"
assert_contains "$work_item_template_output" 'input_refs:'
assert_contains "$work_item_template_output" 'requirement_refs:'
assert_contains "$work_item_template_output" 'verification_refs:'
assert_contains "$work_item_template_output" 'evidence_refs:'
[[ "$work_item_template_output" != *'change//spec.md#input-intake'* ]] || die 'work-item template rendered invalid input_ref placeholder'

git -C "$TMP_REPO" add .
git -C "$TMP_REPO" -c user.name='Claude Code' -c user.email='noreply@example.com' commit -qm 'seed initial smoke repo'
git -C "$TMP_REPO" reset -q

help_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" --help)"
assert_contains "$help_output" 'Gate views:'
assert_contains "$help_output" 'design-structure-complete -> design artifacts are structurally complete and aligned with work item derivation'
assert_contains "$help_output" 'design-readiness -> alias of design-structure-complete'
assert_contains "$help_output" 'implementation-ready -> design-structure-complete + implementation-start'
assert_contains "$help_output" 'codespec promote-version <stable-version> [container]'
assert_contains "$help_output" 'codespec start-implementation <WI-ID> [container]'
assert_contains "$help_output" 'complete-change -> mark Deployment change completed'

status_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" status)"
assert_contains "$status_output" 'phase: Proposal'
assert_contains "$status_output" 'branch_alignment: not_applicable'
readset_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" readset)"
assert_contains "$readset_output" 'lessons_learned.md'
assert_contains "$readset_output" 'change/demo/CLAUDE.md'
assert_contains "$readset_output" 'change/demo/spec.md'
assert_contains "$readset_output" 'change/demo/design.md'
claude_output="$(<"$TMP_REPO/change/demo/CLAUDE.md")"
assert_contains "$claude_output" '## 按 phase 的默认导航'
assert_contains "$claude_output" 'Requirements：主读 `spec.md`'
assert_contains "$claude_output" 'Deployment：先确认 `testing.md` 已覆盖应验证 acceptance'

CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" start-requirements demo >/dev/null
[ "$(yq eval '.phase' "$TMP_REPO/change/demo/meta.yaml")" = 'Requirements' ] || die 'start-requirements did not set phase'
printf '\n# requirements update\n' >> "$TMP_REPO/change/demo/spec.md"
git -C "$TMP_REPO" add change/demo/spec.md
pre_commit_output="$(cd "$TMP_REPO" && CODESPEC_PROJECT_ROOT="$TMP_REPO" ./.codespec/hooks/pre-commit)"
assert_contains "$pre_commit_output" 'pre-commit checks passed'
git -C "$TMP_REPO" reset -q -- change/demo/spec.md
git -C "$TMP_REPO" checkout -- change/demo/spec.md
pre_push_output="$(cd "$TMP_REPO" && CODESPEC_PROJECT_ROOT="$TMP_REPO" ./.codespec/hooks/pre-push)"
assert_contains "$pre_push_output" 'pre-push checks passed'

CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" start-design demo >/dev/null
yq eval '.goal = "implement auth login boundary" | .derived_from = "design.md#work-item-derivation" | .input_refs = ["docs/inputs/example.md#intent"] | .allowed_paths = ["src/**", "change/demo/contracts/**"] | .forbidden_paths = ["versions/**"] | .contract_refs = ["contracts/auth-api.md"] | .required_verification = ["ACC-001 pass record in testing.md"] | .stop_conditions = ["contract must change"] | .reopen_triggers = ["spec or design must change"] | .hard_constraints = ["frozen contract must not be edited"]' -i "$TMP_REPO/change/demo/work-items/WI-001.yaml"
mkdir -p "$TMP_REPO/change/demo/contracts"
cat > "$TMP_REPO/change/demo/contracts/auth-api.md" <<'EOF'
contract_id: auth-api
status: frozen
frozen_at: 2026-04-07
consumers: [WI-001]

## Interface Definition
login(token): ok

## Notes
- invariant: stable
EOF
cat > "$TMP_REPO/change/demo/testing.md" <<'EOF'
- acceptance_ref: ACC-001
  verification_type: automated
  artifact_ref: smoke/test/login
  result: pass
  residual_risk: none
  reopen_required: false
EOF
[ "$(yq eval '.phase' "$TMP_REPO/change/demo/meta.yaml")" = 'Design' ] || die 'start-design did not set phase'
design_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" check-gate design-structure-complete)"
assert_contains "$design_output" 'design-structure-complete gate passed'
expect_fail_cmd 'focus_work_item is null' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate implementation-ready"
CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" add-container exec demo >/dev/null
metadata_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="exec" "$TMP_REPO/.codespec/codespec" check-gate metadata-consistency)"
assert_contains "$metadata_output" 'metadata-consistency gate passed'

CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" start-implementation WI-001 demo >/dev/null
[ "$(yq eval '.phase' "$TMP_REPO/change/demo/meta.yaml")" = 'Implementation' ] || die 'start-implementation did not set phase'
[ "$(yq eval '.focus_work_item' "$TMP_REPO/change/demo/meta.yaml")" = 'WI-001' ] || die 'start-implementation did not set focus_work_item'
expect_fail_cmd 'cannot move from Implementation to Design' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" \"$TMP_REPO/.codespec/codespec\" start-design demo"

write_implementation_state

git -C "$TMP_REPO" add .
git -C "$TMP_REPO" -c user.name='Claude Code' -c user.email='noreply@example.com' commit -qm 'seed smoke repo'
git -C "$TMP_REPO" reset -q

git -C "$TMP_REPO" checkout -qb feature/add-auth
git -C "$TMP_REPO" checkout -qb group/demo
git -C "$TMP_REPO" checkout feature/add-auth >/dev/null
printf '\n// feature ahead\n' >> "$TMP_REPO/src/index.js"
git -C "$TMP_REPO" add src/index.js
git -C "$TMP_REPO" -c user.name='Claude Code' -c user.email='noreply@example.com' commit -qm 'feature ahead for sync check'
git -C "$TMP_REPO" checkout master >/dev/null
write_implementation_state

git -C "$TMP_REPO" config core.hooksPath .githooks
"$TMP_REPO/.codespec/scripts/install-hooks.sh" "$TMP_REPO" >/dev/null
[ -x "$TMP_REPO/.githooks/pre-commit" ] || die 'install-hooks did not respect core.hooksPath for pre-commit'
[ -x "$TMP_REPO/.githooks/pre-push" ] || die 'install-hooks did not respect core.hooksPath for pre-push'
git -C "$TMP_REPO" config --unset core.hooksPath
"$TMP_REPO/.codespec/scripts/install-hooks.sh" "$TMP_REPO" >/dev/null

status_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" status)"
assert_contains "$status_output" 'phase: Implementation'
assert_contains "$status_output" 'focus_work_item: WI-001'
assert_contains "$status_output" 'branch_alignment: not_applicable'
readset_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" readset)"
assert_contains "$readset_output" 'change/demo/work-items/WI-001.yaml'
assert_contains "$readset_output" 'change/demo/contracts/auth-api.md'

spec_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" check-gate spec-completeness)"
assert_contains "$spec_output" 'proposal-maturity gate passed'
assert_contains "$spec_output" 'requirements-approval gate passed'

design_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" check-gate design-structure-complete)"
assert_contains "$design_output" 'design-structure-complete gate passed'

implementation_ready_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" check-gate implementation-ready)"
assert_contains "$implementation_ready_output" 'design-structure-complete gate passed'
assert_contains "$implementation_ready_output" 'implementation-start gate passed'

cat > "$TMP_REPO/change/demo/work-items/WI-002.yaml" <<'EOF'
wi_id: WI-002
goal: implement dependent auth follow-up
scope:
  - update auth source files
out_of_scope:
  - add logout flow

allowed_paths:
  - change/demo/contracts/**
  - src/**
forbidden_paths:
  - versions/**

phase_scope: Implementation

input_refs:
  - docs/inputs/add-auth.md#intent
requirement_refs:
  - REQ-001
acceptance_refs:
  - ACC-001
verification_refs:
  - VO-001
derived_from: design.md#work-item-derivation
dependency_refs:
  - WI-001
dependency_type: strong
contract_refs:
  - contracts/auth-api.md

evidence_refs: []

verification_profile: focused
required_verification:
  - dependency WI-001 must be complete before start

stop_conditions:
  - contract must change
reopen_triggers:
  - spec or design must change
hard_constraints:
  - frozen contract must not be edited
EOF
yq eval '.focus_work_item = "WI-002" | .active_work_items = ["WI-002"]' -i "$TMP_REPO/change/demo/meta.yaml"
expect_fail_cmd 'focus work item WI-002 is missing from design work item derivation' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate implementation-start"

write_implementation_state
yq eval '.acceptance_refs = ["ACC-999"]' -i "$TMP_REPO/change/demo/work-items/WI-001.yaml"
perl -0pi -e 's/covered_acceptance_refs: \[ACC-001\]/covered_acceptance_refs: [ACC-999]/g' "$TMP_REPO/change/demo/design.md"
expect_fail_cmd 'WI-001 references unknown acceptance_ref: ACC-999' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate implementation-start"
write_implementation_state

CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" check-gate verification >/dev/null

printf '\n// allowed change\n' >> "$TMP_REPO/src/index.js"
git -C "$TMP_REPO" add src/index.js
pre_commit_output="$(cd "$TMP_REPO" && CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" ./.codespec/hooks/pre-commit)"
assert_contains "$pre_commit_output" 'pre-commit checks passed'
git -C "$TMP_REPO" reset -q -- src/index.js
git -C "$TMP_REPO" checkout -- src/index.js

printf 'tmp\n' > "$TMP_REPO/versions/tmp.txt"
git -C "$TMP_REPO" add "$TMP_REPO/versions/tmp.txt"
expect_fail_cmd 'staged file versions/tmp.txt is forbidden by WI-001' "cd \"$TMP_REPO\" && CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" ./.codespec/hooks/pre-commit"
git -C "$TMP_REPO" reset -q -- versions/tmp.txt
rm -f "$TMP_REPO/versions/tmp.txt"

expect_fail_cmd 'frozen contract cannot be modified' "cd \"$TMP_REPO\" && perl -0pi -e 's/status: frozen/status: draft/' change/demo/contracts/auth-api.md && git add change/demo/contracts/auth-api.md && CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" ./.codespec/hooks/pre-commit"
git -C "$TMP_REPO" reset -q -- change/demo/contracts/auth-api.md
git -C "$TMP_REPO" checkout -- change/demo/contracts/auth-api.md

cat > "$TMP_REPO/change/demo/spec-appendices/appendix.md" <<'EOF'
- acc_id: ACC-099
  source_ref: REQ-001
  expected_outcome: appendix should not define formal acceptance
EOF
expect_fail_cmd 'spec appendix defines formal IDs' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate spec-completeness"
rm -f "$TMP_REPO/change/demo/spec-appendices/appendix.md"

cat > "$TMP_REPO/change/demo/design-appendices/DD-999.md" <<'EOF'
- vo_id: VO-099
  acceptance_ref: ACC-001
  verification_type: manual
EOF
expect_fail_cmd 'design appendix defines formal IDs' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate design-structure-complete"
rm -f "$TMP_REPO/change/demo/design-appendices/DD-999.md"

write_execution_group_state
status_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" status)"
assert_contains "$status_output" 'execution_branch: group/demo'
assert_contains "$status_output" 'git_branch: master'
assert_contains "$status_output" 'branch_alignment: mismatch'
expect_fail_cmd 'current git branch master does not match execution_branch group/demo' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate branch-alignment"

git -C "$TMP_REPO" checkout group/demo >/dev/null
expect_fail_cmd 'execution branch group/demo is behind feature branch feature/add-auth; merge feature/add-auth before continuing' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate feature-sync"

git -C "$TMP_REPO" checkout master >/dev/null
write_implementation_state
yq eval '(.[] | select(.acceptance_ref == "ACC-001") | .result) = "fail"' -i "$TMP_REPO/change/demo/testing.md"
expect_fail_cmd 'current work item acceptance ACC-001 has no pass record' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" start-testing demo"
write_implementation_state

cat > "$TMP_REPO/change/demo/work-items/WI-002.yaml" <<'EOF'
wi_id: WI-002
acceptance_refs:
  - ACC-002
dependency_refs: []
EOF
yq eval '.focus_work_item = "WI-001" | .active_work_items = ["WI-001", "WI-002"]' -i "$TMP_REPO/change/demo/meta.yaml"
expect_fail_cmd 'current work item acceptance ACC-002 has no testing record' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" start-testing demo"
write_implementation_state

yq eval '.active_work_items = []' -i "$TMP_REPO/change/demo/meta.yaml"
expect_fail_cmd 'cannot clear active_work_items while focus_work_item is set in Implementation phase' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" set-active-work-items [] demo"
expect_fail_cmd 'focus_work_item WI-001 must be included in active_work_items' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" set-active-work-items WI-002 demo"

write_implementation_state
yq eval '.active_work_items = ["WI-001", "WI-999"]' -i "$TMP_REPO/change/demo/meta.yaml"
expect_fail_cmd 'active_work_items references missing work item: WI-999' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate metadata-consistency"

write_testing_state_with_pending_acceptance
yq eval '.active_work_items = ["WI-001"]' -i "$TMP_REPO/change/demo/meta.yaml"
expect_fail_cmd 'Testing phase requires active_work_items = []' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" set-active-work-items WI-001 demo"
write_testing_state_with_pending_acceptance

write_deployment_state
yq eval '.active_work_items = ["WI-001"]' -i "$TMP_REPO/change/demo/meta.yaml"
expect_fail_cmd 'Deployment phase requires active_work_items = []' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate metadata-consistency"
rm -f "$TMP_REPO/change/demo/deployment.md"

cat > "$TMP_REPO/change/demo/spec.md" <<'EOF'
# spec.md

## Default Read Layer

### Intent Summary
- Problem: auth entrypoint is missing
- Goals:
  - Provide a stable login boundary
- Non-goals:
  - Add extra auth flows
- Must-have Anchors:
  - login(token) returns ok
- Prohibition Anchors:
  - no contract churn during implementation
- Success Anchors:
  - ACC-001 passes
- Boundary Alerts:
  - auth contract is frozen
- Unresolved Decisions:
  - none

### Input Intake Summary
- input_maturity: L1
- input_refs:
  - docs/inputs/add-auth.md#intent
- input_owner: human
- approval_basis: owner approved intake for auth scope
- normalization_status: anchored

### Requirements Quick Index
- Proposal Coverage Map: maintain in `## Requirements`
- Clarification Status: maintain in `## Requirements`
- Requirements Index:
  - REQ-001: login validates token

### Acceptance Index
- ACC-001 -> REQ-001

### Verification Index
- VO-001 -> ACC-001

### Appendix Map
- none: never

<!-- SKELETON-END -->

## Intent

### Problem / Background
Need a minimal auth entrypoint.

### Goals
- Add a stable login boundary.

### Non-goals
- Add logout or profile flows.

### Must-have Anchors
- login(token) returns ok.

### Prohibition Anchors
- Do not expand auth scope.

### Success Anchors
- ACC-001 has pass evidence.

### Boundary Alerts
- Shared auth contract is frozen.

### Unresolved Decisions
- none

### Input Intake
- input_maturity: L1
- input_refs:
  - docs/inputs/add-auth.md#intent
- input_owner: human
- approval_basis: owner approved intake for auth scope
- normalization_status: anchored

### Testing Priority Rules
- P0: must be automated for safety, money, data integrity, or core flow
- P1: prefer automated; otherwise must have manual or equivalent pass evidence
- P2: may use manual or equivalent verification, but still requires a pass result

## Requirements

### Proposal Coverage Map
- login flow -> REQ-001

### Clarification Status
- Closed login happy path smoke

### Functional Requirements
- REQ-001
  - summary: login(token) returns ok for a valid token
  - rationale: provide a canonical auth entrypoint

### Constraints / Prohibitions
- auth contract must remain stable during implementation

### Non-functional Requirements
- [Only include if measurable]

## Acceptance

- acc_id: ACC-001
  source_ref: REQ-001
  expected_outcome: login(token) returns ok
  priority: P0
  priority_rationale: core auth flow
  status: approved

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - login(token) returns ok
  artifact_expectation: testing.md pass record for ACC-001
EOF
expect_fail_cmd 'proposal anchor not closed in Requirements: Add a stable login boundary.' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate spec-completeness"
write_implementation_state

yq eval '(.dummy = "dummy")' -i "$TMP_REPO/change/demo/work-items/WI-001.yaml"
yq eval 'del(.dummy) | .acceptance_refs = ["ACC-999"]' -i "$TMP_REPO/change/demo/work-items/WI-001.yaml"
expect_fail_cmd 'design/work-item acceptance mismatch for WI-001' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate design-structure-complete"
write_implementation_state

write_testing_state_with_pending_acceptance
trace_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" check-gate trace-consistency)"
assert_contains "$trace_output" 'trace-consistency gate passed'

yq eval '(.[] | select(.acceptance_ref == "ACC-001") | .verification_type) = "manual"' -i "$TMP_REPO/change/demo/testing.md"
expect_fail_cmd 'P0 acceptance ACC-001 must use automated verification' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate testing-coverage"
write_testing_state_with_pending_acceptance
verification_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" check-gate verification)"
assert_contains "$verification_output" 'testing-coverage gate passed'
assert_contains "$verification_output" 'verification gate passed'

cat > "$TMP_REPO/change/demo/spec.md" <<'EOF'
# spec.md

## Default Read Layer

### Intent Summary
- Problem: auth entrypoint is missing
- Goals:
  - Provide a stable login boundary
- Non-goals:
  - Add extra auth flows
- Must-have Anchors:
  - login(token) returns ok
- Prohibition Anchors:
  - no contract churn during implementation
- Success Anchors:
  - metadata acceptance can remain manual-equivalent
- Boundary Alerts:
  - auth contract is frozen
- Unresolved Decisions:
  - none

### Input Intake Summary
- input_maturity: L1
- input_refs:
  - docs/inputs/add-auth.md#intent
- input_owner: human
- approval_basis: owner approved intake for auth scope
- normalization_status: anchored

### Requirements Quick Index
- Proposal Coverage Map: maintain in `## Requirements`
- Clarification Status: maintain in `## Requirements`
- Requirements Index:
  - REQ-001: login validates token

### Acceptance Index
- ACC-001 -> REQ-001
- ACC-002 -> REQ-001

### Verification Index
- VO-001 -> ACC-001
- VO-002 -> ACC-002

### Appendix Map
- none: never

<!-- SKELETON-END -->

## Intent

### Problem / Background
Need a minimal auth entrypoint.

### Goals
- Add a stable login boundary.

### Non-goals
- Add logout or profile flows.

### Must-have Anchors
- login(token) returns ok.

### Prohibition Anchors
- Do not expand auth scope.

### Success Anchors
- metadata acceptance can remain manual-equivalent.

### Boundary Alerts
- Shared auth contract is frozen.

### Unresolved Decisions
- none

### Input Intake
- input_maturity: L1
- input_refs:
  - docs/inputs/add-auth.md#intent
- input_owner: human
- approval_basis: owner approved intake for auth scope
- normalization_status: anchored

### Testing Priority Rules
- P0: must be automated for safety, money, data integrity, or core flow
- P1: prefer automated; otherwise must have manual or equivalent pass evidence
- P2: may use manual or equivalent verification, but still requires a pass result

## Requirements

### Proposal Coverage Map
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Add a stable login boundary.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: login(token) returns ok.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Do not expand auth scope.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: metadata acceptance can remain manual-equivalent.
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/add-auth.md#intent
  anchor_ref: Shared auth contract is frozen.
  target_ref: REQ-001
  status: covered

### Clarification Status
- clr_id: CLR-001
  source_ref: docs/inputs/add-auth.md#intent
  status: resolved
  impact: low
  owner: human
  next_action: none

### Functional Requirements
- REQ-001
  - summary: login(token) returns ok for a valid token
  - rationale: provide a canonical auth entrypoint

### Constraints / Prohibitions
- auth contract must remain stable during implementation

### Non-functional Requirements
- [Only include if measurable]

## Acceptance

- acc_id: ACC-001
  source_ref: REQ-001
  expected_outcome: login(token) returns ok
  priority: P0
  priority_rationale: core auth flow
  status: approved

- acc_id: ACC-002
  source_ref: REQ-001
  expected_outcome: login(token) exposes extra metadata
  priority: P2
  priority_rationale: optional future behavior
  status: approved

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - login(token) returns ok
  artifact_expectation: testing.md pass record for ACC-001

- vo_id: VO-002
  acceptance_ref: ACC-002
  verification_type: equivalent
  verification_profile: focused
  obligations:
    - metadata behavior is verified through equivalent evidence
  artifact_expectation: testing.md pass record for ACC-002
EOF
cat > "$TMP_REPO/change/demo/testing.md" <<'EOF'
- acceptance_ref: ACC-001
  verification_type: automated
  artifact_ref: smoke/test/login
  result: pass
  residual_risk: none
  reopen_required: false
- acceptance_ref: ACC-002
  verification_type: equivalent
  artifact_ref: smoke/equivalent/metadata-review
  result: pass
  residual_risk: none
  reopen_required: false
EOF
p2_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" check-gate testing-coverage)"
assert_contains "$p2_output" 'testing-coverage gate passed'
write_testing_state_with_pending_acceptance

pre_push_output="$(cd "$TMP_REPO" && CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" ./.codespec/hooks/pre-push)"
assert_contains "$pre_push_output" 'pre-push checks passed'

expect_fail_cmd 'missing deployment.md' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" start-deployment demo"
cat > "$TMP_REPO/change/demo/deployment.md" <<'EOF'
# deployment.md

## Deployment Plan
target_env: STAGING
deployment_date: 2026-04-07
deployment_method: manual

## Pre-deployment Checklist
- [x] all acceptance items passed
- [x] required migrations verified
- [x] rollback plan prepared
- [x] smoke checks prepared

## Deployment Steps
1. deploy the release artifact
2. run smoke validation

## Verification Results
- smoke_test: pass
- key_features: [login]
- performance: [within baseline]

## Acceptance Conclusion
status: pass
notes: deployment accepted
approved_by: smoke
approved_at: 2026-04-07

## Rollback Plan
trigger_conditions:
  - login flow fails
rollback_steps:
  1. restore previous release

## Monitoring
metrics:
  - auth login success rate
alerts:
  - auth login failure spike

## Post-deployment Actions
- [x] update related docs
- [x] record lessons learned if needed
- [x] archive change dossier to versions/
EOF

yq eval '(.[] | select(.acceptance_ref == "ACC-001") | .result) = "fail"' -i "$TMP_REPO/change/demo/testing.md"
expect_fail_cmd 'testing.md does not have a passing record for ACC-001' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" start-deployment demo"
write_testing_state_with_pending_acceptance
cat > "$TMP_REPO/change/demo/deployment.md" <<'EOF'
# deployment.md

## Deployment Plan
target_env: STAGING
deployment_date: YYYY-MM-DD
deployment_method: manual

## Pre-deployment Checklist
- [ ] all acceptance items passed
- [ ] required migrations verified
- [ ] rollback plan prepared
- [ ] smoke checks prepared

## Deployment Steps
1. [step]
2. [step]

## Verification Results
- smoke_test: pass
- key_features: []
- performance: []

## Acceptance Conclusion
status: pass
notes: [deployment conclusion]
approved_by: [name]
approved_at: YYYY-MM-DD

## Rollback Plan
trigger_conditions:
  - [condition]
rollback_steps:
  1. [step]

## Monitoring
metrics:
  - [metric]
alerts:
  - [alert]

## Post-deployment Actions
- [ ] update related docs
- [ ] record lessons learned if needed
- [ ] archive change dossier to versions/
EOF
expect_fail_cmd 'deployment.md contains placeholder value' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate deployment-readiness"
cat > "$TMP_REPO/change/demo/deployment.md" <<'EOF'
# deployment.md

## Deployment Plan
target_env:
deployment_date: 2026-04-07
deployment_method: manual

## Pre-deployment Checklist
- [x] all acceptance items passed
- [x] required migrations verified
- [x] rollback plan prepared
- [x] smoke checks prepared

## Deployment Steps
1. deploy the release artifact
2. run smoke validation

## Verification Results
- smoke_test: pass
- key_features: [login]
- performance: [within baseline]

## Acceptance Conclusion
status: pass
notes: deployment accepted
approved_by: smoke
approved_at: 2026-04-07

## Rollback Plan
trigger_conditions:
  - login flow fails
rollback_steps:
  1. restore previous release

## Monitoring
metrics:
  - auth login success rate
alerts:
  - auth login failure spike

## Post-deployment Actions
- [x] update related docs
- [x] record lessons learned if needed
- [x] archive change dossier to versions/
EOF
expect_fail_cmd 'deployment.md target_env is missing' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" check-gate deployment-readiness"
rm -f "$TMP_REPO/change/demo/deployment.md"
expect_fail_cmd 'missing deployment.md' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" CODESPEC_REQUIRE_DEPLOYMENT_FILE=1 \"$TMP_REPO/.codespec/codespec\" check-gate deployment-readiness"
write_deployment_state

promotion_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" check-gate promotion)"
assert_contains "$promotion_output" 'deployment-readiness gate passed'
assert_contains "$promotion_output" 'promotion-criteria gate passed'
CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" complete-change demo >/dev/null
[ "$(yq eval '.status' "$TMP_REPO/change/demo/meta.yaml")" = 'completed' ] || die 'complete-change did not set status'

start_deployment_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" CODESPEC_CONTAINER="demo" "$TMP_REPO/.codespec/codespec" start-deployment demo)"
assert_contains "$start_deployment_output" 'started Deployment phase: change/demo'

yq eval '(.[] | select(.acceptance_ref == "ACC-001") | .result) = "fail"' -i "$TMP_REPO/change/demo/testing.md"
expect_fail_cmd 'testing.md does not have a passing record for ACC-001' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" \"$TMP_REPO/.codespec/codespec\" complete-change demo"
yq eval '(.[] | select(.acceptance_ref == "ACC-001") | .result) = "pass"' -i "$TMP_REPO/change/demo/testing.md"
rm -f "$TMP_REPO/change/demo/deployment.md"
write_deployment_state

CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" promote-version v1.0.1 demo >/dev/null
git -C "$TMP_REPO" add -A versions/v1.0.1
expect_fail_cmd 'is forbidden by WI-001' "cd \"$TMP_REPO\" && yq eval '.phase = \"Implementation\" | .status = \"in_progress\" | .focus_work_item = \"WI-001\" | .active_work_items = [\"WI-001\"]' -i change/demo/meta.yaml && CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" ./.codespec/hooks/pre-commit"
git -C "$TMP_REPO" reset -q -- versions/v1.0.1
rm -rf "$TMP_REPO/versions/v1.0.1"

expect_fail_cmd 'complete-change requires Deployment phase' "CODESPEC_PROJECT_ROOT=\"$TMP_REPO\" CODESPEC_CONTAINER=\"demo\" rm -f \"$TMP_REPO/change/demo/deployment.md\" && \"$TMP_REPO/.codespec/codespec\" complete-change demo"
write_deployment_state
cp -R "$TMP_REPO/change/demo/." "$TMP_REPO/change/extra/"

promote_output="$(CODESPEC_PROJECT_ROOT="$TMP_REPO" "$TMP_REPO/.codespec/codespec" promote-version v1.0.0 demo)"
assert_contains "$promote_output" 'promoted container dossier'
assert_contains "$promote_output" 'target: versions/v1.0.0'
[ -f "$TMP_REPO/versions/v1.0.0/meta.yaml" ] || die 'promote-version did not create versions/v1.0.0/meta.yaml'
[ -f "$TMP_REPO/versions/v1.0.0/spec.md" ] || die 'promote-version did not copy spec.md'
[ -f "$TMP_REPO/versions/v1.0.0/design.md" ] || die 'promote-version did not copy design.md'
[ -f "$TMP_REPO/versions/v1.0.0/testing.md" ] || die 'promote-version did not copy testing.md'
[ -f "$TMP_REPO/versions/v1.0.0/deployment.md" ] || die 'promote-version did not copy deployment.md'
[ -f "$TMP_REPO/versions/v1.0.0/work-items/WI-001.yaml" ] || die 'promote-version did not copy work item files'
[ "$(yq eval '.status' "$TMP_REPO/versions/v1.0.0/meta.yaml")" = 'completed' ] || die 'promoted meta.yaml status is not completed'
[ "$(yq eval '.focus_work_item' "$TMP_REPO/versions/v1.0.0/meta.yaml")" = 'null' ] || die 'promoted meta.yaml focus_work_item is not null'
[ "$(yq eval '.updated_by' "$TMP_REPO/versions/v1.0.0/meta.yaml")" = 'codespec-promote' ] || die 'promoted meta.yaml updated_by is not codespec-promote'

log '✓ smoke script passed'
