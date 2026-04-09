# codespec

`codespec` 是一个可嵌入到业务项目中的变更规范 runtime。  
它会在目标项目中生成 `.codespec` 运行时、`change/<container>` dossier、以及生命周期门禁（gate + hooks）。

## 前置条件

- 目标项目目录已存在
- 已安装 `git`、`bash`、`yq`
- 建议目标项目已初始化 Git 仓库

## 安装到具体项目

```bash
FRAMEWORK_ROOT="/home/admin/.codespec"
PROJECT_ROOT="/你的/项目绝对路径"

bash "$FRAMEWORK_ROOT/scripts/install.sh" "$PROJECT_ROOT" main baseline null
```

等价命令（CLI 入口）：

```bash
"/home/admin/.codespec/codespec" install "$PROJECT_ROOT" main baseline null
```

参数说明：

- `main`：容器名（container）
- `baseline`：`change_id`
- `null`：`base_version`

安装后会初始化：

- `PROJECT_ROOT/.codespec/**`
- `PROJECT_ROOT/change/main/**`
- `PROJECT_ROOT/versions/`
- `PROJECT_ROOT/lessons_learned.md`（若不存在）
- `PROJECT_ROOT/CLAUDE.md`（若不存在）
- 如果 `PROJECT_ROOT` 是 Git 仓库：会自动安装 `pre-commit` / `pre-push` hooks
- 如果 `PROJECT_ROOT` 还不是 Git 仓库：会跳过 hooks 安装并给出提示

## 手动补装/重装 Git hooks

当目标项目在安装时还不是 Git 仓库，或你修改了 `core.hooksPath` 需要重装 hooks 时，执行：

```bash
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" install-hooks
```

## 安装后快速自检

```bash
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" CODESPEC_CONTAINER=main "$PROJECT_ROOT/.codespec/codespec" status
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" CODESPEC_CONTAINER=main "$PROJECT_ROOT/.codespec/codespec" readset
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" CODESPEC_CONTAINER=main "$PROJECT_ROOT/.codespec/codespec" check-gate proposal-maturity
```

## 常用生命周期命令

```bash
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-requirements main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-design main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" add-work-item WI-001 main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-implementation WI-001 main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-testing main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-deployment main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" complete-change main
```

## 框架回归验证（可选）

```bash
bash /home/admin/.codespec/scripts/smoke.sh
```
