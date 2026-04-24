# spec.md

## Summary

[用 3-5 行说明这次变更的目标、边界和成败标准。不要重复后文条目。]

## Inputs

- source_refs:
  - [稳定的 repo 文件引用，禁止 conversation://]
- source_owner: [需求提出人]
- maturity: L0/L1/L2/L3
- normalization_note: [如何把原始输入整理成当前规格]
- approval_basis: [谁基于什么确认了当前方向]

## Scope

- goal: [目标]
- boundary: [边界]
- out_of_scope: [明确不做]

## Requirements

- REQ-001
  - summary: [需求描述]
  - source_ref: [追溯到 Inputs 中的 source_refs]
  - rationale: [为什么需要]

## Acceptance

- acc_id: ACC-001
  source_ref: REQ-001
  expected_outcome: [可观测结果]
  priority: P0
  priority_rationale: [为什么是这个优先级]
  status: approved

## Verification

- vo_id: VO-001
  acceptance_ref: ACC-001
  verification_type: automated
  verification_profile: focused
  obligations:
    - [what must be verified]
  artifact_expectation: [test path, command, or evidence shape]
