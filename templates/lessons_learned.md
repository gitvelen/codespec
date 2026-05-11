# Lessons Learned

## 快速索引（硬规则）
- **R1**（scope）：修改文件前必须检查是否在 design.md §4 可修改路径中
- **R2**（测试）：每个 approved acceptance 都必须有 `TC-*` 测试用例，必测 `TC-*` 最终必须有对应阶段的 `RUN-* result: pass`
- **R3**（偏离）：Design 改变 Spec 时必须先回写 Spec
- **R4**（appendix 契约）：若 spec/design 使用 appendices，阅读契约必须用矩阵写清每类附件的读取触发、权威边界和冲突处理；附件是正文的重要索引和强证据展开层，命中领域时必须读，但不得默认一股脑读取全部附件，也不能承载正式 REQ/ACC/VO 或新增产品口径
- **R5**（验证分工）：`spec.md` 的 `VO-*` 只定义验证义务和证据类型，`testing.md` 的 `TC-*` 只定义可执行场景、fixture、命令和 RUN 证据；两者冲突时以 `REQ/ACC/VO` 为准并回写测试计划
- **R6**（正向形态与下游冷启动深度）：任何阶段的正式文档不能只写边界、排除项和职责名，必须说清"要做成什么样"让下游冷启动即可展开。通用判定：下游只读本阶段正式文档能否直接动手——答不出就回写或追问，不得以"下阶段再细化"掩盖缺口
- **R7**（Agent 协作设计不可退化为能力卡）：多 Agent 系统必须分别设计"岗位能力"和"协作机制"。不得把"独立"默认为读隔离；必须先确认独立性指能力、责任、产物署名、过程隔离还是数据隔离
- **R8**（Design 必须交付运行语义而非对象清单）：复杂系统的 Design 不能只写原则、对象模型、职责边界、字段清单、接口名或测试报告名，必须同时交付 `Runbook / Contract / View / Verification` 四层实现输入。机器 gate 通过只代表结构最低门槛，不能替代人工语义复审
- **R9**（gate/生命周期命令必须证明能失败且不写坏状态）：新增或修改任何 phase gate、hook、review 自动化、`reopen-*`、`start-*`、`set-*` 等框架校验或状态迁移命令时，不能只证明正向文档能通过；必须为声称覆盖的缺陷类型加入负例 fixture、突变测试或 `expect_fail`，证明 gate 能拦住"结构合法但语义缺失"的样本，且状态迁移命令不能把 `meta.yaml` / evidence ledger 写成不一致状态
- **R10**（实现完成必须分级）：任何 slice/ACC/RUN 不得只写 `pass`，必须声明完成等级：`fixture_contract / in_memory_domain / api_connected / db_persistent / integrated_runtime / owner_verified`
- **R11**（真实集成门槛）：`full-integration` 必须启动或等价验证真实依赖边界。若只跑 pytest/vitest/static scan，只能标为 branch-local 或 fixture integration，不得记录为 `full-integration`
- **R12**（gate 不得忽略 dirty worktree）：scope / verification / contract-boundary / promotion 类 gate 必须检查 tracked dirty、untracked、staged、unstaged 文件；存在未提交实现或证据时不得输出 `no changed files` 或允许完成
- **R13**（报告不能自证 pass）：verification report 的 `result: pass` 必须由测试断言真实行为得出，不能由 report builder 常量生成；测试不得只验证报告字段存在和 `result == pass`，必须同时验证触发输入、执行路径、失败路径和可复核 artifact
- **R14**（authority repair path）：Implementation / Testing / Deployment 阶段若 gate、hook、review 或 lifecycle 命令发现上游 authority 文档存在必须先修的结构性或语义性缺口，必须通过 `codespec authority-repair begin ...` 进入显式修复态，声明原因和最小 `allowed_paths`；修复态不得扩大产品口径、修改 frozen contract 或夹带实现，关闭前必须重跑对应 gate 与 smoke 并记录证据；未进入修复态时仍阻断越权 authority 修改
- **R15**（主动未完成清单与语义验收）：Implementation / Testing / Deployment 任一轮开发、修复、阶段切换或汇报结束前，必须主动对照当前 design.md §7 slice、design implementation input / appendix、contracts、TC 和 RUN 证据列出未完成项、最高完成等级、阻塞原因和下一步；`fixture_contract` / `api_connected` / branch-local 只能按对应等级表述，fallback/fixture 静默替代真实失败态必须标为未完成，直到加载、空、错、stale、trace/retry、冲突和真实 API 数据路径均有证据；禁止用测试绿灯、dirty gate fail 或缺 owner_verified 的状态包装成”完成”

## 条目列表

### __DATE__｜示例问题
- **触发**： [发生了什么]
- **根因**： [为什么会发生]
- **影响**： [造成了什么影响]
- **改进行动**： [下次如何避免]
- **验证方式**： [如何确认改进生效]
- **升级决策**： [是否升级为硬规则或 hook]
