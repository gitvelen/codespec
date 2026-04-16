# codespec

`codespec` 是一个可嵌入到业务项目中的变更规范 runtime。  
它会在目标项目中生成 `.codespec` 运行时、`change/<container>` dossier、以及生命周期门禁（gate + hooks）。

## 框架真实模型

当前版本的 `codespec` 应按四层理解，而不是把所有约束都理解成“runtime 已完整自动化”：

1. **硬门禁（runtime / gate / hooks）**
   - 负责低歧义、可脚本化、误判成本低的约束。
   - 典型内容：阶段基础结构、最小追溯闭合、分支对齐、allowed/forbidden/owned path、冻结 contract 保护、testing / deployment 最低载体存在性。
2. **软审查（phase-review-policy / rfr）**
   - 负责语义充分性，而不是结构存在性。
   - 典型内容：acceptance 是否可判 PASS/FAIL、verification 是否真正可执行、design 是否仍能解释当前实现、是否出现隐性扩 scope。
3. **人工裁决（reviewer / owner）**
   - 负责跨切片、跨 container、共享边界和例外处理这类很难安全脚本化的问题。
   - 典型内容：shared owner / conflict policy、是否接受 residual risk、是否需要 reopen spec/design、是否允许偏离默认分支计划。
4. **执行便利（install / add-container / readset / agent entry）**
   - 负责提高可用性，不定义语义真值。
   - 典型内容：初始化 dossier、生成入口文件、安装 hooks、派生 container、给出最小 readset。

一句话说：**`check-gate pass` 只代表最低机器门槛通过，不等于语义审查通过，更不等于人工批准已经完成。**

### 当前已自动化 / 未自动化边界

| 类别 | 当前已自动化 | 当前未自动化 / 仍主要靠审查 |
| --- | --- | --- |
| Phase 基础结构 | Proposal / Requirements / Design / Implementation / Testing / Deployment 的最低章节和载体存在性 | 内容质量是否真的足以进入下一阶段 |
| Trace / 引用闭合 | `REQ -> ACC -> VO`、work item 与 spec/design 的最小追溯对齐 | acceptance 是否语义合理、verification 是否足够支撑验收 |
| 分支与执行线 | `execution_branch` 对齐、feature sync、`allowed_paths` / `forbidden_paths`、`branch_execution.owned_paths` 最低约束 | `shared_paths` / `shared_file_owner` / `conflict_policy` 的完整 enforcement |
| Contract 边界 | `contract-boundary`：contract refs 可解析、frozen contract 不可直接改、新 frozen contract 需显式 review flow | 更广义的 shared boundary 治理、谁拥有共享面、跨执行线集成策略 |
| Testing / Deployment | `testing.md` / `deployment.md` 的最低字段、pass record、artifact、residual risk、rollback/monitoring 最低检查；其中 `testing.md` 是当前 container / 当前执行线的验证证据账本，Implementation 后期即可开始累计 pass evidence，Testing 阶段再完成全量 approved acceptance 闭环 | 测试证据是否真的“足够有说服力”、deployment 审批是否构成正式组织批准 |
| Review / Approval | `phase-review-policy.md`、`rfr` 与阶段切换前对应 review verdict artifact 的存在性检查提供统一审查口径 | review 质量、组织审批状态机、显式 reviewer judgment / sign-off 是否成立 |

因此，使用这个框架时最稳妥的心智模型是：
- **runtime** 负责把明显越界、缺结构、缺最小证据的情况尽早拦下；
- **reviewer / rfr** 负责判断“虽然结构齐了，但语义上是否真的能推进”；
- **owner / 人工裁决** 负责处理共享边界、例外批准和跨执行线协调。

## 前置条件

- 目标项目目录已存在
- 已安装 `git`、`bash`、`yq`
- 建议目标项目已初始化 Git 仓库

## 首次安装到项目根目录

