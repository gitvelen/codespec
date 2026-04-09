# spec.md

## Default Read Layer

### Intent Summary
- Problem: [一句话描述问题]
- Goals:
  - [G1]
- Non-goals:
  - [NG1]
- Must-have Anchors:
  - [A1]
- Prohibition Anchors:
  - [P1]
- Success Anchors:
  - [S1]
- Boundary Alerts:
  - [B1]
- Unresolved Decisions:
  - [D1]

### Input Intake Summary
- input_maturity: L1
- input_refs:
  - docs/inputs/example.md#intent
- input_owner: human
- approval_basis: owner approved intake for scope refinement
- normalization_status: anchored

### Requirements Quick Index
- Proposal Coverage Map: maintain in `## Requirements`
- Clarification Status: maintain in `## Requirements`
- Requirements Index:
  - REQ-001: [short summary]

### Acceptance Index
- ACC-001 -> REQ-001

### Verification Index
- VO-001 -> ACC-001

### Appendix Map
- [appendix-name]: [when to read]

<!-- SKELETON-END -->

## Intent

### Problem / Background
[Describe the problem being solved.]

### Goals
- [Goal 1]

### Non-goals
- [Non-goal 1]

### Must-have Anchors
- [Anchor 1]

### Prohibition Anchors
- [Prohibition 1]

### Success Anchors
- [Success anchor 1]

### Boundary Alerts
- [Boundary alert 1]

### Unresolved Decisions
- [Decision 1]

### Input Intake
- input_maturity: L1
- input_refs:
  - docs/inputs/example.md#intent
- input_owner: human
- approval_basis: owner approved intake for scope refinement
- normalization_status: anchored

### Testing Priority Rules
- P0: must be automated for safety, money, data integrity, or core flow
- P1: prefer automated; otherwise must have manual or equivalent pass evidence
- P2: may use manual or equivalent verification, but still requires a pass result

## Requirements

### Proposal Coverage Map
- source_ref: docs/inputs/example.md#intent
  anchor_ref: [Goal 1]
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/example.md#intent
  anchor_ref: [Anchor 1]
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/example.md#intent
  anchor_ref: [Prohibition 1]
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/example.md#intent
  anchor_ref: [Success anchor 1]
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/example.md#intent
  anchor_ref: [Boundary alert 1]
  target_ref: REQ-001
  status: covered
- source_ref: docs/inputs/example.md#intent
  anchor_ref: [Decision 1]
  target_ref: CLR-001
  status: needs-clarification

### Clarification Status
- clr_id: CLR-001
  source_ref: docs/inputs/example.md#intent
  status: deferred
  impact: medium
  owner: human
  next_action: resolve before design freeze

### Functional Requirements
- REQ-001
  - summary: [formal requirement]
  - rationale: [why this exists]

### Constraints / Prohibitions
- [Constraint 1]

### Non-functional Requirements
- [Only include if measurable]

## Acceptance

- acc_id: ACC-001
  source_ref: REQ-001
  expected_outcome: [observable outcome]
  priority: P0
  priority_rationale: [why this priority applies]
  status: approved

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - [what must be verified]
  artifact_expectation: [test path, command, or evidence shape]
