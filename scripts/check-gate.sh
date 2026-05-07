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
    (cd "$CODESPEC_PROJECT_ROOT" && pwd)
    return
  fi

  local dir
  dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/meta.yaml" ]; then
      printf '%s\n' "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done

  local git_root metas meta_dir
  if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    if [ -f "$git_root/meta.yaml" ]; then
      printf '%s\n' "$git_root"
      return
    fi

    mapfile -t metas < <(
      git -C "$git_root" ls-files -co --exclude-standard -- 'meta.yaml' '*/meta.yaml' 2>/dev/null |
        grep -vE '(^|/)(\.codespec|versions|project-docs)/' |
        sort -u
    )
    if [ "${#metas[@]}" -eq 1 ]; then
      meta_dir="$(dirname "${metas[0]}")"
      if [ "$meta_dir" = "." ]; then
        printf '%s\n' "$git_root"
      else
        (cd "$git_root/$meta_dir" && pwd)
      fi
      return
    fi

    printf '%s\n' "$git_root"
    return
  fi

  printf '%s\n' "$PWD"
}

git_path_to_project_path() {
  local file prefix
  file="${1#./}"
  prefix="${PROJECT_GIT_PREFIX:-}"
  prefix="${prefix%/}"

  if [ -z "$prefix" ]; then
    printf '%s\n' "$file"
    return 0
  fi

  case "$file" in
    "$prefix"/*)
      printf '%s\n' "${file#"$prefix"/}"
      return 0
      ;;
  esac

  return 1
}

project_path_to_git_path() {
  local file prefix
  file="${1#./}"
  prefix="${PROJECT_GIT_PREFIX:-}"
  prefix="${prefix%/}"

  if [ -z "$prefix" ]; then
    printf '%s\n' "$file"
  else
    printf '%s/%s\n' "$prefix" "$file"
  fi
}

filter_project_paths() {
  local file
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    git_path_to_project_path "$file" || true
  done | grep -v '^$' | sort -u
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

match_any_path() {
  local file="$1"
  shift || true
  local pattern
  for pattern in "$@"; do
    if match_path "$file" "$pattern"; then
      return 0
    fi
  done
  return 1
}

active_authority_repair_id() {
  yq eval '.active_authority_repair // "null"' "$META_FILE"
}

authority_repair_file_for_id() {
  local repair_id="$1"
  printf '%s/authority-repairs/%s.yaml\n' "$PROJECT_ROOT" "$repair_id"
}

authority_repair_path_is_valid() {
  local path="$1"
  [ -n "$path" ] || return 1
  [ "$path" != 'null' ] || return 1
  [[ "$path" != /* ]] || return 1
  [[ "$path" != *..* ]] || return 1
  case "$path" in
    meta.yaml|spec.md|src/**|src/*|Dockerfile|versions/**|versions/*|authority-repairs/**|authority-repairs/*)
      return 1
      ;;
    design.md|testing.md|deployment.md|contracts/*.md)
      return 0
      ;;
    work-items/WI-[0-9][0-9][0-9].yaml)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_authority_repair_record() {
  local repair_file="$1"
  [ -f "$repair_file" ] || die "missing authority repair record: ${repair_file#$PROJECT_ROOT/}"

  local repair_id expected_id status phase gate reason allowed=() path gate_result smoke_result
  repair_id="$(yaml_scalar "$repair_file" repair_id)"
  expected_id="$(basename "$repair_file" .yaml)"
  [ "$repair_id" = "$expected_id" ] || die "authority repair record id mismatch: ${repair_file#$PROJECT_ROOT/}"

  status="$(yaml_scalar "$repair_file" status)"
  case "$status" in
    open|closed) ;;
    *) die "authority repair $repair_id status must be open or closed" ;;
  esac

  phase="$(yaml_scalar "$repair_file" phase)"
  case "$phase" in
    Implementation|Testing|Deployment) ;;
    *) die "authority repair $repair_id phase must be Implementation, Testing, or Deployment" ;;
  esac

  gate="$(yaml_scalar "$repair_file" gate)"
  case "$gate" in
    design-quality|design-readiness|implementation-ready|implementation-start|active-work-items-complete|scope|contract-boundary|trace-consistency|verification|testing-coverage|deployment-plan-ready|deployment-readiness|promotion-criteria) ;;
    *) die "authority repair $repair_id has unsupported gate: $gate" ;;
  esac

  reason="$(yaml_scalar "$repair_file" reason)"
  is_placeholder_token "$reason" && die "authority repair $repair_id requires reason"

  mapfile -t allowed < <(yaml_list "$repair_file" allowed_paths)
  [ "${#allowed[@]}" -gt 0 ] || die "authority repair $repair_id requires allowed_paths"
  for path in "${allowed[@]}"; do
    authority_repair_path_is_valid "$path" || die "authority repair $repair_id has invalid allowed_path: $path"
  done

  if [ "$status" = 'closed' ]; then
    gate_result="$(yaml_scalar "$repair_file" gate_result)"
    smoke_result="$(yaml_scalar "$repair_file" smoke_result)"
    [ "$gate_result" = 'pass' ] || die "closed authority repair $repair_id requires gate_result: pass"
    [ "$smoke_result" = 'pass' ] || die "closed authority repair $repair_id requires smoke_result: pass"
  fi
}

active_authority_repair_allows_path() {
  local file="$1"
  local repair_id repair_file allowed=() pattern
  repair_id="$(active_authority_repair_id)"
  [ "$repair_id" != 'null' ] || return 1
  repair_file="$(authority_repair_file_for_id "$repair_id")"
  [ -f "$repair_file" ] || return 1

  case "$file" in
    meta.yaml|authority-repairs/"$repair_id".yaml)
      return 0
      ;;
  esac

  mapfile -t allowed < <(yaml_list "$repair_file" allowed_paths)
  for pattern in "${allowed[@]}"; do
    if match_path "$file" "$pattern"; then
      return 0
    fi
  done
  return 1
}

staged_file_changed() {
  local file="$1"
  local git_file
  git_file="$(project_path_to_git_path "$file")"
  git -C "$GIT_ROOT" diff --cached --name-only --diff-filter=ACMRD -- "$git_file" | grep -Fxq "$git_file"
}

authority_repair_record_change_is_allowed() {
  local file="$1"
  local repair_file="$PROJECT_ROOT/$file"
  local status repair_id head_status head_repair_id git_file

  case "$file" in
    authority-repairs/*.yaml) ;;
    *) return 1 ;;
  esac

  [ -f "$repair_file" ] || return 1
  validate_authority_repair_record "$repair_file"

  status="$(yaml_scalar "$repair_file" status)"
  repair_id="$(yaml_scalar "$repair_file" repair_id)"
  git_file="$(project_path_to_git_path "$file")"

  if ! git -C "$GIT_ROOT" cat-file -e "HEAD:$git_file" 2>/dev/null; then
    [ "$status" = 'closed' ]
    return
  fi

  head_status="$(git -C "$GIT_ROOT" show "HEAD:$git_file" | yq eval '.status // "null"' - 2>/dev/null || printf 'null')"
  head_repair_id="$(git -C "$GIT_ROOT" show "HEAD:$git_file" | yq eval '.repair_id // "null"' - 2>/dev/null || printf 'null')"
  [ "$head_repair_id" = "$repair_id" ] || return 1
  [ "$head_status" = 'open' ] && [ "$status" = 'closed' ]
}

validate_staged_authority_repair_records() {
  local active_repair staged
  active_repair="$(active_authority_repair_id)"

  while IFS= read -r staged; do
    case "$staged" in
      authority-repairs/*.yaml) ;;
      *) continue ;;
    esac

    if [ "$active_repair" != 'null' ]; then
      [ "$staged" = "authority-repairs/$active_repair.yaml" ] || die "active authority repair may only change its own record: $staged"
      validate_authority_repair_record "$PROJECT_ROOT/$staged"
      continue
    fi

    authority_repair_record_change_is_allowed "$staged" || die "authority repair record $staged can only be created closed or close a previously open repair"
  done < <(collect_staged_files)
}

staged_closed_authority_repair_allows_path() {
  local file="$1"
  local staged repair_file status pattern allowed=()
  while IFS= read -r staged; do
    case "$staged" in
      authority-repairs/*.yaml) ;;
      *) continue ;;
    esac
    repair_file="$PROJECT_ROOT/$staged"
    [ -f "$repair_file" ] || continue
    status="$(yaml_scalar "$repair_file" status)"
    [ "$status" = 'closed' ] || continue
    validate_authority_repair_record "$repair_file"
    mapfile -t allowed < <(yaml_list "$repair_file" allowed_paths)
    for pattern in "${allowed[@]}"; do
      if match_path "$file" "$pattern"; then
        return 0
      fi
    done
  done < <(collect_staged_files)
  return 1
}

closed_authority_repair_allows_path() {
  local file="$1"
  local repair_file status pattern allowed=() git_file
  git_file="$(project_path_to_git_path "$file")"

  case "$file" in
    authority-repairs/*.yaml)
      [ -f "$PROJECT_ROOT/$file" ] || return 1
      if staged_file_changed "$file" || ! git -C "$GIT_ROOT" diff --quiet -- "$git_file"; then
        authority_repair_record_change_is_allowed "$file"
        return
      fi
      git -C "$GIT_ROOT" cat-file -e "HEAD:$git_file" 2>/dev/null || return 1
      validate_authority_repair_record "$PROJECT_ROOT/$file"
      [ "$(yaml_scalar "$PROJECT_ROOT/$file" status)" = 'closed' ]
      return
      ;;
  esac

  if staged_file_changed "$file"; then
    staged_closed_authority_repair_allows_path "$file"
    return
  fi

  [ -d "$PROJECT_ROOT/authority-repairs" ] || return 1
  for repair_file in "$PROJECT_ROOT"/authority-repairs/*.yaml; do
    [ -e "$repair_file" ] || continue
    status="$(yaml_scalar "$repair_file" status)"
    [ "$status" = 'closed' ] || continue
    validate_authority_repair_record "$repair_file"
    mapfile -t allowed < <(yaml_list "$repair_file" allowed_paths)
    for pattern in "${allowed[@]}"; do
      if match_path "$file" "$pattern"; then
        return 0
      fi
    done
  done
  return 1
}

normalize_csv() {
  printf '%s' "$1" | tr ',' '\n' | grep -v '^$' | sort | paste -sd ',' -
}

require_context() {
  require_yq
  PROJECT_ROOT="$(find_project_root)"
  if [ -n "${CODESPEC_GIT_ROOT:-}" ]; then
    GIT_ROOT="$CODESPEC_GIT_ROOT"
  elif git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_ROOT="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel)"
  else
    GIT_ROOT="$PROJECT_ROOT"
  fi
  PROJECT_GIT_PREFIX="${CODESPEC_PROJECT_PREFIX:-}"
  if [ -z "$PROJECT_GIT_PREFIX" ] && git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    PROJECT_GIT_PREFIX="$(git -C "$PROJECT_ROOT" rev-parse --show-prefix)"
  fi
  PROJECT_GIT_PREFIX="${PROJECT_GIT_PREFIX%/}"
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
  if git -C "$GIT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$GIT_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'detached'
    return
  fi
  printf 'none'
}

validate_git_revision() {
  local revision="$1"
  [ -n "$revision" ] || return 1
  [ "$revision" != 'null' ] || return 1
  git -C "$GIT_ROOT" rev-parse --verify "${revision}^{commit}" >/dev/null 2>&1
}

collect_staged_files() {
  git -C "$GIT_ROOT" diff --cached --name-only --diff-filter=ACMRD | filter_project_paths
}

collect_explicit_changed_files() {
  if [ -n "${CODESPEC_CHANGED_FILES_FILE:-}" ]; then
    [ -f "$CODESPEC_CHANGED_FILES_FILE" ] || die "CODESPEC_CHANGED_FILES_FILE does not exist: $CODESPEC_CHANGED_FILES_FILE"
    grep -v '^$' "$CODESPEC_CHANGED_FILES_FILE" | filter_project_paths
    return
  fi

  if [ -n "${CODESPEC_CHANGED_FILES:-}" ]; then
    printf '%s\n' "$CODESPEC_CHANGED_FILES" | grep -v '^$' | filter_project_paths
    return
  fi

  return 0
}

collect_implementation_span_files() {
  local base_revision
  base_revision="$(yaml_scalar "$META_FILE" implementation_base_revision)"
  validate_git_revision "$base_revision" || die "implementation_base_revision is missing or invalid: ${base_revision:-null}"

  {
    git -C "$GIT_ROOT" diff --name-only --diff-filter=ACMRD "${base_revision}..HEAD"
    git -C "$GIT_ROOT" diff --cached --name-only --diff-filter=ACMRD
    git -C "$GIT_ROOT" diff --name-only --diff-filter=ACMRD
    git -C "$GIT_ROOT" ls-files --others --exclude-standard
  } | filter_project_paths
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

# Collect dirty (uncommitted) files in the worktree.
# Default mode excludes lifecycle files historically allowed during normal operation.
# Strict mode includes lifecycle files so phase-completion gates cannot ignore
# unstaged evidence or metadata drift.
collect_dirty_files() {
  local strict="${1:-false}"
  local files
  files="$(
    {
      git -C "$GIT_ROOT" diff --name-only --diff-filter=ACMRD
      git -C "$GIT_ROOT" ls-files --others --exclude-standard
    } | filter_project_paths || true
  )"

  if [ "$strict" = 'true' ]; then
    printf '%s\n' "$files" | grep -v '^$' | sort -u || true
    return
  fi

  printf '%s\n' "$files" \
    | grep -v '^$' \
    | grep -vE '(^|/)meta\.ya?ml$' \
    | grep -vE '(^|/)testing\.md$' \
    | sort -u || true
}

appendix_dir_has_files() {
  local dir="$1"
  [ -d "$dir" ] || return 1
  find "$dir" -type f \( -name '*.md' -o -name '*.markdown' \) -print -quit 2>/dev/null | grep -q .
}

check_ai_reading_contract_matrix() {
  local file="$1"
  local appendix_dir="$2"
  local label="$3"

  appendix_dir_has_files "$appendix_dir" || return 0

  awk '
    /^## 0\. AI 阅读契约$/ {
      in_section = 1
      next
    }
    in_section && /^## / {
      exit
    }
    in_section && /^\|/ {
      row = $0
      if (row ~ /读取触发/ && row ~ /权威边界/ && row ~ /冲突处理/) {
        header = 1
        next
      }
      if (header && row !~ /^[|[:space:]-]+$/ && row ~ /\|/) {
        data = 1
      }
    }
    END {
      exit(header && data ? 0 : 1)
    }
  ' "$file" || die "${label} AI reading contract must define appendix reading matrix"
}

# Check for dirty worktree files that fall within active WI allowed_paths, or
# all dirty files when strict=true.
check_dirty_worktree() {
  local strict="${1:-false}"
  local dirty_files
  dirty_files="$(collect_dirty_files "$strict")"
  if [ -n "$dirty_files" ] && [ -n "${CODESPEC_DIRTY_WORKTREE_IGNORE:-}" ]; then
    local ignored=()
    local filtered=()
    local file pattern skip
    IFS=',' read -r -a ignored <<< "$CODESPEC_DIRTY_WORKTREE_IGNORE"
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      skip=0
      for pattern in "${ignored[@]}"; do
        pattern="$(trim_value "$pattern")"
        if match_path "$file" "$pattern"; then
          skip=1
          break
        fi
      done
      [ "$skip" -eq 1 ] || filtered+=("$file")
    done <<< "$dirty_files"
    dirty_files="$(printf '%s\n' "${filtered[@]}" | grep -v '^$' || true)"
  fi
  [ -n "$dirty_files" ] || return 0

  if [ "$strict" = 'true' ] || [ "${CODESPEC_DIRTY_WORKTREE_STRICT:-}" = 'true' ]; then
    die "dirty worktree: uncommitted files detected: $(printf '%s' "$dirty_files" | tr '\n' ', ')"
  fi

  # In Implementation phase, check against active WI allowed_paths
  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"
  if [ "$phase" = 'Implementation' ] || [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
    local active=()
    mapfile -t active < <(collect_active_work_items)
    if [ "${#active[@]}" -gt 0 ]; then
      local dirty_in_scope=()
      local file wi wi_file
      local wi_allowed=()
      for file in $dirty_files; do
        for wi in "${active[@]}"; do
          wi_file="$PROJECT_ROOT/work-items/$wi.yaml"
          [ -f "$wi_file" ] || continue
          mapfile -t wi_allowed < <(yaml_list "$wi_file" allowed_paths)
          for pattern in "${wi_allowed[@]}"; do
            if match_path "$file" "$pattern"; then
              dirty_in_scope+=("$file")
              break 2
            fi
          done
        done
      done
      if [ "${#dirty_in_scope[@]}" -gt 0 ]; then
        die "dirty worktree: uncommitted files within active WI scope: $(printf '%s' "${dirty_in_scope[*]}" | tr ' ' ', ')"
      fi
    fi
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
    null|pending|todo|tbd|placeholder|none|yyyy-mm-dd|待填写|待补充|待确认)
      return 0
      ;;
  esac

  [[ "$normalized_value" =~ ^\[[^]]+\]$ ]] && return 0
  return 1
}

placeholder_text_pattern() {
  printf '%s' '\[[^]]*(用|谁|什么|来源|描述|必须|如何|为什么|当前|本|替换|期望|没有|主要|稳定|需求|测试|真实|命令|执行者|可复核|语言|数据库|第三方|工具|系统|模块|外部|接口|数据|兼容|鉴权|错误|日志|容量|垂直|预期|阶段|修改|说明|示例|填写|补充|确认)[^]]*\]|待填写|待补充|待确认|TODO|TBD|placeholder|YYYY-MM-DD|yyyy-mm-dd'
}

contains_placeholder_text() {
  local file="$1"
  grep -nE "$(placeholder_text_pattern)" "$file" 2>/dev/null || true
}

block_contains_placeholder_text() {
  local block="$1"
  grep -nE "$(placeholder_text_pattern)" <<< "$block" 2>/dev/null || true
}

require_markdown_heading() {
  local file="$1"
  local regex="$2"
  local message="$3"
  grep -qE "$regex" "$file" || die "$message"
}

markdown_section_scalar() {
  local file="$1"
  local header="$2"
  local key="$3"
  awk -v header="$header" -v key="$key" '
    function is_header_alias(line, expected) {
      if (line == expected) return 1
      if (expected == "## Deployment Plan" && line == "## 1. 发布对象与环境") return 1
      if (expected == "## Pre-deployment Checklist" && line == "## 2. 发布前条件") return 1
      if (expected == "## Execution Evidence" && line == "## 3. 执行证据") return 1
      if (expected == "## Verification Results" && line == "## 4. 运行验证") return 1
      if (expected == "## Acceptance Conclusion" && line == "## 6. 人工验收与收口") return 1
      return 0
    }
    is_header_alias($0, header) {
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

markdown_section_contains() {
  local file="$1"
  local header_regex="$2"
  local pattern="$3"
  awk -v header_regex="$header_regex" -v pattern="$pattern" '
    $0 ~ header_regex {
      in_section = 1
      next
    }
    in_section && /^## / {
      exit
    }
    in_section && $0 ~ pattern {
      found = 1
      exit
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$file"
}

design_requirement_trace_refs() {
  awk '
    function emit_ids(text) {
      while (match(text, /REQ-[0-9]{3}/)) {
        print substr(text, RSTART, RLENGTH)
        text = substr(text, RSTART + RLENGTH)
      }
    }

    /^## (Requirements Trace|2\. 需求追溯)$/ {
      in_trace = 1
      capture_requirements = 0
      next
    }

    in_trace && /^## / {
      exit
    }

    !in_trace {
      next
    }

    /^[[:space:]]*-[[:space:]]*requirement_ref:[[:space:]]*/ || /^[[:space:]]*requirement_ref:[[:space:]]*/ {
      emit_ids($0)
      capture_requirements = 0
      next
    }

    /^[[:space:]]*-[[:space:]]*requirement_refs:[[:space:]]*/ || /^[[:space:]]*requirement_refs:[[:space:]]*/ {
      emit_ids($0)
      capture_requirements = 1
      next
    }

    capture_requirements && /^[[:space:]]*-[[:space:]]*REQ-[0-9]{3}[[:space:]]*$/ {
      emit_ids($0)
      next
    }

    capture_requirements && /^[[:space:]]*[^[:space:]-][A-Za-z_]+:[[:space:]]*/ {
      capture_requirements = 0
      next
    }
  ' "$DESIGN_FILE" | sort -u || true
}

