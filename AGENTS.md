# Agent 工作约定

## 唯一来源
只向 `natefox2017/qingfeng` 提交。Notion 是人类需求与设计入口；仓库只维护稳定规格及技术契约；GitHub Issues 是唯一任务/TODO与实施证据来源，Todoist Board 是唯一任务领取与状态入口，PR 是实现、验证和回退记录。发现 remote 指向其他仓库时停止写操作；不能依赖重命名重定向。

本项目是新工程。禁止整仓拉回旧代码、图片、测试、历史提交或旧 ID/存档。用户后续明确修改要求优先；是否改文档遵守下述变更门槛，不因每个 PR 或 Bug 自动同步文档，也不在多个页面追加相互冲突的补丁。

## 需求文档与 GitHub 执行记录的边界
1. **需求文档（Notion 及仓库中的产品/玩法/地图/美术/UI 规格）**只记录经用户确认的需求、设计决策、稳定边界和验收目标。**需求没变就不改文档**；普通修 Bug、性能优化、重构、调整实现、CI、测试或状态变化不触发 Notion/Markdown 同步。
2. **GitHub Issues**记录全部具体开发任务、Bug/复现、排查结论、优化/技术债、阻塞、测试与验收结果、负责人及 checkbox 进度；任务阶段状态由 Todoist Board 统一管理。优先更新已有对应 Issue；独立问题另开 Issue 并关联所属任务。不要在 Notion、README、审计/交接 Markdown 再维护一套执行日志或完成状态。
3. **GitHub PR**承载代码/素材/配置/测试等实际变更，关联 Issue/Todoist 卡，写清修改范围、验证命令与证据、未验项和回退。合入并经核验后更新 Issue 状态；仅修改代码/修复缺陷时，不要求同步任何需求文档。
4. **修改文档的门槛**：只有用户确认需求或设计/验收口径改变，或实际跨模块/外部接口、存档/字段契约的变化使既有规格失真，才在**对应的唯一权威文件**作最小修改，并由 Issue/PR 链接。意见未定时先登记 Issue 待确认，不把 Bug 处理过程写成新需求。
5. **协作约束例外**：`AGENTS.md` 仅在用户明确调整开发协作规则时修改；Notion/README 作为稳定入口，不随每次提交更新 SHA、进度快照、Bug 处理或测试日报。

## 四层权威和 Todoist 唯一领取入口（2026-10-10）

