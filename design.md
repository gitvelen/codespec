# design.md

## Summary

[简要说明方案核心、关键边界、以及为什么这是最小可行实现。]

## Technical Approach

[Describe the implementation approach and key technical decisions.]

## Boundaries & Impacted Surfaces

- system_context: [current flow or subsystem entrypoint]
- impacted_surfaces:
  - [surface]
- out_of_scope:
  - [surface or behavior that must remain untouched]

## Execution Model

- mode: single-branch
- rationale: [why this execution model is enough]

## Work Item Mapping

- wi_id: WI-001
  requirement_refs: [REQ-001]
  acceptance_refs: [ACC-001]
  summary: [slice summary]

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

## Verification Design

- ACC-001:
  - approach: [how it will be verified]
  - evidence: [expected artifact]

## Reopen Triggers

- [when spec/design must be reopened]
