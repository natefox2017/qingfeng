# 第一章总地图布局、坐标与分层合同

合同版本：`chapter1.map.layout.v1`；所有者：#87；消费者：#88–#97、#104/#106/#107/#109/#111。最小工程合同已冻结，供 WORLD 串行实现；视觉状态仍 proposed，不宣称 accepted。按用户最新授权，proposed 素材可开发接图，人工审图不阻塞工程启动。

唯一空间母版：[`world_chapter1_map`](../../art/approved/refs/world_chapter1_map.png)，1672×941，SHA-256 `ba35eef32eb0a49a5e50ad8ec4498148845c8f4065d3695b315c4ea1286bddd7`。来源与去重映射见 [`chapter1_asset_source_index.json`](../../art/requests/chapter1_asset_source_index.json)。

本合同冻结区域相对位置、通路关系、坐标表达方式及绘制/碰撞分层。母版像素不是游戏格，母版不作为游戏底图、碰撞图或运行时纹理。02/03/04 仅作历史或局部辅助来源；不得覆盖 01 的拓扑。不得重生或导入另一张整章地图。

## 坐标合同

- 已明确的技术规格：世界地形格 `16×16 px`、item/action 独立 RGBA 图符 `24×24 px`、HUD 独立 RGBA 图符 `16×16 px`、逻辑视口 `640×360 px`。后者与当前 `game/project.godot` 一致。1280×720/1920×1080 是整数放大验证尺寸，不改变世界坐标或原生像素密度。
- 正式 palette、人物内容高度、屋门占格、脚锚、物件最终画布及镜头视觉比例继续 **TBD / proposed**；空值只表示未签收，不阻塞 WORLD 选择可执行的整数尺寸/脚锚并在场景记录工程决定。#88 隔离样板 `[8,8]` 格中心不是角色/房屋脚锚合同。
- 参考图坐标系：左上原点，`x` 向东、`y` 向南，范围为参考图像素 `1672×941`。它只用于描述图中区域方位，不是可编辑地图坐标；不从概念图像素比例换算世界格。
- 世界格：地形逻辑格为 `16×16 px`。各 Space 左上原点；格边界、R 区矩形及新增对象落位由 WORLD 按母版选择工程坐标，保存到 Godot 场景。文档中的 TBD 是未宣称视觉批准，不是禁止铺图。
- 世界格使用整数 `(x, y)`；每个已冻结 `space_id` 在其场景内采用左上原点、向东/向南递增。禁止以图像缩放、窗口分辨率或美术裁切推导世界坐标。
- `space.farm` 当前 96×64 格仅是现有起始范围，不代表第一章完整边界。当前稳定 Space ID 为 `space.farm`、`space.village`、`space.house`、`space.shop`、`space.workshop`。本合同不将 R 区擅自映射到新 Space，也不创建额外 Space。
- 精确坐标仍由对应 Godot 场景中的 Marker、碰撞体和 TileMapLayer 持有。文档只定义稳定区域 ID 和关系，不复制第二份数字坐标表。

## R01–R09 区域拓扑

