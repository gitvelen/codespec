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
- smoke_test: fail
- key_features: []
- performance: []

## Acceptance Conclusion
status: fail
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