`install` / `scripts/install.sh` 永远是把 `codespec` runtime 安装到**业务项目根目录**。
命令本身可以在任意目录执行，但传入的 `PROJECT_ROOT` 必须是你要接入 `codespec` 的项目根目录，而不是 `change/`、`.codespec/` 或其他子目录。

典型场景：

- 新建项目第一次接入：先创建业务项目根目录，再把 `codespec` 安装到这个根目录
- 已有项目第一次接入：直接把 `codespec` 安装到现有仓库根目录
- 已经接入过 `codespec`，只是要新增一个变更：**不要重新执行 `install`**；应在同一个项目根目录里执行 `init-change` 或 `add-container`
- 如果约定**禁止使用 worktree**，但又需要多个 Git 分支并行推进：应先准备好 `.codespec` 和所需 `change/<container>` dossier，再通过多个独立 `git clone` 目录分别承载不同分支；不要把同一工作区里的不同子目录当成不同分支承载点

```bash
FRAMEWORK_ROOT="/home/admin/.codespec"
PROJECT_ROOT="/你的/项目绝对路径"

bash "$FRAMEWORK_ROOT/scripts/install.sh" "$PROJECT_ROOT" main baseline null
```

等价命令（CLI 入口）：

```bash
"/home/admin/.codespec/codespec" install "$PROJECT_ROOT" main baseline null
```

如果只是给一个已经安装过 `codespec` 的项目新增变更，不要重新执行 `install`。应根据目标选择下面两条路径之一：

### 路径 A：新建独立变更 container（从 Proposal 开始）

```bash
cd "$PROJECT_ROOT"

"$PROJECT_ROOT/.codespec/codespec" init-change add-auth add-auth v1.2.3
```

适用于：这是一个新的变更线，需要独立的 Proposal / Requirements / Design 生命周期。

### 路径 B：从共享 baseline / source container 派生执行 container

如果要从共享 baseline container 派生多个并行 container，可以这样做。下面的 `sanguoA` / `sanguoB` / `sanguoC` 只是示例，实际数量由 Design 阶段的并行分支计划决定：

```bash
cd "$PROJECT_ROOT"

"$PROJECT_ROOT/.codespec/codespec" add-container sanguoA main
"$PROJECT_ROOT/.codespec/codespec" add-container sanguoB main
"$PROJECT_ROOT/.codespec/codespec" add-container sanguoC main
```

`add-container` 会复制 `change/main/` 的 dossier 中与设计/执行边界相关的内容（如 `spec.md`、`design.md`、work-items、contracts 等），继承 `change_id` / `base_version`，并写入 execution metadata（默认 `execution_branch = group/<container>`）；它**不会自动创建 git branch**，也**不会创建独立 clone 目录**。按当前模型，`testing.md` 视为**当前 container / 当前执行线的独立验证证据账本**，因此 `add-container` **不会复制 source container 的 testing pass records**。如果后续要让不同 container 在不同 Git 分支上并行执行，而你们又约定禁止使用 worktree，那么应改用多个独立 clone 目录来承载这些分支。

`main baseline null` 是 3 个位置参数的默认值。下面示例仍显式写出它们，只是为了更直观。

参数说明：

- `main`：`container`，对应目录 `change/main/`
  作用：标识当前 baseline dossier / container 名称
  怎么填：首次安装推荐直接用 `main`，把它当作共享 baseline container 名
  后续怎么扩展：需要多个并行 container 时，不要重复执行 `install`；应先保留 `main` 作为 baseline，再用 `add-container` 派生 `sanguoA`、`sanguoB`、`sanguoC` 这类并行 container。这里的数量没有固定上限，实际派生多少个取决于 Design 阶段的 `branch_plan`。若这些 container 后续要分别落到不同 Git 分支上，则应再基于已准备好的仓库创建多个独立 clone 目录，各自 checkout 到对应 `execution_branch`
