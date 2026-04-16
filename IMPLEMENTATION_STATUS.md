# codespec v2.0 改革实施状态

## 已完成的工作

### ✅ Phase 1: 目录结构改革（部分完成）
- [x] 创建 `scripts/install-workspace.sh` - 在工作区根目录安装共享资源
- [x] 创建 `scripts/init-dossier.sh` - 在项目根目录初始化 dossier
- [x] 更新 `codespec` 主脚本的路径解析函数（find_workspace_root, find_project_root）
- [ ] 删除 `detect_container()` 函数及所有引用（待完成）
- [ ] 更新所有使用 `change/` 路径的代码（待完成，约 100+ 处）

### ✅ Phase 3: design.md 改革（已完成）
- [x] 更新 `templates/design.md`
  - 添加 `Dependency Analysis` 章节
  - 添加 `Parallel Recommendation` 章节
  - 添加 `Branch Strategy Recommendation` 章节
  - 添加 `Shared Surface Analysis` 章节
  - 添加 `Pre-work for Parent Feature Branch` 章节
  - 去掉 `Branch Plan` 章节
- [ ] 更新 `check-gate.sh` 检查新章节（待完成）

### ✅ Phase 4: 文件修改规则（已完成）
- [x] 更新 `hooks/pre-commit`
  - 添加文件修改规则检查
  - 检查是否在执行分支修改受限文件
- [x] 更新 `templates/CLAUDE.md`
  - 添加 File Modification Rules 章节
  - 说明哪些文件只能在 parent feature 分支修改
- [x] 更新 `templates/AGENTS.md`
  - 同步 CLAUDE.md 的更新

### ✅ 文档（已完成）
- [x] 创建 `MIGRATION.md` - 详细的迁移指南
- [x] 创建 `IMPLEMENTATION_STATUS.md` - 本文件

### ⏳ Phase 2: 命令改革（未完成）
需要完成的工作：
- [ ] 删除 `add-container` 命令及相关函数
- [ ] 更新 `init-change` 命令（改名为 `init-dossier`）
- [ ] 更新所有生命周期命令，去掉 `[container]` 参数
  - `start-requirements`
  - `start-design`
  - `start-implementation`
  - `set-active-work-items`
  - `start-testing`
  - `start-deployment`
  - `complete-change`
  - `add-work-item`
  - `materialize-deployment`
  - `promote-version`

### ⏳ Phase 5: 依赖分析增强（未完成）
需要完成的工作：
- [ ] 更新 `templates/design.md` 添加 `confidence` 字段（已在 Phase 3 完成基础结构）
- [ ] 更新 `hooks/pre-commit` 添加依赖检测逻辑

### ⏳ 更新文档（未完成）
需要完成的工作：
- [ ] 更新 `README.md` 反映新的工作流和目录结构
- [ ] 更新所有示例代码

## 剩余工作量估算

### 高优先级（核心功能）
1. **更新 check-gate.sh**（约 2-3 小时）
   - 去掉所有 `change/` 路径引用
   - 去掉 `detect_container()` 调用
   - 更新路径为直接使用 `$PROJECT_ROOT/`
   - 约 50+ 处修改

2. **更新 codespec 主脚本**（约 2-3 小时）
   - 删除 `add-container` 函数
   - 删除 `detect_container` 函数
   - 删除 `list_containers` 函数
   - 更新所有命令去掉 container 参数
   - 更新所有路径引用
   - 约 50+ 处修改

3. **更新 README.md**（约 1 小时）
   - 重写工作流说明
   - 更新所有示例
   - 添加新命令说明

### 中优先级（增强功能）
4. **依赖检测逻辑**（约 1 小时）
   - 在 pre-commit hook 添加依赖 WI 检查

5. **更新 work-item.yaml 模板**（约 30 分钟）
   - 去掉 container 相关字段

### 低优先级（可选）
6. **更新 smoke.sh 测试**（约 1 小时）
   - 适配新的目录结构

7. **创建自动化迁移脚本**（约 2 小时）
   - 帮助用户从 v1.x 迁移到 v2.0

## 当前可用性

### ✅ 可以使用的功能
- 新的工作区安装：`codespec install-workspace`
- 新的 dossier 初始化：`codespec init-dossier`
- 文件修改规则检查（pre-commit hook）
- 新的 design.md 模板
- 迁移指南

### ⚠️ 部分可用的功能
- 旧的命令仍然可以使用，但使用旧的目录结构（`change/`）
- check-gate 仍然使用旧的路径

### ❌ 不可用的功能
- 完整的新工作流（因为 codespec 主脚本和 check-gate.sh 未完全更新）

## 建议的完成策略

### 选项 A：完整实施（推荐）
继续完成所有剩余工作，预计需要 8-10 小时。完成后发布 v2.0.0。

### 选项 B：分阶段发布
1. 当前状态发布为 v2.0.0-alpha
2. 提供迁移指南和新命令
3. 逐步完成剩余工作
4. 发布 v2.0.0-beta, v2.0.0-rc, v2.0.0

### 选项 C：混合模式
保留旧命令的兼容性，同时提供新命令。用户可以选择何时迁移。

## 测试计划

完成后需要测试：
1. 单分支工作流
2. 多分支并行工作流
3. 文件修改规则检查
4. 所有生命周期命令
5. check-gate 所有 gates
6. 迁移流程

## 风险评估

### 高风险
- check-gate.sh 的修改可能影响所有 gates
- codespec 主脚本的修改可能影响所有命令

### 中风险
- 路径引用的遗漏可能导致运行时错误

### 低风险
- 文档更新
- 模板更新

## 下一步行动

建议按以下顺序完成：
1. 更新 check-gate.sh（最关键）
2. 更新 codespec 主脚本（最关键）
3. 测试核心功能
4. 更新 README.md
5. 添加依赖检测
6. 完整测试
7. 发布 v2.0.0
