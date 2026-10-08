# PR #117 修复交接（2026-10-09，优先于下方历史暂停记录）

用户现已要求继续处理 PR #117 问题。**当前修复代码已提交到原 PR 分支，但未在本地 Mac 上做 Godot 4.7.2 验证，不可标记通过或合并。**

已提交的修复：
- `game/app/chapter1_map_migration.gd`：仅识别 PR #117 之前主线的六个农田坐标指纹 (17–19,7–8)，恢复到当前地图权威 Marker；保留作物状态、钱、物、关系和事件；旧户外玩家重锚到当前场景安全 spawn，老村庄居民重锚到其新版 social marker；其他未知坐标布局**严格不自动迁移**，原签名存档只读不覆盖。
- `game/app/main.gd`：在正式 restore 前对已知旧布局执行非破坏性迁移，并再次校验 schema；存档不兼容时拒绝，不绕过 Domain 验证。
- `game/world/farm_first_screen.gd`、`game/world/village_first_screen.gd`：世界边界仅由 `TerrainGround` 的实际图块矩形决定；水、装饰、广场和动态 `PlotStates` 不再扩大相机和外墙。
- `game/tests/chapter1_map_save_migration_test.gd`：从真实 signed save 构造准确旧布局，检查读档及新存档、完整状态、原旧档不被修改，并包含村庄与室内迁移路径、未知布局拒绝规则。
- `game/tests/chapter1_map_editability_test.gd`：增加农庄和村庄在地图外放装饰 tile 时世界边界/相机不变的回归断言。

**下一位本地 AI 必须在 PR 当前最新 HEAD 而不是原暂停提交 `7d3df0a` 上执行**：

```sh
git fetch origin
git switch codex/chapter1-map-delivery
git pull --ff-only
python3 tools/check_scaffold.py
python3 -m unittest discover -s tools/tests -v
./run_game.sh --test
./run_game.sh --test-all
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --editor --import --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/chapter1_map_save_migration_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/chapter1_map_editability_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/chapter1_map_playability_test.gd
```

这组测试是**必须执行的待验命令，不是测试已通过的记录**。如果 Godot 路径不同，请使用本地实际 Godot 4.7.2 可执行路径，不能自行跳过测试。优先修复新测试的实际报错；保留失败完整日志，不删断言、不降低通过门槛。

待补：
1. 在最终 HEAD 验证迁移能读真实旧档（农庄/村庄/室内）以及新档、六田和居民安全落点；需要时由CORE owner做显式安全迁移，不静默清理玩家进度。
2. 核验真实玩家走通：收/播/浇、桥两向、村庄各门、经济/箱子、保存退出重读；独立 QA 曾对较早提交失败，这不是新 HEAD 的结论。
3. P1 清晰度：`project.godot` 仍使用 `canvas_items`，按父 #84 P1-2 对比 Nearest/整数 2×3×、1366×768 非整数窗口、相机移动30秒及中文UI，提供真实原生截图；根据数据决定改渲染方案，勿盲改。
4. 审核村庄匿名 `@TileMapLayer@2/3` 的数据归属、是否重叠，确认后安全命名/移除并重新测试；不得猜测后直接删除。
5. 对照四张定版设计图特别是01总图，农庄/小镇大面积空草地、整齐阵列田、细节密度不足，当前视觉均 `proposed`；局部用 PixelLab/像素编辑器补件并运行对照截图，用户签收前不标 `accepted`。

**合并门**：上述最新 HEAD 的真实运行/编辑/存档兼容性、画面清晰度和用户首屏视觉评审均通过后，再将 Draft 标 ready。旧“暂停”段落保留作为历史源证据，不作为当前停止修复的指令。

---

# 第一章地图暂停交付

用户于 2026-10-09 要求提交已开发成果并暂停后续工作。本 PR 保存现有代码、真实素材和阶段证据；不是整图完成或验收通过声明。

## 已保存

- WORLD 来源：d8a3358、ca7f756、362bfd28438b2891cf91032564206abdeb4c60e2。112×64 的 farm 与 80×40 的 village，由 Godot TileMapLayer 和独立 PackedScene 组成。
- 最新地图修复：实例内部 owner 保留、河水层级、河岸测试探针、门交互位置、围栏、九块视觉菜床与萝卜装饰。六个玩法 plot_id 和既有 Space/存档合同保留。
- terrain 来源 5bbe5c5；river 6217f714；objects c8aadfb9；town 4bede504；animals 7d908da。source/runtime/reviews 含真实 PNG、PXO、rect/anchor、job/provenance、SHA256 和 8× 最近邻预览。所有素材仍为 proposed。
- QA 来源 bfdfa12、c9d269f、0e3d172。旧基础层成功和 ca7f756 失败按源提交分目录保留，不相互替代。

## 验证范围

WORLD 在最终 362bfd2 上已执行 Godot 4.7.2 headless：world_layout_test 35/0，phase0_visual_contract_test 33/0，farm_exploration_test 12/0，village_shop_route_test 19/0；作者另做房屋移动诊断，7 个 child 均在树内，碰撞跟随移动。

独立 QA 对 ca7f756 的真实输入路线 65 检查/1 失败（005 被稻草人阻挡，后续动作/桥/门/交易/存读档未执行）；编辑性 54/4 失败，布局 33/2 失败，并有大量节点退出泄漏。这些证据保存于 ../map_qa/checkpoint_ca7f756/。最终 owner 与布局修复尚未独立重跑，不推断全部失败已消除。

本目录三张 PNG 为 WORLD 在暂停前捕获的原生 SubViewport 图像，SHA 在 manifest.json；截图脚本退出有清理告警，不证明完整玩法。用户要求暂停后，综合分支未新增 Godot 测试，只做 Git diff/check、来源及 PNG 字节一致性核对。

## 未验收与恢复入口

整图构图/密度/像素风格人工签收、最终六田动作及完整桥岸/八门/经济/存档路线、编辑器实际编辑扩图、冷导入/导出发布均未最终验收。未来恢复从本 PR head 开始，在隔离 worktree 重新运行独立 QA；不要拿 d8a3358 的基础层 46/0 与 52/0 代表新地图。

运行入口是仓库 game/project.godot；从 Codex worktree 或检出本 PR 的仓库在 Godot 打开该项目。旧 main 工作树未改动，未部署、未合并、未关闭 Issue。
