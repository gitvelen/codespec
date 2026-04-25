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

contract_status() {
  local file="$1"
  grep '^status:' "$file" | awk '{print $2}' || true
}

find_workspace_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/.codespec/codespec" ]; then
      printf '%s\n' "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

find_project_root() {
  if [ -n "${CODESPEC_PROJECT_ROOT:-}" ]; then
    printf '%s\n' "$CODESPEC_PROJECT_ROOT"
    return
  fi

  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
    return
  fi

  printf '%s\n' "$PWD"
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

normalize_csv() {
  printf '%s' "$1" | tr ',' '\n' | grep -v '^$' | sort | paste -sd ',' -
}

require_context() {
  require_yq
  PROJECT_ROOT="$(find_project_root)"
  META_FILE="$PROJECT_ROOT/meta.yaml"
  SPEC_FILE="$PROJECT_ROOT/spec.md"
  DESIGN_FILE="$PROJECT_ROOT/design.md"
  TESTING_FILE="$PROJECT_ROOT/testing.md"

  [ -f "$META_FILE" ] || die "missing $META_FILE"
  [ -f "$SPEC_FILE" ] || die "missing $SPEC_FILE"
  [ -f "$DESIGN_FILE" ] || die "missing $DESIGN_FILE"
}

require_focus_wi() {
  if [ -n "${CODESPEC_FOCUS_WI:-}" ] && [ "${CODESPEC_FOCUS_WI}" != 'null' ]; then
    FOCUS_WI="$CODESPEC_FOCUS_WI"
  else
    FOCUS_WI="$(yaml_scalar "$META_FILE" focus_work_item)"
  fi
  [ "$FOCUS_WI" != "null" ] || die "focus_work_item is null"
  WI_FILE="$PROJECT_ROOT/work-items/$FOCUS_WI.yaml"
  [ -f "$WI_FILE" ] || die "missing work item: $WI_FILE"
}

current_git_branch() {
  if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$PROJECT_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached'
    return
  fi
  printf 'none'
}

validate_git_revision() {
  local revision="$1"
  [ -n "$revision" ] || return 1
  [ "$revision" != 'null' ] || return 1
  git -C "$PROJECT_ROOT" rev-parse --verify "${revision}^{commit}" >/dev/null 2>&1
}

collect_staged_files() {
  git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMRD
}

collect_implementation_span_files() {
  local base_revision
  base_revision="$(yaml_scalar "$META_FILE" implementation_base_revision)"
  validate_git_revision "$base_revision" || die "implementation_base_revision is missing or invalid: ${base_revision:-null}"

  {
    git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMRD "${base_revision}..HEAD"
    git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMRD
    git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMRD
    git -C "$PROJECT_ROOT" ls-files --others --exclude-standard
  } | grep -v '^$' | sort -u
}

collect_active_work_items() {
  local items
  items=$(yaml_list "$META_FILE" active_work_items | grep -vE '^(|null)$' || true)

  # Check for duplicates
  if [ -n "$items" ]; then
    local unique_count total_count
    unique_count=$(echo "$items" | sort -u | wc -l)
    total_count=$(echo "$items" | wc -l)
    if [ "$unique_count" -ne "$total_count" ]; then
      die "Duplicate work items found in active_work_items"
    fi

    printf '%s\n' "$items"
  fi
}

contains_exact_line() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

is_placeholder_token() {
  local value
  value="$(trim_value "$1")"
  [ -n "$value" ] || return 0

  normalized_value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | tr -d "'\"")"

  case "$normalized_value" in
    null|pending|todo|tbd|placeholder|none|yyyy-mm-dd)
      return 0
      ;;
  esac

  [[ "$normalized_value" =~ ^\[[^]]+\]$ ]] && return 0
  return 1
}

markdown_section_scalar() {
  local file="$1"
  local header="$2"
  local key="$3"
  awk -v header="$header" -v key="$key" '
    $0 == header {
      in_section = 1
      next
    }
    in_section && /^## / {
      exit
    }
    in_section && $0 ~ "^[[:space:]]*-?[[:space:]]*" key ":[[:space:]]*" {
      line = $0
      sub("^[[:space:]]*-?[[:space:]]*" key ":[[:space:]]*", "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$file"
}

input_intake_scalar() {
  local key="$1"
  awk -v key="$key" '
    BEGIN { in_intake = 0 }
    /^## Inputs$/ || /^### Input Intake Summary$/ || /^### Input Intake$/ {
      in_intake = 1
      next
    }
    in_intake && /^### / {
      exit
    }
    in_intake && /^## / {
      exit
    }
    in_intake && $0 ~ "^[[:space:]]*-[[:space:]]*" key ":[[:space:]]*" {
      line = $0
      sub("^[[:space:]]*-[[:space:]]*" key ":[[:space:]]*", "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$SPEC_FILE"
}

input_intake_refs() {
  awk '
    BEGIN { capture = 0; in_intake = 0 }
    /^## Inputs$/ || /^### Input Intake Summary$/ || /^### Input Intake$/ {
      in_intake = 1
      next
    }
    in_intake && /^### / {
      exit
    }
    in_intake && /^## / {
      exit
    }
    in_intake && (/^[[:space:]]*-[[:space:]]*source_refs:[[:space:]]*$/ || /^[[:space:]]*-[[:space:]]*input_refs:[[:space:]]*$/) {
      capture = 1
      next
    }
    capture && /^[[:space:]][[:space:]]+-[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]+-[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      next
    }
    capture && /^[[:space:]]*-[[:space:]]*[a-zA-Z_]+:[[:space:]]*/ {
      exit
    }
    capture && /^[[:space:]]*$/ {
      next
    }
    capture {
      exit
    }
  ' "$SPEC_FILE"
}

is_stable_repo_input_ref() {
  local ref="$1"
  local target_path="${ref%%#*}"

  [ -n "$ref" ] || return 1
  [ -n "$target_path" ] || return 1

  case "$ref" in
    *://*)
      return 1
      ;;
    /*)
      return 1
      ;;
    ../*|*/../*|*/..|..)
      return 1
      ;;
    ./*|*/./*|*/.|.)
      return 1
      ;;
  esac

  return 0
}

validate_input_evidence_refs() {
  local source_refs=("$@")
  local source_ref target_path

  for source_ref in "${source_refs[@]}"; do
    is_stable_repo_input_ref "$source_ref" || die "input_refs must reference stable repo artifacts; conversation:// is not allowed"
    target_path="${source_ref%%#*}"
    [ -f "$PROJECT_ROOT/$target_path" ] || die "input_refs references missing repo artifact: ${target_path}"
  done
}

requirements_source_refs() {
  awk '
    BEGIN { in_requirements = 0 }
    /^## Requirements$/ {
      in_requirements = 1
      next
    }
    /^## / && in_requirements {
      exit
    }
    !in_requirements {
      next
    }

    /^[[:space:]]*-[[:space:]]*source_ref:[[:space:]]*/ || /^[[:space:]]*source_ref:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*source_ref:[[:space:]]*/, "", line)
      sub(/^[[:space:]]*source_ref:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      next
    }
  ' "$SPEC_FILE" | grep -v '^$' | sort -u
}

collect_formal_requirement_ids() {
  awk '
    BEGIN { in_requirements = 0; in_functional = 0 }
    /^## Requirements$/ {
      in_requirements = 1
      in_functional = 0
      next
    }
    /^## / {
      if (in_requirements) {
        in_requirements = 0
        in_functional = 0
      }
      next
    }
    !in_requirements { next }
    /^### Functional Requirements$/ {
      in_functional = 1
      next
    }
    /^### / {
      in_functional = 0
      next
    }
    in_functional && /^[[:space:]]*-[[:space:]]*REQ-[0-9]{3}[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
    }
  ' "$SPEC_FILE" | sort -u || true
}

gate_metadata_consistency() {
  local phase status focus_wi execution_group execution_branch implementation_base_revision active=() wi
  phase="$(yaml_scalar "$META_FILE" phase)"
  status="$(yaml_scalar "$META_FILE" status)"
  focus_wi="$(yaml_scalar "$META_FILE" focus_work_item)"
  execution_group="$(yaml_scalar "$META_FILE" execution_group)"
  execution_branch="$(yaml_scalar "$META_FILE" execution_branch)"
  implementation_base_revision="$(yaml_scalar "$META_FILE" implementation_base_revision)"
  mapfile -t active < <(collect_active_work_items)

  case "$status" in
    active|blocked|completed) ;;
    *) die "status must be one of active|blocked|completed (got: ${status:-missing})" ;;
  esac

  if [ "$implementation_base_revision" != 'null' ] && [ -n "$implementation_base_revision" ]; then
    validate_git_revision "$implementation_base_revision" || die "implementation_base_revision must be a valid commit (got: $implementation_base_revision)"
  fi

  for wi in "${active[@]}"; do
    [ -f "$PROJECT_ROOT/work-items/$wi.yaml" ] || die "active_work_items references missing work item: ${wi}"
  done

  if [ "$focus_wi" != 'null' ]; then
    [ -f "$PROJECT_ROOT/work-items/$focus_wi.yaml" ] || die "missing work item: $PROJECT_ROOT/work-items/$focus_wi.yaml"
    contains_exact_line "$focus_wi" "${active[@]}" || die "focus_work_item ${focus_wi} must be listed in active_work_items"
  fi

  case "$phase" in
    Implementation)
      [ "$focus_wi" != 'null' ] || die 'Implementation phase requires focus_work_item'
      [ "${#active[@]}" -gt 0 ] || die 'Implementation phase requires active_work_items to be non-empty'
      [ "$implementation_base_revision" != 'null' ] || die 'Implementation phase requires implementation_base_revision'
      ;;
    Testing)
      [ "$focus_wi" = 'null' ] || die 'Testing phase requires focus_work_item = null'
      # Testing 阶段保留 active_work_items 用于 verification gate
      [ "${#active[@]}" -gt 0 ] || die 'Testing phase requires active_work_items to be non-empty (should be preserved from Implementation)'
      [ "$implementation_base_revision" != 'null' ] || die 'Testing phase requires implementation_base_revision'
      ;;
    Deployment)
      [ "$focus_wi" = 'null' ] || die 'Deployment phase requires focus_work_item = null'
      [ "$implementation_base_revision" != 'null' ] || die 'Deployment phase requires implementation_base_revision'
      if [ "$status" = 'completed' ]; then
        [ "${#active[@]}" -eq 0 ] || die 'completed status requires active_work_items = []'
      else
        # Deployment 阶段也保留 active_work_items
        [ "${#active[@]}" -gt 0 ] || die 'Deployment phase requires active_work_items to be non-empty (should be preserved from Implementation)'
      fi
      ;;
  esac

  log '✓ metadata-consistency gate passed'
}