input_intake_scalar() {
  local key="$1"
  awk -v key="$key" '
    BEGIN { in_intake = 0 }
    /^## Inputs$/ || /^## 2\. 决策与来源$/ || /^### Input Intake Summary$/ || /^### Input Intake$/ {
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
    /^## Inputs$/ || /^## 2\. 决策与来源$/ || /^### Input Intake Summary$/ || /^### Input Intake$/ {
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
    /^## Requirements$/ || /^## 4\. 需求与验收$/ {
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

gate_metadata_consistency() {
  local phase status focus_wi execution_group execution_branch implementation_base_revision active=() wi blocked_reason active_repair repair_file repair_phase
  phase="$(yaml_scalar "$META_FILE" phase)"
  status="$(yaml_scalar "$META_FILE" status)"
  focus_wi="$(yaml_scalar "$META_FILE" focus_work_item)"
  execution_group="$(yaml_scalar "$META_FILE" execution_group)"
  execution_branch="$(yaml_scalar "$META_FILE" execution_branch)"
  implementation_base_revision="$(yaml_scalar "$META_FILE" implementation_base_revision)"
  blocked_reason="$(yaml_scalar "$META_FILE" blocked_reason)"
  active_repair="$(active_authority_repair_id)"
  mapfile -t active < <(collect_active_work_items)

  case "$phase" in
    Requirement|Design|Implementation|Testing|Deployment) ;;
    *) die "phase must be one of Requirement|Design|Implementation|Testing|Deployment (got: ${phase:-missing})" ;;
  esac

  case "$status" in
    active|blocked|completed) ;;
    *) die "status must be one of active|blocked|completed (got: ${status:-missing})" ;;
  esac

  if [ "$status" = 'completed' ] && [ "$phase" != 'Deployment' ]; then
    die 'completed status requires Deployment phase'
  fi

  if [ "$status" = 'blocked' ]; then
    is_placeholder_token "$blocked_reason" && die 'blocked status requires blocked_reason'
  fi

  if [ "$active_repair" != 'null' ]; then
    [[ "$active_repair" =~ ^REPAIR-[A-Za-z0-9._-]+$ ]] || die "active_authority_repair has invalid id: $active_repair"
    repair_file="$(authority_repair_file_for_id "$active_repair")"
    validate_authority_repair_record "$repair_file"
    [ "$(yaml_scalar "$repair_file" status)" = 'open' ] || die "active_authority_repair must point to an open repair: $active_repair"
    repair_phase="$(yaml_scalar "$repair_file" phase)"
    [ "$repair_phase" = "$phase" ] || die "active_authority_repair phase mismatch: $active_repair is $repair_phase but meta phase is $phase"
  fi
  validate_staged_authority_repair_records

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

gate_active_work_items_complete() {
  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"
  [ "$phase" = 'Implementation' ] || {
    log "✓ active-work-items-complete gate passed (phase ${phase})"
    return
  }

  local active=()
  local rows=()
  local row wi
  mapfile -t active < <(collect_active_work_items)
  mapfile -t rows < <(design_work_item_acceptance_rows)
  [ "${#rows[@]}" -gt 0 ] || die 'design.md has no concrete WI derivation rows yet'

  for row in "${rows[@]}"; do
    [ -n "$row" ] || continue
    wi="${row%%:*}"
    contains_exact_line "$wi" "${active[@]}" || die "active_work_items missing design work item: ${wi}"
  done

  log '✓ active-work-items-complete gate passed'
}

collect_formal_requirement_ids() {
  awk '
    BEGIN { in_requirements = 0 }
    /^## Requirements$/ || /^## 4\. 需求与验收$/ {
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
    /^[[:space:]]*-[[:space:]]*req_id:[[:space:]]*REQ-[0-9]{3}[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*req_id:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      print line
    }
  ' "$SPEC_FILE" | sort -u || true
}

validate_formal_id_definitions() {
  local violation
  violation="$(
    awk '
      BEGIN { section = "" }
      /^## Requirements$/ {
        section = "requirements"
        next
      }
      /^## Acceptance$/ {
        section = "acceptance"
        next
      }
      /^## Verification$/ {
        section = "verification"
        next
      }
      /^## 4\. 需求与验收$/ {
        section = "combined"
        next
      }
      /^## / {
        section = ""
        next
      }
      section != "" && /^[[:space:]]*-[[:space:]]*REQ-[0-9]{3}[[:space:]]*$/ {
        print "formal requirement IDs must use req_id: REQ-XXX"
        exit
      }
      section != "" && /^[[:space:]]*-[[:space:]]*ACC-[0-9]{3}[[:space:]]*$/ {
        print "formal acceptance IDs must use acc_id: ACC-XXX"
        exit
      }
      section != "" && /^[[:space:]]*-[[:space:]]*VO-[0-9]{3}[[:space:]]*$/ {
        print "formal verification IDs must use vo_id: VO-XXX"
        exit
      }
    ' "$SPEC_FILE"
  )"
  [ -z "$violation" ] || die "$violation"
}

