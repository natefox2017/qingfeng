# 晴风谷定版图与游戏资产的接入约束

2026-10-08 用户已在当前项目正式确认前述设计图：一张较大农庄→桥→小镇的世界地图效果图、一张首屏农庄效果图、河畔/布局参考，以及标题、创建角色、选择存档页面的效果图。**这些图批准的是视觉风格与构图，不意味着背景是一张可直接碰撞、可互动的游戏地图。**

本仓库唯一的设计清单在 [reference_manifest.json](../art/approved/reference_manifest.json)；它保存 8 张源图的原始路径、1672×941 尺寸和 SHA256，避免后续重新生图或错传旧版。**二进制源图在提交到 GitHub 前不可标记为“仓库已包含”**。用户在当前对话可以取得原始设计图归档，待实际二进制入库时更新清单的 storage_status 并校验每项 SHA；不能以清单代替 PNG 文件。

## 为什么保留 Godot TileMapLayer
对照 [Godot 官方 TileMap](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html)、[YATI / Godot4](https://github.com/Kiamo2/YATI) 和 [vnen Tiled importer](https://github.com/vnen/godot-tiled-importer)：当前项目已经原生建好了共享 TileSet、TileMapLayer、物理 Shape、Camera2D、锚点和存档字段，继续使用内置 Godot TileMap 编辑器更简单。Tiled + YATI 适合团队主要在 Tiled 创作时再迁移，但目前不引入转换链；老版 importer 不直接作为 Godot4.7 的技术依据。

**制作次序**：锁定设计稿坐标/16px 标尺 → 先定区域和宽的道路 → 独立地面、水、桥、树/墙/农舍组件图集 → 可编辑 TileMapLayer → 同场景唯一碰撞和 Marker → 实际玩家行走/相机追踪 → 截图和人评对照。新场景不能拿整张效果图作一个碰撞 Sprite，也不能把效果图里每一座房子当已实现的实体。大地图按可编辑区域扩建，现有六块田、旧存档和门落点需保留。

**菜单**：三张 UI 原图分别对应 title/new_game/load。图中烘焙的玩家名、示例存档数字和选择器不能当真实状态；需要用原生 Label、LineEdit、Button、ScrollContainer 投影已有 SessionStore/Settings，仍保留错误、可访问性、焦点和 Esc。插入背景 PNG 后必须确保点击区域覆盖真实按钮/可输入文字字段，不能将用户姓名烘焙成不可编辑像素。

## 导入被批准的源图
开发机持有项目对话交付的 `qingfeng_approved_designs_originals.zip` 时，执行：
```sh
python3 tools/import_approved_designs.py /path/to/qingfeng_approved_designs_originals.zip
python3 tools/check_scaffold.py
./run_game.sh --test
./run_game.sh --capture ./captures
```
导入脚本只在提交期使用，不需要为普通玩家配置 Godot 路径，也不会联网下载图像。它验证 8 个 PNG 的原始 SHA256，复制到 `art/approved/refs/`，把 3 张真实 UI 背景复制到 `game/assets/approved/` 并登记 `art/manifest.json`。**务必在 GitHub 核对真实二进制文件出现后才勾“已入仓”。** 地图世界素材仍需可重复使用的透明图集/小组件，不能直接裁一个不规则大图替代碰撞和路径。

## 阶段状态
- 2026-10-08：视觉图正式确认，原图已打包并校验，Github 文本清单与真实代码分开提交。
- 地图：原生世界区块逐渐扩为多屏，目前仍使用 Phase0 原创候选 TileSet，不可称完全还原定版地图。
- UI：已确认目标，但背景源图真正出现在 `game/assets/approved/` 后才能判断最终像素级贴图是否完成。
- 仍需：狗实体/动画、内容丰富度、更多可操作田地、地图区域扩展/导航、导出包和用户 5 分钟真人试玩。
