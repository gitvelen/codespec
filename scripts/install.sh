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

TARGET_ROOT="${1:-$PWD}"
CONTAINER="${2:-main}"
CHANGE_ID="${3:-baseline}"
BASE_VERSION="${4:-null}"

[ -d "$TARGET_ROOT" ] || die "target root does not exist: $TARGET_ROOT"

mkdir -p "$TARGET_ROOT/.codespec" "$TARGET_ROOT/.codespec/hooks" "$TARGET_ROOT/.codespec/scripts" "$TARGET_ROOT/.codespec/templates"

cp "$FRAMEWORK_ROOT/codespec" "$TARGET_ROOT/.codespec/codespec"
cp "$FRAMEWORK_ROOT/hooks/pre-commit" "$TARGET_ROOT/.codespec/hooks/pre-commit"
cp "$FRAMEWORK_ROOT/hooks/pre-push" "$TARGET_ROOT/.codespec/hooks/pre-push"
cp "$FRAMEWORK_ROOT/scripts/check-gate.sh" "$TARGET_ROOT/.codespec/scripts/check-gate.sh"
cp "$FRAMEWORK_ROOT/scripts/install-hooks.sh" "$TARGET_ROOT/.codespec/scripts/install-hooks.sh"
cp "$FRAMEWORK_ROOT/scripts/install.sh" "$TARGET_ROOT/.codespec/scripts/install.sh"
cp "$FRAMEWORK_ROOT/scripts/smoke.sh" "$TARGET_ROOT/.codespec/scripts/smoke.sh"
cp "$FRAMEWORK_ROOT/templates/CLAUDE.md" "$TARGET_ROOT/.codespec/templates/CLAUDE.md"
cp "$FRAMEWORK_ROOT/templates/meta.yaml" "$TARGET_ROOT/.codespec/templates/meta.yaml"
cp "$FRAMEWORK_ROOT/templates/spec.md" "$TARGET_ROOT/.codespec/templates/spec.md"
cp "$FRAMEWORK_ROOT/templates/design.md" "$TARGET_ROOT/.codespec/templates/design.md"
cp "$FRAMEWORK_ROOT/templates/work-item.yaml" "$TARGET_ROOT/.codespec/templates/work-item.yaml"
cp "$FRAMEWORK_ROOT/templates/testing.md" "$TARGET_ROOT/.codespec/templates/testing.md"
cp "$FRAMEWORK_ROOT/templates/contract.md" "$TARGET_ROOT/.codespec/templates/contract.md"
cp "$FRAMEWORK_ROOT/templates/deployment.md" "$TARGET_ROOT/.codespec/templates/deployment.md"
cp "$FRAMEWORK_ROOT/templates/lessons_learned.md" "$TARGET_ROOT/.codespec/templates/lessons_learned.md"

chmod +x "$TARGET_ROOT/.codespec/codespec" \
  "$TARGET_ROOT/.codespec/hooks/pre-commit" \
  "$TARGET_ROOT/.codespec/hooks/pre-push" \
  "$TARGET_ROOT/.codespec/scripts/check-gate.sh" \
  "$TARGET_ROOT/.codespec/scripts/install-hooks.sh" \
  "$TARGET_ROOT/.codespec/scripts/install.sh" \
  "$TARGET_ROOT/.codespec/scripts/smoke.sh"

CODESPEC_PROJECT_ROOT="$TARGET_ROOT" "$TARGET_ROOT/.codespec/codespec" init-project "$CONTAINER" "$CHANGE_ID" "$BASE_VERSION"

log "installed .codespec runtime assets"
log "target_root: $TARGET_ROOT"