- `baseline`：`change_id`
  作用：记录这次变更的语义 ID，并派生默认 `feature_branch = feature/<change_id>`
  怎么填：有明确变更时，优先填真实 ID，如 `add-auth`、`upgrade-payment-sdk`
  什么时候可填 `baseline`：只是在项目里落一份初始 dossier / 基线 container，暂时没有具体变更时
- `null`：`base_version`
  作用：记录这次变更基于哪个稳定版本；当前 runtime 只写入 `change/<container>/meta.yaml`，不会参与硬 gate
  怎么填：没有已发布版本、首次从零开始、或这个字段暂时不适用时，填 `null`
  什么时候填具体值：已有稳定版本作为变更基线时，填 `v1.2.3`、`2026.04` 这类你们团队认可的版本号

一个更贴近日常使用的例子：

```bash
PROJECT_ROOT="/home/admin/sanguo"
FRAMEWORK_ROOT="/home/admin/.codespec"

"$FRAMEWORK_ROOT/codespec" install "$PROJECT_ROOT" main baseline null

cd "$PROJECT_ROOT"
"$PROJECT_ROOT/.codespec/codespec" add-container sanguoA main
"$PROJECT_ROOT/.codespec/codespec" add-container sanguoB main
"$PROJECT_ROOT/.codespec/codespec" add-container sanguoC main
```

这表示：

- 首次在 `/home/admin/sanguo` 安装 `.codespec/` 和 `change/main/`
- 保留 `main` 作为共享 baseline container
- 在同一个仓库副本里先从 `main` 派生 `sanguoA` / `sanguoB` / `sanguoC` dossier
- 如果这些 container 后续需要分别在不同 Git 分支上并行执行，则不要在这个仓库副本里来回切分支，而应从这个已准备好的仓库再 clone 出多个独立目录，各自 checkout 到对应 `execution_branch`

### 以 container 为中心的日常工作流

也支持先进入某个 container 目录再启动 Claude/Codex，例如：

```bash
cd /home/admin/sanguo/change/sanguoA
claude
```

这是正常用法。container 解析规则要分三种情况理解：

- 当前位于 `change/<container>/` 目录：runtime 会按当前路径解析 container。
- 当前位于项目根目录且项目里只有一个 container：runtime 可以自动解析。
- 当前位于项目根目录且项目里有多个 container：必须先设置 `CODESPEC_CONTAINER`，或先进入对应的 `change/<container>/`。

也就是说，你可以在项目根目录运行，但**只有单 container 项目才适合依赖自动解析**；多 container 项目里，根目录命令必须显式选定 container。

如果你的工作方式是把 `main` 作为共享设计 baseline container，再从它派生若干执行 container（例如 `sanguoA` / `sanguoB` / `sanguoC`），那么需要把下面两件事分开理解：

- `container` 是 dossier / 工作上下文划分，对应 `change/<container>/`
- Git `branch` 是**整个仓库工作区级别**的版本线划分，不是“某个目录单独切分支”

本项目的默认约定是：**禁止使用 worktree**。因此，如果若干执行 container 需要在不同 Git 分支上并行推进，正确做法不是在同一个仓库副本里把 `change/main/`、`change/sanguoA/`、`change/sanguoB/` 当成不同分支承载点，而是使用多个独立 clone 目录，每个 clone 各自 checkout 到该 container 的 `execution_branch`，并在该 clone 内进入对应的 `change/<container>` 上下文工作。

推荐拓扑如下：

```text
/home/admin/sanguo-baseline   # 准备 baseline 和派生 container；可停留在基线分支
/home/admin/sanguo-A          # 独立 clone，checkout 到 group/sanguoA，在 change/sanguoA 下工作
/home/admin/sanguo-B          # 独立 clone，checkout 到 group/sanguoB，在 change/sanguoB 下工作
/home/admin/sanguo-C          # 独立 clone，checkout 到 group/sanguoC，在 change/sanguoC 下工作
```

一个更符合该约束的推荐流程是：

