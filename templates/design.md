# design.md

## Default Read Layer

### Goal / Scope Link
- spec_refs:
  - REQ-001
- acceptance_refs:
  - ACC-001
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
- dependency_summary:
  - WI-001: no dependency
- parallel_recommendation:
  - Group A: WI-001
- notes:
  - [execution note]

### Design Slice Index
- DS-001 -> [slice summary]

### Work Item Derivation
- wi_id: WI-001
  goal: [execution slice goal]
  covered_acceptance_refs: [ACC-001]
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

### Dependency Summary
- WI-001: no dependency

### Parallel Recommendation
- Group A: WI-001

### Notes
- [execution note]

## Design Slice Index
- DS-001:
  - appendix_ref: design-appendices/DD-001.md
  - scope: [slice scope]
  - acceptance_refs: [ACC-001]

## Work Item Derivation
- wi_id: WI-001
  goal: [execution slice goal]
  covered_acceptance_refs: [ACC-001]
  dependency_refs: []
  contract_needed: false
  notes_on_boundary: [boundary note]

## Contract Needs
- contract_id: [optional]
  required: false
  reason: [why]
  consumers: []

## Verification Design
- ACC-001:
  - approach: [how it will be verified]
  - evidence: [expected artifact]

## Failure Paths / Reopen Triggers
- [when to reopen spec]
- [when to reopen design]

## Appendix Map
- design-appendices/DD-001.md: [when deeper drill-down is needed]