collect_formal_acceptance_ids() {
  awk '
    BEGIN { in_acceptance = 0 }
    /^## Acceptance$/ || /^## 4\. 需求与验收$/ {
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
    /^## Verification$/ || /^## 4\. 需求与验收$/ {
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
    /^## Acceptance$/ || /^## 4\. 需求与验收$/ {
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
    /^## Acceptance$/ || /^## 4\. 需求与验收$/ {
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

collect_test_case_ids() {
  [ -f "$TESTING_FILE" ] || return 0
  grep -E '^[[:space:]]*-[[:space:]]*tc_id:[[:space:]]*TC-[A-Za-z0-9_-]+[[:space:]]*$' "$TESTING_FILE" \
    | sed -E 's/^[[:space:]]*-[[:space:]]*tc_id:[[:space:]]*//' \
    | sed -E 's/[[:space:]]*$//' \
    | sort -u || true
}

test_case_block() {
  local tc="$1"
  [ -f "$TESTING_FILE" ] || return 0
  awk -v tc="$tc" '
    function flush_case() {
      if (current_tc == tc && current_block != "") {
        selected = current_block
      }
      current_tc = ""
      current_block = ""
    }
    /^[[:space:]]*-[[:space:]]*tc_id:[[:space:]]*TC-[A-Za-z0-9_-]+[[:space:]]*$/ {
      flush_case()
      current_tc = $0
      sub(/^[[:space:]]*-[[:space:]]*tc_id:[[:space:]]*/, "", current_tc)
      sub(/[[:space:]]*$/, "", current_tc)
      current_block = $0
      next
    }
    /^[[:space:]]*-[[:space:]]*run_id:[[:space:]]*RUN-[A-Za-z0-9_-]+[[:space:]]*$/ {
      flush_case()
      next
    }
    current_tc != "" {
      current_block = current_block ORS $0
    }
    END {
      flush_case()
      if (selected != "") {
        printf "%s\n", selected
      }
    }
  ' "$TESTING_FILE"
}

test_case_scalar() {
  local tc="$1"
  local key="$2"
  test_case_block "$tc" | block_scalar_value "$key"
}

test_case_list_values() {
  local tc="$1"
  local key="$2"
  test_case_block "$tc" | block_list_values "$key"
}

test_cases_for_acceptance() {
  local acc="$1"
  local tc
  while IFS= read -r tc; do
    [ -n "$tc" ] || continue
    [ "$(test_case_scalar "$tc" acceptance_ref)" = "$acc" ] && printf '%s\n' "$tc"
  done < <(collect_test_case_ids)
}

testing_target_test_case_ids() {
  local acc tc
  while IFS= read -r acc; do
    [ -n "$acc" ] || continue
    while IFS= read -r tc; do
      [ -n "$tc" ] && printf '%s\n' "$tc"
    done < <(test_cases_for_acceptance "$acc")
  done < <(testing_target_acceptance_ids) | sort -u
}

work_item_refs_test_cases() {
  local file
  for file in "$PROJECT_ROOT"/work-items/*.yaml; do
    [ -f "$file" ] || continue
    yaml_list "$file" test_case_refs
  done | grep -E '^TC-[A-Za-z0-9_-]+$' | sort -u || true
}

testing_record_latest_scalar_for_tc() {
  local tc="$1"
  local key="$2"
  local scope="${3:-}"
  local acc
  acc="$(test_case_scalar "$tc" acceptance_ref)"
  [ -n "$acc" ] || return 0
  awk -v tc="$tc" -v acc="$acc" -v key="$key" -v scope="$scope" '
    function reset_record() {
      in_record = 0
      record_tc = ""
      record_acc = ""
      record_scope = ""
      record_result = ""
      record_value = ""
    }

    function record_matches() {
      if (record_tc == tc) return 1
      if (record_tc == "" && record_acc == acc) return 1
      return 0
    }

    function flush_record() {
      if (!in_record) return

      if (record_result != "" && record_result != "pass" && record_result != "fail") {
        print "ERROR: invalid result value: " record_result " (must be pass or fail)" > "/dev/stderr"
        exit_code = 1
        should_abort = 1
        return
      }

      if (!record_matches()) return
      if (scope != "" && record_scope != scope) return

      selected = record_value
      found = 1
    }

    BEGIN {
      reset_record()
      found = 0
      should_abort = 0
      exit_code = 0
    }

    /^[[:space:]]*-[[:space:]]*(run_id:[[:space:]]*RUN-[A-Za-z0-9_-]+|acceptance_ref:[[:space:]]*ACC-[0-9]{3})[[:space:]]*$/ {
      flush_record()
      if (should_abort) exit exit_code

      reset_record()
      in_record = 1
      if ($0 ~ /^[[:space:]]*-[[:space:]]*acceptance_ref:[[:space:]]*ACC-[0-9]{3}[[:space:]]*$/) {
        record_acc = $0
        sub(/^[[:space:]]*-[[:space:]]*acceptance_ref:[[:space:]]*/, "", record_acc)
        sub(/[[:space:]]*$/, "", record_acc)
        if (key == "acceptance_ref") record_value = record_acc
      }
      next
    }

    /^[[:space:]]*-[[:space:]]*handoff_id:[[:space:]]*HANDOFF-[A-Za-z0-9._-]+[[:space:]]*$/ {
      flush_record()
      if (should_abort) exit exit_code
      reset_record()
      next
    }

    !in_record { next }

    /^[[:space:]]*test_case_ref:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*test_case_ref:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      record_tc = line
      if (key == "test_case_ref") record_value = line
      next
    }

    /^[[:space:]]*acceptance_ref:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*acceptance_ref:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      record_acc = line
      if (key == "acceptance_ref") record_value = line
      next
    }

    /^[[:space:]]*test_scope:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*test_scope:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      record_scope = line
      if (key == "test_scope") record_value = line
      next
    }

    /^[[:space:]]*result:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*result:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      record_result = tolower(line)
      if (key == "result") record_value = record_result
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
      if (should_abort) exit exit_code
      if (found) print selected
    }
  ' "$TESTING_FILE"
}

has_test_case_pass() {
  local tc="$1"
  local result
  [ -f "$TESTING_FILE" ] || return 1
  result="$(testing_record_latest_scalar_for_tc "$tc" result)" || return 1
  [ "$result" = 'pass' ]
}

has_test_case_scope_pass() {
  local tc="$1"
  local scope="$2"
  local result
  [ -f "$TESTING_FILE" ] || return 1
  result="$(testing_record_latest_scalar_for_tc "$tc" result "$scope")" || return 1
  [ "$result" = 'pass' ]
}

completion_level_rank() {
  case "$1" in
    fixture_contract) printf '1\n' ;;
    in_memory_domain) printf '2\n' ;;
    api_connected) printf '3\n' ;;
    db_persistent) printf '4\n' ;;
    integrated_runtime) printf '5\n' ;;
    owner_verified) printf '6\n' ;;
    *) return 1 ;;
  esac
}

valid_completion_level() {
  completion_level_rank "$1" >/dev/null 2>&1
}

completion_level_less_than() {
  local current="$1"
  local target="$2"
  local current_rank target_rank
  current_rank="$(completion_level_rank "$current")" || return 0
  target_rank="$(completion_level_rank "$target")" || target_rank="$(completion_level_rank integrated_runtime)"
  [ "$current_rank" -lt "$target_rank" ]
}

semantic_handoff_block_for_phase() {
  local handoff_phase="$1"
  [ -f "$TESTING_FILE" ] || return 0
  awk -v handoff_phase="$handoff_phase" '
    function flush_record() {
      if (current_phase == handoff_phase && block != "") {
        selected = block
      }
      in_record = 0
      current_phase = ""
      block = ""
    }

    /^[[:space:]]*-[[:space:]]*handoff_id:[[:space:]]*HANDOFF-[A-Za-z0-9._-]+[[:space:]]*$/ {
      flush_record()
      in_record = 1
      block = $0
      next
    }

    !in_record { next }

    /^[[:space:]]*phase:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*phase:[[:space:]]*/, "", line)
      sub(/[[:space:]]*$/, "", line)
      current_phase = line
    }

    {
      block = block ORS $0
    }

    END {
      flush_record()
      if (selected != "") printf "%s\n", selected
    }
  ' "$TESTING_FILE"
}

semantic_handoff_scalar() {
  local phase="$1"
  local key="$2"
  semantic_handoff_block_for_phase "$phase" | block_scalar_value "$key"
}

semantic_handoff_has_list_entries() {
  local key="$1"
  awk -v key="$key" '
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*(none|null|\\[\\])[[:space:]]*$" {
      found = 0
      exit
    }
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*$" {
      capture = 1
      next
    }
    capture && /^[[:space:]]*-[[:space:]]+/ {
      found = 1
      exit
    }
    capture && /^[[:space:]]*[A-Za-z_]+:[[:space:]]*/ {
      capture = 0
      next
    }
    END {
      exit(found ? 0 : 1)
    }
  '
}

semantic_handoff_requires_unfinished() {
  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"

  case "$phase" in
    Implementation)
      local active=() wi wi_file wi_level tc current_level target_level residual_risk
      mapfile -t active < <(collect_active_work_items)
      [ "${#active[@]}" -gt 0 ] || return 0
      for wi in "${active[@]}"; do
        wi_file="$PROJECT_ROOT/work-items/$wi.yaml"
        [ -f "$wi_file" ] || continue
        wi_level="$(yaml_scalar "$wi_file" completion_level)"
        completion_level_less_than "$wi_level" integrated_runtime && return 0
        while IFS= read -r tc; do
          [ -n "$tc" ] || continue
          target_level="$(test_case_scalar "$tc" required_completion_level)"
          [ -n "$target_level" ] && [ "$target_level" != 'null' ] || target_level='integrated_runtime'
          current_level="$(testing_record_latest_scalar_for_tc "$tc" completion_level branch-local)"
          [ -n "$current_level" ] && [ "$current_level" != 'null' ] || current_level='fixture_contract'
          completion_level_less_than "$current_level" "$target_level" && return 0
          residual_risk="$(testing_record_latest_scalar_for_tc "$tc" residual_risk branch-local)"
          [ -z "$residual_risk" ] || [ "$residual_risk" = 'none' ] || return 0
        done < <(yaml_list "$wi_file" test_case_refs)
      done
      return 1
      ;;
    Testing)
      local tc required_stage current_level target_level residual_risk reopen_required
      while IFS= read -r tc; do
        [ -n "$tc" ] || continue
        required_stage="$(test_case_scalar "$tc" required_stage)"
        [ "$required_stage" != 'deployment' ] || continue
        has_test_case_scope_pass "$tc" full-integration || return 0
        target_level="$(test_case_scalar "$tc" required_completion_level)"
        [ -n "$target_level" ] && [ "$target_level" != 'null' ] || target_level='integrated_runtime'
        current_level="$(testing_record_latest_scalar_for_tc "$tc" completion_level full-integration)"
        [ -n "$current_level" ] && [ "$current_level" != 'null' ] || current_level='fixture_contract'
        completion_level_less_than "$current_level" "$target_level" && return 0
        residual_risk="$(testing_record_latest_scalar_for_tc "$tc" residual_risk full-integration)"
        [ -z "$residual_risk" ] || [ "$residual_risk" = 'none' ] || return 0
        reopen_required="$(testing_record_latest_scalar_for_tc "$tc" reopen_required full-integration)"
        [ "$reopen_required" = 'false' ] || return 0
      done < <(testing_target_test_case_ids)
      return 1
      ;;
    Deployment)
      local deployment_file="$PROJECT_ROOT/deployment.md"
      [ -f "$deployment_file" ] || return 0
      [ "$(markdown_section_scalar "$deployment_file" '## Acceptance Conclusion' 'status')" = 'pass' ] || return 0
      return 1
      ;;
    *)
      return 1
      ;;
  esac
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

    /^[[:space:]]*-[[:space:]]*handoff_id:[[:space:]]*HANDOFF-[A-Za-z0-9._-]+[[:space:]]*$/ {
      flush_record()
      if (should_abort) {
        exit exit_code
      }
      reset_record()
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
    /^## Acceptance$/ || /^## 4\. 需求与验收$/ {
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

review_file_for_target_phase() {
  local target_phase="${CODESPEC_TARGET_PHASE:-}"
  case "$target_phase" in
    Design)
      printf '%s\n' "$PROJECT_ROOT/reviews/design-review.yaml"
      ;;
    Implementation)
      printf '%s\n' "$PROJECT_ROOT/reviews/implementation-review.yaml"
      ;;
    *)
      return 1
      ;;
  esac
}

require_review_list_entries() {
  local review_file="$1"
  local key="$2"
  local message="$3"
  local entries=()
  local entry
  mapfile -t entries < <(yaml_list "$review_file" "$key" | grep -vE '^(|null)$' || true)
  [ "${#entries[@]}" -gt 0 ] || die "$message"
  for entry in "${entries[@]}"; do
    is_placeholder_token "$entry" && die "${key} contains placeholder value in ${review_file#$PROJECT_ROOT/}"
  done
  return 0
}

require_review_scalar() {
  local review_file="$1"
  local key="$2"
  local value
  value="$(yaml_scalar "$review_file" "$key")"
  is_placeholder_token "$value" && die "${key} contains placeholder value in ${review_file#$PROJECT_ROOT/}"
  return 0
}

require_review_gate_evidence() {
  local review_file="$1"
  local commands=()
  local results=()
  local idx command result

  mapfile -t commands < <(yq eval '.gate_evidence[].command' "$review_file" 2>/dev/null | grep -vE '^(|null)$' || true)
  mapfile -t results < <(yq eval '.gate_evidence[].result' "$review_file" 2>/dev/null | grep -vE '^(|null)$' || true)
  [ "${#commands[@]}" -gt 0 ] || die 'review gate_evidence must list at least one gate command'
  [ "${#commands[@]}" -eq "${#results[@]}" ] || die 'review gate_evidence entries must include command and result'

  for idx in "${!commands[@]}"; do
    command="${commands[$idx]}"
    result="${results[$idx]}"
    is_placeholder_token "$command" && die "review gate_evidence command contains placeholder value in ${review_file#$PROJECT_ROOT/}"
    case "$result" in
      pass) ;;
      *) die "review gate_evidence result must be pass in ${review_file#$PROJECT_ROOT/}" ;;
    esac
  done
  return 0
}

require_review_findings() {
  local review_file="$1"
  local severities=()
  local summaries=()
  local idx severity summary

  mapfile -t severities < <(yq eval '.findings[].severity' "$review_file" 2>/dev/null | grep -vE '^(|null)$' || true)
  mapfile -t summaries < <(yq eval '.findings[].summary' "$review_file" 2>/dev/null | grep -vE '^(|null)$' || true)
  [ "${#severities[@]}" -gt 0 ] || die 'review findings must include at least one explicit finding summary'
  [ "${#severities[@]}" -eq "${#summaries[@]}" ] || die 'review findings entries must include severity and summary'

  for idx in "${!severities[@]}"; do
    severity="${severities[$idx]}"
    summary="${summaries[$idx]}"
    case "$severity" in
      P0|P1|P2|none) ;;
      *) die "review finding severity must be P0/P1/P2/none in ${review_file#$PROJECT_ROOT/}" ;;
    esac
    is_placeholder_token "$summary" && die "review finding summary contains placeholder value in ${review_file#$PROJECT_ROOT/}"
  done
  return 0
}

