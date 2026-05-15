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

usage() {
  cat <<'EOF'
Usage:
  install-workspace.sh [workspace_root] [--migrate-project <project_root>] [--apply-migration] [--reset-stale-contracts]

Options:
  --migrate-project <project_root>  Run legacy WI audit/migration for the given project after installing runtime.
  --apply-migration                Apply the migration. Without this flag, migration runs as dry-run.
  --reset-stale-contracts          With --apply-migration, reset contracts that still encode the removed WI model.
EOF
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

WORKSPACE_ROOT="$PWD"
MIGRATE_PROJECT=""
APPLY_MIGRATION=false
RESET_STALE_CONTRACTS=false

if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then
  WORKSPACE_ROOT="$1"
  shift
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --migrate-project)
      [ "$#" -ge 2 ] || die "--migrate-project requires a project_root"
      MIGRATE_PROJECT="$2"
      shift 2
      ;;
    --apply-migration)
      APPLY_MIGRATION=true
      shift
      ;;
    --reset-stale-contracts)
      RESET_STALE_CONTRACTS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

if [ "$APPLY_MIGRATION" = true ] && [ -z "$MIGRATE_PROJECT" ]; then
  die "--apply-migration requires --migrate-project <project_root>"
fi
if [ "$RESET_STALE_CONTRACTS" = true ] && [ -z "$MIGRATE_PROJECT" ]; then
  die "--reset-stale-contracts requires --migrate-project <project_root>"
fi

[ -d "$WORKSPACE_ROOT" ] || die "workspace root does not exist: $WORKSPACE_ROOT"

# 创建 .codespec 目录结构
mkdir -p "$WORKSPACE_ROOT/.codespec" \
  "$WORKSPACE_ROOT/.codespec/hooks" \
  "$WORKSPACE_ROOT/.codespec/scripts/lib" \
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
cp "$FRAMEWORK_ROOT/scripts/audit-regressions.sh" "$WORKSPACE_ROOT/.codespec/scripts/audit-regressions.sh"
cp "$FRAMEWORK_ROOT/scripts/lint.sh" "$WORKSPACE_ROOT/.codespec/scripts/lint.sh"
cp "$FRAMEWORK_ROOT/scripts/migrate-to-requirement-phase.sh" "$WORKSPACE_ROOT/.codespec/scripts/migrate-to-requirement-phase.sh"
cp "$FRAMEWORK_ROOT/scripts/smoke.sh" "$WORKSPACE_ROOT/.codespec/scripts/smoke.sh"
cp "$FRAMEWORK_ROOT/scripts/lib/testing-ledger.sh" "$WORKSPACE_ROOT/.codespec/scripts/lib/testing-ledger.sh"
cp "$FRAMEWORK_ROOT/scripts/lib/legacy-wi-audit.sh" "$WORKSPACE_ROOT/.codespec/scripts/lib/legacy-wi-audit.sh"

# 复制模板文件
cp "$FRAMEWORK_ROOT/templates/AI_INSTRUCTIONS.md" "$WORKSPACE_ROOT/.codespec/templates/AI_INSTRUCTIONS.md"
cp "$FRAMEWORK_ROOT/templates/gate-map.yaml" "$WORKSPACE_ROOT/.codespec/templates/gate-map.yaml"
{
  printf '# AGENTS.md\n\n'
  cat "$FRAMEWORK_ROOT/templates/AI_INSTRUCTIONS.md"
} > "$WORKSPACE_ROOT/.codespec/templates/AGENTS.md"
{
  printf '# CLAUDE.md\n\n'
  cat "$FRAMEWORK_ROOT/templates/AI_INSTRUCTIONS.md"
} > "$WORKSPACE_ROOT/.codespec/templates/CLAUDE.md"
cp "$FRAMEWORK_ROOT/templates/meta.yaml" "$WORKSPACE_ROOT/.codespec/templates/meta.yaml"
cp "$FRAMEWORK_ROOT/templates/spec.md" "$WORKSPACE_ROOT/.codespec/templates/spec.md"
cp "$FRAMEWORK_ROOT/templates/design.md" "$WORKSPACE_ROOT/.codespec/templates/design.md"
cp "$FRAMEWORK_ROOT/templates/phase-review-policy.md" "$WORKSPACE_ROOT/.codespec/templates/phase-review-policy.md"
cp "$FRAMEWORK_ROOT/templates/testing.md" "$WORKSPACE_ROOT/.codespec/templates/testing.md"
cp "$FRAMEWORK_ROOT/templates/contract.md" "$WORKSPACE_ROOT/.codespec/templates/contract.md"
cp "$FRAMEWORK_ROOT/templates/deployment.md" "$WORKSPACE_ROOT/.codespec/templates/deployment.md"
cp "$FRAMEWORK_ROOT/templates/codespec-deploy" "$WORKSPACE_ROOT/.codespec/templates/codespec-deploy"
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
  "$WORKSPACE_ROOT/.codespec/scripts/audit-regressions.sh" \
  "$WORKSPACE_ROOT/.codespec/scripts/lint.sh" \
  "$WORKSPACE_ROOT/.codespec/scripts/migrate-to-requirement-phase.sh" \
  "$WORKSPACE_ROOT/.codespec/scripts/smoke.sh"

