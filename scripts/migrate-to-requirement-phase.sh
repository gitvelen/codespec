#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PROJECT_ROOT="${1:-.}"
shift || true

exec "$FRAMEWORK_ROOT/codespec" migrate-requirement-phase "$PROJECT_ROOT" "$@"
