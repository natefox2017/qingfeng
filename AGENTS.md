# Agent 工作约定

## 唯一仓库与四层职责

**唯一代码仓库：** `natefox2017/qingfeng`，以 GitHub 实时默认分支和可见性为准；本仓库是独立新工程，不迁入旧代码、图片、存档、Git 历史或旧 ID。远端指向其他仓库时停止写入。**可见性可能变化：2026-10-10 最新 `get_repo` 已读回 `private`，但此 AI 未执行该权限修改**。不得根据历史 Public/Private 记录推断当前访问范围；始终禁止提交密钥、私人玩家存档、无授权素材，并检查协作者及 CI 实际权限。

**唯一任务管理项目：** [晴风谷 Development](https://linear.app/gengyun/project/晴风谷-development-747beb5958f6)，Linear Team `DEV`。四层职责不可交叉：
1. **Linear Issues** 是当前唯一需求、独立 TODO、Bug、QA、技术债、研究、依赖、进度与验收证据真值。每个可独立交付任务有一个 Linear Issue，包含真实 Checkbox、父子依赖、验收和交付证据。
2. **Linear Board** 是唯一的任务领取、负责人、阶段状态和并行协调入口。**禁止**通过旧 GitHub Issues、GitHub Projects、Todoist、聊天记录、分支名或标签抢领业务工作。
3. **GitHub** 仅保留代码/合法素材/项目文件、分支、Commit、PR、审核、CI 与合并事实。一个独立代码交付原则上一条 Linear Issue + 一个 PR；纯研究/验收无仓库变更时，可在 Linear Issue 直接交付可核验结果，不创建无意义 PR。
4. **Notion/Markdown** 只承载确认的产品需求、游戏设计、架构、稳定 API/存档合同、编码/测试及 AI 协作规则。Bug、任务分配、临时 handoff、测试结果、开发进度不得同步成第二套 Markdown/Notion TODO。只有已批准需求或真实长期契约变化才改对应唯一文档。

**历史边界**：旧 GitHub #1/#84/#120 与其子 Issues 仅作只读溯源，不再新增/领取 GitHub Issue。历史任务曾迁入 Linear 旧团队，但如果原 Linear Issue、UUID 或父子关系当前不可读，必须先按 [DEV-110 恢复/去重门](https://linear.app/gengyun/issue/DEV-110) 调查团队恢复与原链接，**禁止重新导入、生成同名任务或虚称已完成**。旧 Todoist 晴风谷看板退出正式流程，归档需独立核验，其他项目不受影响。

## Linear DEV 默认状态与实际领取门

**完整保留 Linear DEV Team 的原生默认状态**：Backlog（未规划）、Todo（已审核且可领取）、In Progress（已领取/开发）、In Review（PR 或研究成果待审核）、Done（全部必要交付与验收通过），以及 Canceled、Duplicate（取消/重复）。**不要为晴风谷额外新建或重命名 Ready、Blocked**，也不要修改 DEV 团队其他项目的状态。Board 可按 Status 分组；仅使用 `Todo → In Progress` 领取。

**可领取门不是只看 Todo 标签**：任务必须具备十项零上下文执行描述、验收 Checkbox、依赖完成、当前无 assignee / 重叠 PR / 其他 AI 领取证据，且没有任何阻断。受阻任务按事实保留 Backlog、Todo 或原来的 In Progress/In Review，使用 `blockedBy`、`QFG-Blocked` 标签以及 Issue 内原因、保留 owner 与恢复条件；**没有独立 Blocked 状态**，也绝不将受阻任务标 Done。已领取的任务不得因为受阻自动释放给其他 AI。

**历史数据保护**：若旧团队/迁移期业务 Issue 不可读，优先按 [DEV-110](https://linear.app/gengyun/issue/DEV-110) 恢复并核验原 UUID、历史附件/Checklist/父子关系与 PR，不通过重新创建相同功能的 Issue 绕过遗留问题。Linear 状态读写不提供原子互斥；多 AI 并发仍需双重回读、冲突立即停工。

## Linear Issue 的零上下文可执行合同

新建/迁移任务必须先查本 Linear 项目与 GitHub 当前代码/分支/PR、历史 Issue/资产 ID，防重复；确实可独立交付和客观验收才建立子 Issue，父 Issue 使用 Checkbox/父子关系索引必要子 Issue，不在 Markdown 维护额外任务清单。每个 Issue 独立包含以下十项，若确实不适用写「不适用」，不确定写「待核实」：
1. **背景**：真实问题、业务原因与影响。
2. **目标**：一项可交付的能力或证据、预期效果。
3. **当前状态**：已实现代码及相关 commit、已存在能力/缺口。
4. **修改范围**：当前仓库的真实文件路径/页面/接口/Schema/数据结构、禁止修改内容。
5. **具体要求**：业务/交互流程、输入输出、异常、取消、边界和数据流。
6. **技术约束**：既有架构/测试、兼容性、授权/安全、优先复用成熟开源能力。
7. **依赖关系**：父/子 Linear Issue、前置依赖、关联 GitHub PR 和权威长期设计。
8. **验收标准**：精确、可以失败的 Markdown `- [ ]`，完成才勾。
9. **测试要求**：真实命令、复现方法、场景、预期/失败判据；没运行则记 `NOT RUN`。
10. **交付要求**：GitHub PR/Commit、测试日志/截图/审核与 Linear TODO/Status 同步；纯研究任务记录可验证成果。

**零上下文检查**：完全没有聊天历史的 AI，能否只凭当前代码和 Linear Issue 定位文件、确认已有实现、处理正常及失败场景、执行测试并客观判断 Done？不能则补充，不转 Todo。禁止「和上次一样」「参考此前讨论」等含糊说明。既有迁移 Issue 的旧正文只是历史快照，不因迁移就自动满足十项标准。

## 领取、依赖与并发保护

1. 每次开工先获取最新 Linear 项目 Board/Issue、GitHub 实际默认分支、关联 PR/分支/Review/CI、文件所有权、依赖、历史已验收产物。**只有处于 Todo、没有 assignee、没有 QFG-Blocked/blockedBy 或其它真实阻断、没有重叠 PR/竞争开发的原子任务可以领取**；Backlog/In Progress/In Review/Done/Canceled/Duplicate 不能直接领取。
2. **领取前再次读取 Issue 仍为 Todo**，然后设置唯一 Linear assignee（共用登录时另写会话/执行者唯一标识），移动至 In Progress，**立即回读**同一 Issue 的 status/assignee/领取回执，并复查是否有另一执行者和同文件活跃分支；确认唯一执行者后方可从最新默认分支开独立 worktree。
3. Linear 的普通状态/负责人读写**不是原子互斥锁**。双 AI 同时读 Todo 仍可能冲突；疑似双领立即停工，不 force push、不接管别人的分支，在 Linear Issue 写证据/当前唯一 owner/恢复条件，协调后才能恢复。除确有实际需求，不另造分布式锁服务。
4. 需求拆成低耦合可独立验收 Issue，按父子关系及 `blockedBy` 明确前置；共享 API、Schema、存档、地图和资产 ID 先冻结唯一契约，ART 和 CODE 可并行独立切片，但依赖的正式资源未交付前不得伪造美术验收或抢改共享文件。

## PR 生命周期、同步与验收

- **Backlog → Todo**：十项描述、可失败的验收标准、依赖与文件边界已核实，代码/PR/素材去重完毕；任务尚无 active assignee / Blocker。仅移 Todo 不代表自动允许开发。
- **Todo → In Progress**：在 Linear Board 设置唯一 assignee、记录执行标识/基线 SHA/准确文件边界，移动 In Progress 后立即回读；每完成一项 Todo 都需更新 Linear Checkbox，关联真实 Commit/PR，记录运行验证或 `NOT RUN`。
- **In Progress → In Review**：创建 GitHub PR 后关联当前 Linear Issue ID（例如分支 `dev-118-native-workflow`、PR 标题 `docs: ... (DEV-118)`、正文 `Refs DEV-118`），验证实际链接。**GitHub 集成事件自动化尚未独立核验时手工移动 In Review 并回读**；PR 合并不能无条件 Done。
- **PR 合并后仍可留 In Review 待验收**：仅当必要代码、PR 已合并、相关测试、人工审查和所有 Linear Checkbox 全部通过、阻塞清零，才标 Done；仓库当前 `repository-policy` / auto-merge 只是合并机制，不是游戏验证。不得设置无条件「PR 合并→Done」导致假验收。
- **阻断/中断（无 Blocked 状态）**：在 Linear Issue 记录原因、受影响文件、保留的 assignee / branch / PR、实际测试与恢复条件；按需使用 `QFG-Blocked` 标签和 `blockedBy`，保持原未完成状态，不自动改为 Todo 或分配其他 AI；冲突需协调唯一 owner。
- **同步不一致**：保留现有 Issue 和 PR/分支，记录准确状态与恢复方法；绝不能凭历史聊天或旧 GitHub Issue 把 Linear 任务标 Done。任务状态只以**当前 Linear 真值 + GitHub 代码/PR 事实**为准。

## 管理规则调整与数据恢复

本次 [DEV-118](https://linear.app/gengyun/issue/DEV-118) 仅用于修正长期管理流程，不能绕过默认 Todo 领取去做游戏功能开发。原 Linear 遗留任务恢复和父子/资产/PR 去重统一见 [DEV-110](https://linear.app/gengyun/issue/DEV-110)，GitHub PR 自动化见 [DEV-108](https://linear.app/gengyun/issue/DEV-108)；**管理规范 PR 与业务验收是不同交付**。旧 GitHub Issues/旧 Todoist 不重新启用为任务源。

## 开工前的实时核实
处理任何项目任务，先以**当前工作树和 GitHub 实时状态**为准；旧交接、聊天摘要、历史 SHA 只可用于定位线索，不能直接作为现状依据。

至少完成以下预检后再写代码或文档：
1. 核实 `git remote -v`、`git status --short --branch`、当前 HEAD、未提交/未跟踪文件；拉取或 fetch 最新 `main`，确认本分支相对最新 `main` 的 ahead/behind 和实际 diff。不得覆盖或混入别人未提交的工作。
2. 核实最新默认分支 SHA、Linear 项目所有相关 Issue/状态/负责人及父子阻断、GitHub 开放 PR、Review Threads、CI 和现有开发分支差异。继续已有 PR 时沿用其 head；新工作从已确认最新默认分支建专用短分支。
3. 读取最新 [文档导航](docs/README.md) 和 [Linear 项目 Board](https://linear.app/gengyun/project/晴风谷-development-747beb5958f6)、当前权威 Linear Issue、关联 GitHub PR；旧 [GitHub #1](https://github.com/natefox2017/qingfeng/issues/1) 仅用于历史交叉核对。任何状态无法实时核实，记录未核实/Blocker，不拿聊天摘要补成当前结论。

## 任务拆分、并行与工作树
1. 单一且不可拆分的任务直接处理，不为了形式强行并行。
2. 工作包含多个可独立推进的 Issue、PR 或模块时，拆成多个**独立 Codex 任务对话**并行处理；使用子对话，不使用子 Agent。每个任务对话必须写清：范围、交付物、依赖、文件边界、验收标准、验证要求。
3. 每个并行任务使用隔离的 git worktree。继续已有 PR 时 worktree 检出该 PR 的现有分支；新任务从核实后的最新 `main` 建专用分支和 worktree。不要让两个任务同时写同一核心文件。
4. 保留一个协调对话负责分配任务、冻结依赖、跟踪 PR/Issue、汇总进度与阻塞；协调对话不得重复实现已分配给其他任务的代码。

## 共享契约与依赖顺序
1. 并行前先冻结共享 API、数据库/存档 Schema、公共字段、命令合同、跨模块事件、入口协议及其他跨任务契约，并记录版本/所有者/消费者。
2. 未冻结的共享依赖必须先串行处理；依赖任务不得各自定义一套接口再事后合并。同一地图、公共 schema、项目入口、CI 和其他共享核心文件由当前持有人串行修改。
3. 无关 ART/代码可并行，依赖图的正式接入等待对应资产；物理测试可用明确夹具，夹具不是最终画面。不要复制第二套库存、时钟或状态中心。

## 开始一个任务
1. **只能从 Linear Board 中经核实无阻断的 Todo Issue 领取**，设置唯一 assignee、In Progress、执行标识并回读；不能仅凭状态、聊天、标签或分支替代领取。旧 GitHub Issues、Todoist、GitHub Projects 不再管开发任务。
2. 阅读 [外部依据](docs/references.md)，核对适用的官方工具 schema/版本；选可复用原生能力，不以以前自己堆出的流程作依据。
3. 先确认任务依赖与文件所有权；发现未冻结共享契约、已有 PR 正在改同一核心文件或 Review Thread 未处理时，先协调并串行，不抢写。
4. 实现过程中只在本任务边界内修改；需要跨边界时先更新依赖和持有人，不把“顺手修”扩成隐式第二任务。

## PixelLab 与美术
按 [PixelLab 流水线](docs/pixellab_pipeline.md) 执行。只有已连接的官方工具可调用；MCP 名称不是 REST 地址。凭据放未跟踪的本地配置。默认不授权购买额度或高价模式；没有连接/预算，只完成准备并报告具体阻塞。
先统一标尺、参考与一条动作样板，再扩图集；提交后保存 job_id 并查询原任务，不盲目重复生成。先下载与归档，再离线验证与导入。禁止生成整张地图后靠切图反推碰撞；地图位置调整不出图。参考画面不是使用原版游戏资源的授权。

涉及 UI 时，正式实现前先确认对应页面/画面已有批准设计或明确可执行的视觉规格；没有批准设计时不得把工程占位、程序化图形或自定样式冒充视觉验收完成。

## 代码与字段
文件/目录、GDScript 函数与变量、自有 JSON 字段使用 snake_case；类/节点 PascalCase；常量 CONSTANT_CASE。字段类型、单位、缺省及所有权见 [合同](docs/data_contracts.md)。状态只通过拥有者公开命令改动。
命令幂等、取消、跨系统原子提交、坏档保护、迟到结果失效必须有测试。不能用每帧全量 snapshot 或网络请求驱动 HUD。
新代码以组合为主；不创建 Candidate/Trial/Current 继承链，不预造空 Manager 或多厂商抽象层。

## 提交、验证与完成
默认普通非 Draft PR；一项可回滚能力一个 PR。先确认 Linear Todo 领取和 In Progress 回读，再从最新默认分支创建独立分支；不 force push、不覆盖别人的工作。PR 必须关联 Linear Issue ID、当前 SHA、实际命令/验证、未验项和回退；PR 创建后同步 In Review，合并并完成验收后才能 Done。

仓库的 `repository-policy`、auto-merge 或其他 GitHub 自动化只是合并机制，**不是验收证据**。只有本任务要求的运行验收、人工审查和必要证据齐全后，才允许合并 PR 或关闭 Issue；如果某个自动化会在证据齐全前自动合并，应先阻止或调整该合并路径，而不是让自动化替代验收。

需要验证时在开发切片内按风险运行最小相关检查，发布/N11 再执行完整冷导入、原生试玩与导出验收。静态检查、类型检查、lint、脚本语法、只输出 PASS 的包装器，以及“CI skipped / 未运行”都不能冒充运行验收。失败测试不能删断言凑绿灯。
原生画面、headless、导出包、真实 Provider 各自记录证据；传送截图不证明通路，录制 FPS 不证明实时性能。涉及生产环境时优先使用隔离环境；未经用户明确授权不得部署生产、修改生产数据、执行不可逆迁移或扩大生产权限。

每个任务完成后必须准确汇报：实际修改文件/能力、Commit SHA、测试命令与真实结果、NOT RUN、关联 PR、Linear Issue 的 TODO/状态/负责人、Review Thread/CI 与剩余阻塞。合入且验收复核后才勾完成；未经证据核实保留未验收，取消/重复采用 Linear 真实状态及 canonical Issue 链接，不把 PR 合并当 Done。
