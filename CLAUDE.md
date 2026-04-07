# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 工作原则
- 尽量用简体中文交流（除非涉及专业术语）
- 运用第一性原理思考，拒绝经验主义和路径盲从，不要假设我完全清楚目标，保持审慎。
- 从原始需求和问题出发，可以基于底层逻辑对我的原始需求进行“审慎挑战”，若目标模糊请停下和我讨论；若目标清晰但路径非最优，请直接建议路径更优的办法；任务澄清且明确无歧义之后就应该直接执行。

### Compact Instructions 如何保留关键信息
保留优先级：
1. 架构决策，不得摘要
2. 已修改文件和关键变更
3. 验证状态，pass/fail
4. 未解决的 TODO 和回滚笔记
5. 工具输出，可删，只保留 pass/fail 结论