gate_review_quality() {
  gate_review_verdict_present >/dev/null

  local review_file reviewed_by reviewed_at verdict
  review_file="$(review_file_for_target_phase)" || die 'review-quality requires CODESPEC_TARGET_PHASE=Design or Implementation'
  [ -f "$review_file" ] || die "missing review artifact: ${review_file#$PROJECT_ROOT/}"

  verdict="$(yaml_scalar "$review_file" verdict)"
  [ "$verdict" = 'approved' ] || die "review verdict must be approved in ${review_file#$PROJECT_ROOT/}"

  reviewed_by="$(yaml_scalar "$review_file" reviewed_by)"
  reviewed_at="$(yaml_scalar "$review_file" reviewed_at)"
  is_placeholder_token "$reviewed_by" && die "reviewed_by contains placeholder value in ${review_file#$PROJECT_ROOT/}"
  is_placeholder_token "$reviewed_at" && die "reviewed_at contains placeholder value in ${review_file#$PROJECT_ROOT/}"
  [[ "$reviewed_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "reviewed_at must be YYYY-MM-DD in ${review_file#$PROJECT_ROOT/}"

  require_review_list_entries "$review_file" scope 'review scope must list at least one reviewed artifact'
  require_review_gate_evidence "$review_file"
  require_review_findings "$review_file"
  require_review_scalar "$review_file" residual_risk
  require_review_scalar "$review_file" decision_notes

  log '✓ review-quality gate passed'
}

design_work_item_acceptance_rows() {
  awk '
    function append_ref(value) {
      gsub(/[[:space:]]/, "", value)
      if (value != "") {
        refs = (refs == "" ? value : refs "," value)
      }
    }
    function flush_row() {
      if (in_derivation && wi != "" && refs != "") print wi ":" refs
      wi = ""
      refs = ""
      capture_refs = 0
    }
    BEGIN { in_work_items = 0; in_derivation = 0; wi = ""; refs = ""; capture_refs = 0 }
    /^## Work Item Derivation$/ {
      flush_row()
      in_work_items = 1
      in_derivation = 1
      next
    }
    /^## 7\. 工作项与验证$/ {
      flush_row()
      in_work_items = 1
      in_derivation = 0
      next
    }
    in_work_items && /^### (工作项派生|Work Item Derivation)$/ {
      flush_row()
      in_derivation = 1
      next
    }
    in_work_items && /^### / {
      flush_row()
      in_derivation = 0
      next
    }
    /^## / {
      flush_row()
      in_work_items = 0
      in_derivation = 0
      next
    }
    !in_derivation { next }
    /^[[:space:]]*-[[:space:]]*wi_id:[[:space:]]*WI-[0-9]{3}[[:space:]]*$/ {
      flush_row()
      wi = $0
      sub(/^[[:space:]]*-[[:space:]]*wi_id:[[:space:]]*/, "", wi)
      sub(/[[:space:]]*$/, "", wi)
      refs = ""
      capture_refs = 0
      next
    }
    wi != "" && /^[[:space:]]*covered_acceptance_refs:[[:space:]]*\[/ {
      line = $0
      sub(/^[[:space:]]*covered_acceptance_refs:[[:space:]]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      append_ref(line)
      capture_refs = 0
      next
    }
    wi != "" && /^[[:space:]]*covered_acceptance_refs:[[:space:]]*$/ {
      capture_refs = 1
      next
    }
    capture_refs && /^[[:space:]]*-[[:space:]]*ACC-[0-9]{3}[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      append_ref(line)
      next
    }
    capture_refs && /^[[:space:]]*[^[:space:]-][A-Za-z_]+:[[:space:]]*/ {
      capture_refs = 0
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
      flush_row()
      in_work_items = 1
      in_derivation = 1
      next
    }

    /^## 7\. 工作项与验证$/ {
      flush_row()
      in_work_items = 1
      in_derivation = 0
      next
    }

    in_work_items && /^### (工作项派生|Work Item Derivation)$/ {
      flush_row()
      in_derivation = 1
      next
    }

    in_work_items && /^### / {
      flush_row()
      in_derivation = 0
      next
    }

    /^## / {
      flush_row()
      in_work_items = 0
      in_derivation = 0
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

spec_req_block() {
  local req="$1"
  awk -v req="$req" '
    function flush_block() {
      if (current == req && block != "") {
        selected = block
      }
      current = ""
      block = ""
    }
    /^## Requirements$/ || /^## 4\. 需求与验收$/ {
      in_requirements = 1
      next
    }
    /^## / {
      if (in_requirements) flush_block()
      in_requirements = 0
      next
    }
    !in_requirements { next }
    /^[[:space:]]*-[[:space:]]*req_id:[[:space:]]*REQ-[0-9]{3}[[:space:]]*$/ {
      flush_block()
      current = $0
      sub(/^[[:space:]]*-[[:space:]]*req_id:[[:space:]]*/, "", current)
      sub(/[[:space:]]*$/, "", current)
      block = $0
      next
    }
    /^[[:space:]]*-[[:space:]]*(acc_id:[[:space:]]*ACC-[0-9]{3}|vo_id:[[:space:]]*VO-[0-9]{3})[[:space:]]*$/ {
      flush_block()
      next
    }
    current != "" {
      block = block ORS $0
    }
    END {
      flush_block()
      if (selected != "") printf "%s\n", selected
    }
  ' "$SPEC_FILE"
}

spec_acc_block() {
  local acc="$1"
  awk -v acc="$acc" '
    function flush_block() {
      if (current == acc && block != "") {
        selected = block
      }
      current = ""
      block = ""
    }
    /^## Acceptance$/ || /^## 4\. 需求与验收$/ {
      in_acceptance = 1
      next
    }
    /^## / {
      if (in_acceptance) flush_block()
      in_acceptance = 0
      next
    }
    !in_acceptance { next }
    /^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*ACC-[0-9]{3}[[:space:]]*$/ {
      flush_block()
      current = $0
      sub(/^[[:space:]]*-[[:space:]]*acc_id:[[:space:]]*/, "", current)
      sub(/[[:space:]]*$/, "", current)
      block = $0
      next
    }
    /^[[:space:]]*-[[:space:]]*(req_id:[[:space:]]*REQ-[0-9]{3}|vo_id:[[:space:]]*VO-[0-9]{3})[[:space:]]*$/ {
      flush_block()
      next
    }
    current != "" {
      block = block ORS $0
    }
    END {
      flush_block()
      if (selected != "") printf "%s\n", selected
    }
  ' "$SPEC_FILE"
}

spec_acceptance_requirement_refs() {
  local acc="$1"
  local block
  block="$(spec_acc_block "$acc")"
  [ -n "$block" ] || return 0

  {
    block_scalar_value requirement_ref <<< "$block"
    block_list_values requirement_refs <<< "$block"
  } | grep -E '^REQ-[0-9]{3}$' | sort -u || true
}

spec_requirement_has_acceptance() {
  local req="$1"
  shift || true

  local acc refs=()
  for acc in "$@"; do
    [ -n "$acc" ] || continue
    mapfile -t refs < <(spec_acceptance_requirement_refs "$acc")
    contains_exact_line "$req" "${refs[@]}" && return 0
  done

  return 1
}

spec_vo_block() {
  local vo="$1"
  awk -v vo="$vo" '
    function flush_block() {
      if (current == vo && block != "") {
        selected = block
      }
      current = ""
      block = ""
    }
    /^## Verification$/ || /^## 4\. 需求与验收$/ {
      in_verification = 1
      next
    }
    /^## / {
      if (in_verification) flush_block()
      in_verification = 0
      next
    }
    !in_verification { next }
    /^[[:space:]]*-[[:space:]]*vo_id:[[:space:]]*VO-[0-9]{3}[[:space:]]*$/ {
      flush_block()
      current = $0
      sub(/^[[:space:]]*-[[:space:]]*vo_id:[[:space:]]*/, "", current)
      sub(/[[:space:]]*$/, "", current)
      block = $0
      next
    }
    /^[[:space:]]*-[[:space:]]*(req_id:[[:space:]]*REQ-[0-9]{3}|acc_id:[[:space:]]*ACC-[0-9]{3})[[:space:]]*$/ {
      flush_block()
      next
    }
    current != "" {
      block = block ORS $0
    }
    END {
      flush_block()
      if (selected != "") printf "%s\n", selected
    }
  ' "$SPEC_FILE"
}

require_block_field() {
  local block="$1"
  local owner="$2"
  local key="$3"
  local value
  value="$(block_scalar_value "$key" <<< "$block")"
  [ -n "$value" ] || die "${owner} missing ${key}"
  is_placeholder_token "$value" && die "${owner} ${key} contains placeholder value"
  return 0
}

check_focus_wi_design_alignment() {
  local design_block
  design_block="$(design_work_item_block "$FOCUS_WI")"
  [ -n "$design_block" ] || die "focus work item ${FOCUS_WI} is missing from design work item derivation"

  local design_requirement_refs=()
  local design_acceptance_refs=()
  local design_verification_refs=()
  local design_test_case_refs=()

  mapfile -t design_requirement_refs < <(printf '%s\n' "$design_block" | block_list_values requirement_refs | grep -vE '^(|null)$' || true)
  mapfile -t design_acceptance_refs < <(printf '%s\n' "$design_block" | block_list_values covered_acceptance_refs | grep -vE '^(|null)$' || true)
  mapfile -t design_verification_refs < <(printf '%s\n' "$design_block" | block_list_values verification_refs | grep -vE '^(|null)$' || true)
  mapfile -t design_test_case_refs < <(printf '%s\n' "$design_block" | block_list_values test_case_refs | grep -vE '^(|null)$' || true)

  # 从 WI_FILE 重新读取这些变量，避免依赖外部作用域
  local wi_requirement_refs=()
  local wi_acceptance_refs=()
  local wi_verification_refs=()
  local wi_test_case_refs=()

  mapfile -t wi_requirement_refs < <(yaml_list "$WI_FILE" requirement_refs)
  mapfile -t wi_acceptance_refs < <(yaml_list "$WI_FILE" acceptance_refs)
  mapfile -t wi_verification_refs < <(yaml_list "$WI_FILE" verification_refs)
  mapfile -t wi_test_case_refs < <(yaml_list "$WI_FILE" test_case_refs)

  local wi_requirements_csv wi_acceptance_csv wi_verification_csv wi_test_case_csv
  local design_requirements_csv design_acceptance_csv design_verification_csv design_test_case_csv

  wi_requirements_csv="$(printf '%s\n' "${wi_requirement_refs[@]}" | paste -sd ',' -)"
  wi_acceptance_csv="$(printf '%s\n' "${wi_acceptance_refs[@]}" | paste -sd ',' -)"
  wi_verification_csv="$(printf '%s\n' "${wi_verification_refs[@]}" | paste -sd ',' -)"
  wi_test_case_csv="$(printf '%s\n' "${wi_test_case_refs[@]}" | paste -sd ',' -)"

  design_requirements_csv="$(printf '%s\n' "${design_requirement_refs[@]}" | paste -sd ',' -)"
  design_acceptance_csv="$(printf '%s\n' "${design_acceptance_refs[@]}" | paste -sd ',' -)"
  design_verification_csv="$(printf '%s\n' "${design_verification_refs[@]}" | paste -sd ',' -)"
  design_test_case_csv="$(printf '%s\n' "${design_test_case_refs[@]}" | paste -sd ',' -)"

  [ "$(normalize_csv "$wi_requirements_csv")" = "$(normalize_csv "$design_requirements_csv")" ] || die "design/work-item requirement_refs mismatch for $FOCUS_WI"
  [ "$(normalize_csv "$wi_acceptance_csv")" = "$(normalize_csv "$design_acceptance_csv")" ] || die "design/work-item acceptance_refs mismatch for $FOCUS_WI"
  [ "$(normalize_csv "$wi_verification_csv")" = "$(normalize_csv "$design_verification_csv")" ] || die "design/work-item verification_refs mismatch for $FOCUS_WI"
  [ "$(normalize_csv "$wi_test_case_csv")" = "$(normalize_csv "$design_test_case_csv")" ] || die "design/work-item test_case_refs mismatch for $FOCUS_WI"
}

check_wi_refs_exist_in_spec() {
  local spec_requirements=()
  local spec_acceptances=()
  local spec_verifications=()
  local known_test_cases=()
  local ref

  mapfile -t spec_requirements < <(collect_spec_ids 'REQ')
  mapfile -t spec_acceptances < <(collect_spec_ids 'ACC')
  mapfile -t spec_verifications < <(collect_spec_ids 'VO')
  mapfile -t known_test_cases < <(collect_test_case_ids)

  for ref in "${requirement_refs[@]}"; do
    contains_exact_line "$ref" "${spec_requirements[@]}" || die "$FOCUS_WI references unknown requirement_ref: ${ref}"
  done

  for ref in "${acceptance_refs[@]}"; do
    contains_exact_line "$ref" "${spec_acceptances[@]}" || die "$FOCUS_WI references unknown acceptance_ref: ${ref}"
  done

  for ref in "${verification_refs[@]}"; do
    contains_exact_line "$ref" "${spec_verifications[@]}" || die "$FOCUS_WI references unknown verification_ref: ${ref}"
  done

  for ref in "${test_case_refs[@]}"; do
    contains_exact_line "$ref" "${known_test_cases[@]}" || die "$FOCUS_WI references unknown test_case_ref: ${ref}"
  done
}

