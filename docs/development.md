# 开发流程与 Agent 协作

**唯一任务入口：** [晴风谷 Development](https://linear.app/gengyun/project/晴风谷-development-747beb5958f6)，DEV Team 的 Linear Issue / Board 管全部任务、Todo、Bug、依赖、QA/验证与领取；旧 GitHub #1/#84/#120 仅保留历史溯源，GitHub PR/Commit/CI 管真实代码交付。恢复历史任务及当前可读性核验由 [DEV-110](https://linear.app/gengyun/issue/DEV-110) 记录；Notion/Markdown 只维护长期规格。

**默认状态**：Backlog（未规划）→ Todo（验收/依赖充分且无活跃 owner 的可领取候选）→ In Progress（认领开发）→ In Review（PR/QA）→ Done（真实验收通过）；Canceled/Duplicate 保留。DEV Team 不新增 Ready/Blocked。阻断用 `QFG-Blocked` 标签、blockedBy 和明确恢复条件记录，受阻时仍不可从 Todo 领取。详细规则见 [AGENTS.md](../AGENTS.md)。

## 从成熟做法到本项目
[参考](references.md)中的图块编辑/共享场景、游戏输入与慢请求分离，转成三个规则：布局先在引擎确定；素材按可复用组件交付；玩家可操作的纵向切片短周期合入。AI Town是技术参考，不把它说成商业农场成品。
先一屏比例/工具动作样板，先种植—背包—休息—存档闭环，最后扩大村庄与居民内容。不要重建整个游戏后才第一次试走。

## 稳定模块所有权与技术依赖

项目的长期文件所有权和集成边界（**不是待领取任务清单**）：
- CORE：公共 Schema、唯一时钟及存档持有者先冻结合同；下游模块通过公开命令/事件读写，不复制状态和另一套保存模型。
- WORLD：Godot 入口、场景、地形、碰撞、门与实体到达锚点作为单一空间真值。地图坐标、共享 `*.tscn` 与 UI/存档跨域变更由当前持有人串行处理。
- ART：先取得像素标尺/风格样板并核对合法来源，再逐组提供图块、房屋、作物、人犬动作、ID/hash 与脚锚；ART 不顺手修改玩法。地图位置调整不重新生图。
- GAMEPLAY：农耕、物品、经济、居民、任务等系统只在各自模块内修改；需要 CORE/WORLD 共享契约时先定义依赖、避免多个 AI 同时修改同一接口/文件。
- UI：只调用公开命令，并显示领域真实状态；正式皮肤、图标、字体素材按具体依赖解锁，不伪造游戏画面验收。
- QA：真实 Godot 原生运行、回归、导出和人工签收分别记录，不能把 CI green/包装器输出当作视觉或功能验收。

旧 `docs/tasks.json` **目前仍由 `tools/check_scaffold.py` 作为历史脚手架检查输入读取**，保留以免本次协作规范修改破坏已有检查；它不是有效任务源、领取/状态真值，也不能因此复制或执行历史任务。现行范围、依赖、TODO、负责人和验收只以**最新 Linear Issue** 为准；可领取状态只在 [Linear Board](https://linear.app/gengyun/project/晴风谷-development-747beb5958f6)。GitHub PR/文件/提交用作可核验实现证据。

## 每个小步骤
**Linear Todo Issue（真实无阻断、无竞争）→ 唯一 assignee、移 In Progress 并立即回读 → Linear Issue 记录 SHA/分支/文件/依赖** → 阅读官方合同与已有代码 → 最小失败测试 → 实现并同步 Linear Checkbox → 正常/失败/取消/保存验证 → 真实 PR 关联 DEV-n ID → In Review → 代码合并且必要验收通过 → Done。
依赖最终图的场景接入等待对应图，领域命令和物理夹具可独立做。pending生成期间处理无冲突的代码/数据，不忙轮询也不重复下单。

## PR规则
分支 feat/fix/refactor/docs/art/test/chore 加语义任务名。PR默认非Draft，一项可验证能力；大Issue通过多个短PR完成。禁止force push、覆盖用户未提交工作或未经检查合并无关PR。
PR用 [模板](../.github/PULL_REQUEST_TEMPLATE.md)，注明实际来源、运行入口、测试证据、保存语义、未验项。预算授权、视觉接受、功能完成三个结论分别写，不互相替代。
main实际规则仍要求 `repository-policy` context，但该 job 现在只负责开启 GitHub 原生 auto-merge 并立即结束，不执行 Scaffold、Godot 冷导入或游戏回归。PR 自动合并只代表集成流程完成，不代表功能验收；高风险切片按需本地/专项验证，完整冷导入、原生试玩和导出集中到 N11 发布验收。

## 当前检查与阶段
```sh
python3 tools/check_scaffold.py
python3 -m unittest discover -s tools/tests -v
```
上面的命令仍可按需本地执行；`python3 tools/runtime.py test` 保留为专项/发布回归工具，但不再作为每个 PR 的 GitHub Actions 门。scaffold没有可启动工程；preproduction有新素材但未接正式运行；foundation须有固定引擎版本、project.godot和正式main_scene；playable必须N11完成完整原生与导出验收。
阶段由 project.json 唯一声明；阶段进展、测试数字、Bug、阻断原因、临时交接和下一步动作写入对应 Linear Issue，实际代码/CI 证据放 GitHub PR，不例行同步 README/Notion。不能把工具测试数字当真实游戏回归。

## 执行入口

[Linear 晴风谷项目](https://linear.app/gengyun/project/晴风谷-development-747beb5958f6) 是唯一任务、领取和验收入口；关联 GitHub PR 时使用**当前真实 DEV-<序号>** Issue ID，不能沿用失联旧团队的 GEN-/QING- 任务编号。旧 GitHub #1/#84 的 Checklist 与 `docs/tasks.json` 仅作历史/脚手架兼容，不再用于新 TODO 或完成声明；如历史 Linear Issue 缺失，先按 [DEV-110](https://linear.app/gengyun/issue/DEV-110) 恢复，不重复创建。