1. 先在一个“准备仓库副本”里安装 `.codespec`，并在父 feature 分支上完成共享设计。
2. 在 Design 阶段明确并行分支计划：拆成几个执行 container / execution branch、每条分支跑哪些 WI、各自拥有的目录、共享文件 owner、禁止触碰范围、合并顺序和冲突处理规则。
3. 用 `add-container` 把需要的 `change/<container>` dossier 都准备好。
4. 确认每个 container 的 `feature_branch` 指向这个父 feature 分支，`execution_branch` 指向后续执行子分支（`add-container` 默认是 `group/<container>`）。
5. 把这些 dossier 变更提交到共享仓库，并在需要跨 clone 获取时推送到远端。
6. 再基于父 feature 分支创建多个独立 clone 目录，每个 clone checkout 到各自的 `execution_branch`。
7. 在每个 clone 中进入对应的 `change/<container>` 目录，作为该分支的工作上下文。
8. 各执行子分支完成验证后，分别合回父 feature 分支。

这样理解更准确：container 负责描述“你在做哪条变更线的 dossier”，clone + branch 负责描述“你当前在哪个独立仓库副本、哪条 Git 版本线里工作”。

### 父 feature 分支 + N 个独立 clone 执行

例如，你在 `/home/admin/sanguo-main` 的父 feature 分支上完成了共享设计，并希望拆成若干条执行线。下面只演示 `sanguoA` / `sanguoB` 两条，实际项目可以是任意 N 条，以 `design.md` 中的 `branch_plan` 为准：

```bash
cd /home/admin/sanguo-main
git switch feature/add-auth

"$PWD/.codespec/codespec" add-container sanguoA main
"$PWD/.codespec/codespec" add-container sanguoB main
# 如有更多执行线，继续按 branch_plan 追加 add-container。

# 如果 meta.yaml 里的 feature_branch 不是当前父 feature 分支，先显式校准。
yq eval '.feature_branch = "feature/add-auth"' -i change/main/meta.yaml change/sanguoA/meta.yaml change/sanguoB/meta.yaml

git add change/main change/sanguoA change/sanguoB
git commit -m "docs: prepare sanguo execution containers"
git push origin feature/add-auth
```

然后用多个独立 clone 承载执行子分支；每条执行线对应一个独立 clone：

```bash
git clone --branch feature/add-auth <REPO_URL> /home/admin/sanguoA
cd /home/admin/sanguoA
git switch -c group/sanguoA
cd change/sanguoA

git clone --branch feature/add-auth <REPO_URL> /home/admin/sanguoB
cd /home/admin/sanguoB
git switch -c group/sanguoB
cd change/sanguoB
# 如有更多执行线，继续为每条 execution_branch 准备一个独立 clone。
```

执行完成并验证通过后，把执行子分支合回父 feature 分支：

```bash
cd /home/admin/sanguo-main
git switch feature/add-auth
git pull --ff-only
git merge --no-ff group/sanguoA
git merge --no-ff group/sanguoB
# 如有更多执行子分支，按 design.md 中约定的 merge_order 继续合并。
```

如果执行子分支只存在于其他 clone，本地合并前需要先把它们推送出来，例如在 `/home/admin/sanguoA` 执行 `git push -u origin group/sanguoA`，再回到 `/home/admin/sanguo-main` 执行 `git fetch origin group/sanguoA:group/sanguoA` 后合并。

关键约束：`change/<container>/meta.yaml` 里的 `feature_branch` 必须是父 feature 分支，例如 `feature/add-auth`；`execution_branch` 必须是当前 clone checkout 的执行子分支，例如 `group/sanguoA`。`start-testing` 会检查当前 Git 分支是否等于 `execution_branch`，并检查执行子分支没有落后于 `feature_branch`。

并行执行计划最好在 `design.md` 的 `Work Item Execution Strategy` 中先写清楚，再同步到各 `work-items/*.yaml`：

