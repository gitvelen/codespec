# deployment.md

## Deployment Plan
target_env: staging
deployment_date: YYYY-MM-DD
deployment_method: manual

## Pre-deployment Checklist
- [ ] all acceptance items passed
- [ ] required migrations verified
- [ ] rollback plan prepared
- [ ] smoke checks prepared

## Deployment Steps
1. [replace with real step]
2. [replace with real step]

## Verification Results
- smoke_test: pass
- key_features: [replace with verified features]
- performance: [replace with observed result]

## Acceptance Conclusion

此部分总结 testing.md 中的验收结果：

**字段定义**：
- `status`: 最终验收状态
  - `pass`: 所有 approved acceptance 都有 test_scope=full-integration 且 result=pass 的记录，且所有 residual_risk 都不是 high
  - `fail`: 任何 approved acceptance 没有通过或有 residual_risk=high（testing-coverage gate 会拒绝 residual_risk=high）
- `notes`: 部署结论和风险说明
- `approved_by`: 批准人
- `approved_at`: 批准日期

**前置条件**：
- testing.md 中每个 approved acceptance 都必须有至少一条 test_scope=full-integration 且 result=pass 的记录
- 所有 residual_risk 都已被评估和记录
- 没有 reopen_required=true 的测试记录（如果有，必须先重新开启 spec/design）

**与 testing.md 的对应关系**：
- deployment.md 的 status=pass 依赖于 testing.md 中所有 acceptance 的测试结果
- 只有当所有 acceptance 都通过 full-integration 测试时，才能标记为 pass

---

status: pass
notes: [replace with deployment conclusion]
approved_by: [replace with approver]
approved_at: YYYY-MM-DD

## Rollback Plan
trigger_conditions:
  - [replace with real condition]
rollback_steps:
  1. [replace with real step]

## Monitoring
metrics:
  - [replace with real metric]
alerts:
  - [replace with real alert]

## Post-deployment Actions
- [ ] update related docs
- [ ] record lessons learned if needed
- [ ] archive change dossier to versions/
