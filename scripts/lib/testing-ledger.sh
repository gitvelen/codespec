#!/usr/bin/env bash

codespec_testing_structured_ledger_yaml() {
  local file="$1"
  [ -f "$file" ] || return 0
  awk '
    /<!-- CODESPEC:TESTING:LEDGER -->/ {
      seen = 1
      next
    }
    seen && /^```ya?ml[[:space:]]*$/ {
      in_fence = 1
      next
    }
    in_fence && /^```[[:space:]]*$/ {
      exit
    }
    in_fence {
      print
    }
  ' "$file"
}

codespec_testing_has_structured_ledger() {
  local file="$1"
  codespec_testing_structured_ledger_yaml "$file" | grep -qE '^[[:space:]]*(schema_version|test_cases|runs|handoffs):'
}

codespec_testing_ledger_to_legacy_text() {
  command -v python3 >/dev/null 2>&1 || {
    printf 'ERROR: python3 is required for structured testing ledger parsing\n' >&2
    return 1
  }
  yq eval -o=json '.' - | python3 -c '
import json
import sys

data = json.load(sys.stdin) or {}

def value_text(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        return "[" + ", ".join(value_text(item) for item in value) + "]"
    return str(value)

def records(value, id_key):
    if isinstance(value, dict):
        for ident, body in value.items():
            if not isinstance(body, dict):
                body = {"value": body}
            yield str(ident), body
    elif isinstance(value, list):
        for body in value:
            if not isinstance(body, dict):
                continue
            ident = body.get(id_key, "")
            yield str(ident), body

def emit_scalar(key, value, indent="  "):
    print(f"{indent}{key}: {value_text(value)}")

def emit_record(record_key, ident, body, ordered_keys):
    if not ident:
        ident = str(body.get(record_key, ""))
    if not ident:
        return
    print(f"- {record_key}: {ident}")
    emitted = {record_key}
    for key in ordered_keys:
        if key in body and key != record_key:
            emit_scalar(key, body[key])
            emitted.add(key)
    for key, value in body.items():
        if key not in emitted:
            emit_scalar(key, value)

def emit_nested_list(key, value, ordered_keys):
    if value in (None, "", "none") or value == []:
        print(f"  {key}: none")
        return
    if not isinstance(value, list):
        emit_scalar(key, value)
        return
    print(f"  {key}:")
    for item in value:
        if not isinstance(item, dict):
            print(f"    - {value_text(item)}")
            continue
        first = True
        emitted = set()
        for item_key in ordered_keys:
            if item_key not in item:
                continue
            prefix = "    - " if first else "      "
            print(f"{prefix}{item_key}: {value_text(item[item_key])}")
            emitted.add(item_key)
            first = False
        for item_key, item_value in item.items():
            if item_key in emitted:
                continue
            prefix = "    - " if first else "      "
            print(f"{prefix}{item_key}: {value_text(item_value)}")
            first = False

case_keys = [
    "requirement_refs", "acceptance_ref", "verification_ref", "test_type",
    "verification_mode", "required_stage", "required_completion_level",
    "scenario", "given", "when", "then", "evidence_expectation",
    "automation_exception_reason", "manual_steps", "status",
]
run_keys = [
    "test_case_ref", "acceptance_ref", "slice_ref", "test_type", "test_scope",
    "verification_type", "completion_level", "command_or_steps", "artifact_ref",
    "result", "tested_at", "tested_by", "residual_risk", "reopen_required",
]
handoff_scalar_keys = [
    "phase", "slice_refs", "highest_completion_level", "current_completion_level",
    "evidence_refs",
]
unfinished_keys = [
    "source_ref", "priority", "current_completion_level", "target_completion_level",
    "blocker", "next_step",
]
fallback_keys = [
    "surface", "completion_level", "real_api_verified", "visible_failure_state",
    "trace_retry_verified",
]

for ident, body in records(data.get("test_cases", {}), "tc_id"):
    emit_record("tc_id", ident, body, case_keys)

for ident, body in records(data.get("runs", {}), "run_id"):
    emit_record("run_id", ident, body, run_keys)

for ident, body in records(data.get("handoffs", {}), "handoff_id"):
    if not ident:
        ident = str(body.get("handoff_id", ""))
    if not ident:
        continue
    print(f"- handoff_id: {ident}")
    emitted = {"handoff_id"}
    for key in handoff_scalar_keys:
        if key in body:
            emit_scalar(key, body[key])
            emitted.add(key)
    emit_nested_list("unfinished_items", body.get("unfinished_items"), unfinished_keys)
    emitted.add("unfinished_items")
    emit_nested_list("fixture_or_fallback_paths", body.get("fixture_or_fallback_paths"), fallback_keys)
    emitted.add("fixture_or_fallback_paths")
    if "wording_guard" in body:
        emit_scalar("wording_guard", body["wording_guard"])
        emitted.add("wording_guard")
    for key, value in body.items():
        if key not in emitted:
            emit_scalar(key, value)
'
}

codespec_testing_ledger_text() {
  local file="$1"
  [ -f "$file" ] || return 0
  if codespec_testing_has_structured_ledger "$file"; then
    codespec_testing_structured_ledger_yaml "$file" | codespec_testing_ledger_to_legacy_text
    return
  fi
  cat "$file"
}