- `container` / `execution_branch`：该分支由哪个 container 承载、checkout 到哪条执行分支
- `work_items`：该分支负责哪些 WI，哪些 WI 必须先完成
- `owned_paths`：该分支可以主导修改的目录或文件
- `shared_paths`：可能与其他分支共享的文件，例如路由表、配置、依赖声明、公共类型
- `shared_file_owner`：共享文件由谁先改、谁集成，避免多个 agent 各自生成重复实现
- `forbidden_paths`：该分支不得触碰的目录或文件
- `merge_order`：多个执行分支合回父 feature 分支的顺序
- `conflict_policy`：发现路径重叠、设计漂移、共享契约变化时，是停下回写 design，还是由指定 owner 集成

安装后会初始化：

- `PROJECT_ROOT/.codespec/**`
- `PROJECT_ROOT/change/main/**`
- `PROJECT_ROOT/versions/`
- `PROJECT_ROOT/lessons_learned.md`（若不存在）
- `PROJECT_ROOT/phase-review-policy.md`（若不存在）
- `PROJECT_ROOT/change/<container>/AGENTS.md`（container 执行入口）
- `PROJECT_ROOT/change/<container>/CLAUDE.md`（container 执行入口）
- 如果 `PROJECT_ROOT` 是 Git 仓库：会自动安装 `pre-commit` / `pre-push` hooks
- 如果 `PROJECT_ROOT` 还不是 Git 仓库：会跳过 hooks 安装并给出提示

补充说明：
- install 不会默认在项目根 materialize `AGENTS.md` / `CLAUDE.md`；当前真实执行入口在 `change/<container>/AGENTS.md` / `CLAUDE.md`
- `readset` / `readset --json` 会根据当前 dossier 状态实时生成；需要当前应读内容时，以它们的输出为准
- `readset` 给人看，`readset --json` 适合 Claude/Codex 或外层自动化消费
- `check-gate` 只检查阶段切换的最低硬门槛；是否允许推进，仍以 `phase-review-policy.md` / `rfr` 的审查结论为准
- 其中 `contract-boundary` gate 只负责 contract refs 可解析、冻结 contract 不被直接修改，以及新 frozen contract 走显式 review flow；它**不代表** runtime 已完整强制 shared boundary / owner / conflict policy 语义
- README 讲总览；`readset` 给当前阅读顺序；`phase-review-policy.md` 定义阶段切换规则；`change/<container>/AGENTS.md` / `CLAUDE.md` 是当前 dossier authority

## 手动补装/重装 Git hooks

当目标项目在安装时还不是 Git 仓库，或你修改了 `core.hooksPath` 需要重装 hooks 时，执行：

```bash
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" install-hooks
```

## 安装后快速自检

先确认 baseline container 可正常工作：

```bash
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" CODESPEC_CONTAINER=main "$PROJECT_ROOT/.codespec/codespec" status
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" CODESPEC_CONTAINER=main "$PROJECT_ROOT/.codespec/codespec" readset
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" CODESPEC_CONTAINER=main "$PROJECT_ROOT/.codespec/codespec" readset --json
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" CODESPEC_CONTAINER=main "$PROJECT_ROOT/.codespec/codespec" check-gate proposal-maturity
```

如果你已经派生了并行 container，也可以任选一个做同样检查，例如：

```bash
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" CODESPEC_CONTAINER=sanguoA "$PROJECT_ROOT/.codespec/codespec" status
```

如果你平时是直接进入 container 目录再启动 Claude/Codex，例如 `cd /home/admin/sanguo/change/sanguoA`，runtime 也能从当前路径推断 container；这时直接按当前上下文运行这些命令即可。

## 常用生命周期命令

```bash
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-requirements main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-design main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" add-work-item WI-001 main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-implementation WI-001 main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" set-active-work-items WI-001,WI-002 main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-testing main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" start-deployment main
CODESPEC_PROJECT_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/.codespec/codespec" complete-change main
```

## 框架回归验证（可选）

```bash
bash /home/admin/.codespec/scripts/smoke.sh
```