collect_formal_requirement_ids() {
  awk '
    BEGIN { in_requirements = 0 }
    /^## Requirements$/ {
      in_requirements = 1
      next
    }
    /^## / {
      if (in_requirements) {
        in_requirements = 0
      }
      next
    }
    !in_requirements { next }
    /^[[:space:]]*-[[:space:]]*REQ-[0-9]{3}[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
    }
  ' "$SPEC_FILE" | sort -u || true
}

collect_formal_acceptance_ids() {
  awk '
    BEGIN { in_acceptance = 0 }
    /^## Acceptance$/ {
      in_acceptance = 1
      next
    }
    /^## / {
      if (in_acceptance) {
        in_acceptance = 0
      }
      next
    }
    !in_acceptance { next }
    /^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*ACC-[0-9]{3}[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
    }
  ' "$SPEC_FILE" | sort -u || true
}

collect_formal_verification_ids() {
  awk '
    BEGIN { in_verification = 0 }
    /^## Verification$/ {
      in_verification = 1
      next
    }
    /^## / {
      if (in_verification) {
        in_verification = 0
      }
      next
    }
    !in_verification { next }
    /^[[:space:]]*-[[:space:]]*vo_id:[[:space:]]*VO-[0-9]{3}[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*vo_id:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
    }
  ' "$SPEC_FILE" | sort -u || true
}

collect_spec_ids() {
  local kind="$1"
  case "$kind" in
    REQ)
      collect_formal_requirement_ids
      ;;
    ACC)
      collect_formal_acceptance_ids
      ;;
    VO)
      collect_formal_verification_ids
      ;;
    *)
      return 0
      ;;
  esac
}

work_item_refs_acceptance() {
  local file
  for file in "$PROJECT_ROOT"/work-items/*.yaml; do
    [ -f "$file" ] || continue
    yaml_list "$file" acceptance_refs
  done | grep -E '^ACC-[0-9]{3}$' | sort -u || true
}

work_item_refs_requirements() {
  local file
  for file in "$PROJECT_ROOT"/work-items/*.yaml; do
    [ -f "$file" ] || continue
    yaml_list "$file" requirement_refs
  done | grep -E '^REQ-[0-9]{3}$' | sort -u || true
}

work_item_refs_verification() {
  local file
  for file in "$PROJECT_ROOT"/work-items/*.yaml; do
    [ -f "$file" ] || continue
    yaml_list "$file" verification_refs
  done | grep -E '^VO-[0-9]{3}$' | sort -u || true
}

acceptance_expected_outcome() {
  local acc="$1"
  awk -v acc="$acc" '
    BEGIN { in_acceptance = 0; current = "" }
    /^## Acceptance$/ {
      in_acceptance = 1
      next
    }
    /^## / && in_acceptance {
      exit
    }
    !in_acceptance { next }
    /^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*ACC-[0-9]{3}[[:space:]]*$/ {
      current = $0
      sub(/^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*/, "", current)
      sub(/[[:space:]]*$/, "", current)
      next
    }
    current == acc && /^[[:space:]]*expected_outcome:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*expected_outcome:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$SPEC_FILE"
}

collect_approved_acceptance_ids() {
  awk '
    BEGIN { in_acceptance = 0; current = ""; approved = 0 }
    /^## Acceptance$/ {
      in_acceptance = 1
      current = ""
      approved = 0
      next
    }
    /^## / {
      if (in_acceptance && current != "" && approved == 1) {
        print current
      }
      in_acceptance = 0
      current = ""
      approved = 0
      next
    }
    !in_acceptance { next }
    /^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*ACC-[0-9]{3}[[:space:]]*$/ {
      if (current != "" && approved == 1) {
        print current
      }
      current = $0
      sub(/^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*/, "", current)
      sub(/[[:space:]]*$/, "", current)
      approved = 0
      next
    }
    current != "" && /^[[:space:]]*status:[[:space:]]*approved[[:space:]]*$/ {
      approved = 1
      next
    }
    END {
      if (in_acceptance && current != "" && approved == 1) {
        print current
      }
    }
  ' "$SPEC_FILE" | sort -u || true
}

work_item_approved_acceptance_refs() {
  local wi_file="$1"
  local approved=()
  local acc

  [ -f "$wi_file" ] || return 0
  mapfile -t approved < <(collect_approved_acceptance_ids)

  while IFS= read -r acc; do
    [ -n "$acc" ] || continue
    contains_exact_line "$acc" "${approved[@]}" && printf '%s\n' "$acc"
  done < <(yaml_list "$wi_file" acceptance_refs)
}

testing_target_acceptance_ids() {
  local approved=()
  mapfile -t approved < <(collect_approved_acceptance_ids)
  if [ "${#approved[@]}" -gt 0 ]; then
    printf '%s\n' "${approved[@]}"
    return
  fi
  collect_spec_ids 'ACC'
}

testing_record_scalar() {
  local acc="$1"
  local key="$2"
  testing_record_latest_scalar "$acc" "$key"
}

testing_record_scalar_from_scope() {
  local acc="$1"
  local key="$2"
  local scope="$3"
  testing_record_latest_scalar "$acc" "$key" "$scope"
}

testing_record_latest_scalar() {
  local acc="$1"
  local key="$2"
  local scope="${3:-}"
  awk -v acc="$acc" -v key="$key" -v scope="$scope" '
    function reset_record() {
      in_record = 0
      record_scope = ""
      record_result = ""
      record_value = ""
    }

    function flush_record() {
      if (!in_record) {
        return
      }

      if (record_result != "" && record_result != "pass" && record_result != "fail") {
        print "ERROR: invalid result value: " record_result " (must be pass or fail)" > "/dev/stderr"
        exit_code = 1
        should_abort = 1
        return
      }

      if (scope != "" && record_scope != scope) {
        return
      }

      selected = record_value
      found = 1
    }

    BEGIN {
      reset_record()
      found = 0
      should_abort = 0
      exit_code = 0
    }

    /^[[:space:]]*-[[:space:]]*acceptance_ref:[[:space:]]*ACC-[0-9]{3}[[:space:]]*$/ {
      flush_record()
      if (should_abort) {
        exit exit_code
      }

      reset_record()
      if ($0 ~ "^[[:space:]]*-[[:space:]]*acceptance_ref:[[:space:]]*" acc "[[:space:]]*$") {
        in_record = 1
      }
      next
    }

    !in_record { next }

    /^[[:space:]]*test_scope:[[:space:]]*/ {
      line = $0
      sub("^[[:space:]]*test_scope:[[:space:]]*", "", line)
      sub(/[[:space:]]*$/, "", line)
      record_scope = line
      if (key == "test_scope") {
        record_value = line
      }
      next
    }

    /^[[:space:]]*result:[[:space:]]*/ {
      line = $0
      sub("^[[:space:]]*result:[[:space:]]*", "", line)
      sub(/[[:space:]]*$/, "", line)
      record_result = tolower(line)
      if (key == "result") {
        record_value = record_result
      }
      next
    }

    $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
      line = $0
      sub("^[[:space:]]*" key ":[[:space:]]*", "", line)
      sub(/[[:space:]]*$/, "", line)
      record_value = line
      next
    }

    END {
      flush_record()
      if (should_abort) {
        exit exit_code
      }
      if (found) {
        print selected
      }
    }
  ' "$TESTING_FILE"
}

spec_acceptance_priority() {
  local acc="$1"
  awk -v acc="$acc" '
    BEGIN { in_acceptance = 0; current = "" }
    /^## Acceptance$/ {
      in_acceptance = 1
      next
    }
    /^## / && in_acceptance {
      exit
    }
    !in_acceptance { next }
    /^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*ACC-[0-9]{3}[[:space:]]*$/ {
      current = $0
      sub(/^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*/, "", current)
      sub(/[[:space:]]*$/, "", current)
      next
    }
    current == acc && /^[[:space:]]*priority:[[:space:]]*P[0-9][[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*priority:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      exit
    }
  ' "$SPEC_FILE"
}

has_testing_record() {
  local acc="$1"
  local result
  [ -f "$TESTING_FILE" ] || return 1
  result="$(testing_record_scalar "$acc" result)" || return 1
  [ "$result" = 'pass' ]
}

