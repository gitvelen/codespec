# Contract Template

## 使用说明

**字段定义**：
- `contract_id`: 契约唯一标识
- `status`: 契约状态
  - `draft`: 草稿状态，可以修改
  - `frozen`: 冻结状态，不能修改（只能在 parent feature 分支冻结）
- `frozen_at`: 冻结时间戳（status=frozen 时必须填写）
- `consumers`: 引用此契约的 work-item ID 列表
  - 对应 work-items/WI-*.yaml 中的 `contract_refs` 字段

**状态转移规则**：
1. 新建契约时，status=draft，frozen_at=null
2. 在 parent feature 分支进行显式 review 后，可以冻结：status=frozen，frozen_at=<timestamp>
3. 冻结后的契约不能修改（pre-commit hook 会阻止）
4. 执行分支不能直接新增 frozen 契约（contract-boundary gate 会拒绝）

**与 work-item.yaml 的对应关系**：
- contract.md 的 `consumers` 字段列出所有引用此契约的 WI
- work-item.yaml 的 `contract_refs` 字段列出该 WI 依赖的所有契约
- 两者必须保持一致（contract-boundary gate 会自动检查双向引用一致性）

---

contract_id: [contract-id]
status: draft
# status flow: draft -> frozen only after explicit review
frozen_at: null
consumers: [WI-001]

## Interface Definition
[Define the shared boundary exactly.]

## Notes
- preconditions: [if any]
- postconditions: [if any]
- invariants: [if any]
