#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${1:-$PWD}"

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

# 查找工作区根目录
find_workspace_root() {
  local dir="$PROJECT_ROOT"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.codespec/codespec" ]; then
      printf '%s\n' "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  die "could not locate workspace root (directory containing .codespec/)"
}

WORKSPACE_ROOT="$(find_workspace_root)"

git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "git repository not found at $PROJECT_ROOT"
[ -f "$WORKSPACE_ROOT/.codespec/hooks/pre-commit" ] || die "missing $WORKSPACE_ROOT/.codespec/hooks/pre-commit"
[ -f "$WORKSPACE_ROOT/.codespec/hooks/pre-push" ] || die "missing $WORKSPACE_ROOT/.codespec/hooks/pre-push"

hooks_path="$(git -C "$PROJECT_ROOT" config --get core.hooksPath || true)"
if [ -z "$hooks_path" ]; then
  hooks_dir="$(git -C "$PROJECT_ROOT" rev-parse --git-path hooks)"
elif [[ "$hooks_path" = /* ]]; then
  hooks_dir="$hooks_path"
else
  hooks_dir="$PROJECT_ROOT/$hooks_path"
fi

mkdir -p "$hooks_dir"
cp "$WORKSPACE_ROOT/.codespec/hooks/pre-commit" "$hooks_dir/pre-commit"
cp "$WORKSPACE_ROOT/.codespec/hooks/pre-push" "$hooks_dir/pre-push"
chmod +x "$hooks_dir/pre-commit" "$hooks_dir/pre-push"

[ -x "$hooks_dir/pre-commit" ] || die 'installed pre-commit hook is not executable'
[ -x "$hooks_dir/pre-push" ] || die 'installed pre-push hook is not executable'
cmp -s "$WORKSPACE_ROOT/.codespec/hooks/pre-commit" "$hooks_dir/pre-commit" || die 'installed pre-commit hook content mismatch'
cmp -s "$WORKSPACE_ROOT/.codespec/hooks/pre-push" "$hooks_dir/pre-push" || die 'installed pre-push hook content mismatch'

log "installed git hooks"
log "project_root: $PROJECT_ROOT"
log "workspace_root: $WORKSPACE_ROOT"
