# codespec v2.0 快速开始指南

## 一键安装

### 前置条件

确保已安装以下工具：
```bash
# 检查依赖
git --version
bash --version
yq --version

# 如果缺少 yq，安装它
# Ubuntu/Debian:
sudo apt-get install yq

# macOS:
brew install yq
```

### 场景 1: 创建新项目（最常见）

```bash
# 一键安装并创建新项目
bash /home/admin/.codespec/scripts/quick-start.sh /home/admin/my-workspace

# 进入项目目录
cd /home/admin/my-workspace/main

# 开始工作
codespec start-requirements
```

### 场景 2: 在现有 Git 仓库中使用

```bash
# Clone 你的项目并安装 codespec
bash /home/admin/.codespec/scripts/quick-start.sh \
  /home/admin/my-workspace \
  https://github.com/user/repo.git \
  myproject

# 进入项目目录
cd /home/admin/my-workspace/myproject

# 开始工作
codespec start-requirements
```

### 场景 3: 在现有本地项目中使用

```bash
# 使用现有本地项目
bash /home/admin/.codespec/scripts/quick-start.sh \
  /home/admin/my-workspace \
  /path/to/existing/project \
  myproject

# 进入项目目录
cd /home/admin/my-workspace/myproject

# 开始工作
codespec start-requirements
```

## 安装后的目录结构

```
/home/admin/my-workspace/        # 工作区目录
├── .codespec/                   # 共享 runtime（框架核心）
│   ├── codespec                 # 主命令
│   ├── scripts/                 # 脚本
│   ├── hooks/                   # Git hooks
│   └── templates/               # 模板文件
├── lessons_learned.md           # 共享经验教训
├── phase-review-policy.md       # 共享审查策略
├── versions/                    # 共享版本快照
└── main/                        # 你的项目（Git clone）
    ├── .git/
    ├── .git/hooks/              # 已安装 pre-commit/pre-push hooks
    ├── spec.md                  # 需求文档
    ├── design.md                # 设计文档
    ├── meta.yaml                # 元数据
    ├── testing.md               # 测试记录
    ├── CLAUDE.md                # Claude 入口文件
    ├── AGENTS.md                # Agent 入口文件
    ├── work-items/              # 工作项定义
    └── src/                     # 你的业务代码
```

## 快速工作流

### 单分支工作流（推荐新手）

```bash
# 1. 进入项目
cd /home/admin/my-workspace/main

# 2. 开始 Requirements 阶段
codespec start-requirements

# 3. 编辑 spec.md 定义需求
vim spec.md

# 4. 创建 review verdict
mkdir -p reviews
cat > reviews/requirements-review.yaml <<EOF
phase: Proposal
verdict: approved
reviewed_by: $(git config user.name)
reviewed_at: $(date +%F)
EOF

# 5. 进入 Design 阶段
codespec start-design

# 6. 编辑 design.md 设计架构
vim design.md

# 7. 创建 review verdict
cat > reviews/design-review.yaml <<EOF
phase: Requirements
verdict: approved
reviewed_by: $(git config user.name)
reviewed_at: $(date +%F)
EOF

# 8. 添加工作项
codespec add-work-item WI-001

# 9. 编辑工作项定义
vim work-items/WI-001.yaml

# 10. 创建 review verdict
cat > reviews/implementation-review.yaml <<EOF
phase: Design
verdict: approved
reviewed_by: $(git config user.name)
reviewed_at: $(date +%F)
EOF

# 11. 开始实现
codespec start-implementation WI-001

# 12. 编写代码
mkdir -p src
echo "console.log('Hello World')" > src/index.js

# 13. 提交代码
git add .
git commit -m "feat: implement WI-001"

# 14. 记录测试
vim testing.md  # 添加测试记录

# 15. 进入 Testing 阶段
codespec start-testing

# 16. 进入 Deployment 阶段
codespec start-deployment

# 17. 完成变更
codespec complete-change
```

## 常用命令

