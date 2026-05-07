# deployment.md

<!-- CODESPEC:DEPLOYMENT:READING -->
## 0. AI 阅读契约

- 本文件记录本次变更的真实交付、运行验证、回滚准备和人工验收结论。
- `release_mode=runtime` 表示需要运行部署；`artifact` 表示交付构建产物、文档或配置；`manual` 表示由人工执行交付步骤。
- 本文件不重复设计中的环境与安全要求，只引用并证明本次交付是否满足。
- `manual_verification_ready: pass` 只表示可以开始人工验收，不表示人工验收通过。

<!-- CODESPEC:DEPLOYMENT:TARGET -->
## 1. 发布对象与环境

release_mode: runtime
target_env: pending
deployment_date: YYYY-MM-DD
design_environment_ref: design.md#6-横切设计
release_artifact: pending

<!-- CODESPEC:DEPLOYMENT:PRECONDITIONS -->
## 2. 发布前条件

- [ ] all required TC full-integration records passed
- [ ] deployment-only/manual TC evidence plan prepared
- [ ] required migrations verified
- [ ] rollback plan prepared
- [ ] smoke checks prepared

<!-- CODESPEC:DEPLOYMENT:EXECUTION -->
## 3. 执行证据

status: pending
execution_ref: pending
deployment_method: pending
deployed_at: pending
deployed_revision: pending
source_revision: pending
restart_required: pending
restart_reason: pending
runtime_observed_revision: pending
runtime_ready_evidence: pending

<!-- CODESPEC:DEPLOYMENT:VERIFY -->
## 4. 运行验证

smoke_test: pending
runtime_ready: pending
manual_verification_ready: pending

说明：`release_mode=artifact|manual` 时，`runtime_ready` 可填写 `not-applicable`，但必须提供 `release_artifact` 与可复核执行证据。

<!-- CODESPEC:DEPLOYMENT:ROLLBACK -->
## 5. 回滚与监控

rollback_trigger_conditions:
  - [replace with real condition]
rollback_steps:
  1. [replace with real step]
monitoring_metrics:
  - [replace with real metric]
monitoring_alerts:
  - [replace with real alert]

<!-- CODESPEC:DEPLOYMENT:ACCEPTANCE -->
## 6. 人工验收与收口

status: pending
notes: pending manual acceptance
approved_by: pending
approved_at: pending

<!-- CODESPEC:DEPLOYMENT:POST_ACTIONS -->
## 7. 收口动作

post_deployment_actions:
  - [ ] update related docs
  - [ ] record lessons learned if needed
  - [ ] submit PR or archive stable version after manual acceptance