| 区域 | 母版中的固定位置与内容 | 必须保留的关系 | 游戏坐标 / Space |
| --- | --- | --- | --- |
| R01 果园 | 左上；果树、樱花、围栏与园内步道 | 位于农舍西北；步道向农庄内部连通 | 工程边界由 WORLD 场景持有；space.farm |
| R02 农舍与院落 | 左侧中部；蓝瓦农舍、前院、井、狗窝/鸡舍及围栏 | 农舍在中央田地以西；院门接入贯通农庄的道路 | 门/脚锚/格边界 TBD；复用现有 `space.farm` 门合同前核对现有 Marker |
| R03 中央田地与道路 | 地图中央；多组田畦由南北/东西土路串接 | 农舍东侧；主路向北接小镇，向东接桥西侧，向南接山间小道方向 | 每块田格与道路格 TBD；保留 `plot.farm.001..006`，其中 `.003` 教程成熟田、`.004` 空田 |
| R04 小镇、石门与集市 | 上方中部；城门、建筑和市场 | 通过中央主路与农庄相接；保持在河流以西 | 工程边界由 WORLD 场景持有；space.village；不新造 Door 字段 |
| R05 河流与瀑布 | 右侧纵向水系；瀑布位于北端并向南流 | 河流在桥处被跨越，沿地图右侧继续向南至下游瀑布/画面边缘 | 河岸/水格/碰撞 TBD；不得把水面或岸壁作为可走桥面 |
| R06 横向木桥 | 中右部横跨河道 | 桥面西端接中央道路，东端接东岸通路；桥板可走，栏杆/桥墩阻挡 | 两端 Marker、桥面与栏杆碰撞格 TBD |
| R07 下游码头 | 右下河段；木质码头、船与钓鱼位置 | 位于桥以南；接岸边步道，码头不改变河道方向 | 可走面、交互 Marker 与碰撞 TBD |
| R08 森林方向 | 右上/东侧；林地与向东出口标识 | 位于河道东岸方向，不移动至小镇、农舍或田地之间 | space.farm 内方向边界；无新增目标 Space |
| R09 山间小道 | 左下；山体、岩壁与向南出口标识 | 从农庄南侧道路接出；不得替换成东侧河岸通路 | space.farm 内方向边界；无新增目标 Space |

道路拓扑的最小不变量：`R01 ↔ R02 ↔ R03 ↔ R04`；`R03 ↔ R06 ↔ R08`；`R05` 在图右侧纵向延伸并被 `R06` 横跨；`R07` 位于桥南的下游河岸；`R03 ↔ R09` 由农庄南侧道路连接。新增分叉及格坐标由 WORLD 作工程决定，既有门/到达点保留，布局实现必须逐段对照 01，不能以这组关系推导未画出的捷径或新 Door。

### WORLD 可执行边界与兼容接口

R01/R02/R03/R05/R06/R07/R08/R09 由现有 `space.farm` 表达；R04 小镇由现有 `space.village` 表达，城镇道路、广场、商铺/工坊外观为其子区。R08/R09 是 farm 内方向/边界区域，不创建林地/山道 Space。室内继续 `space.house`、`space.shop`、`space.workshop`。#104 正文同步采用上表唯一 R 编号；旧编号废止，任务 checkbox 不因此完成。

现有 Door 字典严格保持 `kind/interaction_id/target_space_id/arrival_anchor_id/arrival_facing` 五个非空 String；kind=`door`，facing 为 north/south/east/west。沿用代码中的八个 Door ID：`door.farm.house`、`door.house.farm`、`door.farm.village`、`door.village.farm`、`door.village.shop`、`door.shop.village`、`door.village.workshop`、`door.workshop.village`。目标到达 Marker 分别保持：house/shop/workshop 的 `DoorArrival`；farm 的 `HouseDoorArrival`、`BridgeEast`；village 的 `FarmArrival`、`ShopDoorArrival`、`WorkshopDoorArrival`。WORLD 不重命名这些接口。

保留当前 scene 中门/到达点、farm `PlayerSpawn` 与 `plot.farm.001..006` 的既有坐标作为兼容基线；`.003` 成熟萝卜、`.004` 空田沿用现有内容。新增路径/区域/对象可工程调整，具体坐标唯一存在于场景，不在本合同另存表。存档仍使用现有 schema 与 `space_id/world_position_px/facing`，保留居民 ID、`storage.house.main` 交互 ID 和 `container.home_chest`；不得创建新 Space 或存档 schema。旧存档实际落点与门回程由 WORLD 回归核验，不从文档推断通过。

## 分层与空间所有权

一块可编辑地图按以下职责绘制；每类空间数据只保留一个权威位置：

