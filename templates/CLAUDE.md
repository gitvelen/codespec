# CLAUDE.md

本项目使用项目内 `./.codespec/codespec` 作为唯一运行时入口。

## 启动顺序
1. 读取 `change/__CONTAINER__/meta.yaml`
2. 先读 `change/__CONTAINER__/spec.md` 的 Default Read Layer，并在 `<!-- SKELETON-END -->` 处先停
3. 再读 `change/__CONTAINER__/design.md` 的 Default Read Layer
4. 如果 `focus_work_item != null`，读取 `change/__CONTAINER__/work-items/<focus_work_item>.yaml`
5. 如果当前 Work Item 的 `contract_refs` 非空，读取对应 `contracts/*.md`
6. 只有在默认层不足以解释当前任务时，才继续下钻 `spec-appendices/` 或 `design-appendices/`

## 默认工作集
Implementation 阶段默认聚焦以下对象：
- 当前 Work Item
- `design.md` 中对应的 Work Item Derivation row
- `design.md` / `design-appendices/` 中对应的 design slice
- 命中边界时再读对应 Contract

## 必须回看 spec.md 的条件
- 可能改变目标、边界、acceptance 或 verification obligations
- 当前 `work-item + design` 已无法稳定解释意图
- 怀疑 Design 已偏离 Spec
- 进入 Testing 前，需要重新确认 acceptance 与 verification obligations

## 必须回看 design.md 的条件
- 切换 `focus_work_item`
- 改动开始触及新的路径、模块或接口边界
- 当前实现方案与既有切片划分不一致
- 需要新增、合并或重新切分 Work Item

## 必须停下的情况
- 需要修改 `forbidden_paths` 中的文件
- 需要实现 `out_of_scope` 中的功能
- 当前 Work Item 无法解释允许修改范围
- 依赖 Work Item 尚未完成，但当前任务需要消费它的结果
- 需要修改 frozen contract
- 测试失败且无法在当前 scope 内修复
- 发现 spec.md 或 design.md 需要回写才能继续

## Gate / Hook 提醒
- `pre-commit` 兜底 `scope` 与 `boundary`
- `pre-push` 兜底 `verification`
- 统一入口：`./.codespec/codespec check-gate <name>`
- 对外最小门禁视图：`spec-completeness`、`design-readiness`、`scope`、`boundary`、`trace-consistency`、`verification`、`promotion`