# 创建共享资源
mkdir -p "$WORKSPACE_ROOT/versions"

if [ ! -f "$WORKSPACE_ROOT/lessons_learned.md" ]; then
  TODAY="$(date +%F)" RENDER_DATE="$TODAY" \
    "$WORKSPACE_ROOT/.codespec/codespec" render-template \
    "$WORKSPACE_ROOT/.codespec/templates/lessons_learned.md" \
    "$WORKSPACE_ROOT/lessons_learned.md"
else
  # Append missing hard rules from template to existing lessons_learned.md
  existing_rules="$(grep -oE '\*\*R[0-9]+\*\*' "$WORKSPACE_ROOT/lessons_learned.md" | sort -u || true)"
  template_rules="$(grep -oE '\*\*R[0-9]+\*\*' "$WORKSPACE_ROOT/.codespec/templates/lessons_learned.md" | sort -u || true)"
  missing_rule_lines=()
  for rule in $template_rules; do
    if ! printf '%s\n' "$existing_rules" | grep -qF "$rule"; then
      rule_line="$(grep -F "$rule" "$WORKSPACE_ROOT/.codespec/templates/lessons_learned.md" | head -1)"
      missing_rule_lines+=("$rule_line")
    fi
  done
  if [ "${#missing_rule_lines[@]}" -gt 0 ]; then
    {
      printf '\n## 补齐的硬规则（codespec install %s）\n\n' "$(date +%F)"
      printf '%s\n' "${missing_rule_lines[@]}"
    } >> "$WORKSPACE_ROOT/lessons_learned.md"
  fi
fi

if [ -f "$WORKSPACE_ROOT/phase-review-policy.md" ] && ! cmp -s "$WORKSPACE_ROOT/.codespec/templates/phase-review-policy.md" "$WORKSPACE_ROOT/phase-review-policy.md"; then
  cp "$WORKSPACE_ROOT/phase-review-policy.md" "$WORKSPACE_ROOT/phase-review-policy.md.bak.$(date +%Y%m%d%H%M%S)"
fi
"$WORKSPACE_ROOT/.codespec/codespec" render-template \
  "$WORKSPACE_ROOT/.codespec/templates/phase-review-policy.md" \
  "$WORKSPACE_ROOT/phase-review-policy.md"

if [ -n "$MIGRATE_PROJECT" ]; then
  migration_args=(migrate-remove-wi "$MIGRATE_PROJECT")
  if [ "$APPLY_MIGRATION" = true ]; then
    migration_args+=(--apply)
  fi
  if [ "$RESET_STALE_CONTRACTS" = true ]; then
    migration_args+=(--reset-stale-contracts)
  fi
  log ""
  log "running project legacy WI audit/migration: $MIGRATE_PROJECT"
  "$WORKSPACE_ROOT/.codespec/codespec" "${migration_args[@]}"
fi

log "installed workspace runtime"
log "workspace_root: $WORKSPACE_ROOT"
log ""
log "Next steps:"
log "1. For a new project: cd into the repository and run $WORKSPACE_ROOT/.codespec/scripts/init-dossier.sh"
log "2. For an existing initialized project: run $WORKSPACE_ROOT/.codespec/scripts/install-hooks.sh <project_root>"
log "3. If the project still uses Proposal/Requirements, run $WORKSPACE_ROOT/.codespec/scripts/migrate-to-requirement-phase.sh <project_root>"
log "4. For an existing WI-era project, run $(resolve_codespec_cmd) audit-legacy-wi <project_root> --strict"
log "5. If blocking residue exists, run $(resolve_codespec_cmd) migrate-remove-wi <project_root>, then rerun with --apply and add --reset-stale-contracts when contracts are stale"
log "6. Continue phase transitions via: $(resolve_codespec_cmd) start-design"
