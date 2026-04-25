# deployment.md

## Deployment Plan
target_env: staging
deployment_date: YYYY-MM-DD

## Pre-deployment Checklist
- [ ] all acceptance items passed
- [ ] required migrations verified
- [ ] rollback plan prepared
- [ ] smoke checks prepared

## Deployment Steps
1. [replace with real step]
2. [replace with real step]

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
- smoke_test: pending
- runtime_ready: pending
- manual_verification_ready: pending

## Acceptance Conclusion

此部分记录人工验收的最终结论：

**字段定义**：
- `status`: 最终验收状态
  - `pending`: 已完成真实部署并达到人工验收就绪，但人工验收尚未给出最终结论
  - `fail`: 人工验收发现问题，需要返工并重新进入 Implementation/Testing/Deployment 闭环
  - `pass`: 人工验收通过；若当前在非默认分支，推荐执行 `codespec submit-pr <stable-version>` 完成交接，也可直接执行 `codespec complete-change <stable-version>` 完成收口并归档稳定版本
- `notes`: 人工验收结论和风险说明
- `approved_by`: 人工验收通过确认人
- `approved_at`: 人工验收通过确认日期

**前置条件**：
- testing.md 中每个 approved acceptance 都必须有至少一条 test_scope=full-integration 且 result=pass 的记录
- 所有 residual_risk 都已被评估和记录
- 没有 reopen_required=true 的测试记录（如果有，必须先重新开启 spec/design）
- `codespec deploy` 已把真实部署结果回写到 `Execution Evidence` 和 `Verification Results`
- `manual_verification_ready: pass` 只表示“可以开始人工验收”，不表示人工验收已通过
- 重新执行 `codespec deploy` 会重置本节为 `pending`，因为新的部署会使旧的人工验收结论失效

**与 testing.md 的对应关系**：
- deployment.md 的 `status=pass` 建立在 testing.md 已满足最终自动化/全量验证前提的基础上
- 若人工验收失败，应使用 `codespec reopen-implementation <WI-ID>` 返回同一 change 的修复回路，而不是 reset 成新 change

---

status: pending
notes: pending manual acceptance
approved_by: pending
approved_at: pending

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
- [ ] submit PR or archive stable version after manual acceptance
