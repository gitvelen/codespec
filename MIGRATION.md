# codespec v2.0 迁移指南

## 概述

codespec v2.0 对目录结构和工作流进行了重大改革，以更好地匹配实际工作方式。

## 主要变化

### 1. 目录结构变化

**旧版本（v1.x）**：
```
project/
├── .codespec/
├── change/
│   ├── main/
│   │   ├── spec.md
│   │   └── design.md
│   ├── sanguoA/
│   └── sanguoB/
└── src/
```

**新版本（v2.0）**：
```
workspace/                   # 工作区目录
├── .codespec/              # 共享 runtime
├── lessons_learned.md
├── phase-review-policy.md
├── versions/
├── main/                   # Git clone
│   ├── spec.md            # dossier 直接在根目录
│   ├── design.md
│   └── src/
├── sanguoA/               # Git clone（按需）
└── sanguoB/               # Git clone（按需）
```

### 2. 命令变化

| 旧命令 | 新命令 | 说明 |
|--------|--------|------|
| `codespec install <project> main baseline null` | `scripts/install-workspace.sh <workspace>` | 安装工作区 |
| 无 | `scripts/init-dossier.sh` | 在 Git clone 中初始化 dossier |
| `codespec add-container sanguoA main` | 手工 `git clone` | 不再需要此命令 |
| `codespec start-requirements main` | `codespec start-requirements` | 去掉 container 参数 |

### 3. 工作流变化

**旧工作流**：
1. 在一个仓库里用 `add-container` 创建多个 container
2. 在 `change/main/`, `change/sanguoA/` 等目录工作

**新工作流**：
1. 在工作区创建多个独立的 Git clone
2. 在各 clone 的根目录工作
3. 通过 Git 分支隔离

## 迁移步骤

### 步骤 1：备份现有项目

```bash
cp -r /path/to/old-project /path/to/old-project.backup
```

### 步骤 2：创建新的工作区结构

```bash
# 创建工作区目录
mkdir -p /path/to/new-workspace
cd /path/to/new-workspace

# 安装工作区 runtime
/path/to/.codespec/scripts/install-workspace.sh .
```

### 步骤 3：迁移 main container

```bash
# 克隆或移动现有仓库
git clone <repo-url> main
# 或
mv /path/to/old-project main

cd main

# 移动 dossier 文件到根目录
mv change/main/* .
rmdir change/main
rmdir change

# 初始化（如果是新 clone）
# /path/to/workspace/.codespec/scripts/init-dossier.sh
```

### 步骤 4：迁移其他 containers（如果有）

```bash
cd /path/to/new-workspace

# 为每个旧 container 创建新的 clone
git clone <repo-url> sanguoA
cd sanguoA
git checkout -b group/sanguoA

# 移动 dossier 文件
mv change/sanguoA/* .
rmdir change/sanguoA
rmdir change
```

### 步骤 5：更新 meta.yaml

编辑各 clone 的 `meta.yaml`，确保：
- `execution_branch` 正确
- `feature_branch` 正确

### 步骤 6：测试

```bash
cd /path/to/new-workspace/main
codespec status
codespec readset
```

## 常见问题

### Q: 为什么要做这个改革？

A: 旧版本的 `change/` 目录结构不匹配实际工作方式。实际工作中，用户会创建多个独立的 Git clone，而不是在一个仓库里管理多个 container 目录。

### Q: 我必须迁移吗？

A: 不是立即必须。v1.x 版本仍然可以使用。但新功能只会在 v2.0 中添加。

### Q: 迁移会丢失数据吗？

A: 不会。只是移动文件位置，所有内容都保留。建议先备份。

### Q: 如何回退到旧版本？

A: 保留旧版本的 `.codespec/` 目录备份，需要时恢复即可。

## 新功能

v2.0 新增功能：

1. **工作区级别的共享资源**
   - `.codespec/` runtime 所有 clone 共享
   - `lessons_learned.md` 所有 clone 共享
   - `versions/` 所有 clone 共享

2. **文件修改规则检查**
   - pre-commit hook 检查是否在执行分支修改了受限文件
   - 避免 Git 合并冲突

3. **增强的 design.md**
   - 依赖分析
   - 并行建议
   - 分支策略建议
   - 共享文件冲突预测

4. **简化的命令**
   - 去掉 container 参数
   - 自动推断项目根目录

## 获取帮助

如果迁移过程中遇到问题：

1. 查看 `/path/to/workspace/.codespec/` 下的文档
2. 运行 `codespec help`
3. 提交 issue 到 GitHub

## 附录：完整的新工作流示例

### 单分支工作流

```bash
# 1. 创建工作区
mkdir -p ~/projects/myapp
cd ~/projects/myapp
bash /path/to/.codespec/scripts/install-workspace.sh .

# 2. 创建/克隆项目
git clone <repo-url> main
cd main
bash /path/to/workspace/.codespec/scripts/init-dossier.sh

# 3. 完成所有阶段
codespec start-requirements
# ... 编辑 spec.md
codespec start-design
# ... 编辑 design.md
codespec start-implementation WI-001
# ... 实现
codespec start-testing
codespec start-deployment
```

### 多分支工作流

```bash
# 1-2. 同上

# 3. Design 阶段
cd ~/projects/myapp/main
codespec start-design
# ... design.md 建议开 2 个分支

# 4. 创建执行分支的 clone
cd ~/projects/myapp
git clone <repo-url> branchA
git clone <repo-url> branchB

cd branchA
git checkout -b group/branchA
yq eval '.execution_branch = "group/branchA"' -i meta.yaml

cd ../branchB
git checkout -b group/branchB
yq eval '.execution_branch = "group/branchB"' -i meta.yaml

# 5. 并行实现
cd ~/projects/myapp/branchA
codespec start-implementation WI-001

cd ~/projects/myapp/branchB
codespec start-implementation WI-002

# 6. 合并回 main
cd ~/projects/myapp/main
git merge group/branchA
git merge group/branchB

# 7. Testing/Deployment
codespec start-testing
codespec start-deployment
```
