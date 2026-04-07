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

[ -d "$PROJECT_ROOT/.git" ] || die "git repository not found at $PROJECT_ROOT"
[ -f "$PROJECT_ROOT/.codespec/hooks/pre-commit" ] || die "missing .codespec/hooks/pre-commit"
[ -f "$PROJECT_ROOT/.codespec/hooks/pre-push" ] || die "missing .codespec/hooks/pre-push"

mkdir -p "$PROJECT_ROOT/.git/hooks"
cp "$PROJECT_ROOT/.codespec/hooks/pre-commit" "$PROJECT_ROOT/.git/hooks/pre-commit"
cp "$PROJECT_ROOT/.codespec/hooks/pre-push" "$PROJECT_ROOT/.git/hooks/pre-push"
chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit" "$PROJECT_ROOT/.git/hooks/pre-push"

log "installed git hooks"
log "project_root: $PROJECT_ROOT"
