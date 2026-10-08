# 第一章美术资源：独立静态验收与交接（2026-10-08）

> **结论：STATIC PASS；Godot Native NOT RUN；Visual NOT ACCEPTED。** 本文是测试证据与操作边界，任务 checkbox 只在 [Master #84](https://github.com/natefox2017/qingfeng/issues/84) / 对应子 Issue 维护，不在本文另建进度真值。

## 最新四张定版母版（覆盖更早的多图口径）

用户最新明确的**定版仅四张**：
- [01 第一章总地图](https://drive.google.com/file/d/1y8qdqr3I3Pm9Ey2MTQnbVzCD-pX5zjxW/view)：所有世界区域拓扑、房屋、田地、果园、村庄、河桥、码头与道路结构以此为唯一整体母版。
- [05 标题主菜单](https://drive.google.com/file/d/1W8qIZPhIaGRirgYwHXozM8QTNJO0ccYW/view)。
- [06 创建新游戏](https://drive.google.com/file/d/1mpxQMYUR7VtsSjyNE6YUB_g3fcopsCFl/view)。
- [07 选择存档](https://drive.google.com/file/d/1iO3P5-LlAS6EsCpbByFUB-nJzBPos4Hf/view)。

历史 `farm_first_screen`、`farm_exploration_reference`、`riverside_reference`（02–04）仅为局部细节和旧版本对照，**不允许覆盖 01 的地图拓扑**。旧 manifest 仍保留这些源 SHA 以保障去重和追溯，不意味着多张正式总地图都要生产。不可重新生成新的整幅地图；只按 01 产出能在 Godot 移动/扩区的地形图块和独立对象。

## 已实际交付的第一批候选

- [Drive Batch 01 文件夹](https://drive.google.com/drive/folders/1OyK5r4fg9uVehZ7du6xIM9i2Evqa1_dp)
- [全量源图、运行 PNG、49 个 AtlasTexture .tres 的 ZIP](https://drive.google.com/file/d/1UdLU4RP5cbdeexmrfYvQNcXZunjqi9hi/view)
- [原生尺寸素材预览](https://drive.google.com/file/d/1LtbPhzMhEXesy_KbIrAKEAcrbWA7JpCd/view)

本地下载候选 ZIP 159344 字节，SHA256 = `6f340dac479b8747d069809909b0f3b4f98e32a1b5440e7f18b2aafc8188ac99`；Google Drive 元数据报告的大小同为 159344 字节，**云端完整内容的 SHA 尚未重新下载核对**。

Batch 01 包含：
- 8×8 / 16px 的 `spring_ground_16.png` 地形**样板**（64 tiles），以及独立草木覆盖层；没有通过 TerrainSet corners/sides、水岸/桥碰撞、图块拼缝的原生 QA。
- 5 件 24×24 真实物品 `item.hoe`、`item.watering_can`、`item.radish_seed`、`item.radish`、`item.wild_herb`，打包 `inventory_items_24.png`（224×28、8 列、3 透明预留槽）。
- `ui_actions_24.png`（224×112，30 个有效 24px 图符、2 个透明预留槽），`hud_status_16.png`（160×40、14 个有效 16px 图符、2 个透明预留槽）。
- 木质菜单按钮、输入框、存档卡和 64×64 九宫格皮肤；49 个实际 `AtlasTexture` 资源定义。

## 独立检查报告：结果与不可推断项

2026-10-08 在隔离 Python/Pillow/ZIP 环境进行的**独立静态校验**：**889 项断言，0 失败**。检查了 181 个 ZIP 条目（CRC、路径和文件名），60 个源/图集 PNG（可解码、RGBA、字节数、SHA256），125 个矩形 region/anchor/九宫格边距，49 个 `.tres` 文件的基本语法与纹理引用，7 组 atlas 的源与切片像素一致性，4 张历史地图源的 SHA/1672×941 尺寸，以及 planned future 空槽透明性。

**不能由此得出“Godot 可直接在正式游戏上线”**：环境没有安装 Godot 4.7.2，因此冷导入、ResourceLoader 真加载、地形 TerrainSet、原生屏幕、UI 交互、桥/水/树冠碰撞、保存读档与人工同镜头还原度均**未执行/未通过验收**。测试中的 `proposed` 必须保持，不得更新为 `accepted`，不可勾掉 #84 的总图和完整 UI 任务。

**不要直接导入 ImageGen 展示板**：后续产生的 `pixel_art_rpg_terrain_tileset_atlas.png`、`cozy_pixel_village_tileset_atlas.png`、`cozy_pixel_farm_ui_atlas.png` 等 1448×1086 图不符合 16px 整格表，也无稳定 rect/anchor 等实际导出元数据；部分像素具有大量半透明边。它们只能作待审候选，必须逐件精修和手工标准化，不能按名称叫 tileset 就直接贴进 Godot，更不能代替上述四张定版。

## 用户接手时的原子执行顺序

1. **第一批验证前置**：获取最新 `main`，隔离 worktree，核对 PR #82 / #83 已合并，查看 #84/#87 和云盘去重清单；遵守只向 `natefox2017/qingfeng` 提交。
2. **切图包接入**：下载 ZIP 并先比对本地 SHA；仅将 `RUNTIME_COPY_TO_REPO/game/assets/*` 按路径复制到仓库 `game/assets/`，`ORIGINAL_SOURCES` 进 art 源归档，避免覆盖相同文件。ZIP 自带源脚本未证明能在其他机器直接运行；先审绝对路径再使用。
3. **原生资源 smoke test**：Godot 锁定 4.7.2 冷导入；逐项 `load(res://assets/ui/generated_regions/…)` 验证全部 49 个 Texture2D/AtlasTexture，无缺图、越界或错参；按钮九宫格实际用 `StyleBoxTexture` / `NinePatchRect` 拉伸，UI 保留真实 Button、LineEdit、ScrollContainer/中文字体。
4. **地图样板测试**：#88 中只将 16px 地形作为地面样板，不预称完成水/悬崖/桥；在 `TileMapLayer + TileSet` 建真实 peering，手铺直/转/T/十字/内外角、菜田/道路/边界、水岸/桥，验证 nearest 无接缝、碰撞/通路合法。
5. **同镜头原生 QA**：分别在 1280×720 和 1920×1080 取 Godot 真实截图；至少走 `title→create→farm house→plot.farm.003 成熟田→plot.farm.004 空田→inventory→save/load`，检查物品数量、交互提示、中文、光标、禁用态、遮挡。
6. **工程回归**：按版本环境执行 `python3 tools/check_scaffold.py`、`python3 -m unittest discover -s tools/tests -v`、`./run_game.sh --test`、`./run_game.sh --test-all`；若没有 smoke test 显式引用新图，则现存游戏回归 PASS **不能证明这批新图已经加载**。
7. **视觉签收与关闭**：在 #96 (items)、#97 (icons/HUD)、#98/#99/#100 (UI) 和 #88 (terrain) 附 `文件SHA + Drive 文件链接 + Godot 截图 + commit/PR + reviewer`；WORLD #104/#106/#107/#109 只在各自依赖美术完成后接图。用户人工审图通过才能标 accepted。#84 最终只在第一章全部可编辑地图和实际可玩路径都验收后关闭。

## 附加阻断

- 清洁版 `title_clean/new_game_clean/load_clean` 尚缺；第一批不含正式角色/狗/NPC 的全四向和农事接触帧。
- 农舍/果园/村镇/室内/桥/码头的终版独立组件和 9 区完整场景均未交付；`spring_ground_16` 不能取代整章地图。
- 三张不同名字的 64×64 主面板贴图目前 SHA 完全相同，接入时应只引用一个 canonical 文件或记录别名，避免“同一图重复制造”。

*当前文档仅更新规格与测试事实，不改变任何游戏运行文件或已存在的存档合同。*