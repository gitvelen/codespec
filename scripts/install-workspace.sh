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

WORKSPACE_ROOT="${1:-$PWD}"

[ -d "$WORKSPACE_ROOT" ] || die "workspace root does not exist: $WORKSPACE_ROOT"

# 创建 .codespec 目录结构
mkdir -p "$WORKSPACE_ROOT/.codespec" \
  "$WORKSPACE_ROOT/.codespec/hooks" \
  "$WORKSPACE_ROOT/.codespec/scripts" \
  "$WORKSPACE_ROOT/.codespec/templates" \
  "$WORKSPACE_ROOT/.codespec/skills"

# 复制 runtime 文件
cp "$FRAMEWORK_ROOT/codespec" "$WORKSPACE_ROOT/.codespec/codespec"
cp "$FRAMEWORK_ROOT/hooks/pre-commit" "$WORKSPACE_ROOT/.codespec/hooks/pre-commit"
cp "$FRAMEWORK_ROOT/hooks/pre-push" "$WORKSPACE_ROOT/.codespec/hooks/pre-push"
cp "$FRAMEWORK_ROOT/scripts/check-gate.sh" "$WORKSPACE_ROOT/.codespec/scripts/check-gate.sh"
cp "$FRAMEWORK_ROOT/scripts/install-hooks.sh" "$WORKSPACE_ROOT/.codespec/scripts/install-hooks.sh"
cp "$FRAMEWORK_ROOT/scripts/install-workspace.sh" "$WORKSPACE_ROOT/.codespec/scripts/install-workspace.sh"
cp "$FRAMEWORK_ROOT/scripts/init-dossier.sh" "$WORKSPACE_ROOT/.codespec/scripts/init-dossier.sh"
cp "$FRAMEWORK_ROOT/scripts/smoke.sh" "$WORKSPACE_ROOT/.codespec/scripts/smoke.sh"

# 复制模板文件
cp "$FRAMEWORK_ROOT/templates/AGENTS.md" "$WORKSPACE_ROOT/.codespec/templates/AGENTS.md"
cp "$FRAMEWORK_ROOT/templates/CLAUDE.md" "$WORKSPACE_ROOT/.codespec/templates/CLAUDE.md"
cp "$FRAMEWORK_ROOT/templates/meta.yaml" "$WORKSPACE_ROOT/.codespec/templates/meta.yaml"
cp "$FRAMEWORK_ROOT/templates/spec.md" "$WORKSPACE_ROOT/.codespec/templates/spec.md"
cp "$FRAMEWORK_ROOT/templates/design.md" "$WORKSPACE_ROOT/.codespec/templates/design.md"
cp "$FRAMEWORK_ROOT/templates/phase-review-policy.md" "$WORKSPACE_ROOT/.codespec/templates/phase-review-policy.md"
cp "$FRAMEWORK_ROOT/templates/work-item.yaml" "$WORKSPACE_ROOT/.codespec/templates/work-item.yaml"
cp "$FRAMEWORK_ROOT/templates/testing.md" "$WORKSPACE_ROOT/.codespec/templates/testing.md"
cp "$FRAMEWORK_ROOT/templates/contract.md" "$WORKSPACE_ROOT/.codespec/templates/contract.md"
cp "$FRAMEWORK_ROOT/templates/deployment.md" "$WORKSPACE_ROOT/.codespec/templates/deployment.md"
cp "$FRAMEWORK_ROOT/templates/lessons_learned.md" "$WORKSPACE_ROOT/.codespec/templates/lessons_learned.md"
cp -R "$FRAMEWORK_ROOT/skills/." "$WORKSPACE_ROOT/.codespec/skills/"

# 设置可执行权限
chmod +x "$WORKSPACE_ROOT/.codespec/codespec" \
  "$WORKSPACE_ROOT/.codespec/hooks/pre-commit" \
  "$WORKSPACE_ROOT/.codespec/hooks/pre-push" \
  "$WORKSPACE_ROOT/.codespec/scripts/check-gate.sh" \
  "$WORKSPACE_ROOT/.codespec/scripts/install-hooks.sh" \
  "$WORKSPACE_ROOT/.codespec/scripts/install-workspace.sh" \
  "$WORKSPACE_ROOT/.codespec/scripts/init-dossier.sh" \
  "$WORKSPACE_ROOT/.codespec/scripts/smoke.sh"

# 创建共享资源
mkdir -p "$WORKSPACE_ROOT/versions"

if [ ! -f "$WORKSPACE_ROOT/lessons_learned.md" ]; then
  TODAY="$(date +%F)" RENDER_DATE="$TODAY" \
    "$WORKSPACE_ROOT/.codespec/codespec" render-template \
    "$WORKSPACE_ROOT/.codespec/templates/lessons_learned.md" \
    "$WORKSPACE_ROOT/lessons_learned.md"
fi

if [ ! -f "$WORKSPACE_ROOT/phase-review-policy.md" ]; then
  "$WORKSPACE_ROOT/.codespec/codespec" render-template \
    "$WORKSPACE_ROOT/.codespec/templates/phase-review-policy.md" \
    "$WORKSPACE_ROOT/phase-review-policy.md"
fi

log "installed workspace runtime"
log "workspace_root: $WORKSPACE_ROOT"
log ""
log "Next steps:"
log "1. Create or clone a Git repository in this workspace"
log "2. cd into the repository directory"
log "3. Initialize a dossier from the project directory: $WORKSPACE_ROOT/.codespec/scripts/init-dossier.sh"
log "4. Advance phases via the standard runtime entry: $(resolve_codespec_cmd) start-requirements"