check_design_work_item_acceptance_alignment() {
  local row wi design_refs work_item_file work_item_refs normalized_design normalized_work_item test_case_refs
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
    test_case_refs="$(yaml_list "$work_item_file" test_case_refs | paste -sd ',' -)"
    [ -n "$(normalize_csv "$test_case_refs")" ] || die "work-item $wi missing test_case_refs"
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
  validate_formal_id_definitions
  grep -qE '^## (Summary|1\. 需求概览)$' "$SPEC_FILE" || die 'spec.md missing requirements overview section'
  grep -qE '^## (Inputs|2\. 决策与来源)$' "$SPEC_FILE" || die 'spec.md missing sources section'
  grep -qE '^## (Scope|1\. 需求概览)$' "$SPEC_FILE" || die 'spec.md missing scope section'
  grep -qE '^## (Requirements|4\. 需求与验收)$' "$SPEC_FILE" || die 'spec.md missing formal requirement section'

  local input_maturity rigor_profile normalization_note input_owner approval_basis source_ref
  input_maturity="$(input_intake_scalar maturity)"
  rigor_profile="$(input_intake_scalar rigor_profile)"
  normalization_note="$(input_intake_scalar normalization_note)"
  input_owner="$(input_intake_scalar source_owner)"
  approval_basis="$(input_intake_scalar approval_basis)"

  if [ -n "$input_maturity" ]; then
    case "$input_maturity" in
      L0|L1|L2|L3) ;;
      *) die "input_maturity must be one of L0/L1/L2/L3 (got: ${input_maturity:-missing})" ;;
    esac
  else
    case "$rigor_profile" in
      light|standard|evidence-rich) ;;
      *) die "rigor_profile must be one of light/standard/evidence-rich (got: ${rigor_profile:-missing})" ;;
    esac
  fi

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

	  local req acc tc tcs=()
	  for req in "${reqs[@]}"; do
	    spec_requirement_has_acceptance "$req" "${accs[@]}" || die "requirement ${req} has no acceptance mapping"
	  done

  for acc in "${accs[@]}"; do
    grep -q "acceptance_ref: ${acc}" "$SPEC_FILE" || die "acceptance ${acc} has no verification mapping"
    is_placeholder_token "$(acceptance_expected_outcome "$acc")" && die "acceptance ${acc} expected_outcome contains placeholder value"

    [ -f "$TESTING_FILE" ] || die "testing.md is required before Requirement can advance to Design"
    mapfile -t tcs < <(test_cases_for_acceptance "$acc")
    [ "${#tcs[@]}" -gt 0 ] || die "acceptance ${acc} has no planned test case in testing.md"

    for tc in "${tcs[@]}"; do
      is_placeholder_token "$(test_case_scalar "$tc" acceptance_ref)" && die "test case ${tc} missing acceptance_ref"
      is_placeholder_token "$(test_case_scalar "$tc" verification_ref)" && die "test case ${tc} missing verification_ref"
      is_placeholder_token "$(test_case_scalar "$tc" test_type)" && die "test case ${tc} missing test_type"
      is_placeholder_token "$(test_case_scalar "$tc" verification_mode)" && die "test case ${tc} missing verification_mode"
      is_placeholder_token "$(test_case_scalar "$tc" required_stage)" && die "test case ${tc} missing required_stage"
      is_placeholder_token "$(test_case_scalar "$tc" scenario)" && die "test case ${tc} missing scenario"
      is_placeholder_token "$(test_case_scalar "$tc" given)" && die "test case ${tc} missing given"
      is_placeholder_token "$(test_case_scalar "$tc" when)" && die "test case ${tc} missing when"
      is_placeholder_token "$(test_case_scalar "$tc" then)" && die "test case ${tc} missing then"
      is_placeholder_token "$(test_case_scalar "$tc" evidence_expectation)" && die "test case ${tc} missing evidence_expectation"
      is_placeholder_token "$(test_case_scalar "$tc" status)" && die "test case ${tc} missing status"
      contains_exact_line "$(test_case_scalar "$tc" verification_ref)" "${vos[@]}" || die "test case ${tc} references unknown verification_ref"
      case "$(test_case_scalar "$tc" verification_mode)" in
        automated|manual|equivalent) ;;
        *) die "test case ${tc} verification_mode must be automated/manual/equivalent" ;;
      esac
      if [ "$(spec_acceptance_priority "$acc")" = 'P0' ] && [ "$(test_case_scalar "$tc" verification_mode)" != 'automated' ]; then
        is_placeholder_token "$(test_case_scalar "$tc" automation_exception_reason)" && die "P0 test case ${tc} requires automation_exception_reason when not automated"
      fi
      case "$(test_case_scalar "$tc" required_stage)" in
        implementation|testing|deployment) ;;
        *) die "test case ${tc} required_stage must be implementation/testing/deployment" ;;
      esac
    done
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

gate_spec_quality() {
  gate_requirement_complete >/dev/null

  require_markdown_heading "$SPEC_FILE" '^## 0\. AI 阅读契约$' 'spec.md missing AI reading contract section'
  check_ai_reading_contract_matrix "$SPEC_FILE" "$PROJECT_ROOT/spec-appendices" 'spec.md'
  require_markdown_heading "$SPEC_FILE" '^## 1\. 需求概览$|^## Summary$' 'spec.md missing requirement overview section'
  require_markdown_heading "$SPEC_FILE" '^## 2\. 决策与来源$|^## Inputs$' 'spec.md missing decision/source section'
  require_markdown_heading "$SPEC_FILE" '^## 3\. 场景、流程与运行叙事$|^## 3\. 场景与行为$|^## Scenarios$' 'spec.md missing scenario narrative section'
  require_markdown_heading "$SPEC_FILE" '^## 4\. 需求与验收$|^## Requirements$' 'spec.md missing formal requirement/acceptance section'
  require_markdown_heading "$SPEC_FILE" '^## 5\. 运行约束$|^## Constraints$|^## Operational Constraints$' 'spec.md missing constraints/verification section'

  # R6: check narrative section has forward-form content (not just headers and scenario index)
  local narrative_line_count
  narrative_line_count="$(awk '
    /^## 3\. 场景、流程与运行叙事$|^## 3\. 场景与行为$|^## Scenarios$/ { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && /^### / { next }
    in_section && /^[[:space:]]*$/ { next }
    in_section && /^- scenario_id:/ { next }
    in_section && /^  [a-z_]+:/ { next }
    in_section && /^- \[.\] / { next }
    in_section { count++ }
    END { print count+0 }
  ' "$SPEC_FILE")"
  [ "$narrative_line_count" -ge 5 ] || die "spec.md scenario narrative has insufficient forward-form content (${narrative_line_count} lines, minimum 5 required by R6)"

  local placeholders
  placeholders="$(contains_placeholder_text "$SPEC_FILE")"
  [ -z "$placeholders" ] || die "spec.md contains template placeholder text: $(printf '%s\n' "$placeholders" | head -n 1)"

  local reqs=()
  local accs=()
  local vos=()
  mapfile -t reqs < <(collect_spec_ids 'REQ')
  mapfile -t accs < <(collect_spec_ids 'ACC')
  mapfile -t vos < <(collect_spec_ids 'VO')

  local req acc vo block value req_ref obligations=()
  for req in "${reqs[@]}"; do
    block="$(spec_req_block "$req")"
    [ -n "$block" ] || die "${req} has no structured block"
    require_block_field "$block" "$req" summary
    require_block_field "$block" "$req" source_ref
    require_block_field "$block" "$req" rationale
    require_block_field "$block" "$req" priority
    value="$(block_scalar_value priority <<< "$block")"
    case "$value" in
      P0|P1|P2) ;;
      *) die "${req} priority must be P0/P1/P2" ;;
    esac
  done

  for acc in "${accs[@]}"; do
    block="$(spec_acc_block "$acc")"
    [ -n "$block" ] || die "${acc} has no structured block"
    req_ref="$(block_scalar_value requirement_ref <<< "$block")"
    if is_placeholder_token "$req_ref"; then
      req_ref="$(block_scalar_value source_ref <<< "$block")"
    fi
    [ -n "$req_ref" ] && ! is_placeholder_token "$req_ref" || die "${acc} missing requirement_ref"
    contains_exact_line "$req_ref" "${reqs[@]}" || die "${acc} requirement_ref references unknown requirement: ${req_ref}"
    require_block_field "$block" "$acc" expected_outcome
    require_block_field "$block" "$acc" priority
    require_block_field "$block" "$acc" priority_rationale
    require_block_field "$block" "$acc" status
    value="$(block_scalar_value priority <<< "$block")"
    case "$value" in
      P0|P1|P2) ;;
      *) die "${acc} priority must be P0/P1/P2" ;;
    esac
    value="$(block_scalar_value status <<< "$block")"
    case "$value" in
      planned|approved) ;;
      *) die "${acc} status must be planned or approved" ;;
    esac
  done

  for vo in "${vos[@]}"; do
    block="$(spec_vo_block "$vo")"
    [ -n "$block" ] || die "${vo} has no structured block"
    require_block_field "$block" "$vo" acceptance_ref
    require_block_field "$block" "$vo" verification_type
    require_block_field "$block" "$vo" verification_profile
    require_block_field "$block" "$vo" artifact_expectation
    value="$(block_scalar_value acceptance_ref <<< "$block")"
    contains_exact_line "$value" "${accs[@]}" || die "${vo} acceptance_ref references unknown acceptance: ${value}"
    value="$(block_scalar_value verification_type <<< "$block")"
    case "$value" in
      automated|manual|equivalent) ;;
      *) die "${vo} verification_type must be automated/manual/equivalent" ;;
    esac
    value="$(block_scalar_value verification_profile <<< "$block")"
    case "$value" in
      focused|full) ;;
      *) die "${vo} verification_profile must be focused/full" ;;
    esac
    mapfile -t obligations < <(block_list_values obligations <<< "$block")
    [ "${#obligations[@]}" -gt 0 ] || die "${vo} missing obligations"
    local obligation
    for obligation in "${obligations[@]}"; do
      is_placeholder_token "$obligation" && die "${vo} obligations contains placeholder value"
    done
  done

  log '✓ spec structural minimum passed (semantic positive-shape review required separately)'
}

gate_test_plan_complete() {
  [ -f "$TESTING_FILE" ] || die 'testing.md is required before Requirement can advance to Design'
  validate_formal_id_definitions

  local accs=()
  local vos=()
  local tcs=()
  mapfile -t accs < <(testing_target_acceptance_ids)
  mapfile -t vos < <(collect_spec_ids 'VO')
  [ "${#accs[@]}" -gt 0 ] || die 'no approved/planned ACC-* entries found for test planning'

  local acc tc block placeholders
  for acc in "${accs[@]}"; do
    mapfile -t tcs < <(test_cases_for_acceptance "$acc")
    [ "${#tcs[@]}" -gt 0 ] || die "acceptance ${acc} has no planned test case in testing.md"
    for tc in "${tcs[@]}"; do
      block="$(test_case_block "$tc")"
      [ -n "$block" ] || die "${tc} has no structured block"
      placeholders="$(block_contains_placeholder_text "$block")"
      [ -z "$placeholders" ] || die "${tc} contains template placeholder text"
      require_block_field "$block" "$tc" acceptance_ref
      require_block_field "$block" "$tc" verification_ref
      require_block_field "$block" "$tc" test_type
      require_block_field "$block" "$tc" verification_mode
      require_block_field "$block" "$tc" required_stage
      require_block_field "$block" "$tc" scenario
      require_block_field "$block" "$tc" given
      require_block_field "$block" "$tc" when
      require_block_field "$block" "$tc" then
      require_block_field "$block" "$tc" evidence_expectation
      require_block_field "$block" "$tc" status
      contains_exact_line "$(block_scalar_value verification_ref <<< "$block")" "${vos[@]}" || die "${tc} references unknown verification_ref"
      case "$(block_scalar_value verification_mode <<< "$block")" in
        automated|manual|equivalent) ;;
        *) die "${tc} verification_mode must be automated/manual/equivalent" ;;
      esac
      case "$(block_scalar_value required_stage <<< "$block")" in
        implementation|testing|deployment) ;;
        *) die "${tc} required_stage must be implementation/testing/deployment" ;;
      esac
      if [ "$(spec_acceptance_priority "$acc")" = 'P0' ] && [ "$(block_scalar_value verification_mode <<< "$block")" != 'automated' ]; then
        require_block_field "$block" "$tc" automation_exception_reason
      fi
    done
  done

  log '✓ test-plan-complete gate passed'
}


gate_design_structure_complete() {
  check_appendix_authority
  grep -qE '^## (Summary|1\. 设计概览)$' "$DESIGN_FILE" || die 'design.md missing design overview'
  grep -qE '^## (Technical Approach|3\. 架构决策)$' "$DESIGN_FILE" || die 'design.md missing architecture decisions'
  grep -qE '^## (Boundaries & Impacted Surfaces|4\. 系统结构)$' "$DESIGN_FILE" || die 'design.md missing system structure'
  grep -qE '^## (Work Item Derivation|7\. 工作项与验证)$' "$DESIGN_FILE" || die 'design.md missing work item derivation'
  grep -qE '技术栈选择|runtime:' "$DESIGN_FILE" || die 'design.md missing technology stack selection'
  grep -qE 'external_interactions|外部交互' "$DESIGN_FILE" || die 'design.md missing external interaction design'
  grep -qE 'security_design|安全' "$DESIGN_FILE" || die 'design.md missing security design'
  grep -qE 'environment_config|环境' "$DESIGN_FILE" || die 'design.md missing environment configuration requirements'

  local derivation_rows=()
  mapfile -t derivation_rows < <(design_work_item_acceptance_rows)
  [ "${#derivation_rows[@]}" -gt 0 ] || die 'design.md has no concrete WI derivation rows yet'

  check_design_work_item_acceptance_alignment
  log '✓ design-structure-complete gate passed'
}

