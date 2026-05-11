#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck \
    "$FRAMEWORK_ROOT/codespec" \
    "$FRAMEWORK_ROOT"/scripts/*.sh \
    "$FRAMEWORK_ROOT"/scripts/lib/*.sh \
    "$FRAMEWORK_ROOT"/hooks/pre-commit \
    "$FRAMEWORK_ROOT"/hooks/pre-push \
    "$FRAMEWORK_ROOT"/templates/codespec-deploy
else
  bash -n \
    "$FRAMEWORK_ROOT/codespec" \
    "$FRAMEWORK_ROOT"/scripts/*.sh \
    "$FRAMEWORK_ROOT"/scripts/lib/*.sh \
    "$FRAMEWORK_ROOT"/hooks/pre-commit \
    "$FRAMEWORK_ROOT"/hooks/pre-push \
    "$FRAMEWORK_ROOT"/templates/codespec-deploy
fi

printf 'lint passed\n'
