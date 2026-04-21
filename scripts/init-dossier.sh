#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

resolve_codespec_cmd() {
  if command -v codespec >/dev/null 2>&1; then
    printf 'codespec'
    return
  fi

  if [ -x "$WORKSPACE_ROOT/.codespec/codespec" ]; then
    printf '%s' "$WORKSPACE_ROOT/.codespec/codespec"
    return
  fi

  die "could not resolve codespec runtime; expected codespec in PATH or $WORKSPACE_ROOT/.codespec/codespec"
}

# 查找工作区根目录
find_workspace_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.codespec/codespec" ]; then
      printf '%s\n' "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  die "could not locate workspace root (directory containing .codespec/)"
}

# 查找项目根目录
find_project_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
    return
  fi
  printf '%s\n' "$PWD"
}

WORKSPACE_ROOT="$(find_workspace_root)"
PROJECT_ROOT="$(find_project_root)"

[ -d "$PROJECT_ROOT" ] || die "project root does not exist: $PROJECT_ROOT"

# 检查是否已经初始化
if [ -f "$PROJECT_ROOT/meta.yaml" ]; then
  die "dossier already initialized in $PROJECT_ROOT"
fi

# 创建 dossier 目录结构
mkdir -p "$PROJECT_ROOT/work-items" \
  "$PROJECT_ROOT/contracts" \
  "$PROJECT_ROOT/design-appendices" \
  "$PROJECT_ROOT/spec-appendices" \
  "$PROJECT_ROOT/reviews"

# 复制模板文件
cp "$WORKSPACE_ROOT/.codespec/templates/spec.md" "$PROJECT_ROOT/spec.md"
cp "$WORKSPACE_ROOT/.codespec/templates/design.md" "$PROJECT_ROOT/design.md"
cp "$WORKSPACE_ROOT/.codespec/templates/testing.md" "$PROJECT_ROOT/testing.md"
cp "$WORKSPACE_ROOT/.codespec/templates/CLAUDE.md" "$PROJECT_ROOT/CLAUDE.md"
cp "$WORKSPACE_ROOT/.codespec/templates/AGENTS.md" "$PROJECT_ROOT/AGENTS.md"

# 创建 meta.yaml
TODAY="$(date +%F)"
CURRENT_BRANCH="$(git -C "$PROJECT_ROOT" symbolic-ref --short HEAD 2>/dev/null || echo "main")"

# 使用 render_template 渲染 meta.yaml
RENDER_DATE="$TODAY" \
RENDER_CHANGE_ID="baseline" \
RENDER_BASE_VERSION="null" \
RENDER_FEATURE_BRANCH="$CURRENT_BRANCH" \
RENDER_EXECUTION_GROUP="null" \
RENDER_EXECUTION_BRANCH="null" \
RENDER_PHASE="Proposal" \
RENDER_STATUS="active" \
RENDER_FOCUS_WORK_ITEM="null" \
RENDER_ACTIVE_WORK_ITEMS="[]" \
RENDER_UPDATED_BY="codespec-init" \
"$WORKSPACE_ROOT/.codespec/codespec" render-template \
  "$WORKSPACE_ROOT/.codespec/templates/meta.yaml" \
  "$PROJECT_ROOT/meta.yaml"

# 安装 Git hooks（如果是 Git 仓库）
if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  "$WORKSPACE_ROOT/.codespec/scripts/install-hooks.sh" "$PROJECT_ROOT"
else
  log "skipped git hooks installation (not a git repository)"
fi

# 创建初始 review verdict 以支持首次 start-requirements
cat > "$PROJECT_ROOT/reviews/requirements-review.yaml" <<EOF
phase: Proposal
verdict: approved
reviewed_by: codespec-init
reviewed_at: $TODAY
EOF

log "initialized dossier in: $PROJECT_ROOT"
log ""
log "Next steps:"
log "1. Edit spec.md to define requirements"
log "2. Run: $(resolve_codespec_cmd) start-requirements"
log "3. Use the same runtime entry for future phase/focus transitions; do not edit meta.yaml directly"
