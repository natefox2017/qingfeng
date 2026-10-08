# PR #117 最终修复与视觉验收准备（2026-10-09）

## 当前状态

- Issue #84 仍为 OPEN；PR #117 仍为 OPEN / Draft，head 分支 `codex/chapter1-map-delivery`。不得合并或关闭 Issue；最终视觉签收留给用户。
- 本文列出的完整 QA 结果对应代码基线 `6f0bd77acd41e2edf8c5b5cf5b1a61bf05469b0f`。此前分项提交：`28fcd11` 旧存档迁移/地图边界/路线回归，`c9c3cff` 清理村庄空匿名层，`a5eadae` 清晰度证据，`4d4b236` 地图细节和多分辨率截图。
- 后续视觉修整提交 `8e286d000f61980aae029524b9a0e5a70b99dba1` 新增可复用的橙白遮阳棚摊位，并将村庄六个摊位中的三个换为橙白版本；所有摊位坐标、碰撞足迹和入口锚点保持原样。按用户要求，此提交后未重新运行 Godot、测试或截图；下方 QA 数据与 PNG 是该提交之前的基线证据，不能视为橙白版本已运行验收。
- 工作树 `/Users/apple/.codex/worktrees/chapter1-map-delivery/qingfeng`；远端仅为 `natefox2017/qingfeng`。主 checkout 未改。Godot 生成的 `.uid` / `.import` 与 `.tmp/` 为本地未跟踪文件，没有加入提交。
- 最终检查：PR 当前 `repository-policy` 为 `SKIPPED`；没有通过中的 CI 检查。PR Review Threads 当前为空；一条旧 COMMENTED review 针对历史 head `7d3df0a`，不是最终验收。

## 实际修改

- 存档：仅迁移识别出的旧六块田坐标签名；旧签名存档保留作物、背包、金币、关系、事件等状态，并安全重锚户外玩家与村民；未知坐标布局拒绝自动迁移，旧源存档不覆盖。测试使用依据旧签名格式构造的旧版本存档夹具；未使用用户个人存档文件。
- 地图：农庄和村庄世界边界、相机限制、外围碰撞由 `TerrainGround` 决定；测试覆盖移动对象、扩图和越界装饰 tile。村庄 `@TileMapLayer@2/3` 确认为空、无重叠冗余层并移除。复用现有 `ground_decor_16.png` 为农庄/村庄 `GroundDetails` 分别增加 43/32 个无碰撞地面装饰 tile，未生成整图或新美术；保留农庄出生点 `(320,560)`，相机 offset 为 `(0,-120)`。
- 显示/UI：保留 `canvas_items + keep + integer`，启用 2D transform pixel snap、Nearest 纹理；1366×768 下游戏内容为整数倍的 1280×720 并留边。`action_button.gd` 不再在文字按钮上叠画中心图标，避免遮挡中文文字。

## Godot 4.7.2 冷导入与回归

引擎：`/Applications/Godot.app/Contents/MacOS/Godot`，`4.7.2.stable.official.ed1daf0bf`（Apple M4 Pro / Metal OpenGL Compatibility）。冷导入及整套回归在隔离项目副本完成：

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./run_game.sh --test-all --timeout 180 --report-dir .tmp/map-pr117-final/full-suite-final3
```

结果：退出码 **0**；冷导入通过；46 个测试日志均通过，`summary.json` 全部为 true。证据：`.tmp/map-pr117-final/full-suite-final3/summary.json`，单测日志同目录。

最终 HEAD 又单独运行以下六项，全部退出码 0：

| 测试 | 结果 | 本地完整日志 |
| --- | --- | --- |
| `chapter1_map_save_migration_test.gd` | 33 checks / 0 failures | `.tmp/map-pr117-final/direct-final/chapter1_map_save_migration_test.log` |
| `chapter1_map_editability_test.gd` | 56 / 0 | `.tmp/map-pr117-final/direct-final/chapter1_map_editability_test.log` |
| `chapter1_map_playability_test.gd` | 431 / 0 | `.tmp/map-pr117-final/direct-final/chapter1_map_playability_test.log` |
| `world_layout_test.gd` | 35 / 0 | `.tmp/map-pr117-final/direct-final/world_layout_test.log` |
| `full_economy_loop_test.gd` | 35 / 0 | `.tmp/map-pr117-final/direct-final/full_economy_loop_test.log` |
| `door_transition_test.gd` | 20 / 0 | `.tmp/map-pr117-final/direct-final/door_transition_test.log` |
| `village_tile_layer_audit_test.gd` | 14 / 0 | `.tmp/map-pr117-final/direct-final/village_tile_layer_audit_test.log` |

单项测试命令（以上各项均退出码 0）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/chapter1_map_save_migration_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/chapter1_map_editability_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/chapter1_map_playability_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/world_layout_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/full_economy_loop_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/door_transition_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/village_tile_layer_audit_test.gd
```