has_full_integration_pass() {
  local acc="$1"
  local result
  [ -f "$TESTING_FILE" ] || return 1
  result="$(testing_record_scalar_from_scope "$acc" result full-integration)" || return 1
  [ "$result" = 'pass' ]
}

check_circular_dependencies() {
  local start_wi="$1"
  local visited=()
  local path=()

  check_circular_recursive() {
    local current="$1"
    local dep

    # Check if current WI is in the path (circular dependency detected)
    for wi in "${path[@]}"; do
      if [ "$wi" = "$current" ]; then
        die "circular dependency detected: ${path[*]} -> $current"
      fi
    done

    # Add current to path
    path+=("$current")

    # Check if already visited (optimization)
    for wi in "${visited[@]}"; do
      if [ "$wi" = "$current" ]; then
        path=("${path[@]:0:${#path[@]}-1}")  # Remove current from path
        return
      fi
    done

    # Mark as visited
    visited+=("$current")

    # Check dependencies recursively
    local wi_file="$PROJECT_ROOT/work-items/$current.yaml"
    if [ -f "$wi_file" ]; then
      while IFS= read -r dep; do
        [ -n "$dep" ] || continue
        [ "$dep" != 'null' ] || continue
        check_circular_recursive "$dep"
      done < <(yaml_list "$wi_file" dependency_refs)
    fi

    # Remove current from path
    path=("${path[@]:0:${#path[@]}-1}")
  }

  check_circular_recursive "$start_wi"
}

check_dependency_pass_records() {
  # NOTE: Currently all dependencies are treated as strong dependencies (must have pass records).
  # The dependency_type field (strong/weak/none) is validated for correctness but weak dependencies
  # are not yet implemented with different behavior. This is intentional - weak dependencies are
  # documented for coordination purposes but enforced the same as strong dependencies.
  local wi_file="${1:-${WI_FILE:-}}"
  local dep acc

  [ -n "$wi_file" ] || die 'missing work item context for dependency check'
  [ -f "$wi_file" ] || die "missing work item: $wi_file"

  while IFS= read -r dep; do
    [ -n "$dep" ] || continue
    [ "$dep" != 'null' ] || continue
    [ -f "$PROJECT_ROOT/work-items/$dep.yaml" ] || die "missing dependency work item: $dep"

    while IFS= read -r acc; do
      [ -n "$acc" ] || continue
      has_testing_record "$acc" || die "dependency ${dep} is not complete: ${acc} has no pass record"
    done < <(work_item_approved_acceptance_refs "$PROJECT_ROOT/work-items/$dep.yaml")
  done < <(yaml_list "$wi_file" dependency_refs)
}

formal_id_definition_matches() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  grep -R -n -E '^[[:space:]]*-[[:space:]]*REQ-[0-9]{3}([[:space:]]*$|[[:space:]]*:)|^[[:space:]]*REQ-[0-9]{3}:[[:space:]]*|^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*ACC-[0-9]{3}[[:space:]]*$|^[[:space:]]*acc_id:[[:space:]]*ACC-[0-9]{3}[[:space:]]*$|^[[:space:]]*-[[:space:]]*vo_id:[[:space:]]*VO-[0-9]{3}[[:space:]]*$|^[[:space:]]*vo_id:[[:space:]]*VO-[0-9]{3}[[:space:]]*$' "$dir" 2>/dev/null || true
}

intent_anchor_lines() {
  awk '
    BEGIN { in_intent = 0; section = "" }
    /^## Intent$/ { in_intent = 1; next }
    /^## / && in_intent { exit }
    !in_intent { next }
    /^### / {
      section = $0
      next
    }
    /^[[:space:]]*-[[:space:]]+/ {
      if (section == "### Goals" || section == "### Must-have Anchors" || section == "### Prohibition Anchors" || section == "### Success Anchors" || section == "### Boundary Alerts" || section == "### Unresolved Decisions") {
        line = $0
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        sub(/[[:space:]]*$/, "", line)
        lower = tolower(line)
        if (lower == "none" || lower == "null") {
          next
        }
        print line
      }
    }
  ' "$SPEC_FILE"
}

review_file_matches() {
  local review_file="$1"
  local expected_file="$2"
  local expected_phase="$3"
  [ -f "$review_file" ] || return 1
  [ "$(basename "$review_file")" = "$expected_file" ] || return 1
  [ "$(yaml_scalar "$review_file" phase)" = "$expected_phase" ] || return 1
  [ "$(yaml_scalar "$review_file" verdict)" = 'approved' ] || return 1
  local rb ra
  rb="$(yaml_scalar "$review_file" reviewed_by)"
  ra="$(yaml_scalar "$review_file" reviewed_at)"
  [ "$rb" != 'null' ] && [ -n "$rb" ] || return 1
  [ "$ra" != 'null' ] && [ -n "$ra" ] || return 1
  return 0
}

gate_review_verdict_present() {
  # NOTE: This gate only supports Requirement/Design/Implementation transitions.
  # If future phases require review verdict checks, add corresponding cases below.
  # Extensibility limitation: target_phase mapping must be manually maintained.
  local reviews_dir="$PROJECT_ROOT/reviews"
  local review_file expected_file expected_phase
  local target_phase="${CODESPEC_TARGET_PHASE:-}"

  case "$target_phase" in
    Design)
      expected_file='design-review.yaml'
      expected_phase='Requirement'
      ;;
    Implementation)
      expected_file='implementation-review.yaml'
      expected_phase='Design'
      ;;
    *)
      die 'review-verdict-present gate failed'
      ;;
  esac

  [ -d "$reviews_dir" ] || die 'review-verdict-present gate failed'

  for review_file in "$reviews_dir"/*.yaml; do
    [ -e "$review_file" ] || continue
    if review_file_matches "$review_file" "$expected_file" "$expected_phase"; then
      log '✓ review-verdict-present gate passed'
      return
    fi
  done

  die 'review-verdict-present gate failed'
}

design_work_item_acceptance_rows() {
  awk '
    function flush_row() {
      if (in_derivation && wi != "") print wi ":" refs
    }
    BEGIN { in_derivation = 0; wi = ""; refs = "" }
    /^## Work Item Derivation$/ {
      flush_row()
      in_derivation = 1
      wi = ""
      refs = ""
      next
    }
    /^## / {
      flush_row()
      in_derivation = 0
      wi = ""
      refs = ""
      next
    }
    !in_derivation { next }
    /^[[:space:]]*-[[:space:]]*wi_id:[[:space:]]*WI-[0-9]{3}[[:space:]]*$/ {
      flush_row()
      wi = $0
      sub(/^[[:space:]]*-[[:space:]]*wi_id:[[:space:]]*/, "", wi)
      sub(/[[:space:]]*$/, "", wi)
      refs = ""
      next
    }
    wi != "" && /^[[:space:]]*covered_acceptance_refs:[[:space:]]*\[/ {
      refs = $0
      sub(/^[[:space:]]*covered_acceptance_refs:[[:space:]]*\[/, "", refs)
      sub(/\][[:space:]]*$/, "", refs)
      gsub(/[[:space:]]/, "", refs)
      next
    }
    END {
      flush_row()
    }
  ' "$DESIGN_FILE"
}

design_work_item_block() {
  local wi="$1"
  awk -v wi="$wi" '
    function flush_row() {
      if (current_wi == wi && current_row != "") {
        selected = current_row
      }
      current_wi = ""
      current_row = ""
    }

    /^## Work Item Derivation$/ {
      if (in_derivation) {
        flush_row()
      }
      in_derivation = 1
      next
    }

    /^## / {
      if (in_derivation) {
        flush_row()
        in_derivation = 0
      }
      next
    }

    !in_derivation {
      next
    }

    /^[[:space:]]*-[[:space:]]*wi_id:[[:space:]]*WI-[0-9]{3}[[:space:]]*$/ {
      flush_row()
      current_wi = $0
      sub(/^[[:space:]]*-[[:space:]]*wi_id:[[:space:]]*/, "", current_wi)
      sub(/[[:space:]]*$/, "", current_wi)
      current_row = $0
      next
    }

    current_wi != "" {
      current_row = current_row ORS $0
    }

    END {
      if (in_derivation) {
        flush_row()
      }
      if (selected != "") {
        printf "%s\n", selected
      }
    }
  ' "$DESIGN_FILE"
}

block_scalar_value() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*-[[:space:]]*" key ":[[:space:]]*" {
      line = $0
      sub("^[[:space:]]*-[[:space:]]*" key ":[[:space:]]*", "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      exit
    }
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
      line = $0
      sub("^[[:space:]]*" key ":[[:space:]]*", "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      exit
    }
  '
}

block_list_values() {
  local key="$1"
  awk -v key="$key" '
    BEGIN { capture = 0 }

    $0 ~ "^[[:space:]]*" key ":[[:space:]]*\\[[^]]*\\][[:space:]]*$" {
      line = $0
      sub("^[[:space:]]*" key ":[[:space:]]*\\[", "", line)
      sub("\\][[:space:]]*$", "", line)
      gsub(/[[:space:]]/, "", line)
      count = split(line, parts, ",")
      for (i = 1; i <= count; i++) {
        if (parts[i] != "") print parts[i]
      }
      capture = 0
      next
    }

    $0 ~ "^[[:space:]]*" key ":[[:space:]]*$" {
      capture = 1
      next
    }

    capture && /^[[:space:]]*-[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
      next
    }

    capture && /^[[:space:]]*[a-zA-Z_]+:[[:space:]]*/ {
      capture = 0
      next
    }
  '
}

