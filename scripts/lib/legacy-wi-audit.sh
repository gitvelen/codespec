#!/usr/bin/env bash

legacy_wi_contract_scalar() {
  local file="$1"
  local key="$2"
  awk -F':[[:space:]]*' -v key="$key" '$1 == key { print $2; exit }' "$file"
}

legacy_wi_emit_record() {
  local severity="$1"
  local category="$2"
  local path="$3"
  local detail="$4"
  printf '%s\t%s\t%s\t%s\n' "$severity" "$category" "$path" "$detail"
}

legacy_wi_project_slug() {
  local project_root="$1"
  printf '%s' "$project_root" | sed 's#^/##; s#[^A-Za-z0-9._-]#_#g'
}

legacy_wi_blocking_contract_records() {
  local project_root="$1"
  local contract file rel status contract_id freeze_review_ref review_file

  [ -d "$project_root/contracts" ] || return 0

  while IFS= read -r contract; do
    [ -f "$contract" ] || continue
    rel="${contract#$project_root/}"

    while IFS= read -r file; do
      [ -n "$file" ] || continue
      legacy_wi_emit_record "blocking" "contract-legacy-wi" "${file#$project_root/}" "contract contains legacy WI/work_item_refs authority"
    done < <(
      grep -HInE 'work_item_refs|Work Item|WI-[0-9]{3}|work-items|work_item|focus_work_item|active_work_items|current WI|当前 WI|work-item\.yaml|execution_branch|feature_branch' "$contract" 2>/dev/null || true
    )

    status="$(legacy_wi_contract_scalar "$contract" status)"
    [ "$status" = "frozen" ] || continue

    contract_id="$(legacy_wi_contract_scalar "$contract" contract_id)"
    freeze_review_ref="$(legacy_wi_contract_scalar "$contract" freeze_review_ref)"
    if [ -z "$freeze_review_ref" ] || [ "$freeze_review_ref" = "null" ]; then
      legacy_wi_emit_record "blocking" "contract-freeze-review" "$rel" "frozen contract missing freeze_review_ref"
      continue
    fi

    review_file="$project_root/$freeze_review_ref"
    if [ ! -f "$review_file" ]; then
      legacy_wi_emit_record "blocking" "contract-freeze-review" "$rel" "frozen contract references missing review: $freeze_review_ref"
      continue
    fi

    if [ "$(yq eval '.contract_ref // "null"' "$review_file" 2>/dev/null)" != "$contract_id" ]; then
      legacy_wi_emit_record "blocking" "contract-freeze-review" "$rel" "freeze review does not reference contract_id $contract_id"
    fi
    if [ "$(yq eval '.action // "null"' "$review_file" 2>/dev/null)" != "freeze" ]; then
      legacy_wi_emit_record "blocking" "contract-freeze-review" "$rel" "freeze review action is not freeze"
    fi
    if [ "$(yq eval '.verdict // "null"' "$review_file" 2>/dev/null)" != "approved" ]; then
      legacy_wi_emit_record "blocking" "contract-freeze-review" "$rel" "freeze review verdict is not approved"
    fi
  done < <(find "$project_root/contracts" -maxdepth 1 -type f -name '*.md' -print 2>/dev/null | sort)
}

legacy_wi_blocking_records() {
  local project_root="$1"
  local meta="$project_root/meta.yaml"
  local field entry rel line

  if [ -d "$project_root/work-items" ]; then
    legacy_wi_emit_record "blocking" "work-items-dir" "work-items/" "current dossier still has work-items directory"
  fi

  if [ -f "$meta" ]; then
    for field in focus_work_item active_work_items execution_group execution_branch feature_branch; do
      if [ "$(yq eval "has(\"$field\")" "$meta" 2>/dev/null)" = "true" ]; then
        legacy_wi_emit_record "blocking" "meta-legacy-field" "meta.yaml" "meta.yaml still has $field"
      fi
    done
  fi

  for entry in "$project_root/AGENTS.md" "$project_root/CLAUDE.md" "$project_root/AI_INSTRUCTIONS.md"; do
    [ -f "$entry" ] || continue
    rel="${entry#$project_root/}"
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      legacy_wi_emit_record "blocking" "entry-legacy-wi" "$rel" "$line"
    done < <(
      grep -nE 'work_item/phase|当前 WI|current WI|Work Item 尚未完成|work-items/\*\.yaml|work-item\.yaml|execution branch|feature_branch|focus_work_item|active_work_items|add-work-item|set-active-work-items|set-execution-context' "$entry" 2>/dev/null || true
    )
  done

  legacy_wi_blocking_contract_records "$project_root"
}

legacy_wi_info_records() {
  local project_root="$1"
  local line rel category

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    rel="${line#$project_root/}"
    category=""
    case "$rel" in
      versions/*) category="historical-version" ;;
      authority-repairs/*) category="historical-authority-repair" ;;
      src/*|tests/*|frontend/*) category="project-implementation-history" ;;
      spec.md:*|testing.md:*|spec-appendices/*|design-appendices/*) category="authority-negative-or-background" ;;
      *) category="manual-review" ;;
    esac
    legacy_wi_emit_record "info" "$category" "$rel" "legacy WI reference kept outside framework authority"
  done < <(
    grep -RInE 'work_item_refs|Work Item|WI-[0-9]{3}|work-items|work_item|focus_work_item|active_work_items|current WI|当前 WI|work-item\.yaml|execution_branch|feature_branch' \
      --exclude=AGENTS.md \
      --exclude=CLAUDE.md \
      --exclude=AI_INSTRUCTIONS.md \
      --exclude=meta.yaml \
      --exclude-dir=.git \
      --exclude-dir=.codespec \
      --exclude-dir=work-items \
      --exclude-dir='work-items.bak.*' \
      --exclude-dir=contracts \
      "$project_root" 2>/dev/null || true
  )
}

legacy_wi_audit_records() {
  local project_root="$1"
  local include_info="${2:-true}"
  legacy_wi_blocking_records "$project_root"
  if [ "$include_info" = "true" ]; then
    legacy_wi_info_records "$project_root"
  fi
}

legacy_wi_records_to_json() {
  python3 -c '
import json
import sys

records = []
for raw in sys.stdin:
    raw = raw.rstrip("\n")
    if not raw:
        continue
    parts = raw.split("\t", 3)
    while len(parts) < 4:
        parts.append("")
    records.append({
        "severity": parts[0],
        "category": parts[1],
        "path": parts[2],
        "detail": parts[3],
    })
print(json.dumps(records, ensure_ascii=False, indent=2))
'
}