上述 playability 用例通过 Godot `Input.action_press` 和物理帧验证萝卜收获、六块田的翻土/播种/浇水、果园、河桥双向、村庄商店和工坊、交易/箱子及存档写入读取。它是自动化路线测试，不等同于人工桌面全路线试玩。迁移测试覆盖旧版签名格式夹具里的六田状态、背包金币、居民安全落点、新档读写和旧档不覆盖；真实用户私有存档未提供，因此未实测该文件。图层审计首次复跑因旧断言要求新加的 `GroundDetails` 仍为空而退出码 1；按当前场景语义改为检查其装饰 tile 位于地面范围内、来源为装饰 atlas 且 TileSet 无碰撞层后，重跑 14/0、退出码 0。没有删除断言或弱化世界边界检查。

## 原生画面与相机滚动证据

截图保存在 `art/reviews/chapter1/map_delivery/native/`，共 18 张 PNG + `manifest.json`：农庄/村庄到达与地图焦点各在 1280×720、1920×1080、1366×768；新建/读档中文 UI 各在三种窗口尺寸。Godot 原生命令均退出码 0：

```sh
Godot --path game --script res://tests/chapter1_map_native_capture.gd -- <output-dir>
Godot --path game --script res://tests/entry_native_capture.gd -- <output-dir>
```

本地日志分别为 `.tmp/map-pr117-final/native-map-clean.log` 和 `.tmp/map-pr117-final/native-entry-final2.log`。截图是 Godot root texture 的渲染内容，不是 OS 全窗口截图。1366×768 PNG 内容为 1280×720 整数缩放画面；该尺寸 PNG 与 1280×720 内容相同，完整窗口留边比较另见 `art/reviews/chapter1/pixel_clarity/final/1366x768-world-scroll.png`。入口截图退出时 Godot 报告 2 个 ObjectDB instance 和 1 个 resource 泄漏告警；脚本报告 `ENTRY_NATIVE_CAPTURE_PASS` 且退出码 0，告警未隐藏。

最终配置下的相机运动在 1366×768 原生 Godot 窗口定向键盘输入 45.132 秒：

```sh
Godot --path game --resolution 1366x768 --script res://tests/chapter1_pixel_clarity_test.gd -- .tmp/map-pr117-final/scroll-1366-posttopid 45
```

结果退出码 0，`PIXEL_CLARITY_PASS duration_s=45.13 samples=175`；玩家 X/Y 位移范围各 291.2 px，相机 X/Y 范围 291.2 / 288.8 px。报告在 `.tmp/map-pr117-final/scroll-1366-posttopid/runtime.json`。此处通过向 Godot 进程定向投递真实方向键完成运动；早期未把按键送达窗口的尝试曾失败，未计作通过。

## 对照定版图与剩余验收

已将上述原生截图与 `art/approved/refs/world_chapter1_map.png` 的农庄、村庄对应区域对照。Nearest、整数倍率、三尺寸内容和移动画面已有运行证据；截图仍显示大面积空草地、规则孤立田格、村庄空旷石广场和市场重复，密度/比例/画风与批准总图仍有明显差距。此次只复用现有装饰组件，没有 PixelLab 新生成素材或重新生成整张地图。所有新截图状态均为 `proposed`，`accepted` 仍为 false，等待用户视觉确认。

尚未完成：人工从农舍门口完整操作到保存退出并重新打开的桌面试玩；用用户提供的私有旧档验证；用 Aseprite/PixelLab 增补并集成缺失的可复用像素组件；用户对视觉截图的最终确认。编辑器里拖动并保存扩建的人工操作也未做，当前扩图/碰撞覆盖由运行回归测试验证。以上不影响已通过的自动化测试结果，但不能被描述成已完成人工/美术验收。

## 视觉检查入口

- 农庄到达：[native/space_farm_arrival_1280x720.png](native/space_farm_arrival_1280x720.png)
- 农庄地图焦点：[native/space_farm_focus_1920x1080.png](native/space_farm_focus_1920x1080.png)
- 村庄到达：[native/space_village_arrival_1280x720.png](native/space_village_arrival_1280x720.png)
- 村庄地图焦点：[native/space_village_focus_1920x1080.png](native/space_village_focus_1920x1080.png)
- 中文新建 UI：[native/new_game_1280x720.png](native/new_game_1280x720.png)
- 中文读档 UI：[native/load_1280x720.png](native/load_1280x720.png)

视觉结论待用户审定；PR 继续 Draft。

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