check_focus_wi_design_alignment() {
  local design_block
  design_block="$(design_work_item_block "$FOCUS_WI")"
  [ -n "$design_block" ] || die "focus work item ${FOCUS_WI} is missing from design work item derivation"

  local design_input_refs=()
  local design_requirement_refs=()
  local design_acceptance_refs=()
  local design_verification_refs=()

  mapfile -t design_input_refs < <(printf '%s\n' "$design_block" | block_list_values input_refs | grep -vE '^(|null)$' || true)
  mapfile -t design_requirement_refs < <(printf '%s\n' "$design_block" | block_list_values requirement_refs | grep -vE '^(|null)$' || true)
  mapfile -t design_acceptance_refs < <(printf '%s\n' "$design_block" | block_list_values covered_acceptance_refs | grep -vE '^(|null)$' || true)
  mapfile -t design_verification_refs < <(printf '%s\n' "$design_block" | block_list_values verification_refs | grep -vE '^(|null)$' || true)

  # 从 WI_FILE 重新读取这些变量，避免依赖外部作用域
  local wi_input_refs=()
  local wi_requirement_refs=()
  local wi_acceptance_refs=()
  local wi_verification_refs=()

  mapfile -t wi_input_refs < <(yaml_list "$WI_FILE" input_refs)
  mapfile -t wi_requirement_refs < <(yaml_list "$WI_FILE" requirement_refs)
  mapfile -t wi_acceptance_refs < <(yaml_list "$WI_FILE" acceptance_refs)
  mapfile -t wi_verification_refs < <(yaml_list "$WI_FILE" verification_refs)

  local wi_inputs_csv wi_requirements_csv wi_acceptance_csv wi_verification_csv
  local design_inputs_csv design_requirements_csv design_acceptance_csv design_verification_csv

  wi_inputs_csv="$(printf '%s\n' "${wi_input_refs[@]}" | paste -sd ',' -)"
  wi_requirements_csv="$(printf '%s\n' "${wi_requirement_refs[@]}" | paste -sd ',' -)"
  wi_acceptance_csv="$(printf '%s\n' "${wi_acceptance_refs[@]}" | paste -sd ',' -)"
  wi_verification_csv="$(printf '%s\n' "${wi_verification_refs[@]}" | paste -sd ',' -)"

  design_inputs_csv="$(printf '%s\n' "${design_input_refs[@]}" | paste -sd ',' -)"
  design_requirements_csv="$(printf '%s\n' "${design_requirement_refs[@]}" | paste -sd ',' -)"
  design_acceptance_csv="$(printf '%s\n' "${design_acceptance_refs[@]}" | paste -sd ',' -)"
  design_verification_csv="$(printf '%s\n' "${design_verification_refs[@]}" | paste -sd ',' -)"

  [ "$(normalize_csv "$wi_inputs_csv")" = "$(normalize_csv "$design_inputs_csv")" ] || die "design/work-item input_refs mismatch for $FOCUS_WI"
  [ "$(normalize_csv "$wi_requirements_csv")" = "$(normalize_csv "$design_requirements_csv")" ] || die "design/work-item requirement_refs mismatch for $FOCUS_WI"
  [ "$(normalize_csv "$wi_acceptance_csv")" = "$(normalize_csv "$design_acceptance_csv")" ] || die "design/work-item acceptance_refs mismatch for $FOCUS_WI"
  [ "$(normalize_csv "$wi_verification_csv")" = "$(normalize_csv "$design_verification_csv")" ] || die "design/work-item verification_refs mismatch for $FOCUS_WI"
}

check_wi_refs_exist_in_spec() {
  local spec_requirements=()
  local spec_acceptances=()
  local spec_verifications=()
  local ref

  mapfile -t spec_requirements < <(collect_spec_ids 'REQ')
  mapfile -t spec_acceptances < <(collect_spec_ids 'ACC')
  mapfile -t spec_verifications < <(collect_spec_ids 'VO')

  for ref in "${requirement_refs[@]}"; do
    contains_exact_line "$ref" "${spec_requirements[@]}" || die "$FOCUS_WI references unknown requirement_ref: ${ref}"
  done

  for ref in "${acceptance_refs[@]}"; do
    contains_exact_line "$ref" "${spec_acceptances[@]}" || die "$FOCUS_WI references unknown acceptance_ref: ${ref}"
  done

  for ref in "${verification_refs[@]}"; do
    contains_exact_line "$ref" "${spec_verifications[@]}" || die "$FOCUS_WI references unknown verification_ref: ${ref}"
  done
}

check_design_work_item_acceptance_alignment() {
  local row wi design_refs work_item_file work_item_refs normalized_design normalized_work_item
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    wi="${row%%:*}"
    design_refs="${row#*:}"
    work_item_file="$PROJECT_ROOT/work-items/$wi.yaml"
    [ -f "$work_item_file" ] || die "design references missing work item: $wi"
    work_item_refs="$(yaml_list "$work_item_file" acceptance_refs | paste -sd ',' -)"
    normalized_design="$(normalize_csv "$design_refs")"
    normalized_work_item="$(normalize_csv "$work_item_refs")"
    [ "$normalized_design" = "$normalized_work_item" ] || die "design/work-item acceptance mismatch for $wi"
  done < <(design_work_item_acceptance_rows)
}

check_appendix_authority() {
  local spec_matches design_matches
  spec_matches="$(formal_id_definition_matches "$PROJECT_ROOT/spec-appendices")"
  design_matches="$(formal_id_definition_matches "$PROJECT_ROOT/design-appendices")"

  if [ -n "$spec_matches" ]; then
    printf '%s\n' "$spec_matches" >&2
    die 'spec appendix defines formal IDs; move REQ/ACC/VO definitions back into spec.md'
  fi

  if [ -n "$design_matches" ]; then
    printf '%s\n' "$design_matches" >&2
    die 'design appendix defines formal IDs; keep formal IDs in spec.md/design.md and only reference them from appendices'
  fi
}

gate_requirement_complete() {
  check_appendix_authority
  grep -q '^## Summary$' "$SPEC_FILE" || die 'spec.md missing Summary section'
  grep -q '^## Inputs$' "$SPEC_FILE" || die 'spec.md missing Inputs section'
  grep -q '^## Scope$' "$SPEC_FILE" || die 'spec.md missing Scope section'
  grep -q '^## Requirements$' "$SPEC_FILE" || die 'spec.md missing Requirements section'
  grep -q '^## Acceptance$' "$SPEC_FILE" || die 'spec.md missing Acceptance section'
  grep -q '^## Verification$' "$SPEC_FILE" || die 'spec.md missing Verification section'

  local input_maturity normalization_note input_owner approval_basis source_ref
  input_maturity="$(input_intake_scalar maturity)"
  normalization_note="$(input_intake_scalar normalization_note)"
  input_owner="$(input_intake_scalar source_owner)"
  approval_basis="$(input_intake_scalar approval_basis)"

  case "$input_maturity" in
    L0|L1|L2|L3) ;;
    *) die "input_maturity must be one of L0/L1/L2/L3 (got: ${input_maturity:-missing})" ;;
  esac

  is_placeholder_token "$input_owner" && die 'input_owner contains placeholder value'
  is_placeholder_token "$approval_basis" && die 'approval_basis contains placeholder value'
  is_placeholder_token "$normalization_note" && die 'normalization_note contains placeholder value'

  local source_refs=()
  mapfile -t source_refs < <(input_intake_refs)
  [ "${#source_refs[@]}" -gt 0 ] || die 'input_refs must contain at least one source reference'

  for source_ref in "${source_refs[@]}"; do
    is_placeholder_token "$source_ref" && die "input_refs contains placeholder value: ${source_ref}"
  done
  validate_input_evidence_refs "${source_refs[@]}"

  local reqs=()
  local accs=()
  local vos=()
  mapfile -t reqs < <(collect_spec_ids 'REQ')
  mapfile -t accs < <(collect_spec_ids 'ACC')
  mapfile -t vos < <(collect_spec_ids 'VO')

  [ "${#reqs[@]}" -gt 0 ] || die 'no REQ-* entries found in spec.md'
  [ "${#accs[@]}" -gt 0 ] || die 'no ACC-* entries found in spec.md'
  [ "${#vos[@]}" -gt 0 ] || die 'no VO-* entries found in spec.md'

  local req acc
  for req in "${reqs[@]}"; do
    grep -q "source_ref:.*${req}" "$SPEC_FILE" || die "requirement ${req} has no acceptance mapping"
  done

  for acc in "${accs[@]}"; do
    grep -q "acceptance_ref: ${acc}" "$SPEC_FILE" || die "acceptance ${acc} has no verification mapping"
    is_placeholder_token "$(acceptance_expected_outcome "$acc")" && die "acceptance ${acc} expected_outcome contains placeholder value"
  done

  local intake_refs=()
  local closure_refs=()
  mapfile -t intake_refs < <(input_intake_refs)
  mapfile -t closure_refs < <(requirements_source_refs)

  for intake_ref in "${intake_refs[@]}"; do
    contains_exact_line "$intake_ref" "${closure_refs[@]}" || \
      die "input_ref is not closed in Requirements source coverage: ${intake_ref}"
  done

  log '✓ requirement-complete gate passed'
}