gate_design_quality() {
  gate_design_structure_complete >/dev/null
  validate_formal_id_definitions

  require_markdown_heading "$DESIGN_FILE" '^## 0\. AI 阅读契约$' 'design.md missing AI reading contract section'
  check_ai_reading_contract_matrix "$DESIGN_FILE" "$PROJECT_ROOT/design-appendices" 'design.md'
  require_markdown_heading "$DESIGN_FILE" '^## 1\. 设计概览$|^## Summary$' 'design.md missing design overview section'
  require_markdown_heading "$DESIGN_FILE" '^## 2\. 需求追溯$|^## Requirements Trace$' 'design.md missing requirements trace section'
  require_markdown_heading "$DESIGN_FILE" '^## 3\. 架构决策$|^## Technical Approach$' 'design.md missing architecture decision section'
  require_markdown_heading "$DESIGN_FILE" '^## 4\. 系统结构$|^## Boundaries & Impacted Surfaces$' 'design.md missing system structure section'
  require_markdown_heading "$DESIGN_FILE" '^## 5\. 契约设计$|^## External Interactions & Contracts$|^## Data & Storage Design$' 'design.md missing contract/data design section'
  require_markdown_heading "$DESIGN_FILE" '^## 6\. 横切设计$|^## Cross-Cutting Design$|^## Cross Cutting Design$' 'design.md missing cross-cutting design section'
  require_markdown_heading "$DESIGN_FILE" '^## 7\. 工作项与验证$|^## Work Item Derivation$' 'design.md missing work item and verification section'
  require_markdown_heading "$DESIGN_FILE" '^## 8\. 实现阶段输入$' 'design.md missing implementation input section (R8: Runbook/Contract/View/Verification)'
  markdown_section_contains "$DESIGN_FILE" '^## 8\. 实现阶段输入$' 'runbook:' || die 'design.md implementation input section missing Runbook (R8)'
  markdown_section_contains "$DESIGN_FILE" '^## 8\. 实现阶段输入$' 'contract_summary:' || die 'design.md implementation input section missing Contract (R8)'
  markdown_section_contains "$DESIGN_FILE" '^## 8\. 实现阶段输入$' 'view_summary:' || die 'design.md implementation input section missing View (R8)'
  markdown_section_contains "$DESIGN_FILE" '^## 8\. 实现阶段输入$' 'verification_summary:' || die 'design.md implementation input section missing Verification (R8)'

  grep -qE '技术栈选择|runtime:' "$DESIGN_FILE" || die 'design.md missing technology stack selection'
  grep -qE 'external_interactions|外部交互' "$DESIGN_FILE" || die 'design.md missing external interaction design'
  markdown_section_contains "$DESIGN_FILE" '^## (5[.] 契约设计|External Interactions & Contracts|Data & Storage Design)$' 'data_contracts|storage:|数据契约|存储设计' || die 'design.md missing data/storage design'
  grep -qE 'security_design|安全' "$DESIGN_FILE" || die 'design.md missing security design'
  grep -qE 'environment_config|环境' "$DESIGN_FILE" || die 'design.md missing environment configuration requirements'
  grep -qE 'reliability_design|错误处理|失败|重试|降级|reopen|Failure Paths' "$DESIGN_FILE" || die 'design.md missing reliability/failure-path design'

  local placeholders
  placeholders="$(contains_placeholder_text "$DESIGN_FILE")"
  [ -z "$placeholders" ] || die "design.md contains template placeholder text: $(printf '%s\n' "$placeholders" | head -n 1)"

  local reqs=()
  local design_trace_refs=()
  local req
  mapfile -t reqs < <(collect_spec_ids 'REQ')
  mapfile -t design_trace_refs < <(design_requirement_trace_refs)
  for req in "${reqs[@]}"; do
    contains_exact_line "$req" "${design_trace_refs[@]}" || die "design.md does not reference requirement ${req}"
  done

  log '✓ design structural minimum passed (semantic cold-start review required separately)'
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
  grep -qE '^## (Technical Approach|3\. 架构决策)$' "$DESIGN_FILE" || die 'design.md missing architecture decisions'
  grep -qE '^## (Boundaries & Impacted Surfaces|4\. 系统结构)$' "$DESIGN_FILE" || die 'design.md missing system structure'
  grep -qE '^## (Verification Design|7\. 工作项与验证)$' "$DESIGN_FILE" || die 'design.md missing verification design'
  log '✓ implementation-readiness-baseline gate passed'
}

check_scope_path_coverage() {
  local required_surfaces=()
  mapfile -t required_surfaces < <(yaml_list "$WI_FILE" required_surfaces)

  # Backwards compatibility: no required_surfaces → warn but pass
  if [ "${#required_surfaces[@]}" -eq 0 ] || [ "${required_surfaces[0]}" = "null" ] || [ -z "${required_surfaces[0]}" ]; then
    log "WARNING: $FOCUS_WI has no required_surfaces; scope-path coverage cannot be verified"
    return 0
  fi

  for item in "${required_surfaces[@]}"; do
    if is_placeholder_token "$item"; then
      log "WARNING: $FOCUS_WI required_surfaces contains placeholder value; skipping coverage check"
      return 0
    fi
  done

  local uncovered=()
  for surface in "${required_surfaces[@]}"; do
    if ! match_any_path "$surface" "${allowed_paths[@]}"; then
      uncovered+=("$surface")
    fi
  done

  if [ "${#uncovered[@]}" -gt 0 ]; then
    die "$FOCUS_WI required_surfaces not covered by allowed_paths: ${uncovered[*]}"
  fi
}


gate_implementation_start() {
  require_focus_wi
  validate_formal_id_definitions
  [ "$(yaml_scalar "$WI_FILE" goal)" != 'null' ] || die "$FOCUS_WI missing goal"
  [ "$(yaml_scalar "$WI_FILE" phase_scope)" = 'Implementation' ] || die "$FOCUS_WI phase_scope must be Implementation"
  is_placeholder_token "$(yaml_scalar "$WI_FILE" goal)" && die "$FOCUS_WI goal contains placeholder value"
  is_placeholder_token "$(yaml_scalar "$WI_FILE" derived_from)" && die "$FOCUS_WI derived_from contains placeholder value"

  local requirement_refs=()
  local acceptance_refs=()
  local verification_refs=()
  local test_case_refs=()
  local allowed_paths=()
  local forbidden_paths=()
  local required_verification=()
  local stop_conditions=()
  local reopen_triggers=()
  local branch_owned_paths=()
  local scope=()
  local out_of_scope=()
  mapfile -t requirement_refs < <(yaml_list "$WI_FILE" requirement_refs)
  mapfile -t acceptance_refs < <(yaml_list "$WI_FILE" acceptance_refs)
  mapfile -t verification_refs < <(yaml_list "$WI_FILE" verification_refs)
  mapfile -t test_case_refs < <(yaml_list "$WI_FILE" test_case_refs)
  mapfile -t allowed_paths < <(yaml_list "$WI_FILE" allowed_paths)
  mapfile -t forbidden_paths < <(yaml_list "$WI_FILE" forbidden_paths)
  mapfile -t required_verification < <(yaml_list "$WI_FILE" required_verification)
  mapfile -t stop_conditions < <(yaml_list "$WI_FILE" stop_conditions)
  mapfile -t reopen_triggers < <(yaml_list "$WI_FILE" reopen_triggers)
  mapfile -t branch_owned_paths < <(yaml_list "$WI_FILE" branch_execution.owned_paths)
  mapfile -t scope < <(yaml_list "$WI_FILE" scope)
  mapfile -t out_of_scope < <(yaml_list "$WI_FILE" out_of_scope)

  [ "${#requirement_refs[@]}" -gt 0 ] || die "$FOCUS_WI missing requirement_refs"
  [ "${#acceptance_refs[@]}" -gt 0 ] || die "$FOCUS_WI missing acceptance_refs"
  [ "${#verification_refs[@]}" -gt 0 ] || die "$FOCUS_WI missing verification_refs"
  [ "${#test_case_refs[@]}" -gt 0 ] || die "$FOCUS_WI missing test_case_refs"
  [ "${#allowed_paths[@]}" -gt 0 ] || die "$FOCUS_WI missing allowed_paths"
  [ "${#forbidden_paths[@]}" -gt 0 ] || die "$FOCUS_WI missing forbidden_paths"
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
  for item in "${allowed_paths[@]}"; do
    is_placeholder_token "$item" && die "$FOCUS_WI allowed_paths contains placeholder value: $item"
  done
  for item in "${forbidden_paths[@]}"; do
    is_placeholder_token "$item" && die "$FOCUS_WI forbidden_paths contains placeholder value: $item"
  done
  for item in "${required_verification[@]}"; do
    is_placeholder_token "$item" && die "$FOCUS_WI required_verification contains placeholder value: $item"
  done
  for item in "${stop_conditions[@]}"; do
    is_placeholder_token "$item" && die "$FOCUS_WI stop_conditions contains placeholder value: $item"
  done
  for item in "${reopen_triggers[@]}"; do
    is_placeholder_token "$item" && die "$FOCUS_WI reopen_triggers contains placeholder value: $item"
  done

  # scope-path coverage: warn if required_surfaces not set or placeholder
  local _rs=()
  mapfile -t _rs < <(yaml_list "$WI_FILE" required_surfaces)
  if [ "${#_rs[@]}" -gt 0 ] && [ "${_rs[0]}" != "null" ] && [ -n "${_rs[0]}" ]; then
    local _has_placeholder=0
    for _item in "${_rs[@]}"; do
      if is_placeholder_token "$_item"; then
        _has_placeholder=1
        break
      fi
    done
    if [ "$_has_placeholder" -eq 0 ]; then
      local _uncovered=()
      for _surface in "${_rs[@]}"; do
        if ! match_any_path "$_surface" "${allowed_paths[@]}"; then
          _uncovered+=("$_surface")
        fi
      done
      if [ "${#_uncovered[@]}" -gt 0 ]; then
        die "$FOCUS_WI required_surfaces not covered by allowed_paths: ${_uncovered[*]}"
      fi
    else
      log "WARNING: $FOCUS_WI required_surfaces contains placeholder; skipping coverage check"
    fi
  else
    log "WARNING: $FOCUS_WI has no required_surfaces; scope-path coverage cannot be verified"
  fi

  # owned_paths 只在并行模式下强制要求
  local execution_group
  execution_group="$(yaml_scalar "$META_FILE" execution_group)"
  if [ "$execution_group" != 'null' ]; then
    [ "${#branch_owned_paths[@]}" -gt 0 ] || die "$FOCUS_WI: parallel execution requires branch_execution.owned_paths"
  fi

  [ "$(yaml_scalar "$WI_FILE" derived_from)" != 'null' ] || die "$FOCUS_WI missing derived_from"

  check_focus_wi_design_alignment
  check_wi_refs_exist_in_spec

  local ref

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
  if [ -z "$dependency_type" ] || [ "$dependency_type" = 'null' ]; then
    dependency_type='none'
    if [ "$dependency_refs_count" -gt 0 ] && [ "${dependency_refs[0]}" != "" ] && [ "${dependency_refs[0]}" != "null" ]; then
      dependency_type='strong'
    fi
  fi

  # Check dependency_type is valid. Weak dependencies are not accepted until they have distinct semantics.
  case "$dependency_type" in
    strong|none)
      # Valid values
      ;;
    *)
      die "$FOCUS_WI dependency_type must be strong or none (got: $dependency_type)"
      ;;
  esac

  # Check semantic consistency: empty dependency_refs requires dependency_type = none
  if [ "$dependency_refs_count" -eq 0 ] || [ "${dependency_refs[0]}" = "" ] || [ "${dependency_refs[0]}" = "null" ]; then
    [ "$dependency_type" = 'none' ] || die "$FOCUS_WI has no dependencies but dependency_type is $dependency_type (must be none)"
  else
    [ "$dependency_type" != 'none' ] || die "$FOCUS_WI has dependencies but dependency_type is none (must be strong)"
  fi

  # Check for circular dependencies before checking pass records
  check_circular_dependencies "$FOCUS_WI"

  check_dependency_pass_records

  log '✓ implementation-start gate passed'
}

gate_phase_capability() {
  local phase mode
  phase="$(yaml_scalar "$META_FILE" phase)"
  mode="${CODESPEC_PHASE_CAPABILITY_MODE:-staged}"
  local changed=()
  if [ "$mode" = 'changed-files' ]; then
    mapfile -t changed < <(collect_explicit_changed_files)
  else
    mapfile -t changed < <(collect_staged_files)
  fi
  [ "${#changed[@]}" -gt 0 ] || {
    log '✓ phase-capability gate passed (no changed files)'
    return
  }

  local active_repair
  active_repair="$(active_authority_repair_id)"
  if [ "$active_repair" != 'null' ]; then
    local file
    for file in "${changed[@]}"; do
      active_authority_repair_allows_path "$file" || die "phase-capability gate failed: changed file $file is outside active authority repair allowed_paths"
    done
    log '✓ phase-capability gate passed (active authority repair)'
    return
  fi

  local forbidden=()
  local forbidden_label
  case "$phase" in
    Requirement)
      forbidden=("src/**" "Dockerfile")
      forbidden_label='implementation artifacts'
      ;;
    Design)
      forbidden=("src/**" "Dockerfile")
      forbidden_label='implementation artifacts'
      ;;
    Testing)
      forbidden=("src/**" "Dockerfile" "spec.md" "design.md" "work-items/**" "contracts/**" "deployment.md")
      forbidden_label='phase-frozen artifacts'
      ;;
    Deployment)
      forbidden=("src/**" "Dockerfile" "spec.md" "design.md" "work-items/**" "contracts/**")
      forbidden_label='phase-frozen artifacts'
      ;;
    *)
      log "✓ phase-capability gate passed (phase ${phase})"
      return
      ;;
  esac

  local file pattern
  for file in "${changed[@]}"; do
    for pattern in "${forbidden[@]}"; do
      if match_path "$file" "$pattern"; then
        if closed_authority_repair_allows_path "$file"; then
          continue 2
        fi
        die "phase-capability gate failed: ${phase} forbids ${forbidden_label}: ${file}"
      fi
    done
  done

  log '✓ phase-capability gate passed'
}

