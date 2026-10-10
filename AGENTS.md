# Agent 工作约定

## 唯一来源
只向 `natefox2017/qingfeng` 提交。Notion 是人类需求与设计入口；仓库只维护稳定需求规格及必要的技术契约；GitHub Issues 是开发执行与进度真值，PR 是实现、验证和回退记录。发现 remote 指向其他仓库时停止写操作；不能依赖重命名重定向。

本项目是新工程。禁止整仓拉回旧代码、图片、测试、历史提交或旧 ID/存档。用户后续明确修改要求优先；是否改文档遵守下述变更门槛，不因每个 PR 或 Bug 自动同步文档，也不在多个页面追加相互冲突的补丁。

## 需求文档与 GitHub 执行记录的边界
1. **需求文档（Notion 及仓库中的产品/玩法/地图/美术/UI 规格）**只记录经用户确认的需求、设计决策、稳定边界和验收目标。**需求没变就不改文档**；普通修 Bug、性能优化、重构、调整实现、CI、测试或状态变化不触发 Notion/Markdown 同步。
2. **GitHub Issues**记录全部具体开发任务、Bug/复现、排查结论、优化/技术债、阻塞、测试与验收结果、负责人及 checkbox 进度。优先更新已有对应 Issue；独立问题另开 Issue 并关联所属任务。不要在 Notion、README、审计/交接 Markdown 再维护一套执行日志或完成状态。
3. **GitHub PR**承载代码/素材/配置/测试等实际变更，关联 Issue，写清修改范围、验证命令与证据、未验项和回退。合入并经核验后更新 Issue 状态；仅修改代码/修复缺陷时，不要求同步任何需求文档。
4. **修改文档的门槛**：只有用户确认需求或设计/验收口径改变，或实际跨模块/外部接口、存档/字段契约的变化使既有规格失真，才在**对应的唯一权威文件**作最小修改，并由 Issue/PR 链接。意见未定时先登记 Issue 待确认，不把 Bug 处理过程写成新需求。
5. **协作约束例外**：`AGENTS.md` 仅在用户明确调整开发协作规则时修改；Notion/README 作为稳定入口，不随每次提交更新 SHA、进度快照、Bug 处理或测试日报。