gate_design_structure_complete() {
  check_appendix_authority
  grep -q '^## Summary$' "$DESIGN_FILE" || die 'design.md missing Summary'
  grep -q '^## Technical Approach$' "$DESIGN_FILE" || die 'design.md missing Technical Approach'
  grep -q '^## Boundaries & Impacted Surfaces$' "$DESIGN_FILE" || die 'design.md missing Boundaries & Impacted Surfaces'
  grep -q '^## Execution Model$' "$DESIGN_FILE" || die 'design.md missing Execution Model'
  grep -q '^## Work Item Mapping$' "$DESIGN_FILE" || die 'design.md missing Work Item Mapping'
  grep -q '^## Work Item Derivation$' "$DESIGN_FILE" || die 'design.md missing Work Item Derivation'
  grep -q '^## Verification Design$' "$DESIGN_FILE" || die 'design.md missing Verification Design'
  grep -q '^## Failure Paths / Reopen Triggers$\|^## Reopen Triggers$' "$DESIGN_FILE" || die 'design.md missing Reopen Triggers'

  local derivation_rows=()
  mapfile -t derivation_rows < <(design_work_item_acceptance_rows)
  [ "${#derivation_rows[@]}" -gt 0 ] || die 'design.md has no concrete WI derivation rows yet'

  check_design_work_item_acceptance_alignment
  log '✓ design-structure-complete gate passed'
}

baseline_section_has_real_content() {
  local heading="$1"
  awk -v heading="$heading" '
    function is_placeholder(line) {
      return (line ~ /^\[[^]]+\]$/)
    }
    BEGIN { in_target = 0; found = 0 }
    $0 == heading {
      in_target = 1
      next
    }
    in_target && /^### / {
      exit
    }
    in_target && /^## / {
      exit
    }
    in_target && /^[[:space:]]*-[[:space:]]+/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      if (line != "" && line != "null" && line != "none" && !is_placeholder(line)) {
        found = 1
        exit
      }
    }
    END { if (found == 1) print "yes" }
  ' "$DESIGN_FILE"
}

gate_implementation_readiness_baseline() {
  grep -q '^## Technical Approach$' "$DESIGN_FILE" || die 'design.md missing Technical Approach'
  grep -q '^## Boundaries & Impacted Surfaces$' "$DESIGN_FILE" || die 'design.md missing Boundaries & Impacted Surfaces'
  grep -q '^## Verification Design$' "$DESIGN_FILE" || die 'design.md missing Verification Design'
  log '✓ implementation-readiness-baseline gate passed'
}


gate_implementation_start() {
  require_focus_wi
  [ "$(yaml_scalar "$WI_FILE" goal)" != 'null' ] || die "$FOCUS_WI missing goal"
  [ "$(yaml_scalar "$WI_FILE" phase_scope)" = 'Implementation' ] || die "$FOCUS_WI phase_scope must be Implementation"
  is_placeholder_token "$(yaml_scalar "$WI_FILE" goal)" && die "$FOCUS_WI goal contains placeholder value"
  is_placeholder_token "$(yaml_scalar "$WI_FILE" derived_from)" && die "$FOCUS_WI derived_from contains placeholder value"

  local input_refs=()
  local requirement_refs=()
  local acceptance_refs=()
  local verification_refs=()
  local allowed_paths=()
  local required_verification=()
  local stop_conditions=()
  local reopen_triggers=()
  local branch_owned_paths=()
  local scope=()
  local out_of_scope=()
  local hard_constraints=()
  mapfile -t input_refs < <(yaml_list "$WI_FILE" input_refs)
  mapfile -t requirement_refs < <(yaml_list "$WI_FILE" requirement_refs)
  mapfile -t acceptance_refs < <(yaml_list "$WI_FILE" acceptance_refs)
  mapfile -t verification_refs < <(yaml_list "$WI_FILE" verification_refs)
  mapfile -t allowed_paths < <(yaml_list "$WI_FILE" allowed_paths)
  mapfile -t required_verification < <(yaml_list "$WI_FILE" required_verification)
  mapfile -t stop_conditions < <(yaml_list "$WI_FILE" stop_conditions)
  mapfile -t reopen_triggers < <(yaml_list "$WI_FILE" reopen_triggers)
  mapfile -t branch_owned_paths < <(yaml_list "$WI_FILE" branch_execution.owned_paths)
  mapfile -t scope < <(yaml_list "$WI_FILE" scope)
  mapfile -t out_of_scope < <(yaml_list "$WI_FILE" out_of_scope)
  mapfile -t hard_constraints < <(yaml_list "$WI_FILE" hard_constraints)

  [ "${#input_refs[@]}" -gt 0 ] || die "$FOCUS_WI missing input_refs"
  [ "${#requirement_refs[@]}" -gt 0 ] || die "$FOCUS_WI missing requirement_refs"
  [ "${#acceptance_refs[@]}" -gt 0 ] || die "$FOCUS_WI missing acceptance_refs"
  [ "${#verification_refs[@]}" -gt 0 ] || die "$FOCUS_WI missing verification_refs"
  [ "${#allowed_paths[@]}" -gt 0 ] || die "$FOCUS_WI missing allowed_paths"
  [ "${#required_verification[@]}" -gt 0 ] || die "$FOCUS_WI missing required_verification"
  [ "${#stop_conditions[@]}" -gt 0 ] || die "$FOCUS_WI missing stop_conditions"
  [ "${#reopen_triggers[@]}" -gt 0 ] || die "$FOCUS_WI missing reopen_triggers"

  # Check scope, out_of_scope, hard_constraints are not placeholder
  for item in "${scope[@]}"; do
    is_placeholder_token "$item" && die "$FOCUS_WI scope contains placeholder value: $item"
  done
  for item in "${out_of_scope[@]}"; do
    is_placeholder_token "$item" && die "$FOCUS_WI out_of_scope contains placeholder value: $item"
  done
  for item in "${hard_constraints[@]}"; do
    is_placeholder_token "$item" && die "$FOCUS_WI hard_constraints contains placeholder value: $item"
  done
  [ "${#allowed_paths[@]}" -gt 0 ] || die "$FOCUS_WI missing allowed_paths"
  [ "${#required_verification[@]}" -gt 0 ] || die "$FOCUS_WI missing required_verification"
  [ "${#stop_conditions[@]}" -gt 0 ] || die "$FOCUS_WI missing stop_conditions"
  [ "${#reopen_triggers[@]}" -gt 0 ] || die "$FOCUS_WI missing reopen_triggers"

  # owned_paths 只在并行模式下强制要求
  local execution_group
  execution_group="$(yaml_scalar "$META_FILE" execution_group)"
  if [ "$execution_group" != 'null' ]; then
    [ "${#branch_owned_paths[@]}" -gt 0 ] || die "$FOCUS_WI: parallel execution requires branch_execution.owned_paths"
  fi

  [ "$(yaml_scalar "$WI_FILE" derived_from)" != 'null' ] || die "$FOCUS_WI missing derived_from"

  check_focus_wi_design_alignment
  check_wi_refs_exist_in_spec

  local closure_refs=()
  local ref

  mapfile -t closure_refs < <(requirements_source_refs)

  for ref in "${input_refs[@]}"; do
    [ -n "$ref" ] || continue
    [ "$ref" != 'null' ] || continue
    [ "$ref" != 'none' ] || continue
    contains_exact_line "$ref" "${closure_refs[@]}" || die "$FOCUS_WI input_ref ${ref} is not represented in spec input intake or design work item derivation"
  done

  # Check contracts before checking dependencies (better error ordering)
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    [ "$ref" != 'null' ] || continue
    [ -f "$PROJECT_ROOT/$ref" ] || die "$FOCUS_WI references missing contract: $ref"
    [ "$(contract_status "$PROJECT_ROOT/$ref")" = 'frozen' ] || die "$FOCUS_WI contract is not frozen: $ref"
  done < <(yaml_list "$WI_FILE" contract_refs)

  [ -f "$TESTING_FILE" ] || die 'missing testing.md'

  # Validate dependency_type
  local dependency_type dependency_refs_count
  dependency_type="$(yaml_scalar "$WI_FILE" dependency_type)"
  mapfile -t dependency_refs < <(yaml_list "$WI_FILE" dependency_refs)
  dependency_refs_count="${#dependency_refs[@]}"

  # Check dependency_type is valid
  case "$dependency_type" in
    strong|weak|none)
      # Valid values
      ;;
    *)
      die "$FOCUS_WI dependency_type must be strong, weak, or none (got: $dependency_type)"
      ;;
  esac

  # Check semantic consistency: empty dependency_refs requires dependency_type = none
  if [ "$dependency_refs_count" -eq 0 ] || [ "${dependency_refs[0]}" = "" ] || [ "${dependency_refs[0]}" = "null" ]; then
    [ "$dependency_type" = 'none' ] || die "$FOCUS_WI has no dependencies but dependency_type is $dependency_type (must be none)"
  else
    [ "$dependency_type" != 'none' ] || die "$FOCUS_WI has dependencies but dependency_type is none (must be strong or weak)"
  fi

  # Check for circular dependencies before checking pass records
  check_circular_dependencies "$FOCUS_WI"

  check_dependency_pass_records

  log '✓ implementation-start gate passed'
}