1. **地面层**：`TerrainGround` / TileMapLayer，绘制草地、土路、土壤、水面、岸和桥面地面；地形连接使用 TileSet/terrain 数据。
2. **地面细节层**：`GroundDetails` / TileMapLayer，放草花、石子等不改变通行和田地状态的贴地装饰。
3. **玩法投影层**：`PlotStates` / TileMapLayer 展示田块状态；作物/田地真值仍属于现有玩法状态与稳定 plot ID，不由贴图或投影层保存。
4. **对象与脚底排序层**：房屋、树木、家具、居民、玩家等对象以脚底/根部锚点排序；树根/建筑足迹碰撞与树冠、屋顶遮挡分开表达。
5. **前景遮挡层**：树冠、屋檐等需盖住角色的部分单独置于前景；不把整张对象合成图作为碰撞或路径阻挡。
6. **碰撞与可走区域**：TileSet 碰撞、对象根部/足迹、桥栏杆和边界由场景中的碰撞数据持有。绘制顺序不决定可走性；不得再在 JSON 或另一地图层复制一份坐标。
7. **Marker/交互锚点**：门、出生点、田块、居民日程、采集点和对话点由其所属场景 Marker 持有。现有 `plot.farm.001..006`、Door/Resident/Chest ID 与目标 Space 保持稳定；不因美术重排而重命名或复制第二套状态。

以上名称以当前 `farm_first_screen.tscn` 已存在的 `TerrainGround`、`GroundDetails`、`PlotStates`、`Solids`、`FarmPlots`、`Anchors`、`FootSorted` 为实现参照，不要求其它场景机械复制节点树。桥的走面与栏杆、河水与岸壁、树根与树冠必须分开验收。

## 扩区、门与存档约束

- 先在现有已批准 Space 内编辑布局。新增独立 Space 前，先由 CORE/存档/Door 所有者审查 `space_id`、目标 Space、到达 Marker、伙伴 Marker、加载/保存恢复和迁移语义；本合同没有批准任何 schema 或 Door API 变更。
- 稳定 ID 不因地图坐标变化而改变。若现存持久化状态引用的 Marker/对象将被移动、删除或重命名，先核对实际保存合同并提供迁移/兼容证据；不得靠场景坐标表另存副本。
- 地形与对象落位完成后，分别验证连续道路、桥面通行、桥栏杆阻挡、河岸阻挡、门双向到达与玩家脚底排序。静态文档不能替代 Godot 原生运行和人工同镜头审图。

## 资产唯一来源与验收状态

[`chapter1_asset_source_index.json`](../../art/requests/chapter1_asset_source_index.json) 以 SHA-256 合并相同源，记录精确本地源路径、commit、复用位置、原始/运行尺寸及状态。Drive URL 只保留为历史来源，不是本地交付前提。01/05/06/07 是已批准设计参考；第一屏四个 phase0 PNG 是仓库内的 `proposed` 候选，不代表符合总图或已通过原生审图。未找到可核验的独立源图或 SHA 时不补造文件记录；未重新下载验证的 Batch 01 云端压缩包只注明证据限制。

#88 本地提交 `fb8a2f54d517b70015ed590979923d4def8ff2ec` 已索引为 **local-only / proposed**：64×80 RGBA 图集、19 个 16×16 源格及 rect/mask、可编辑 PXO、4×/8× nearest 预览和三尺寸 Godot 截图。它不在本分支或 main，不能假称已集成。源与 runtime atlas SHA 均为 `44b1d5600d4217b3a729b13f3a7184470b2af69dc8c727f712f7c71d4079f7f4`；完整证据逐文件 SHA 在索引中。格中心 `[8,8]`、NESW mask 和 Match Sides 只覆盖窄路样板，不包含宽路/石路/角点 peering 或正式地图通路。

本任务复核文件/hash/rect、nearest 放大和截图尺寸；Godot 4.7.2 执行记录来自 #88 所有者，本任务没有重跑 Godot，也不能仅凭 PNG 独立证明其捕获过程。该固定提交未记录批准母版局部裁图的输入路径/rect/SHA；#88 正在补此证据，后续提交须重新核实，不静默混入当前索引。草叶重复频率、palette、同镜头人物尺度及用户签收均待验；按最新用户授权，proposed 可用于开发接图与工程扩产，不能将开发使用写成 accepted。

本次只完成静态合同和来源映射。尚无 Godot 地图布局、R 区世界格坐标、资产逐件 runtime 验收或人工同镜头视觉签收；不得据此勾选这些完成项。