gate_scope() {
  local phase status mode
  phase="$(yaml_scalar "$META_FILE" phase)"
  status="$(yaml_scalar "$META_FILE" status)"
  mode="${CODESPEC_SCOPE_MODE:-staged}"
  if [ "$phase" != 'Implementation' ] && [ "$mode" != 'implementation-span' ]; then
    if [ "$status" = 'completed' ]; then
      log "✓ scope gate passed (phase ${phase}, status completed)"
      return
    fi
    if [ "$mode" != 'changed-files' ] || { [ "$phase" != 'Testing' ] && [ "$phase" != 'Deployment' ]; }; then
      log "✓ scope gate passed (phase ${phase})"
      return
    fi
  fi

  local changed=()
  if [ "$mode" = 'implementation-span' ]; then
    mapfile -t changed < <(collect_implementation_span_files)
  elif [ "$mode" = 'changed-files' ]; then
    if [ "$phase" = 'Implementation' ]; then
      require_focus_wi
    fi
    mapfile -t changed < <(collect_explicit_changed_files)
  else
    require_focus_wi
    # staged mode: collect both staged and dirty (unstaged/untracked) files
    local staged_files=() dirty_files=()
    mapfile -t staged_files < <(collect_staged_files)
    mapfile -t dirty_files < <(collect_dirty_files)
    changed=()
    if [ "${#staged_files[@]}" -gt 0 ] || [ "${#dirty_files[@]}" -gt 0 ]; then
      local all_files
      all_files="$(printf '%s\n' "${staged_files[@]}" "${dirty_files[@]}" | grep -v '^$' | sort -u)"
      mapfile -t changed < <(printf '%s\n' "$all_files")
    fi
  fi
  [ "${#changed[@]}" -gt 0 ] || {
    log '✓ scope gate passed (no changed files)'
    return
  }

  local active_repair
  active_repair="$(active_authority_repair_id)"
  if [ "$active_repair" != 'null' ]; then
    if [ "$mode" = 'implementation-span' ] && [ "${CODESPEC_AUTHORITY_REPAIR_CLOSING:-}" != '1' ]; then
      die "active authority repair must be closed before implementation-span scope checks: $active_repair"
    fi
    local repair_file
    for repair_file in "${changed[@]}"; do
      active_authority_repair_allows_path "$repair_file" || die "changed file $repair_file is outside active authority repair allowed_paths"
    done
    log '✓ scope gate passed (active authority repair)'
    return
  fi

  if [ "$mode" = 'implementation-span' ] || { [ "$mode" = 'changed-files' ] && [ "$phase" != 'Implementation' ]; }; then
    local active=() global_forbidden=()
    local file wi wi_file ok forbidden_match
    local wi_allowed=() wi_forbidden=()

    mapfile -t active < <(collect_active_work_items)
    if [ "$mode" = 'implementation-span' ]; then
      [ "${#active[@]}" -gt 0 ] || die 'Implementation scope span requires active_work_items'
    else
      [ "${#active[@]}" -gt 0 ] || die "${phase} changed-files scope requires active_work_items"
    fi

    # Authority files like work-items/WI-001.yaml may be explicitly owned by an
    # active work item. Keep hard-frozen docs global, but let work-item files
    # fall through to the per-WI allowed/forbidden match below.
    if [ "$mode" = 'implementation-span' ]; then
      global_forbidden=("versions/**" "spec.md" "design.md" "deployment.md")
    else
      global_forbidden=()
    fi

    for file in "${changed[@]}"; do
      case "$file" in
        meta.yaml|testing.md)
          continue
          ;;
      esac
      if [ "$mode" = 'changed-files' ] && [ "$phase" = 'Deployment' ] && [ "$file" = 'deployment.md' ]; then
        continue
      fi

      if closed_authority_repair_allows_path "$file"; then
        continue
      fi

      if match_any_path "$file" "${global_forbidden[@]}"; then
        if closed_authority_repair_allows_path "$file"; then
          continue
        fi
        die "implementation span file $file is forbidden by implementation phase scope"
      fi

      ok=0
      forbidden_match=0
      for wi in "${active[@]}"; do
        wi_file="$PROJECT_ROOT/work-items/$wi.yaml"
        [ -f "$wi_file" ] || die "missing work item: $wi_file"
        mapfile -t wi_allowed < <(yaml_list "$wi_file" allowed_paths)
        mapfile -t wi_forbidden < <(yaml_list "$wi_file" forbidden_paths)
        [ "${#wi_forbidden[@]}" -gt 0 ] || die "$wi has empty forbidden_paths (must specify at least one pattern)"

        if ! match_any_path "$file" "${wi_allowed[@]}"; then
          continue
        fi

        if match_any_path "$file" "${wi_forbidden[@]}"; then
          forbidden_match=1
          continue
        fi

        ok=1
        break
      done

      if [ "$ok" -eq 1 ]; then
        continue
      fi

      if [ "$forbidden_match" -eq 1 ]; then
        if [ "$mode" = 'implementation-span' ]; then
          die "implementation span file $file is forbidden by matching active work item scope"
        fi
        die "changed file $file is forbidden by matching active work item scope"
      fi

      if [ "$mode" = 'implementation-span' ]; then
        die "implementation span file $file is outside allowed_paths of active work items"
      fi
      die "changed file $file is outside allowed_paths of active work items"
    done

    log '✓ scope gate passed'
    return
  fi

  local allowed=()
  local forbidden=()
  mapfile -t allowed < <(yaml_list "$WI_FILE" allowed_paths)
  mapfile -t forbidden < <(yaml_list "$WI_FILE" forbidden_paths)

  if [ "${#forbidden[@]}" -eq 0 ]; then
    if [ "$mode" = 'implementation-span' ]; then
      die 'active work items have empty forbidden_paths (must specify at least one pattern)'
    fi
    die "$FOCUS_WI has empty forbidden_paths (must specify at least one pattern)"
  fi

  local file pattern ok
  for file in "${changed[@]}"; do
    if closed_authority_repair_allows_path "$file"; then
      continue
    fi

    for pattern in "${forbidden[@]}"; do
      if match_path "$file" "$pattern"; then
        if [ "$mode" = 'implementation-span' ]; then
          die "implementation span file $file is forbidden by active work items"
        fi
        die "changed file $file is forbidden by $FOCUS_WI"
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
        die "changed file $file is outside allowed_paths of $FOCUS_WI"
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
  local git_file
  git_file="$(project_path_to_git_path "$file")"
  git -C "$GIT_ROOT" show "${revision}:${git_file}" 2>/dev/null | awk -F': ' -v key="$key" '$1 == key { print $2; exit }'
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
  check_dirty_worktree true

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
      local git_file
      git_file="$(project_path_to_git_path "$file")"
      head_status="$(git -C "$GIT_ROOT" show "HEAD:$git_file" 2>/dev/null | grep '^status:' | awk '{print $2}' || true)"
      current_status="$(git -C "$GIT_ROOT" show ":$git_file" 2>/dev/null | grep '^status:' | awk '{print $2}' || true)"
      base_status="$head_status"
    fi

    if [ "$base_status" = 'frozen' ]; then
      die "frozen contract cannot be modified: $file"
    fi

    if [ "$current_status" = 'frozen' ]; then
      validate_frozen_contract_file "$file"
      if [ "$mode" = 'staged' ] && ! git -C "$GIT_ROOT" cat-file -e "HEAD:$(project_path_to_git_path "$file")" 2>/dev/null; then
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
  validate_formal_id_definitions
  check_design_work_item_acceptance_alignment
  local reqs=()
  local accs=()
  local vos=()
  local wi_reqs=()
  local wis=()
  local wi_vos=()
  local wi_tcs=()
  local intake_refs=()
  local closure_refs=()
  local testing_accs=()
  local testing_tcs=()
  mapfile -t reqs < <(collect_spec_ids 'REQ')
  mapfile -t accs < <(collect_spec_ids 'ACC')
  mapfile -t vos < <(collect_spec_ids 'VO')
  mapfile -t wi_reqs < <(work_item_refs_requirements)
  mapfile -t wis < <(work_item_refs_acceptance)
  mapfile -t wi_vos < <(work_item_refs_verification)
  mapfile -t wi_tcs < <(work_item_refs_test_cases)
  mapfile -t intake_refs < <(input_intake_refs)
  mapfile -t closure_refs < <(requirements_source_refs)
  mapfile -t testing_accs < <(testing_target_acceptance_ids)
  mapfile -t testing_tcs < <(testing_target_test_case_ids)

	  local req
	  for req in "${reqs[@]}"; do
	    spec_requirement_has_acceptance "$req" "${accs[@]}" || die "trace gap: ${req} has no ACC"
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

    local tc
    for tc in "${testing_tcs[@]}"; do
      contains_exact_line "$tc" "${wi_tcs[@]}" || die "trace gap: ${tc} is not referenced by any work item test_case_refs"
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
    for tc in "${testing_tcs[@]}"; do
      grep -q -E "test_case_ref: ${tc}$|tc_id: ${tc}$" "$TESTING_FILE" || die "trace gap: ${tc} has no testing record"
    done
  fi

  log '✓ trace-consistency gate passed'
}

gate_testing_coverage() {
  validate_formal_id_definitions
  # NOTE: This gate checks testing record quality (test_scope, verification_type, etc.).
  # It is called by gate_verification() in Testing/Deployment phases.
  # In contrast, gate_trace_consistency() only checks that testing records exist,
  # without validating test_scope or other quality attributes.
  # This separation allows trace-consistency to verify traceability independently
  # of testing quality requirements.
  [ -f "$TESTING_FILE" ] || die 'missing testing.md'
  local test_cases=()
  mapfile -t test_cases < <(testing_target_test_case_ids)
  [ "${#test_cases[@]}" -gt 0 ] || die 'no TC-* entries found in testing.md'

  local phase
  phase="$(yaml_scalar "$META_FILE" phase)"

  local tc acc priority verification_type artifact_ref residual_risk reopen_required test_type test_scope required_stage required_scope
  for tc in "${test_cases[@]}"; do
    acc="$(test_case_scalar "$tc" acceptance_ref)"
    required_stage="$(test_case_scalar "$tc" required_stage)"

    if [ "$phase" = 'Testing' ] && [ "$required_stage" = 'deployment' ]; then
      continue
    fi

    required_scope='full-integration'
    if [ "$phase" = 'Deployment' ] && [ "$required_stage" = 'deployment' ]; then
      required_scope='deployment'
    fi

    has_test_case_scope_pass "$tc" "$required_scope" || die "testing.md does not have a ${required_scope} pass record for ${acc} / ${tc}"

    artifact_ref="$(testing_record_latest_scalar_for_tc "$tc" artifact_ref "$required_scope")"
    residual_risk="$(testing_record_latest_scalar_for_tc "$tc" residual_risk "$required_scope")"
    reopen_required="$(testing_record_latest_scalar_for_tc "$tc" reopen_required "$required_scope")"
    verification_type="$(testing_record_latest_scalar_for_tc "$tc" verification_type "$required_scope")"
    test_type="$(testing_record_latest_scalar_for_tc "$tc" test_type "$required_scope")"
    test_scope="$(testing_record_latest_scalar_for_tc "$tc" test_scope "$required_scope")"

    [ -n "$artifact_ref" ] || die "testing.md artifact_ref is missing for ${tc}"
    is_placeholder_token "$artifact_ref" && die "testing.md artifact_ref contains placeholder value for ${tc}"

    # R13: command_or_steps must have real content (not self-attesting)
    local command_or_steps
    command_or_steps="$(testing_record_latest_scalar_for_tc "$tc" command_or_steps "$required_scope")"
    [ -n "$command_or_steps" ] || die "testing.md command_or_steps is missing for ${tc}"
    is_placeholder_token "$command_or_steps" && die "testing.md command_or_steps contains placeholder value for ${tc} (R13: must record actual command or steps executed)"

    [ -n "$test_type" ] || die "testing.md test_type is missing for ${tc}"
    is_placeholder_token "$test_type" && die "testing.md test_type contains placeholder value for ${tc}"

    [ -n "$test_scope" ] || die "testing.md test_scope is missing for ${tc}"
    is_placeholder_token "$test_scope" && die "testing.md test_scope contains placeholder value for ${tc}"

    # R10/R11: completion_level must be present and match test_scope
    local completion_level
    completion_level="$(testing_record_latest_scalar_for_tc "$tc" completion_level "$required_scope")"
    [ -n "$completion_level" ] || die "testing.md completion_level is missing for ${tc}"
    case "$completion_level" in
      fixture_contract|in_memory_domain|api_connected|db_persistent|integrated_runtime|owner_verified) ;;
      *) die "testing.md completion_level must be a valid enum for ${tc} (got: ${completion_level})" ;;
    esac
    if [ "$required_scope" = 'full-integration' ]; then
      case "$completion_level" in
        integrated_runtime|owner_verified) ;;
        *) die "testing.md full-integration RUN completion_level must be >= integrated_runtime for ${tc} (got: ${completion_level})" ;;
      esac
    fi

    [ -n "$residual_risk" ] || die "testing.md residual_risk is missing for ${tc}"
    if [ "$(printf '%s' "$residual_risk" | tr '[:upper:]' '[:lower:]')" != 'none' ]; then
      is_placeholder_token "$residual_risk" && die "testing.md residual_risk contains placeholder value for ${tc}"
    fi

    # Check residual_risk=high is not allowed
    if [ "$(printf '%s' "$residual_risk" | tr '[:upper:]' '[:lower:]')" = 'high' ]; then
      die "testing.md residual_risk=high is not allowed for ${tc} (must be resolved before deployment)"
    fi

    [ -n "$reopen_required" ] || die "testing.md reopen_required is missing for ${tc}"
    case "$(printf '%s' "$reopen_required" | tr '[:upper:]' '[:lower:]')" in
      true|false) ;;
      *) die "testing.md reopen_required must be true or false for ${tc}" ;;
    esac
    [ "$(printf '%s' "$reopen_required" | tr '[:upper:]' '[:lower:]')" = 'false' ] || die "testing.md reopen_required must be false before phase transition for ${tc}"

    priority="$(spec_acceptance_priority "$acc")"
    case "$priority" in
      P0)
        if [ "$verification_type" != 'automated' ]; then
          is_placeholder_token "$(test_case_scalar "$tc" automation_exception_reason)" && die "P0 acceptance ${acc} / ${tc} must use automated verification or document automation_exception_reason"
        fi
        ;;
      P1|P2)
        case "$verification_type" in
          automated|manual|equivalent) ;;
          *) die "${priority} acceptance ${acc} / ${tc} must use automated/manual/equivalent verification" ;;
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

  local active_repair
  active_repair="$(active_authority_repair_id)"
  if [ "$active_repair" != 'null' ] && [ "${CODESPEC_AUTHORITY_REPAIR_CLOSING:-}" != '1' ]; then
    die "active authority repair must be closed before verification: $active_repair"
  fi

  # R12: dirty worktree check for Implementation/Testing/Deployment
  check_dirty_worktree true

  validate_formal_id_definitions
  [ -f "$TESTING_FILE" ] || die 'missing testing.md'

  if [ "$phase" = 'Implementation' ]; then
    local active=() wi wi_file tc acc priority verification_type required_stage verification_mode
    mapfile -t active < <(collect_active_work_items)
    [ "${#active[@]}" -gt 0 ] || die 'Implementation verification requires active_work_items'

    for wi in "${active[@]}"; do
      wi_file="$PROJECT_ROOT/work-items/$wi.yaml"
      [ -f "$wi_file" ] || die "missing work item: $wi_file"

      # R10: validate WI completion_level enum
      local wi_completion_level
      wi_completion_level="$(yaml_scalar "$wi_file" completion_level)"
      case "$wi_completion_level" in
        fixture_contract|in_memory_domain|api_connected|db_persistent|integrated_runtime|owner_verified) ;;
        *) die "$wi completion_level must be one of fixture_contract|in_memory_domain|api_connected|db_persistent|integrated_runtime|owner_verified (got: ${wi_completion_level:-missing})" ;;
      esac

      check_dependency_pass_records "$wi_file"

      while IFS= read -r tc; do
        [ -n "$tc" ] || continue
        acc="$(test_case_scalar "$tc" acceptance_ref)"
        verification_mode="$(test_case_scalar "$tc" verification_mode)"
        required_stage="$(test_case_scalar "$tc" required_stage)"

        if [ "$required_stage" = 'deployment' ] || [ "$verification_mode" != 'automated' ]; then
          continue
        fi

        has_test_case_scope_pass "$tc" branch-local || die "current work item test case ${tc} has no branch-local pass record"

        # Check P0 verification_type requirement in Implementation phase
        priority="$(spec_acceptance_priority "$acc")"
        verification_type="$(testing_record_latest_scalar_for_tc "$tc" verification_type branch-local)"
        if [ "$priority" = 'P0' ]; then
          if [ "$verification_type" != 'automated' ]; then
            is_placeholder_token "$(test_case_scalar "$tc" automation_exception_reason)" && die "P0 acceptance ${acc} / ${tc} must use automated verification or document automation_exception_reason"
          fi
        fi
      done < <(yaml_list "$wi_file" test_case_refs)
    done
  fi

  if [ "$phase" = 'Testing' ] || [ "$phase" = 'Deployment' ]; then
    gate_testing_coverage
  fi

  log '✓ verification gate passed'
}

