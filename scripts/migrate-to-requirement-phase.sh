#!/usr/bin/env bash
set -euo pipefail

# migrate-to-requirement-phase.sh
# 将已有项目从 Proposal/Requirements 阶段迁移到新的 Requirement 阶段

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-.}"

cd "$PROJECT_DIR"

echo "=== Codespec Phase Migration ==="
echo "Migrating project to Requirement phase..."
echo

# 检查 meta.yaml 是否存在
if [ ! -f "meta.yaml" ]; then
  echo "ERROR: meta.yaml not found in $PROJECT_DIR"
  exit 1
fi

# 读取当前阶段
current_phase=$(yq eval '.phase' meta.yaml)
echo "Current phase: $current_phase"

# 只迁移 Proposal 或 Requirements 阶段
if [ "$current_phase" != "Proposal" ] && [ "$current_phase" != "Requirements" ]; then
  echo "INFO: Project is in $current_phase phase, no migration needed"
  exit 0
fi

# 更新 meta.yaml 中的 phase
echo "Updating meta.yaml: $current_phase → Requirement"
yq eval '.phase = "Requirement"' -i meta.yaml

# 迁移审查文件
if [ -f "reviews/requirements-review.yaml" ]; then
  echo "Migrating reviews/requirements-review.yaml → reviews/design-review.yaml"

  # 更新审查文件中的 phase 字段
  if grep -q "phase: Proposal" reviews/requirements-review.yaml; then
    sed -i 's/phase: Proposal/phase: Requirement/g' reviews/requirements-review.yaml
  fi
  if grep -q "phase: Requirements" reviews/requirements-review.yaml; then
    sed -i 's/phase: Requirements/phase: Requirement/g' reviews/requirements-review.yaml
  fi

  # 重命名文件
  mv reviews/requirements-review.yaml reviews/design-review.yaml
fi

# 更新 spec.md 结构（如果需要）
if [ -f "spec.md" ]; then
  echo "Checking spec.md structure..."

  # 检查是否有旧的章节结构
  if grep -q "## Intent" spec.md; then
    echo "WARNING: spec.md contains old '## Intent' section"
    echo "Please manually merge Intent content into ## Scope section"
  fi

  if grep -q "## Open Decisions" spec.md; then
    echo "WARNING: spec.md contains '## Open Decisions' section"
    echo "Please manually resolve open decisions or remove this section"
  fi

  if grep -q "### Source Coverage" spec.md; then
    echo "WARNING: spec.md contains '### Source Coverage' section"
    echo "Please manually verify REQ source_ref traceability"
  fi
fi

echo
echo "✓ Migration completed"
echo
echo "Next steps:"
echo "1. Review meta.yaml (phase should be 'Requirement')"
echo "2. Review reviews/design-review.yaml (phase should be 'Requirement')"
echo "3. Manually update spec.md if needed:"
echo "   - Merge '## Intent' into '## Scope'"
echo "   - Resolve or remove '## Open Decisions'"
echo "   - Add 'source_ref' to each REQ-* item"
echo "4. Continue with: codespec start-design"