gate_phase_capability() {
  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"
  if [ "$phase" != 'Requirement' ]; then
    log "✓ phase-capability gate passed (phase ${phase})"
    return
  fi

  local changed=()
  mapfile -t changed < <(git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMRD)
  [ "${#changed[@]}" -gt 0 ] || {
    log '✓ phase-capability gate passed (no staged changes)'
    return
  }

  local file
  for file in "${changed[@]}"; do
    case "$file" in
      src/**|Dockerfile)
        die "phase-capability gate failed: ${phase} forbids implementation artifacts: ${file}"
        ;;
    esac
  done

  log '✓ phase-capability gate passed'
}

gate_scope() {
  local phase mode
  phase="$(yaml_scalar "$META_FILE" phase)"
  if [ "$phase" != 'Implementation' ]; then
    log "✓ scope gate passed (phase ${phase})"
    return
  fi

  mode="${CODESPEC_SCOPE_MODE:-staged}"
  local changed=()
  if [ "$mode" = 'implementation-span' ]; then
    mapfile -t changed < <(collect_implementation_span_files)
  else
    require_focus_wi
    mapfile -t changed < <(collect_staged_files)
  fi
  [ "${#changed[@]}" -gt 0 ] || {
    log '✓ scope gate passed (no staged changes)'
    return
  }

  local allowed=()
  local forbidden=()
  if [ "$mode" = 'implementation-span' ]; then
    local active=() wi wi_file pattern
    mapfile -t active < <(collect_active_work_items)
    [ "${#active[@]}" -gt 0 ] || die 'Implementation scope span requires active_work_items'
    for wi in "${active[@]}"; do
      wi_file="$PROJECT_ROOT/work-items/$wi.yaml"
      [ -f "$wi_file" ] || die "missing work item: $wi_file"
      while IFS= read -r pattern; do
        [ -n "$pattern" ] && [ "$pattern" != 'null' ] || continue
        allowed+=("$pattern")
      done < <(yaml_list "$wi_file" allowed_paths)
      while IFS= read -r pattern; do
        [ -n "$pattern" ] && [ "$pattern" != 'null' ] || continue
        forbidden+=("$pattern")
      done < <(yaml_list "$wi_file" forbidden_paths)
    done
  else
    mapfile -t allowed < <(yaml_list "$WI_FILE" allowed_paths)
    mapfile -t forbidden < <(yaml_list "$WI_FILE" forbidden_paths)
  fi

  if [ "${#forbidden[@]}" -eq 0 ]; then
    if [ "$mode" = 'implementation-span' ]; then
      die 'active work items have empty forbidden_paths (must specify at least one pattern)'
    fi
    die "$FOCUS_WI has empty forbidden_paths (must specify at least one pattern)"
  fi

  local file pattern ok
  for file in "${changed[@]}"; do
    for pattern in "${forbidden[@]}"; do
      if match_path "$file" "$pattern"; then
        if [ "$mode" = 'implementation-span' ]; then
          die "implementation span file $file is forbidden by active work items"
        fi
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
      if [ "$ok" -ne 1 ]; then
        if [ "$mode" = 'implementation-span' ]; then
          die "implementation span file $file is outside allowed_paths of active work items"
        fi
        die "staged file $file is outside allowed_paths of $FOCUS_WI"
      fi
    fi
  done

  log '✓ scope gate passed'
}

contract_scalar_current() {
  local file="$1"
  local key="$2"
  awk -F': ' -v key="$key" '$1 == key { print $2; exit }' "$file"
}

contract_scalar_from_revision() {
  local revision="$1"
  local file="$2"
  local key="$3"
  git -C "$PROJECT_ROOT" show "${revision}:${file}" 2>/dev/null | awk -F': ' -v key="$key" '$1 == key { print $2; exit }'
}

validate_frozen_contract_file() {
  local file="$1"
  local contract_id freeze_review_ref frozen_at review_file
  contract_id="$(contract_scalar_current "$PROJECT_ROOT/$file" contract_id)"
  freeze_review_ref="$(contract_scalar_current "$PROJECT_ROOT/$file" freeze_review_ref)"
  frozen_at="$(contract_scalar_current "$PROJECT_ROOT/$file" frozen_at)"

  [ -n "$frozen_at" ] && [ "$frozen_at" != 'null' ] || die "frozen contract $file must have frozen_at timestamp"
  [[ "$frozen_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "frozen contract $file frozen_at must be YYYY-MM-DD format (got: $frozen_at)"

  [ -n "$freeze_review_ref" ] && [ "$freeze_review_ref" != 'null' ] || die "frozen contract $file requires explicit review (missing freeze_review_ref)"
  review_file="$PROJECT_ROOT/$freeze_review_ref"
  [ -f "$review_file" ] || die "frozen contract $file requires explicit review artifact: $freeze_review_ref"
  [ "$(yaml_scalar "$review_file" contract_ref)" = "$contract_id" ] || die "freeze review $freeze_review_ref does not reference contract_id $contract_id"
  [ "$(yaml_scalar "$review_file" action)" = 'freeze' ] || die "freeze review $freeze_review_ref must have action=freeze"
  [ "$(yaml_scalar "$review_file" verdict)" = 'approved' ] || die "freeze review $freeze_review_ref must be approved"
  [ "$(yaml_scalar "$review_file" reviewed_by)" != 'null' ] || die "freeze review $freeze_review_ref missing reviewed_by"
  [ "$(yaml_scalar "$review_file" reviewed_at)" != 'null' ] || die "freeze review $freeze_review_ref missing reviewed_at"
}

gate_contract_boundary() {
  local mode
  mode="${CODESPEC_CONTRACT_BOUNDARY_MODE:-staged}"

  # Check focus_work_item contract_refs (Implementation phase)
  if [ -f "$META_FILE" ] && [ "$(yaml_scalar "$META_FILE" focus_work_item)" != 'null' ]; then
    require_focus_wi
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      [ "$ref" != 'null' ] || continue
      [ -f "$PROJECT_ROOT/$ref" ] || die "$FOCUS_WI references missing contract: $ref"
    done < <(yaml_list "$WI_FILE" contract_refs)
  fi

  # Check active_work_items contract_refs (Testing/Deployment phase)
  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"
  if [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
    local active_wis=()
    mapfile -t active_wis < <(yaml_list "$META_FILE" active_work_items)
    for wi_id in "${active_wis[@]}"; do
      [ -n "$wi_id" ] || continue
      [ "$wi_id" != 'null' ] || continue
      local wi_file="$PROJECT_ROOT/work-items/${wi_id}.yaml"
      [ -f "$wi_file" ] || die "active work item $wi_id file not found"
      while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        [ "$ref" != 'null' ] || continue
        [ -f "$PROJECT_ROOT/$ref" ] || die "$wi_id references missing contract: $ref"
      done < <(yaml_list "$wi_file" contract_refs)
    done
  fi

  local rel_contract_root="contracts/"
  local file head_status current_status base_status implementation_base_revision
  if [ "$mode" = 'implementation-span' ]; then
    implementation_base_revision="$(yaml_scalar "$META_FILE" implementation_base_revision)"
    validate_git_revision "$implementation_base_revision" || die "implementation_base_revision is missing or invalid: ${implementation_base_revision:-null}"
  fi

  while IFS= read -r file; do
    [[ "$file" == ${rel_contract_root}* ]] || continue

    [ -f "$PROJECT_ROOT/$file" ] || continue

    if [ "$mode" = 'implementation-span' ]; then
      head_status="$(contract_scalar_from_revision "$implementation_base_revision" "$file" status || true)"
      current_status="$(contract_scalar_current "$PROJECT_ROOT/$file" status)"
      base_status="$head_status"
    else
      head_status="$(git -C "$PROJECT_ROOT" show "HEAD:$file" 2>/dev/null | grep '^status:' | awk '{print $2}' || true)"
      current_status="$(git -C "$PROJECT_ROOT" show ":$file" 2>/dev/null | grep '^status:' | awk '{print $2}' || true)"
      base_status="$head_status"
    fi

    if [ "$base_status" = 'frozen' ]; then
      die "frozen contract cannot be modified: $file"
    fi

    if [ "$current_status" = 'frozen' ]; then
      validate_frozen_contract_file "$file"
      if [ "$mode" = 'staged' ] && ! git -C "$PROJECT_ROOT" cat-file -e "HEAD:$file" 2>/dev/null; then
        die "new frozen contract requires explicit review flow: $file"
      fi
    fi
  done < <(
    if [ "$mode" = 'implementation-span' ]; then
      collect_implementation_span_files
    else
      collect_staged_files
    fi
  )

  # Check contract consumers consistency with work-item contract_refs
  local contract_file contract_id consumers wi_file wi_id contract_refs
  while IFS= read -r contract_file; do
    [ -f "$PROJECT_ROOT/$contract_file" ] || continue
    contract_id="$(yaml_scalar "$PROJECT_ROOT/$contract_file" contract_id)"
    [ -n "$contract_id" ] && [ "$contract_id" != 'null' ] || continue

    # Collect consumers from contract
    local contract_consumers=()
    mapfile -t contract_consumers < <(yaml_list "$PROJECT_ROOT/$contract_file" consumers)

    # Verify each consumer actually references this contract
    for wi_id in "${contract_consumers[@]}"; do
      [ -n "$wi_id" ] && [ "$wi_id" != 'null' ] || continue
      wi_file="$PROJECT_ROOT/work-items/${wi_id}.yaml"
      [ -f "$wi_file" ] || die "contract $contract_file lists consumer $wi_id but work-item file not found"

      local found=0
      while IFS= read -r ref; do
        [ -n "$ref" ] && [ "$ref" != 'null' ] || continue
        if [ "$ref" = "$contract_file" ]; then
          found=1
          break
        fi
      done < <(yaml_list "$wi_file" contract_refs)

      [ "$found" -eq 1 ] || die "contract $contract_file lists $wi_id as consumer but $wi_id does not reference it in contract_refs"
    done
  done < <(find "$PROJECT_ROOT/contracts" -name '*.md' 2>/dev/null || true)

  # Verify work-items that reference contracts are listed as consumers
  while IFS= read -r wi_file; do
    [ -f "$wi_file" ] || continue
    wi_id="$(basename "$wi_file" .yaml)"

    while IFS= read -r ref; do
      [ -n "$ref" ] && [ "$ref" != 'null' ] || continue
      [ -f "$PROJECT_ROOT/$ref" ] || continue

      local found=0
      while IFS= read -r consumer; do
        [ -n "$consumer" ] && [ "$consumer" != 'null' ] || continue
        if [ "$consumer" = "$wi_id" ]; then
          found=1
          break
        fi
      done < <(yaml_list "$PROJECT_ROOT/$ref" consumers)

      [ "$found" -eq 1 ] || die "work-item $wi_id references contract $ref but is not listed in contract consumers"
    done < <(yaml_list "$wi_file" contract_refs)
  done < <(find "$PROJECT_ROOT/work-items" -name '*.yaml' 2>/dev/null || true)

  log '✓ contract-boundary gate passed'
}

gate_trace_consistency() {
  check_appendix_authority
  check_design_work_item_acceptance_alignment
  local reqs=()
  local accs=()
  local vos=()
  local wi_reqs=()
  local wis=()
  local wi_vos=()
  local intake_refs=()
  local closure_refs=()
  local testing_accs=()
  mapfile -t reqs < <(collect_spec_ids 'REQ')
  mapfile -t accs < <(collect_spec_ids 'ACC')
  mapfile -t vos < <(collect_spec_ids 'VO')
  mapfile -t wi_reqs < <(work_item_refs_requirements)
  mapfile -t wis < <(work_item_refs_acceptance)
  mapfile -t wi_vos < <(work_item_refs_verification)
  mapfile -t intake_refs < <(input_intake_refs)
  mapfile -t closure_refs < <(requirements_source_refs)
  mapfile -t testing_accs < <(testing_target_acceptance_ids)

  local req
  for req in "${reqs[@]}"; do
    grep -q "source_ref: ${req}" "$SPEC_FILE" || die "trace gap: ${req} has no ACC"
  done

  local acc
  for acc in "${accs[@]}"; do
    grep -q "acceptance_ref: ${acc}" "$SPEC_FILE" || die "trace gap: ${acc} has no VO"
  done

  local vo
  for vo in "${vos[@]}"; do
    grep -q "vo_id: ${vo}" "$SPEC_FILE" || die "trace gap: missing VO definition ${vo}"
  done

  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"
  if [ "$phase" = 'Design' ] || [ "$phase" = 'Implementation' ] || [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
    for req in "${reqs[@]}"; do
      contains_exact_line "$req" "${wi_reqs[@]}" || die "trace gap: ${req} is not referenced by any work item requirement_refs"
    done

    for acc in "${accs[@]}"; do
      contains_exact_line "$acc" "${wis[@]}" || die "trace gap: ${acc} is not referenced by any work item acceptance_refs"
    done

    for vo in "${vos[@]}"; do
      contains_exact_line "$vo" "${wi_vos[@]}" || die "trace gap: ${vo} is not referenced by any work item verification_refs"
    done
  fi

  local ref
  for ref in "${intake_refs[@]}"; do
    contains_exact_line "$ref" "${closure_refs[@]}" || die "trace gap: input_ref ${ref} is not represented in requirements closure"
  done

  if [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
    [ -f "$TESTING_FILE" ] || die 'testing.md is required in Testing/Deployment phase'
    for acc in "${testing_accs[@]}"; do
      grep -q -E "acceptance_ref: ${acc}$" "$TESTING_FILE" || die "trace gap: ${acc} has no testing record"
    done
  fi

  log '✓ trace-consistency gate passed'
}

gate_testing_coverage() {
  # NOTE: This gate checks testing record quality (test_scope, verification_type, etc.).
  # It is called by gate_verification() in Testing/Deployment phases.
  # In contrast, gate_trace_consistency() only checks that testing records exist,
  # without validating test_scope or other quality attributes.
  # This separation allows trace-consistency to verify traceability independently
  # of testing quality requirements.
  [ -f "$TESTING_FILE" ] || die 'missing testing.md'
  local accs=()
  mapfile -t accs < <(testing_target_acceptance_ids)
  [ "${#accs[@]}" -gt 0 ] || die 'no ACC-* entries found in spec.md'

  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"

  local acc priority verification_type artifact_ref residual_risk reopen_required test_type test_scope
  for acc in "${accs[@]}"; do
    grep -q -E "acceptance_ref: ${acc}$" "$TESTING_FILE" || die "testing.md missing record for ${acc}"

    # In Testing/Deployment phase, require at least one full-integration pass record
    if [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
      has_full_integration_pass "$acc" || die "testing.md does not have a full-integration pass record for ${acc}"

      # Extract fields from full-integration pass record
      artifact_ref="$(testing_record_scalar_from_scope "$acc" artifact_ref full-integration)"
      residual_risk="$(testing_record_scalar_from_scope "$acc" residual_risk full-integration)"
      reopen_required="$(testing_record_scalar_from_scope "$acc" reopen_required full-integration)"
      verification_type="$(testing_record_scalar_from_scope "$acc" verification_type full-integration)"
      test_type="$(testing_record_scalar_from_scope "$acc" test_type full-integration)"
      test_scope="$(testing_record_scalar_from_scope "$acc" test_scope full-integration)"
    else
      has_testing_record "$acc" || die "testing.md does not have a passing record for ${acc}"
      # In other phases, extract from any pass record (first match)
      artifact_ref="$(testing_record_scalar "$acc" artifact_ref)"
      residual_risk="$(testing_record_scalar "$acc" residual_risk)"
      reopen_required="$(testing_record_scalar "$acc" reopen_required)"
      verification_type="$(testing_record_scalar "$acc" verification_type)"
      test_type="$(testing_record_scalar "$acc" test_type)"
      test_scope="$(testing_record_scalar "$acc" test_scope)"
    fi

    [ -n "$artifact_ref" ] || die "testing.md artifact_ref is missing for ${acc}"
    is_placeholder_token "$artifact_ref" && die "testing.md artifact_ref contains placeholder value for ${acc}"

    [ -n "$test_type" ] || die "testing.md test_type is missing for ${acc}"
    is_placeholder_token "$test_type" && die "testing.md test_type contains placeholder value for ${acc}"

    [ -n "$test_scope" ] || die "testing.md test_scope is missing for ${acc}"
    is_placeholder_token "$test_scope" && die "testing.md test_scope contains placeholder value for ${acc}"

    [ -n "$residual_risk" ] || die "testing.md residual_risk is missing for ${acc}"
    if [ "$(printf '%s' "$residual_risk" | tr '[:upper:]' '[:lower:]')" != 'none' ]; then
      is_placeholder_token "$residual_risk" && die "testing.md residual_risk contains placeholder value for ${acc}"
    fi

    # Check residual_risk=high is not allowed
    if [ "$(printf '%s' "$residual_risk" | tr '[:upper:]' '[:lower:]')" = 'high' ]; then
      die "testing.md residual_risk=high is not allowed for ${acc} (must be resolved before deployment)"
    fi

    [ -n "$reopen_required" ] || die "testing.md reopen_required is missing for ${acc}"
    case "$(printf '%s' "$reopen_required" | tr '[:upper:]' '[:lower:]')" in
      true|false) ;;
      *) die "testing.md reopen_required must be true or false for ${acc}" ;;
    esac
    [ "$(printf '%s' "$reopen_required" | tr '[:upper:]' '[:lower:]')" = 'false' ] || die "testing.md reopen_required must be false before phase transition for ${acc}"

    priority="$(spec_acceptance_priority "$acc")"
    case "$priority" in
      P0)
        [ "$verification_type" = 'automated' ] || die "P0 acceptance ${acc} must use automated verification"
        ;;
      P1|P2)
        case "$verification_type" in
          automated|manual|equivalent) ;;
          *) die "${priority} acceptance ${acc} must use automated/manual/equivalent verification" ;;
        esac
        ;;
    esac
  done

  log '✓ testing-coverage gate passed'
}

gate_verification() {
  gate_metadata_consistency
  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"

  if [ "$phase" = 'Requirement' ] || [ "$phase" = 'Design' ]; then
    log "✓ verification gate passed (phase ${phase})"
    return
  fi

  [ -f "$TESTING_FILE" ] || die 'missing testing.md'

  if [ "$phase" = 'Implementation' ]; then
    local active=() wi wi_file acc priority verification_type
    mapfile -t active < <(collect_active_work_items)
    [ "${#active[@]}" -gt 0 ] || die 'Implementation verification requires active_work_items'

    for wi in "${active[@]}"; do
      wi_file="$PROJECT_ROOT/work-items/$wi.yaml"
      [ -f "$wi_file" ] || die "missing work item: $wi_file"

      check_dependency_pass_records "$wi_file"

      while IFS= read -r acc; do
        [ -n "$acc" ] || continue
        grep -q -E "acceptance_ref: ${acc}$" "$TESTING_FILE" || die "current work item acceptance ${acc} has no testing record"
        has_testing_record "$acc" || die "current work item acceptance ${acc} has no pass record"

        # Check P0 verification_type requirement in Implementation phase
        priority="$(spec_acceptance_priority "$acc")"
        verification_type="$(testing_record_scalar "$acc" verification_type)"
        if [ "$priority" = 'P0' ]; then
          [ "$verification_type" = 'automated' ] || die "P0 acceptance ${acc} must use automated verification (got: ${verification_type})"
        fi
      done < <(work_item_approved_acceptance_refs "$wi_file")
    done
  fi

  if [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
    gate_testing_coverage
  fi

  log '✓ verification gate passed'
}

gate_deployment_readiness() {
  local deployment_file="$PROJECT_ROOT/deployment.md"
  local phase enforce_materialized
  phase="$(yaml_scalar "$META_FILE" phase)"
  enforce_materialized="${CODESPEC_REQUIRE_DEPLOYMENT_FILE:-0}"
  if [ ! -f "$deployment_file" ]; then
    if [ "$enforce_materialized" = '1' ] || [ "$phase" = 'Deployment' ] || [ "$(yaml_scalar "$META_FILE" status)" = 'completed' ]; then
      die 'missing deployment.md'
    fi
    log '✓ deployment-readiness gate passed (deployment.md not materialized)'
    return
  fi

  grep -q '^## Deployment Plan$' "$deployment_file" || die 'deployment.md missing Deployment Plan section'
  grep -q '^## Pre-deployment Checklist$' "$deployment_file" || die 'deployment.md missing Pre-deployment Checklist section'
  grep -q '^## Deployment Steps$' "$deployment_file" || die 'deployment.md missing Deployment Steps section'
  grep -q '^## Execution Evidence$' "$deployment_file" || die 'deployment.md missing Execution Evidence section'
  grep -q '^## Verification Results$' "$deployment_file" || die 'deployment.md missing Verification Results section'
  grep -q '^## Acceptance Conclusion$' "$deployment_file" || die 'deployment.md missing Acceptance Conclusion section'
  grep -q '^## Rollback Plan$' "$deployment_file" || die 'deployment.md missing Rollback Plan section'
  grep -q '^## Monitoring$' "$deployment_file" || die 'deployment.md missing Monitoring section'
  grep -q '^## Post-deployment Actions$' "$deployment_file" || die 'deployment.md missing Post-deployment Actions section'

  local target_env deployment_date execution_status execution_ref deployment_method deployed_at deployed_revision restart_required restart_reason runtime_observed_revision runtime_ready_evidence smoke_test runtime_ready manual_verification_ready
  target_env="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'target_env')"
  deployment_date="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'deployment_date')"
  execution_status="$(markdown_section_scalar "$deployment_file" '## Execution Evidence' 'status')"
  execution_ref="$(markdown_section_scalar "$deployment_file" '## Execution Evidence' 'execution_ref')"
  deployment_method="$(markdown_section_scalar "$deployment_file" '## Execution Evidence' 'deployment_method')"
  deployed_at="$(markdown_section_scalar "$deployment_file" '## Execution Evidence' 'deployed_at')"
  deployed_revision="$(markdown_section_scalar "$deployment_file" '## Execution Evidence' 'deployed_revision')"
  restart_required="$(markdown_section_scalar "$deployment_file" '## Execution Evidence' 'restart_required')"
  restart_reason="$(markdown_section_scalar "$deployment_file" '## Execution Evidence' 'restart_reason')"
  runtime_observed_revision="$(markdown_section_scalar "$deployment_file" '## Execution Evidence' 'runtime_observed_revision')"
  runtime_ready_evidence="$(markdown_section_scalar "$deployment_file" '## Execution Evidence' 'runtime_ready_evidence')"
  smoke_test="$(markdown_section_scalar "$deployment_file" '## Verification Results' 'smoke_test')"
  runtime_ready="$(markdown_section_scalar "$deployment_file" '## Verification Results' 'runtime_ready')"
  manual_verification_ready="$(markdown_section_scalar "$deployment_file" '## Verification Results' 'manual_verification_ready')"

  is_placeholder_token "$target_env" && die 'deployment.md target_env is missing'
  printf '%s\n' "$deployment_date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || die 'deployment.md deployment_date must be YYYY-MM-DD'
  [ "$execution_status" = 'pass' ] || die 'deployment.md execution evidence status must be pass'
  is_placeholder_token "$execution_ref" && die 'deployment.md execution_ref is missing'
  is_placeholder_token "$deployment_method" && die 'deployment.md deployment_method is missing'
  printf '%s\n' "$deployed_at" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' || die 'deployment.md deployed_at must be an RFC3339 timestamp'
  is_placeholder_token "$deployed_revision" && die 'deployment.md deployed_revision is missing'
  case "$restart_required" in
    yes|no) ;;
    *) die 'deployment.md restart_required must be yes or no in Execution Evidence section' ;;
  esac
  is_placeholder_token "$restart_reason" && die 'deployment.md restart_reason is missing'
  [ "$smoke_test" = 'pass' ] || die 'deployment.md smoke_test: pass must be in Verification Results section'
  [ "$runtime_ready" = 'pass' ] || die 'deployment.md runtime_ready: pass must be in Verification Results section'
  [ "$manual_verification_ready" = 'pass' ] || die 'deployment.md manual_verification_ready: pass must be in Verification Results section'
  is_placeholder_token "$runtime_observed_revision" && die 'deployment.md runtime_observed_revision is missing'
  is_placeholder_token "$runtime_ready_evidence" && die 'deployment.md runtime_ready_evidence is required in Execution Evidence section'
  [ "$deployed_revision" = "$runtime_observed_revision" ] || die 'deployment.md runtime_observed_revision must match deployed_revision'

  if [ "$restart_required" = 'yes' ]; then
    printf '%s\n' "$runtime_ready_evidence" | grep -Eqi 'restart|restarted|rolled|reloaded|recreated' || die 'deployment.md runtime_ready_evidence must include restart evidence for restart-required deployment'
  else
    printf '%s\n' "$runtime_ready_evidence" | grep -Eqi 'not needed|hot reload|hot-reload|rolling update|rollout|replaced in place|no restart' || die 'deployment.md runtime_ready_evidence must explain why restart was not needed when restart_required: no'
  fi

  # Check for remaining placeholders
  local placeholders
  placeholders="$(grep -nE 'YYYY-MM-DD|\[name\]|\[step\]|\[condition\]|\[metric\]|\[alert\]|\[deployment conclusion\]|\[yes/no\]|\[replace with[^]]*\]|\[STAGING/PRODUCTION\]|\[STAGING\]|\[PRODUCTION\]' "$deployment_file" || true)"
  [ -z "$placeholders" ] || die 'deployment.md contains placeholder value'

  log '✓ deployment-readiness gate passed'
}

gate_promotion_criteria() {
  gate_metadata_consistency
  local workspace_root
  workspace_root="$(find_workspace_root)" || die 'could not locate workspace root'
  [ -d "$workspace_root/versions" ] || die 'versions directory is missing in workspace root'
  local phase status
  phase="$(yaml_scalar "$META_FILE" phase)"
  status="$(yaml_scalar "$META_FILE" status)"
  [ "$phase" = 'Deployment' ] || [ "$status" = 'completed' ] || die 'promotion requires Deployment phase or completed status'
  gate_trace_consistency
  gate_testing_coverage
  gate_deployment_readiness
  local deployment_file="$PROJECT_ROOT/deployment.md"
  local acceptance_status acceptance_notes approved_by approved_at
  acceptance_status="$(markdown_section_scalar "$deployment_file" '## Acceptance Conclusion' 'status')"
  acceptance_notes="$(markdown_section_scalar "$deployment_file" '## Acceptance Conclusion' 'notes')"
  approved_by="$(markdown_section_scalar "$deployment_file" '## Acceptance Conclusion' 'approved_by')"
  approved_at="$(markdown_section_scalar "$deployment_file" '## Acceptance Conclusion' 'approved_at')"
  [ "$acceptance_status" = 'pass' ] || die 'deployment.md acceptance conclusion status must be pass'
  is_placeholder_token "$acceptance_notes" && die 'deployment.md acceptance conclusion notes is missing'
  is_placeholder_token "$approved_by" && die 'deployment.md approved_by is missing'
  printf '%s\n' "$approved_at" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || die 'deployment.md approved_at must be YYYY-MM-DD'
  log '✓ promotion-criteria gate passed'
}

main() {
  [ -n "$GATE" ] || die 'usage: check-gate.sh <name>'
  require_context

  case "$GATE" in
    requirement-complete)
      gate_requirement_complete
      ;;
    review-verdict-present)
      gate_review_verdict_present
      ;;
    design-structure-complete)
      gate_design_structure_complete
      ;;
    design-readiness)
      gate_design_structure_complete
      ;;
    implementation-ready)
      gate_design_structure_complete
      gate_implementation_start
      gate_implementation_readiness_baseline
      ;;
    implementation-start)
      gate_implementation_start
      ;;
    metadata-consistency)
      gate_metadata_consistency
      ;;
    phase-capability)
      gate_phase_capability
      ;;
    scope)
      gate_scope
      ;;
    contract-boundary|boundary)
      gate_contract_boundary
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
      gate_metadata_consistency
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