本仓库正式工作系统：
- **GitHub Issues：唯一任务/TODO/Bug/QA/技术债及执行证据来源。** 每个可独立交付的任务对应独立 Issue，父 Issue 的 checkbox 只索引真实子 Issue；实质验收、依赖和 TODO 完成状态均写回 Issue。
- **[Todoist 正式 Board](https://app.todoist.com/app/project/6hj76M7Ghj5pR3xm)：唯一任务排队、领取和阶段状态入口。** 对应仓库 `natefox2017/qingfeng`，每个独立 Issue 最多一张未「完成」的可见卡，卡片仅放仓库标识、Issue 编号/链接、PR 链接及必要的状态提示。**GitHub Projects 不是领取入口**；不得绕过 Todoist 通过聊天、Issue 评论/标签、GitHub assignee、分支或父 TODO 认领。
- **GitHub PR：独立分支代码/素材/配置交付、审核与合并入口**。原则上一个可独立交付的 Issue 配一个 PR；无仓库变更的纯研究/核验可只在 Issue 留可验证结果。
- **Notion 与 Markdown：只记录已确认的产品需求、设计、架构、字段/接口契约、编码/测试和 AI 协作规范。** 不在 README/Markdown/Notion 建平行任务、Bug、进度或交接状态表；需求或长期契约确实变化才最小修改其唯一权威文件。

### Todoist 六状态与 Done 语义
正式 Board 开启 Board 视图，**仅有且按顺序是 Backlog、Ready、In Progress、In Review、Blocked、Done 六个 Section**。Backlog 是未澄清/依赖未解决；Ready 是可领且无活跃持有人；In Progress 是领取成功正在处理；In Review 是 PR/成果待验证；Blocked 保存阻塞、恢复条件与既有持有人；Done 是必要验收/合并和 GitHub Issue 完整同步后状态。取消/重复仅通过 GitHub Issue 的 `not_planned`/`duplicate` 等真实关闭原因记录，不另设状态列。**Done 只移动 Section，不点击 Todoist 的「完成任务」操作；卡片 `checked=false` 必须保留可见以便去重与审计。**

### 独立 Issue 的零上下文执行合同
创建/更新 Issue 前先核对最新默认分支、开放/历史 Issue、PR、分支、代码、资产 ID 和规范，优先复用已存在任务；无任务才创建。每个 Issue 完整填写以下十项（无适用内容写明「不适用」，未经核实写「待核实」）：
1. **背景**：真实问题和业务/技术原因。
2. **目标**：唯一可独立交付的预期效果。
3. **当前状态**：已实现能力、当前仓库/commit/代码和遗留问题。
4. **修改范围**：现有模块、真实文件路径、页面、接口、数据库/Schema；标明禁止改动的共同文件。
5. **具体要求**：输入输出、业务流程、交互、边界和失败/取消处理，不使用历史聊天代词。
6. **技术约束**：遵守项目已有架构/规范、复用项目代码及合法开源方案、兼容和权限要求。
7. **依赖关系**：父子 Issue、前置任务、关联 PR、需求/技术合同，明确何时解锁。
8. **验收标准**：逐条真实可失败/可检查的 `- [ ]`；父 Issue 用 checkbox 引用必要子 Issue。
9. **测试要求**：执行命令、手动场景、预期与失败判定；确实未执行则记 `NOT RUN`。
10. **交付要求**：分支/PR 或研究证据、Commit、测试日志/截图/审查人、Issue checkbox 与 Todoist 状态回写。
**发布任务前零上下文自检**：一个完全不了解对话的 AI，能否只凭当前代码与 Issue 完整定位文件、判断依赖、实施、运行测试并客观验收？不满足保持 Backlog 并补全；不允许「按之前讨论」「和上次一样」等缺省要求。

### 拆分、依赖、并行和任务防重
每个低耦合、可独立验收的小交付建立一个子 Issue + 一张 Todoist 卡，不捆绑无关目标，也不过度拆分不可独立验证的细枝。父 Issue 用 checkbox 指向真实子 Issue，全部必要子项完成前不得关闭；明确前置 Issue 与共享 API、Schema、存档格式、素材 ID 的冻结/签收顺序。独立工作可使用不同对话和隔离 worktree 并行，**同一文件、地图、manifest、公共契约禁止竞争写入**；依赖 ART 的 CODE 仅等待其所需素材，不阻塞无关工作。已完成/重复 Issue 与已合并代码不得重新开发。

### 唯一领取流程（Ready → In Progress）
1. **实时读取正式 Todoist 看板**，只考虑 Ready 中未被领取的卡片，阅读其 GitHub Issue 的十项内容和 checkbox。
2. 检查最新 GitHub 默认分支、工作树、所有关联 PR/分支/审查与依赖，确认无持有人、无完成证据、无重叠文件或现存阻塞。关键事实不可核实时保持 Blocked/Backlog，不自认 Ready。
3. **再次读取同一 Todoist 卡片并确认仍为 Ready**；将该卡移动到 In Progress，**立即回读相同卡片**，核对 project/section、仍未被 Todoist `complete`、同一 Issue 没有第二张卡。
4. 再查竞争认领、活跃分支及文件权属；在对应 GitHub Issue 记录领取者/对话标识、UTC 时间、基线 SHA、现有或新分支、准确任务/文件/依赖/验证方式。**不强制使用 Todoist 原生 assignee**，其存在与否都不能替代 Section 领取。没有完整回读确认，禁止编辑业务文件。
5. **并发事实**：Todoist Section 移动与回读不是原子互斥锁；多个 AI 同时读取 Ready 可能竞争。检测到双领、回读不一致或同文件活跃 PR 时立即停工核对、在 Issue 记录并协调唯一执行者；不为了普通认领另造复杂分布式锁。
6. 中断或交接时记录实际交付、Commit/PR、剩余 TODO 和恢复条件，在 Todoist 移至 Blocked 或经原执行者确认释放回 Ready，回读核实；其他对话不得从 In Progress/In Review/Blocked/Done 直接抢占。

### 实时状态、验收和关闭
- **Backlog → Ready**：十项 Issue 资料齐全、唯一、边界明确、依赖解决且无人开发；迁移旧任务默认 Backlog，不自动把未验项标 Ready。
- **In Progress**：每完成一项验收 TODO 立即更新 GitHub Issue checkbox、对应 Commit/PR 与**实际**测试结果；失败或未验保持未勾，同时同步必要的 Todoist 状态。
- **In Review**：PR 已创建或无需 PR 的研究成果已提交；Todoist 移到 In Review，并回写 Issue 里的 PR 链接、验证范围/未验项。
- **Blocked**：Todoist 移到 Blocked，Issue 写原因、受影响文件/依赖、已做证据和恢复条件；未经核对不能由其他 AI 接手。
- **Done**：所有必要 TODO 勾完、PR 已合并、真实测试/人工签收通过、无关键阻塞、GitHub Issue/PR/Todoist 相互一致；将 **Todoist 卡片移动到 Done Section（不点击完成）**，回读卡片仍可见，然后关闭符合验收条件的 GitHub Issue 并更新父子链接；纯研究任务以 Issue 内独立验收证据替代无意义 PR。部分完成不能 Done。
- 若两个系统状态不一致，保留卡片和 Issue，在 Issue 记恢复路径，必要时 Blocked；不得虚报完成。**GitHub Issue 与 Todoist 最新实时结果**优先于聊天摘要和旧 handoff。

### 迁移引导例外
仅限首次建立/调整本仓库 Todoist Board 和修改协作规范，复用 [迁移 Issue #120](https://github.com/natefox2017/qingfeng/issues/120) 记录真实操作。先确认没有同类活跃 PR/领取，再执行、留痕和测试；正式 Board 验证后业务任务仍严格遵守 Ready 领取，**引导例外不得外溢到游戏开发**。

## 开工前的实时核实
处理任何项目任务，先以**当前工作树和 GitHub 实时状态**为准；旧交接、聊天摘要、历史 SHA 只可用于定位线索，不能直接作为现状依据。

至少完成以下预检后再写代码或文档：
1. 核实 `git remote -v`、`git status --short --branch`、当前 HEAD、未提交/未跟踪文件；拉取或 fetch 最新 `main`，确认本分支相对最新 `main` 的 ahead/behind 和实际 diff。不得覆盖或混入别人未提交的工作。
2. 核实最新 `main` SHA、开放 Issue、开放 PR、仓库 Discussions（若启用）、PR Conversation、Review Threads、检查/工作流状态，以及相关分支差异。继续已有 PR 时沿用它的 head 分支；新工作从最新 `main` 建专用短分支。
3. 读取最新 main 的 [文档导航](docs/README.md) 和[任务入口 #1](https://github.com/natefox2017/qingfeng/issues/1)，再进入对应 Issue/PR。若某项状态无法实时核实，明确记录“未核实”及原因，不得拿旧记录补成当前结论。

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
1. **先从正式 Todoist Board 的 Ready Section 领取**，按上文协议移动到 In Progress 并回读、确认无竞争、在 GitHub Issue 写领取回执；不可绕过 Board 以 Issue 评论/标签/父 checkbox 或 GitHub Projects 替代。
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
默认普通非 Draft PR；一项可回滚能力一个 PR。先确认 Todoist 领取，再从最新默认分支创建独立分支，不 force push，不覆盖他人工作。PR 填真实入口、Issue 与 Todoist 卡、命令、结果、来源、未验项与回退；PR 后同步 In Review，合并并验收后才同步 Done。

仓库的 `repository-policy`、auto-merge 或其他 GitHub 自动化只是合并机制，**不是验收证据**。只有本任务要求的运行验收、人工审查和必要证据齐全后，才允许合并 PR 或关闭 Issue；如果某个自动化会在证据齐全前自动合并，应先阻止或调整该合并路径，而不是让自动化替代验收。

需要验证时在开发切片内按风险运行最小相关检查，发布/N11 再执行完整冷导入、原生试玩与导出验收。静态检查、类型检查、lint、脚本语法、只输出 PASS 的包装器，以及“CI skipped / 未运行”都不能冒充运行验收。失败测试不能删断言凑绿灯。
原生画面、headless、导出包、真实 Provider 各自记录证据；传送截图不证明通路，录制 FPS 不证明实时性能。涉及生产环境时优先使用隔离环境；未经用户明确授权不得部署生产、修改生产数据、执行不可逆迁移或扩大生产权限。

每个任务完成后必须准确汇报：实际修改的文件/能力、提交 SHA、执行过的测试命令与真实结果、未执行项、PR/Issue 当前状态、Review Thread/检查状态、剩余阻塞。代码合入并按验收复核后才勾任务；没有证据的项目写“未验收”，不得推断为通过。废止用 not_planned，迁仓用明确目标链接，不能当作功能完成。
