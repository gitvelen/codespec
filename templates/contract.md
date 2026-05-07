# contract.md

<!-- CODESPEC:CONTRACT:READING -->
## 0. AI 阅读契约

- 只有共享边界需要冻结时才创建契约；普通单 WI 内部实现不要创建本文件。
- `status: frozen` 后执行分支不得修改本契约；需要修改时必须回到 parent feature 分支并重新审查。
- 所有消费者必须在 `consumers` 中列出，并在对应 `work-items/*.yaml` 的 `contract_refs` 中反向引用。

<!-- CODESPEC:CONTRACT:IDENTITY -->
## 1. 契约身份与状态

contract_id: CONTRACT-001
status: draft
frozen_at: null
freeze_review_ref: null
consumers:
  - WI-001
requirement_refs:
  - REQ-001

<!-- CODESPEC:CONTRACT:SHAPE -->
## 2. 接口/数据形状

- surface: [API、事件、数据结构、文件格式或共享模块]
- definition: [字段、参数、返回、错误码、权限或调用约定]

<!-- CODESPEC:CONTRACT:BEHAVIOR -->
## 3. 行为约束

- preconditions:
  - [调用或读写前置条件；没有则写 none]
- postconditions:
  - [完成后的状态保证；没有则写 none]
- invariants:
  - [必须始终成立的约束；没有则写 none]

<!-- CODESPEC:CONTRACT:CHANGE_POLICY -->
## 4. 兼容与变更规则

- compatibility_policy:
  - [向后兼容、迁移、回滚或废弃规则]
- change_policy:
  - [什么情况下允许修改、需要谁审查]

<!-- CODESPEC:CONTRACT:TRACE -->
## 5. 消费方与追溯

- consumer: WI-001
  requirement_refs: [REQ-001]
  usage: [该 WI 如何依赖本契约]
