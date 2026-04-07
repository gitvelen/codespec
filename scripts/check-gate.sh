#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GATE="${1:-}"

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_yq() {
  command -v yq >/dev/null 2>&1 || die "yq is required for gate checks"
}

yaml_scalar() {
  local file="$1"
  local key="$2"
  yq eval ".${key}" "$file"
}

yaml_list() {
  local file="$1"
  local key="$2"
  yq eval ".${key}[]" "$file" 2>/dev/null || true
}

find_project_root() {
  if [ -n "${CODESPEC_PROJECT_ROOT:-}" ] && [ -f "${CODESPEC_PROJECT_ROOT}/.codespec/codespec" ]; then
    printf '%s\n' "$CODESPEC_PROJECT_ROOT"
    return
  fi

  local candidate
  candidate="$(dirname "$FRAMEWORK_ROOT")"
  if [ -f "$candidate/.codespec/codespec" ]; then
    printf '%s\n' "$candidate"
    return
  fi

  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.codespec/codespec" ]; then
      printf '%s\n' "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done

  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    dir="$(git rev-parse --show-toplevel)"
    if [ -f "$dir/.codespec/codespec" ]; then
      printf '%s\n' "$dir"
      return
    fi
  fi

  die "could not locate project root"
}

list_containers() {
  local project_root="$1"
  local dir
  if [ ! -d "$project_root/change" ]; then
    return
  fi
  for dir in "$project_root"/change/*; do
    [ -d "$dir" ] || continue
    basename "$dir"
  done
}

detect_container() {
  local project_root="$1"
  if [ -n "${CODESPEC_CONTAINER:-}" ] && [ -d "$project_root/change/$CODESPEC_CONTAINER" ]; then
    printf '%s\n' "$CODESPEC_CONTAINER"
    return
  fi

  if [[ "$PWD" == "$project_root/change/"* ]]; then
    local rel
    rel="${PWD#"$project_root/change/"}"
    printf '%s\n' "${rel%%/*}"
    return
  fi

  local containers=()
  local item
  while IFS= read -r item; do
    [ -n "$item" ] && containers+=("$item")
  done < <(list_containers "$project_root")

  if [ "${#containers[@]}" -eq 1 ]; then
    printf '%s\n' "${containers[0]}"
    return
  fi

  die "could not determine current container"
}

match_path() {
  local file="$1"
  local pattern="$2"
  [ -n "$pattern" ] || return 1
  [ "$pattern" != "null" ] || return 1
  case "$file" in
    "$pattern") return 0 ;;
    $pattern) return 0 ;;
    *) return 1 ;;
  esac
}

require_context() {
  require_yq
  PROJECT_ROOT="$(find_project_root)"
  CONTAINER="$(detect_container "$PROJECT_ROOT")"
  CONTAINER_ROOT="$PROJECT_ROOT/change/$CONTAINER"
  META_FILE="$CONTAINER_ROOT/meta.yaml"
  SPEC_FILE="$CONTAINER_ROOT/spec.md"
  DESIGN_FILE="$CONTAINER_ROOT/design.md"
  TESTING_FILE="$CONTAINER_ROOT/testing.md"

  [ -f "$META_FILE" ] || die "missing $META_FILE"
  [ -f "$SPEC_FILE" ] || die "missing $SPEC_FILE"
  [ -f "$DESIGN_FILE" ] || die "missing $DESIGN_FILE"
}

require_focus_wi() {
  FOCUS_WI="$(yaml_scalar "$META_FILE" focus_work_item)"
  [ "$FOCUS_WI" != "null" ] || die "focus_work_item is null"
  WI_FILE="$CONTAINER_ROOT/work-items/$FOCUS_WI.yaml"
  [ -f "$WI_FILE" ] || die "missing work item: $WI_FILE"
}

collect_spec_ids() {
  local kind="$1"
  grep -oE "${kind}-[0-9]{3}" "$SPEC_FILE" | sort -u || true
}

work_item_refs_acceptance() {
  local file
  for file in "$CONTAINER_ROOT"/work-items/*.yaml; do
    [ -f "$file" ] || continue
    yaml_list "$file" acceptance_refs
  done | grep -E '^ACC-[0-9]{3}$' | sort -u || true
}

has_testing_record() {
  local acc="$1"
  [ -f "$TESTING_FILE" ] || return 1
  grep -A 5 -E "acceptance_ref: ${acc}$" "$TESTING_FILE" | grep -q 'result: pass'
}

gate_proposal_maturity() {
  grep -q '^## Default Read Layer$' "$SPEC_FILE" || die 'spec.md missing Default Read Layer'
  grep -q '^## Intent$' "$SPEC_FILE" || die 'spec.md missing Intent section'
  grep -q '^## Requirements$' "$SPEC_FILE" || die 'spec.md missing Requirements section'
  grep -q '^## Acceptance$' "$SPEC_FILE" || die 'spec.md missing Acceptance section'
  grep -q '^## Verification$' "$SPEC_FILE" || die 'spec.md missing Verification section'
  grep -q '^### Goals$' "$SPEC_FILE" || die 'spec.md missing Goals'
  grep -q '^### Testing Priority Rules$' "$SPEC_FILE" || die 'spec.md missing Testing Priority Rules'
  grep -q '<!-- SKELETON-END -->' "$SPEC_FILE" || die 'spec.md missing SKELETON-END marker'
  log '✓ proposal-maturity gate passed'
}

gate_requirements_approval() {
  grep -q '^### Proposal Coverage Map$' "$SPEC_FILE" || die 'spec.md missing Proposal Coverage Map'
  grep -q '^### Clarification Status$' "$SPEC_FILE" || die 'spec.md missing Clarification Status'

  local reqs=()
  local accs=()
  local vos=()
  mapfile -t reqs < <(collect_spec_ids 'REQ')
  mapfile -t accs < <(collect_spec_ids 'ACC')
  mapfile -t vos < <(collect_spec_ids 'VO')

  [ "${#reqs[@]}" -gt 0 ] || die 'no REQ-* entries found in spec.md'
  [ "${#accs[@]}" -gt 0 ] || die 'no ACC-* entries found in spec.md'
  [ "${#vos[@]}" -gt 0 ] || die 'no VO-* entries found in spec.md'

  local req
  for req in "${reqs[@]}"; do
    grep -q "source_ref: ${req}" "$SPEC_FILE" || die "requirement ${req} has no acceptance mapping"
  done

  local acc
  for acc in "${accs[@]}"; do
    grep -q "acceptance_ref: ${acc}" "$SPEC_FILE" || die "acceptance ${acc} has no verification mapping"
  done

  log '✓ requirements-approval gate passed'
}

gate_design_readiness() {
  grep -q '^## Default Read Layer$' "$DESIGN_FILE" || die 'design.md missing Default Read Layer'
  grep -q '^## Goal / Scope Link$' "$DESIGN_FILE" || die 'design.md missing Goal / Scope Link'
  grep -q '^## Architecture Boundary$' "$DESIGN_FILE" || die 'design.md missing Architecture Boundary'
  grep -q '^## Work Item Execution Strategy$' "$DESIGN_FILE" || die 'design.md missing Work Item Execution Strategy'
  grep -q '^## Design Slice Index$' "$DESIGN_FILE" || die 'design.md missing Design Slice Index'
  grep -q '^## Work Item Derivation$' "$DESIGN_FILE" || die 'design.md missing Work Item Derivation'
  grep -q '^## Contract Needs$' "$DESIGN_FILE" || die 'design.md missing Contract Needs'
  grep -q '^## Verification Design$' "$DESIGN_FILE" || die 'design.md missing Verification Design'
  grep -q '^## Failure Paths / Reopen Triggers$' "$DESIGN_FILE" || die 'design.md missing Failure Paths / Reopen Triggers'
  grep -q '^## Appendix Map$' "$DESIGN_FILE" || die 'design.md missing Appendix Map'
  grep -Eq 'WI-[0-9]{3}' "$DESIGN_FILE" || die 'design.md has no concrete WI derivation rows yet'
  log '✓ design-readiness gate passed'
}

gate_implementation_start() {
  require_focus_wi
  [ "$(yaml_scalar "$WI_FILE" goal)" != 'null' ] || die "$FOCUS_WI missing goal"
  [ "$(yaml_scalar "$WI_FILE" phase_scope)" = 'Implementation' ] || die "$FOCUS_WI phase_scope must be Implementation"

  local acceptance_refs=()
  local allowed_paths=()
  mapfile -t acceptance_refs < <(yaml_list "$WI_FILE" acceptance_refs)
  mapfile -t allowed_paths < <(yaml_list "$WI_FILE" allowed_paths)

  [ "${#acceptance_refs[@]}" -gt 0 ] || die "$FOCUS_WI missing acceptance_refs"
  [ "${#allowed_paths[@]}" -gt 0 ] || die "$FOCUS_WI missing allowed_paths"
  [ "$(yaml_scalar "$WI_FILE" derived_from)" != 'null' ] || die "$FOCUS_WI missing derived_from"

  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    [ "$ref" != 'null' ] || continue
    [ -f "$CONTAINER_ROOT/$ref" ] || die "$FOCUS_WI references missing contract: $ref"
  done < <(yaml_list "$WI_FILE" contract_refs)

  log '✓ implementation-start gate passed'
}

gate_scope() {
  require_focus_wi
  local changed=()
  mapfile -t changed < <(git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMR)
  [ "${#changed[@]}" -gt 0 ] || {
    log '✓ scope gate passed (no staged changes)'
    return
  }

  local allowed=()
  local forbidden=()
  mapfile -t allowed < <(yaml_list "$WI_FILE" allowed_paths)
  mapfile -t forbidden < <(yaml_list "$WI_FILE" forbidden_paths)

  local file pattern ok
  for file in "${changed[@]}"; do
    for pattern in "${forbidden[@]}"; do
      if match_path "$file" "$pattern"; then
        die "staged file $file is forbidden by $FOCUS_WI"
      fi
    done

    if [ "${#allowed[@]}" -gt 0 ]; then
      ok=0
      for pattern in "${allowed[@]}"; do
        if match_path "$file" "$pattern"; then
          ok=1
          break
        fi
      done
      [ "$ok" -eq 1 ] || die "staged file $file is outside allowed_paths of $FOCUS_WI"
    fi
  done

  log '✓ scope gate passed'
}

gate_boundary() {
  if [ -f "$META_FILE" ] && [ "$(yaml_scalar "$META_FILE" focus_work_item)" != 'null' ]; then
    require_focus_wi
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      [ "$ref" != 'null' ] || continue
      [ -f "$CONTAINER_ROOT/$ref" ] || die "$FOCUS_WI references missing contract: $ref"
    done < <(yaml_list "$WI_FILE" contract_refs)
  fi

  local rel_contract_root="change/$CONTAINER/contracts/"
  local file head_status index_status diff_lines filtered
  while IFS= read -r file; do
    [[ "$file" == ${rel_contract_root}* ]] || continue

    head_status="$(git -C "$PROJECT_ROOT" show "HEAD:$file" 2>/dev/null | grep '^status:' | awk '{print $2}' || true)"
    index_status="$(git -C "$PROJECT_ROOT" show ":$file" 2>/dev/null | grep '^status:' | awk '{print $2}' || true)"

    if [ "$head_status" = 'frozen' ]; then
      diff_lines="$(git -C "$PROJECT_ROOT" diff --cached --unified=0 -- "$file" | grep -E '^[+-]' | grep -vE '^(---|\+\+\+)' || true)"
      filtered="$(printf '%s\n' "$diff_lines" | grep -vE '^[+-]status: (frozen|draft)$' || true)"
      if [ "$index_status" = 'draft' ] && [ -z "$filtered" ]; then
        continue
      fi
      die "frozen contract cannot be modified: $file"
    fi
  done < <(git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMR)

  log '✓ boundary gate passed'
}

gate_trace_consistency() {
  local reqs=()
  local accs=()
  local wis=()
  mapfile -t reqs < <(collect_spec_ids 'REQ')
  mapfile -t accs < <(collect_spec_ids 'ACC')
  mapfile -t wis < <(work_item_refs_acceptance)

  local req
  for req in "${reqs[@]}"; do
    grep -q "source_ref: ${req}" "$SPEC_FILE" || die "trace gap: ${req} has no ACC"
  done

  local acc
  for acc in "${accs[@]}"; do
    grep -q "acceptance_ref: ${acc}" "$SPEC_FILE" || die "trace gap: ${acc} has no VO"
  done

  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"
  if [ "$phase" = 'Design' ] || [ "$phase" = 'Implementation' ] || [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
    for acc in "${accs[@]}"; do
      printf '%s\n' "${wis[@]}" | grep -qx "$acc" || die "trace gap: ${acc} is not referenced by any work item"
    done
  fi

  if [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
    [ -f "$TESTING_FILE" ] || die 'testing.md is required in Testing/Deployment phase'
    for acc in "${accs[@]}"; do
      grep -q -E "acceptance_ref: ${acc}$" "$TESTING_FILE" || die "trace gap: ${acc} has no testing record"
    done
  fi

  log '✓ trace-consistency gate passed'
}

gate_testing_coverage() {
  [ -f "$TESTING_FILE" ] || die 'missing testing.md'
  local accs=()
  mapfile -t accs < <(collect_spec_ids 'ACC')
  [ "${#accs[@]}" -gt 0 ] || die 'no ACC-* entries found in spec.md'

  local acc
  for acc in "${accs[@]}"; do
    grep -q -E "acceptance_ref: ${acc}$" "$TESTING_FILE" || die "testing.md missing record for ${acc}"
    has_testing_record "$acc" || die "testing.md does not have a passing record for ${acc}"
  done

  log '✓ testing-coverage gate passed'
}

gate_verification() {
  require_focus_wi
  [ -f "$TESTING_FILE" ] || die 'missing testing.md'
  local dep acc

  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    [ "$dep" != 'null' ] || continue
    [ -f "$CONTAINER_ROOT/work-items/$dep.yaml" ] || die "missing dependency work item: $dep"
    while IFS= read -r acc; do
      [ -n "$acc" ] || continue
      has_testing_record "$acc" || die "dependency ${dep} is not complete: ${acc} has no pass record"
    done < <(yaml_list "$CONTAINER_ROOT/work-items/$dep.yaml" acceptance_refs)
  done < <(yaml_list "$WI_FILE" dependency_refs)

  while IFS= read -r acc; do
    [ -n "$acc" ] || continue
    grep -q -E "acceptance_ref: ${acc}$" "$TESTING_FILE" || die "current work item acceptance ${acc} has no testing record"
    has_testing_record "$acc" || die "current work item acceptance ${acc} has no pass record"
  done < <(yaml_list "$WI_FILE" acceptance_refs)

  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"
  if [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
    gate_testing_coverage
  fi

  log '✓ verification gate passed'
}

gate_deployment_readiness() {
  local deployment_file="$CONTAINER_ROOT/deployment.md"
  if [ ! -f "$deployment_file" ]; then
    log '✓ deployment-readiness gate passed (deployment.md not materialized)'
    return
  fi

  grep -q '^## Acceptance Conclusion$' "$deployment_file" || die 'deployment.md missing Acceptance Conclusion'
  grep -q '^status: pass$' "$deployment_file" || die 'deployment.md acceptance conclusion is not pass'
  grep -q 'smoke_test: pass' "$deployment_file" || die 'deployment.md smoke_test is not pass'
  log '✓ deployment-readiness gate passed'
}

gate_promotion_criteria() {
  [ -d "$PROJECT_ROOT/versions" ] || die 'versions directory is missing'
  local phase status
  phase="$(yaml_scalar "$META_FILE" phase)"
  status="$(yaml_scalar "$META_FILE" status)"
  [ "$phase" = 'Deployment' ] || [ "$status" = 'completed' ] || die 'promotion requires Deployment phase or completed status'
  gate_testing_coverage
  gate_deployment_readiness
  log '✓ promotion-criteria gate passed'
}

main() {
  [ -n "$GATE" ] || die 'usage: check-gate.sh <name>'
  require_context

  case "$GATE" in
    spec-completeness)
      gate_proposal_maturity
      gate_requirements_approval
      ;;
    proposal-maturity)
      gate_proposal_maturity
      ;;
    requirements-approval)
      gate_requirements_approval
      ;;
    design-readiness)
      gate_design_readiness
      ;;
    implementation-start)
      gate_implementation_start
      ;;
    scope)
      gate_scope
      ;;
    boundary)
      gate_boundary
      ;;
    trace-consistency)
      gate_trace_consistency
      ;;
    verification)
      gate_verification
      ;;
    testing-coverage)
      gate_testing_coverage
      ;;
    deployment-readiness)
      gate_deployment_readiness
      ;;
    promotion)
      gate_deployment_readiness
      gate_promotion_criteria
      ;;
    promotion-criteria)
      gate_promotion_criteria
      ;;
    *)
      die "unknown gate: $GATE"
      ;;
  esac
}

main "$@"