```bash
# 查看当前状态
codespec status

# 查看推荐阅读文件
codespec readset

# 查看推荐阅读文件（JSON 格式）
codespec readset --json

# 检查 gate
codespec check-gate metadata-consistency
codespec check-gate phase-capability
codespec check-gate scope
codespec check-gate contract-boundary

# 查看帮助
codespec --help
```

## 多分支并行工作流（高级）

适用于大型项目，需要多人并行开发。

```bash
# 1. 在 main clone 完成 Proposal → Requirements → Design
cd /home/admin/my-workspace/main
git checkout -b feature/add-auth
codespec start-requirements
# ... 完成 spec.md
codespec start-design
# ... 完成 design.md，建议开 2 个分支并行

# 2. 提交并推送 design
git add .
git commit -m "docs: complete design for add-auth"
git push -u origin feature/add-auth

# 3. 创建其他 clone 用于并行执行
cd /home/admin/my-workspace
git clone <REPO_URL> projectA
git clone <REPO_URL> projectB

# 4. 在各 clone 创建执行分支
cd projectA
git checkout feature/add-auth
git checkout -b group/projectA
codespec install-hooks
yq eval '.execution_group = "parallel-impl"' -i meta.yaml
yq eval '.execution_branch = "group/projectA"' -i meta.yaml

cd ../projectB
git checkout feature/add-auth
git checkout -b group/projectB
codespec install-hooks
yq eval '.execution_group = "parallel-impl"' -i meta.yaml
yq eval '.execution_branch = "group/projectB"' -i meta.yaml

# 5. 并行实现
cd /home/admin/my-workspace/projectA
codespec start-implementation WI-001
# ... 实现 WI-001
git add .
git commit -m "feat: implement WI-001"
git push -u origin group/projectA

cd /home/admin/my-workspace/projectB
codespec start-implementation WI-002
# ... 实现 WI-002
git add .
git commit -m "feat: implement WI-002"
git push -u origin group/projectB

# 6. 合并回 feature 分支
cd /home/admin/my-workspace/main
git fetch origin
git merge origin/group/projectA
git merge origin/group/projectB
# 注意：meta.yaml 会有合并冲突，手动清空 execution_* 字段

# 7. Testing → Deployment 在 main clone
codespec start-testing
codespec start-deployment
codespec complete-change
```

## 故障排查

### 问题 1: yq 命令不存在

```bash
# Ubuntu/Debian
sudo apt-get install yq

# macOS
brew install yq

# 或者手动安装
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

### 问题 2: pre-commit hook 失败

```bash
# 查看详细错误
git commit -v

# 检查 gate
codespec check-gate metadata-consistency
codespec check-gate phase-capability
codespec check-gate scope
codespec check-gate contract-boundary

# 如果确实需要绕过（不推荐）
git commit --no-verify -m "your message"
```

### 问题 3: 找不到 codespec 命令

```bash
# 确保使用完整路径
/home/admin/my-workspace/.codespec/codespec status

# 或者添加到 PATH（可选）
export PATH="/home/admin/my-workspace/.codespec:$PATH"
echo 'export PATH="/home/admin/my-workspace/.codespec:$PATH"' >> ~/.bashrc
```

### 问题 4: 工作区已存在

```bash
# 如果工作区已存在，可以直接初始化新项目
cd /home/admin/my-workspace
mkdir new-project
cd new-project
git init
/home/admin/my-workspace/.codespec/scripts/init-dossier.sh
```

## 更多资源

- **完整文档**: `/home/admin/.codespec/README.md`
- **迁移指南**: `/home/admin/.codespec/MIGRATION.md`
- **实施状态**: `/home/admin/.codespec/IMPLEMENTATION_STATUS.md`
- **回归测试**: `bash /home/admin/.codespec/scripts/smoke.sh`

## 获取帮助

```bash
# 查看命令帮助
codespec --help

# 查看特定命令的用法
codespec start-requirements --help

# 运行测试验证安装
bash /home/admin/my-workspace/.codespec/scripts/smoke.sh
```
