#!/usr/bin/env bash
# codespec v2.0 一键安装脚本
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
  echo -e "${GREEN}✓${NC} $*"
}

warn() {
  echo -e "${YELLOW}⚠${NC} $*"
}

error() {
  echo -e "${RED}✗${NC} $*" >&2
  exit 1
}

resolve_codespec_cmd() {
  local workspace_dir="$1"

  if command -v codespec >/dev/null 2>&1; then
    printf 'codespec'
    return
  fi

  if [ -x "$workspace_dir/.codespec/codespec" ]; then
    printf '%s' "$workspace_dir/.codespec/codespec"
    return
  fi

  error "无法解析 codespec 运行时：既不在 PATH 中，也不存在 $workspace_dir/.codespec/codespec"
}

usage() {
  cat <<EOF
codespec v2.0 一键安装脚本

用法:
  $0 <workspace-dir> [repo-url] [project-name]

参数:
  workspace-dir   工作区目录（如 /home/admin/sanguo）
  repo-url        可选：Git 仓库 URL（如果要 clone 现有项目）
  project-name    可选：项目名称（默认为 main）

示例:
  # 场景 1: 创建新项目
  $0 /home/admin/sanguo

  # 场景 2: Clone 现有项目
  $0 /home/admin/sanguo https://github.com/user/repo.git myproject

  # 场景 3: 使用现有本地项目
  $0 /home/admin/sanguo /path/to/existing/project existing-project

安装后:
  cd <workspace-dir>/<project-name>
  # 初始化 dossier 后，手工创建 reviews/design-review.yaml 并填写审查结论
  # 然后使用标准 runtime 入口推进阶段：codespec start-design
  # 若 codespec 不在 PATH，则使用 <workspace-dir>/.codespec/codespec start-design
EOF
}

check_dependencies() {
  local missing=()

  command -v git >/dev/null 2>&1 || missing+=("git")
  command -v bash >/dev/null 2>&1 || missing+=("bash")
  command -v yq >/dev/null 2>&1 || missing+=("yq")

  if [ ${#missing[@]} -gt 0 ]; then
    error "缺少依赖: ${missing[*]}\n请先安装: sudo apt-get install git yq"
  fi
}

install_workspace() {
  local workspace_dir="$1"

  echo "=== 步骤 1: 安装工作区共享资源 ==="

  if [ -d "$workspace_dir/.codespec" ]; then
    warn "工作区已存在，跳过安装"
  else
    "$FRAMEWORK_ROOT/scripts/install-workspace.sh" "$workspace_dir"
    log "工作区安装完成: $workspace_dir"
  fi
}

setup_project() {
  local workspace_dir="$1"
  local repo_url="${2:-}"
  local project_name="${3:-main}"
  local project_dir="$workspace_dir/$project_name"

  echo ""
  echo "=== 步骤 2: 设置项目 ==="

  if [ -d "$project_dir" ]; then
    warn "项目目录已存在: $project_dir"
    read -p "是否继续初始化 dossier? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      error "用户取消"
    fi
  elif [ -n "$repo_url" ]; then
    if [ -d "$repo_url" ]; then
      # 本地路径
      log "复制本地项目: $repo_url -> $project_dir"
      cp -r "$repo_url" "$project_dir"
    else
      # Git URL
      log "克隆远程仓库: $repo_url"
      git clone "$repo_url" "$project_dir"
    fi
  else
    # 创建新项目
    log "创建新项目: $project_dir"
    mkdir -p "$project_dir"
    cd "$project_dir"
    git init
    log "初始化 Git 仓库"
  fi

  cd "$project_dir"

  # 检查是否已经初始化
  if [ -f "meta.yaml" ]; then
    warn "项目已初始化 dossier，跳过"
    return
  fi

  echo ""
  echo "=== 步骤 3: 初始化 dossier ==="
  "$workspace_dir/.codespec/scripts/init-dossier.sh"
  log "Dossier 初始化完成"
}

show_next_steps() {
  local workspace_dir="$1"
  local project_name="${2:-main}"
  local project_dir="$workspace_dir/$project_name"
  local codespec_cmd
  codespec_cmd="$(resolve_codespec_cmd "$workspace_dir")"

  cat <<EOF

${GREEN}========================================${NC}
${GREEN}✓ 安装完成！${NC}
${GREEN}========================================${NC}

项目位置: $project_dir

下一步操作:

  ${YELLOW}# 1. 进入项目目录${NC}
  cd $project_dir

  ${YELLOW}# 2. 编辑 spec.md 定义需求${NC}
  vim spec.md

  ${YELLOW}# 3. 创建 review verdict 并进入 Design 阶段${NC}
  mkdir -p reviews
  cat > reviews/design-review.yaml <<EOFR
phase: Requirement
verdict: approved
reviewed_by: $(git config user.name || echo "your-name")
reviewed_at: \$(date +%F)
EOFR
  $codespec_cmd start-design

  ${YELLOW}# 5. 查看当前状态${NC}
  $codespec_cmd status

  ${YELLOW}# 6. 查看推荐阅读文件${NC}
  $codespec_cmd readset

  ${YELLOW}# 7. 后续阶段/焦点切换继续使用同一入口，不要手改 meta.yaml${NC}

更多帮助:
  - 查看命令帮助: $codespec_cmd --help
  - 运行测试: bash $workspace_dir/.codespec/scripts/smoke.sh

EOF
}

main() {
  if [ $# -lt 1 ]; then
    usage
    exit 1
  fi

  local workspace_dir="$1"
  local repo_url="${2:-}"
  local project_name="${3:-main}"

  echo "codespec v2.0 一键安装"
  echo "====================="
  echo ""

  # 检查依赖
  check_dependencies

  # 创建工作区目录
  mkdir -p "$workspace_dir"
  workspace_dir="$(cd "$workspace_dir" && pwd)"

  # 安装工作区
  install_workspace "$workspace_dir"

  # 设置项目
  setup_project "$workspace_dir" "$repo_url" "$project_name"

  # 显示后续步骤
  show_next_steps "$workspace_dir" "$project_name"
}

main "$@"
