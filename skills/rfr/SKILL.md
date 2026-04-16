---
name: rfr
description: Use when a codespec change dossier has reviewable phase output and the user wants a strict review-before-advance loop before changing phase, especially after prompts such as review, 复审, 走查, 复查, 阶段验收, or comprehensive check.
---

# RFR 阶段复审闭环

`rfr` 只服务 `codespec`。它负责把阶段复审执行成稳定闭环，不负责重新定义阶段规则。所有阶段切换规则、gate 与阻塞条件，以 `phase-review-policy.md` 为权威源。

用户可见输出默认使用简体中文。

## 先读什么
- 项目根 `phase-review-policy.md`
- 当前 dossier 的 agent 入口文件：`AGENTS.md` 或 `CLAUDE.md`，二选一
- 当前 dossier `meta.yaml`
- 再按当前 `phase` 读取权威文件

如果 `meta.yaml.phase` 与当前工作内容不匹配，先指出错位，不要硬做 review。

## 路径说明
- 实际审查业务项目时，优先读取项目根的 `phase-review-policy.md`
- 在框架源码仓审阅 skill 本身时，对应规则来源是 `templates/phase-review-policy.md`

## 什么时候用
- 用户说“复审”“走查”“复查”“阶段验收”“全面检查”
- 某个 phase 已产出可审查结果，推进下一阶段前要做严格门禁
- 需要的不是普通 code review，而是“发现问题 -> 修明确问题 -> 复审确认是否收敛”

不要用于：
- 纯 brainstorming
- 还没形成可审查产物的阶段
- 只想看一段代码有没有 bug 的普通 review

## 执行顺序
1. 定位 project root、container、current phase、focus work item、execution branch。
2. 先读 `phase-review-policy.md`，再读当前 phase 对应权威文件；不要把 gate pass 当作 phase 已批准。
3. 先跑本 phase 的 gate，记录失败点；不要边扫边修。
4. 按当前 phase 做全量检查，先把问题找全，再统一分级。
5. 只修复“现有权威文件已经把方向限定死”的问题。
6. 重跑相关 gate / 验证，再按同一口径复审，直到 P0/P1 收敛或暴露真实阻塞。

## 阶段提示

### Proposal / 准备进入 Requirements
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- 当前 intent 是否还停留在复述输入，尚未形成可判断目标
- must-have、prohibition、success、boundary 之间是否互相冲突
- 是否把高风险模糊点偷留到 appendix 或“后续再说”

### Requirements / 准备进入 Design
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- `REQ -> ACC -> VO` 是否只是形式闭合，语义上却不对应
- acceptance 是否过大、带多个结果、只能靠主观判断
- deferred clarification 是否会实质改变后续 design boundary

### Design / 准备进入 Implementation
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- architecture boundary 是否真正回答“改哪里、不改哪里、共享面受不受影响”
- work item 是否被切成可执行垂直切片，而不是整块需求原样下发
- 应该建 contract 却没建的共享边界是否被漏掉
- reopen trigger 是否足以约束何时必须回写 spec/design

### Implementation / 准备进入 Testing
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- 是否隐性扩大了 scope 或绕开既定 design slice
- shared boundary 是否只停留在约定，没有落到可复核证据
- testing record 是否只是形式上的 pass，没有真实 artifact/evidence
- 当前实现是否仍能被 `spec.md`、`design.md`、当前 work item 合法解释

### Testing / 准备进入 Deployment
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- pass record 是否真正对应 acceptance expected outcome，而不是实现细节
- `manual` / `equivalent` 证据是否足够支撑第三方复核
- 是否遗漏了 boundary alert 或 prohibition anchor 的验证
- 是否存在 `reopen_required: true` 却仍试图推进 Deployment

### Deployment / 准备 Complete Change 或 Promotion
权威阶段规则：见 `phase-review-policy.md` 对应章节。

额外关注：
- smoke test 是否覆盖关键用户路径，而不是无关检查
- rollback trigger 与 rollback steps 是否真的可执行
- monitoring 的 metrics/alerts 是否能发现本次变更的主要风险
- post-deployment actions 是否形成闭环

## 修复边界
只有同时满足下面条件时才直接修复：
- 修复方向已被 `spec.md`、`design.md`、`work-items/*.yaml`、`testing.md`、`deployment.md` 或 gate 明确限定
- 不会改变产品方向、公共契约、业务规则或 scope 决策
- 能立刻通过命令、测试、文档证据或 gate 重新验证

遇到以下情况必须停下问用户：
- 需要改 acceptance、verification obligation、scope、contract 或对外行为
- 需求、设计、work item 之间互相冲突
- 需要 Accept / Defer 一个 P0/P1
- 需要扩大 allowed_paths 或动 `forbidden_paths`

## 对话输出
至少包含：
- 结论摘要：通过 / 有条件通过 / 不通过；P0 / P1 / P2 数量
- 关键发现：证据、风险、建议修改、验证方式
- 覆盖率与证据：读了哪些权威文件，跑了哪些 gate / 命令，哪些还没覆盖
- 已修复项：修了什么，为什么无需额外产品决策
- 复审结论：是否收敛，剩余风险、阻塞项、待人决策项