## GitHub Projects v2 Kanban：唯一领取与状态回写（2026-10-10 用户确认）
**单一入口**：GitHub Projects v2 看板；[看板配置与迁移 Issue #120](https://github.com/natefox2017/qingfeng/issues/120) 保留实际 Project URL、字段和验证记录。Notion 是需求入口，父 Issue 是聚合导航；**不能从聊天建议、Notion、README、父 Issue checkbox、普通 Issue 列表、评论或旧 PR 直接开始/认领开发**。无权读取或更新真实 Board 时，记录为「未领取/Blocked」，立即停止该业务任务，不能凭标签或口头声明绕过。配置 #120 属于一次性引导例外。

1. **登记与拆分**：所有确认需求、Bug、代码、ART、DATA、UI、音频、QA、技术债、验收工作先检索 GitHub 现有 Issue/PR/分支和 asset_id/task_id。每个可独立领取/交付/验证的 TODO 都应对应一个**唯一的仓库 Issue + Kanban 卡片**，含 stable Task ID、父需求、具体 checkbox、验收、依赖、文件边界与资产来源。父 #1/#84 和各系统父 Issue 的大 checkbox 仅负责汇总；不能把同一父 Issue 的多项独立工作合领为一张卡，不能建立重复任务。已关闭重复 Issue 不再作为待领任务。
2. **看板 Status（仅六种，按项目统一规范）**：Backlog（待规划）→ Ready（依赖已满足且无人认领）→ In Progress（已从看板认领，处理中）→ In Review（PR/视觉/QA 待审核）→ Done（已完成且经验证），以及 Blocked（阻断）。**没有 Inbox、Claimed、Review、Cancelled 独立列**；废弃/重复通过 Issue state_reason=not_planned/duplicate 与主 Issue 关联处理。Status 必须是真实 GitHub Projects 字段，Issue open/closed 和评论不是 Status 的替代品。Project 尚未创建、卡片不存在或 API 不可确认时没有「默认可领」状态。
3. **领取动作（只从 Ready 看板卡发起）**：先刷新 Board 卡片、Issue/父项 checkbox、所有关联 PR/branch/asset，确认未完成且无现任 owner、无冲突写者，依赖已验收；将 Board Status 从 Ready 改为 In Progress，并给**原子 Issue 唯一 assignee**，写认领回执（领取账号、对话/运行实例唯一标识、UTC 时间、main SHA、分支/worktree、Task ID、精确 checkbox、文件集合、依赖及预计验证）。**回读同一 Project 卡（In Progress）、Issue assignee 和认领回执，三者一致才开工**。多 Agent 共用一个 GitHub 登录时，还必须比较不同对话/branch 的领取标识，不能只看 assignee。任何冲突、更新失败或二次认领先停工转 Blocked，请原 owner/协调方处理；不能覆盖前一个人的领取记录。
4. **冲突并发边界**：Projects Status/Issue assignee 的普通读写不是事务性锁；仅「我已经移动卡片」不足以在并发情况下保证独占。#120 的串行领取/原子锁和对账自动化未真正配置、并发验证前，不得宣称强互斥已经上线；多对话遇到同一项时一律先停工协调。公用场景、存档 schema、入口、manifest 与同一文件写入即使不同 Issue 也要执行文件锁定/错峰。
5. **进展与关闭是强制回写事务**：每完成一个子步骤，马上在该 Issue 勾选对应 checkbox，附 PR/commit SHA、测试命令和实际结果（含 NOT RUN）、截图/资产 source_hash、剩余阻塞；同步 Board Status。未验收、PR 未合并、素材为 proposed、测试没执行或部分 TODO 未勾时，保持 In Review/Blocked/In Progress，不能先 Done。**全部 Done 条件满足后**将卡片置 Done、Issue 关闭，再按证据更新父 Issue 对应聚合 checkbox；失败须回滚错误勾选、重新打开并还原看板状态，禁止留下「Issue 已完成但看板还在 Doing」或相反的不一致。
6. **转交/超时/重复**：放弃认领时先写未完成、已有产物/PR/branch、可继续步骤、风险和 owner 释放证明，再由看板退回 Ready；接手者必须重新完整领取。不可凭时间自动抢占。重复项用 canonical Issue 链接关闭为 duplicate，不标业务完成；需求取消用 not_planned。任何会话终止前核对自己的全部已领卡，没有已完成但未回写的 TODO。
7. **迁移与上线门**：旧父 Issue 的 checkbox 不因采用新 Kanban 而自动完成。分拆既有任务时保留旧证据，已在修的 #117 与 #88 先对照现任负责人、禁止另起工作。Project 和权限/自动化未验收期间，这一协议是强制操作规范，不是「看板已经部署」的证明；以 #120 的未勾项为阻断清单。

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
1. **先从真实 GitHub Projects v2 Kanban 的 Ready 卡片领取**，按上文协议验证唯一 owner、写 Issue 认领回执并回读；不可直接从 Issue 评论或父 checkbox 认领。
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
默认普通非 Draft PR；一项可回滚能力一个 PR。从最新 main 开分支，不 force push，不覆盖他人工作。PR 填真实入口、命令、结果、来源、未验项与回退。

仓库的 `repository-policy`、auto-merge 或其他 GitHub 自动化只是合并机制，**不是验收证据**。只有本任务要求的运行验收、人工审查和必要证据齐全后，才允许合并 PR 或关闭 Issue；如果某个自动化会在证据齐全前自动合并，应先阻止或调整该合并路径，而不是让自动化替代验收。

需要验证时在开发切片内按风险运行最小相关检查，发布/N11 再执行完整冷导入、原生试玩与导出验收。静态检查、类型检查、lint、脚本语法、只输出 PASS 的包装器，以及“CI skipped / 未运行”都不能冒充运行验收。失败测试不能删断言凑绿灯。
原生画面、headless、导出包、真实 Provider 各自记录证据；传送截图不证明通路，录制 FPS 不证明实时性能。涉及生产环境时优先使用隔离环境；未经用户明确授权不得部署生产、修改生产数据、执行不可逆迁移或扩大生产权限。

每个任务完成后必须准确汇报：实际修改的文件/能力、提交 SHA、执行过的测试命令与真实结果、未执行项、PR/Issue 当前状态、Review Thread/检查状态、剩余阻塞。代码合入并按验收复核后才勾任务；没有证据的项目写“未验收”，不得推断为通过。废止用 not_planned，迁仓用明确目标链接，不能当作功能完成。
