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
    notes: [why this design remains aligned]

### Architecture Boundary
- impacted_capabilities:
  - [capability]
- not_impacted_capabilities:
  - [capability]
- impacted_shared_surfaces:
  - [surface]
- not_impacted_shared_surfaces:
  - [surface]
- major_constraints:
  - [constraint]
- contract_required: false
- compatibility_constraints:
  - [constraint]

### Work Item Execution Strategy

#### Dependency Analysis
dependency_graph:
  WI-001:
    depends_on: []
    blocks: []
    confidence: high

#### Parallel Recommendation
parallel_groups:
  - group: G1
    work_items: [WI-001]
    can_parallel: false
    rationale: [rationale]

#### Branch Strategy Recommendation
recommended_branch_count: 1
rationale: |
  [Why single branch is recommended]

alternative_if_parallel_needed: |
  [Alternative parallel strategy if needed]

**Note**: The above three sections (Dependency Analysis, Parallel Recommendation, Branch Strategy Recommendation) 
are suggestions only, not enforced by gates. User decides the actual execution strategy.

#### Shared Surface Analysis
potentially_conflicting_files:
  - path: [file-path]
    reason: [why multiple WIs might modify this]
    recommendation: [how to avoid conflicts]

conflict_risk_assessment:
  high_risk: []
  medium_risk: []
  low_risk: []

#### Pre-work for Parent Feature Branch
tasks:
  - task: [task description]
    content: |
      [code or content to add]
    rationale: [why this prevents conflicts]

#### Notes
- [execution note]

### Design Slice Index
- DS-001 -> [slice summary]

### Work Item Derivation
- wi_id: WI-001
  input_refs:
    - docs/inputs/example.md#intent
  requirement_refs:
    - REQ-001
  goal: [execution slice goal]
  covered_acceptance_refs: [ACC-001]
  verification_refs:
    - VO-001
  dependency_refs: []
  contract_needed: false
  notes_on_boundary: [boundary note]

### Contract Needs
- [none or contract decision]

### Failure Paths / Reopen Triggers
- [trigger 1]

### Appendix Map
- DD-001.md -> [when to read]

## Goal / Scope Link

### Scope Summary
- [high-level scope]

### spec_alignment_check
- spec_ref: REQ-001
  aligned: true
  notes: [alignment note]

## Architecture Boundary
- system_context: [context]
- impacted_capabilities:
  - [capability]
- not_impacted_capabilities:
  - [capability]
- impacted_shared_surfaces:
  - [surface]
- not_impacted_shared_surfaces:
  - [surface]
- major_constraints:
  - [constraint]
- contract_required: false
- compatibility_constraints:
  - [constraint]

## Work Item Execution Strategy

### Dependency Analysis
dependency_graph:
  WI-001:
    depends_on: []
    blocks: []
    confidence: high

### Parallel Recommendation
parallel_groups:
  - group: G1
    work_items: [WI-001]
    can_parallel: false
    rationale: [rationale]

### Branch Strategy Recommendation
recommended_branch_count: 1
rationale: |
  [Why single branch is recommended]

alternative_if_parallel_needed: |
  [Alternative parallel strategy if needed]

**Note**: The above three sections (Dependency Analysis, Parallel Recommendation, Branch Strategy Recommendation) 
are suggestions only, not enforced by gates. User decides the actual execution strategy.

### Shared Surface Analysis
potentially_conflicting_files:
  - path: [file-path]
    reason: [why multiple WIs might modify this]
    recommendation: [how to avoid conflicts]

conflict_risk_assessment:
  high_risk: []
  medium_risk: []
  low_risk: []

### Pre-work for Parent Feature Branch
tasks:
  - task: [task description]
    content: |
      [code or content to add]
    rationale: [why this prevents conflicts]

### Notes
- [execution note]

## Design Slice Index
- DS-001:
  - appendix_ref: design-appendices/DD-001.md
  - scope: [slice scope]
  - requirement_refs: [REQ-001]
  - acceptance_refs: [ACC-001]
  - verification_refs: [VO-001]

## Work Item Derivation
- wi_id: WI-001
  input_refs:
    - docs/inputs/example.md#intent
  requirement_refs:
    - REQ-001
  goal: [execution slice goal]
  covered_acceptance_refs: [ACC-001]
  verification_refs:
    - VO-001
  dependency_refs: []
  contract_needed: false
  notes_on_boundary: [boundary note]
  work_item_alignment: keep equal to work-items/WI-001.yaml acceptance_refs

## Contract Needs
- contract_id: [optional]
  required: false
  reason: [why]
  consumers: []

## Implementation Readiness Baseline

### Environment Configuration Matrix
- [environment config item]

### Security Baseline
- [security baseline item]

### Data / Migration Strategy
- [data or migration strategy item]

### Operability / Health Checks
- [operability or health check item]

### Backup / Restore
- [backup or restore item]

### UX / Experience Readiness
- [only required when spec defines Experience Acceptance]

## Verification Design
- ACC-001:
  - approach: [how it will be verified]
  - evidence: [expected artifact]

## Failure Paths / Reopen Triggers
- [when to reopen spec]
- [when to reopen design]

## Appendix Map
- design-appendices/DD-001.md: [when deeper drill-down is needed]