gate_semantic_handoff() {
  gate_metadata_consistency

  local phase block highest wording_guard placeholders evidence_refs=()
  phase="$(yaml_scalar "$META_FILE" phase)"
  case "$phase" in
    Requirement|Design)
      log "✓ semantic-handoff gate passed (phase ${phase})"
      return
      ;;
    Implementation|Testing|Deployment) ;;
    *)
      die "semantic-handoff unsupported phase: $phase"
      ;;
  esac

  block="$(semantic_handoff_block_for_phase "$phase")"
  [ -n "$block" ] || die "semantic handoff missing for phase $phase"
  placeholders="$(block_contains_placeholder_text "$block")"
  [ -z "$placeholders" ] || die 'semantic handoff contains template placeholder text'

  highest="$(block_scalar_value highest_completion_level <<< "$block")"
  valid_completion_level "$highest" || die "semantic handoff highest_completion_level must be a valid completion level"

  wording_guard="$(block_scalar_value wording_guard <<< "$block")"
  [ -n "$wording_guard" ] || die 'semantic handoff missing wording_guard'
  is_placeholder_token "$wording_guard" && die 'semantic handoff wording_guard contains placeholder value'

  mapfile -t evidence_refs < <(printf '%s\n' "$block" | block_list_values evidence_refs | grep -vE '^(|null|none)$' || true)
  [ "${#evidence_refs[@]}" -gt 0 ] || die 'semantic handoff missing evidence_refs'

  if [ "$phase" = 'Implementation' ]; then
    local wi_refs=()
    mapfile -t wi_refs < <(printf '%s\n' "$block" | block_list_values work_item_refs | grep -vE '^(|null|none)$' || true)
    [ "${#wi_refs[@]}" -gt 0 ] || die 'semantic handoff missing work_item_refs'
  fi

  if semantic_handoff_requires_unfinished; then
    printf '%s\n' "$block" | semantic_handoff_has_list_entries unfinished_items || die 'semantic handoff must list unfinished_items'
    for field in source_ref current_completion_level target_completion_level blocker next_step; do
      grep -qE "^[[:space:]]*(-[[:space:]]*)?${field}:[[:space:]]*[^[:space:]]" <<< "$block" || die "semantic handoff unfinished_items missing ${field}"
    done
    if completion_level_less_than "$highest" integrated_runtime; then
      printf '%s\n' "$block" | semantic_handoff_has_list_entries fixture_or_fallback_paths || die 'semantic handoff must list fixture_or_fallback_paths below integrated_runtime'
      for field in surface real_api_verified visible_failure_state trace_retry_verified; do
        grep -qE "^[[:space:]]*(-[[:space:]]*)?${field}:[[:space:]]*[^[:space:]]" <<< "$block" || die "semantic handoff fixture_or_fallback_paths missing ${field}"
      done
    fi
  fi

  log '✓ semantic-handoff gate passed'
}

gate_deployment_plan_ready() {
  local deployment_file="$PROJECT_ROOT/deployment.md"
  [ -f "$deployment_file" ] || die 'missing deployment.md'

  grep -qE '^## (Deployment Plan|1\. 发布对象与环境)$' "$deployment_file" || die 'deployment.md missing deployment target section'
  grep -qE '^## (Pre-deployment Checklist|2\. 发布前条件)$' "$deployment_file" || die 'deployment.md missing pre-deployment section'
  grep -qE '^## (Rollback Plan|5\. 回滚与监控)$' "$deployment_file" || die 'deployment.md missing rollback section'
  grep -qE '^## (Monitoring|5\. 回滚与监控)$' "$deployment_file" || die 'deployment.md missing monitoring section'

  local release_mode target_env deployment_date release_artifact
  release_mode="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'release_mode')"
  [ -n "$release_mode" ] || release_mode='runtime'
  target_env="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'target_env')"
  deployment_date="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'deployment_date')"
  release_artifact="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'release_artifact')"

  case "$release_mode" in
    runtime|artifact|manual) ;;
    *) die 'deployment.md release_mode must be runtime, artifact, or manual' ;;
  esac
  is_placeholder_token "$target_env" && die 'deployment.md target_env is missing'
  printf '%s\n' "$deployment_date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || die 'deployment.md deployment_date must be YYYY-MM-DD'
  if [ "$release_mode" != 'runtime' ]; then
    is_placeholder_token "$release_artifact" && die 'deployment.md release_artifact is required for artifact/manual release_mode'
  fi

  if awk '
    /^## (Pre-deployment Checklist|2\. 发布前条件)$/ { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && /^[[:space:]]*-[[:space:]]*\[[[:space:]]\]/ { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$deployment_file"; then
    die 'deployment.md pre-deployment checklist must be complete before deploy'
  fi

  local placeholders
  placeholders="$(grep -nE 'YYYY-MM-DD|\[name\]|\[step\]|\[condition\]|\[metric\]|\[alert\]|\[deployment conclusion\]|\[yes/no\]|\[replace with[^]]*\]|\[STAGING/PRODUCTION\]|\[STAGING\]|\[PRODUCTION\]' "$deployment_file" || true)"
  [ -z "$placeholders" ] || die 'deployment.md contains placeholder value'

  log '✓ deployment-plan-ready gate passed'
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

  grep -qE '^## (Deployment Plan|1\. 发布对象与环境)$' "$deployment_file" || die 'deployment.md missing deployment target section'
  grep -qE '^## (Pre-deployment Checklist|2\. 发布前条件)$' "$deployment_file" || die 'deployment.md missing pre-deployment section'
  grep -qE '^## (Deployment Steps|3\. 执行证据)$' "$deployment_file" || die 'deployment.md missing execution section'
  grep -qE '^## (Execution Evidence|3\. 执行证据)$' "$deployment_file" || die 'deployment.md missing execution evidence section'
  grep -qE '^## (Verification Results|4\. 运行验证)$' "$deployment_file" || die 'deployment.md missing verification results section'
  grep -qE '^## (Acceptance Conclusion|6\. 人工验收与收口)$' "$deployment_file" || die 'deployment.md missing acceptance conclusion section'
  grep -qE '^## (Rollback Plan|5\. 回滚与监控)$' "$deployment_file" || die 'deployment.md missing rollback section'
  grep -qE '^## (Monitoring|5\. 回滚与监控)$' "$deployment_file" || die 'deployment.md missing monitoring section'

  local release_mode target_env deployment_date release_artifact execution_status execution_ref deployment_method deployed_at deployed_revision restart_required restart_reason runtime_observed_revision runtime_ready_evidence smoke_test runtime_ready manual_verification_ready
  release_mode="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'release_mode')"
  [ -n "$release_mode" ] || release_mode='runtime'
  target_env="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'target_env')"
  deployment_date="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'deployment_date')"
  release_artifact="$(markdown_section_scalar "$deployment_file" '## Deployment Plan' 'release_artifact')"
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

  case "$release_mode" in
    runtime|artifact|manual) ;;
    *) die 'deployment.md release_mode must be runtime, artifact, or manual' ;;
  esac
  is_placeholder_token "$target_env" && die 'deployment.md target_env is missing'
  printf '%s\n' "$deployment_date" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || die 'deployment.md deployment_date must be YYYY-MM-DD'
  [ "$execution_status" = 'pass' ] || die 'deployment.md execution evidence status must be pass'
  is_placeholder_token "$execution_ref" && die 'deployment.md execution_ref is missing'
  is_placeholder_token "$deployment_method" && die 'deployment.md deployment_method is missing'
  printf '%s\n' "$deployed_at" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' || die 'deployment.md deployed_at must be an RFC3339 timestamp'
  is_placeholder_token "$deployed_revision" && die 'deployment.md deployed_revision is missing'
  [ "$smoke_test" = 'pass' ] || die 'deployment.md smoke_test: pass must be in Verification Results section'
  [ "$manual_verification_ready" = 'pass' ] || die 'deployment.md manual_verification_ready: pass must be in Verification Results section'

  if [ "$release_mode" = 'runtime' ]; then
    case "$restart_required" in
      yes|no) ;;
      *) die 'deployment.md restart_required must be yes or no in Execution Evidence section' ;;
    esac
    is_placeholder_token "$restart_reason" && die 'deployment.md restart_reason is missing'
    [ "$runtime_ready" = 'pass' ] || die 'deployment.md runtime_ready: pass must be in Verification Results section'
    is_placeholder_token "$runtime_observed_revision" && die 'deployment.md runtime_observed_revision is missing'
    is_placeholder_token "$runtime_ready_evidence" && die 'deployment.md runtime_ready_evidence is required in Execution Evidence section'
    [ "$deployed_revision" = "$runtime_observed_revision" ] || die 'deployment.md runtime_observed_revision must match deployed_revision'

    if [ "$restart_required" = 'yes' ]; then
      printf '%s\n' "$runtime_ready_evidence" | grep -Eqi 'restart|restarted|rolled|reloaded|recreated' || die 'deployment.md runtime_ready_evidence must include restart evidence for restart-required deployment'
    else
      printf '%s\n' "$runtime_ready_evidence" | grep -Eqi 'not needed|hot reload|hot-reload|rolling update|rollout|replaced in place|no restart' || die 'deployment.md runtime_ready_evidence must explain why restart was not needed when restart_required: no'
    fi
  else
    is_placeholder_token "$release_artifact" && die 'deployment.md release_artifact is required for artifact/manual release_mode'
    case "$runtime_ready" in
      pass|not-applicable|n/a) ;;
      *) die 'deployment.md runtime_ready must be pass or not-applicable for artifact/manual release_mode' ;;
    esac
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
  # R12: dirty worktree check before promotion
  check_dirty_worktree true
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

gate_policy_consistency() {
  local file stale
  for file in "$FRAMEWORK_ROOT/templates/phase-review-policy.md" "$PROJECT_ROOT/phase-review-policy.md"; do
    [ -f "$file" ] || continue
    stale="$(grep -nE 'proposal-maturity|requirements-approval' "$file" 2>/dev/null || true)"
    [ -z "$stale" ] || die "${file#$PROJECT_ROOT/} references stale gate names"
  done

  grep -q 'spec-quality' "$FRAMEWORK_ROOT/templates/phase-review-policy.md" || die 'phase-review-policy template missing spec-quality gate'
  grep -q 'design-quality' "$FRAMEWORK_ROOT/templates/phase-review-policy.md" || die 'phase-review-policy template missing design-quality gate'
  grep -q 'test-plan-complete' "$FRAMEWORK_ROOT/templates/phase-review-policy.md" || die 'phase-review-policy template missing test-plan-complete gate'
  grep -q 'review-quality' "$FRAMEWORK_ROOT/templates/phase-review-policy.md" || die 'phase-review-policy template missing review-quality gate'
  grep -q 'active-work-items-complete' "$FRAMEWORK_ROOT/templates/phase-review-policy.md" || die 'phase-review-policy template missing active-work-items-complete gate'
  grep -q 'deployment-plan-ready' "$FRAMEWORK_ROOT/templates/phase-review-policy.md" || die 'phase-review-policy template missing deployment-plan-ready gate'

  log '✓ policy-consistency gate passed'
}

main() {
  [ -n "$GATE" ] || die 'usage: check-gate.sh <name>'
  require_context

  case "$GATE" in
    requirement-complete)
      gate_requirement_complete
      ;;
    spec-quality)
      gate_spec_quality
      ;;
    test-plan-complete)
      gate_test_plan_complete
      ;;
    review-verdict-present)
      gate_review_verdict_present
      ;;
    review-quality)
      gate_review_quality
      ;;
    design-structure-complete)
      gate_design_structure_complete
      ;;
    design-quality)
      gate_design_quality
      ;;
    design-readiness)
      gate_design_quality
      ;;
    implementation-ready)
      gate_design_quality
      gate_implementation_start
      gate_implementation_readiness_baseline
      ;;
    active-work-items-complete)
      gate_active_work_items_complete
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
    semantic-handoff)
      gate_semantic_handoff
      ;;
    testing-coverage)
      gate_testing_coverage
      ;;
    deployment-readiness)
      gate_deployment_readiness
      ;;
    deployment-plan-ready)
      gate_deployment_plan_ready
      ;;
    promotion)
      gate_metadata_consistency
      gate_deployment_readiness
      gate_promotion_criteria
      ;;
    promotion-criteria)
      gate_promotion_criteria
      ;;
    policy-consistency)
      gate_policy_consistency
      ;;
    proposal-maturity|requirements-approval)
      printf 'WARNING: %s is deprecated; use requirement-complete/spec-quality/test-plan-complete instead.\n' "$GATE" >&2
      gate_requirement_complete
      ;;
    *)
      die "unknown gate: $GATE"
      ;;
  esac
}

main "$@"
