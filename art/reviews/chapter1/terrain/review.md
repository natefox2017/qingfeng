# #88 PixelLab 原生地形开发交付 / proposed

2026-10-08，分支 `codex/issue-88-terrain-art`；worktree `/Users/apple/.codex/worktrees/issue-88-terrain-recovery/qingfeng`。实时 main `a871fdb2f18eea1f9208dcb6c478823677966460`，起点 `9458d71c50a456ead0e762c11f8a9c3cfdff5877`，未改 main/公共地图/manifest/UI。新指令允许按经验选择 proposed 素材给可玩开发使用；不是用户视觉accepted。

A01/A02：真正调用普通 `create_image_pixflux` 三次，每次1订阅生成，共3/8，未购买/充值、无pro。恢复时余额1277、credits0、全部3个原任务completed，无在途任务，未重生。请求/prompt/seed/实际输入裁图rect与SHA/job_id/raw PNG SHA/修整过程见 `art/sources/chapter1/terrain/pixellab_requests.json`；原始PNG与输入局部都保存。

- 第1草地 `1f1fb84e-ad42-4abd-b4c1-8e19b5b40333`：出现土块，REJECTED_FOR_A01，不入runtime。
- 第2草地 `84c51e79-6543-4be5-b56c-85af8fe19329`：32×32原生生成，母版rect `[1120,490,32,32]` 实际base64作为强制色板。179色过多，在Pixelorama减为6色，再精确原尺寸裁3个16×16草格，原生修缝；不缩小插画。
- 土路 `831adbfd-74eb-430a-9f4d-0ed8061cd989`：32×32原生，母版rect `[550,490,32,32]` 实际强制色板；原图57色并夹草边，Pixelorama收敛5个暖土色，精确中心16px裁图/修缝；保留原始形态结果和限制。

运行入口：`game/assets/chapter1/terrain/grass_dirt_tileset.tres` 是现有可编辑TileSet；`grass_dirt_atlas_16.png` 仍64×80 /19格，canonical asset_id、NESW=1/2/4/8 Match Sides合同、rect/anchor `[8,8]`、margin/separation0保持。metadata见同目录 `grass_dirt_atlas.json`；hash `e98c0d3ef92a66d386a35822f4938f088de56e0c0bf5691d842818af92a79682`。
额外 `game/assets/chapter1/terrain/dirt_base_16.png` 是完整土路格，供多格宽路使用；sidecar `standalone_surfaces`有同一土路asset_id/rect/hash，未擅自改逻辑16px或增加角点模式。WORLD可引用这些资源，正式场景由WORLD唯一写者接入。

实际命令（Python=`/Users/apple/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3`；Godot=`/Applications/Godot.app/Contents/MacOS/Godot`）：

- Python `art/sources/chapter1/terrain/verify_atlas.py`：19源图/rect/hash、11色、alpha仅0/255、256兼容边、8×exact，通过。
- Python `tools/atlas_contract.py game/assets/chapter1/terrain/grass_dirt_atlas.json`：静态合同PASS，非视觉验收。
- Godot `--headless --path game --editor --import --quit`：exit0真实PNG重新导入，无ERROR/WARNING；未清空原有缓存，不称冷导入。
- Godot `--headless --path game --script res://assets/chapter1/terrain/build_sample.gd --quit-after 120`：exit0；19tiles/920cells/46roads，三处5×5重复；实际Terrain solver验证孤岛/端头/直线/角/T/十字。
- Godot `--path game --script res://assets/chapter1/terrain/capture_sample.gd --quit-after 240 -- /Users/apple/.codex/worktrees/issue-88-terrain-recovery/qingfeng/art/reviews/chapter1/terrain`：exit0，macOS OpenGL Compatibility/M4 Pro原生640×360、1280×720、1920×1080截图，无ERROR/WARNING；2×/3×逐像素nearest一致。截图与本批PNG一起提交，全部精确hash/尺寸见 `pixel_qa.json`。
- `git diff --check`通过。执行日志位于未跟踪 `.tmp/issue-88-pixellab/native/`。

审图：`reference_comparison.png` 为母版局部1×/2×与运行图集1×/4×/8×对照，母版crop仅review不运行。共享边修缝可能形成可见格线，三草格仍重复；图集覆盖窄路而非完整宽路内外角/石路。当前选择的是工程可消费版本，不能称母版画面已还原。正式世界/人物尺度/可玩通路、全套游戏回归、发布导出、用户视觉签收未验。本地commit，不push/merge，不关闭或勾Issue。#88 OPEN；无本分支PR/CI。原开放#114/#115/#116无terrain文件冲突，均Draft/无autoMerge，检查SKIPPED不算验收。

## 最终开发消费补充（A03/A07，不增加生成费用）

早期草路commit为 `c62a61d3552cb2b5e15a3f9b1fb434273ec4a58a`；本节描述随后提交的最终tree。看到真实渲染中草地矩形框过强后，原生压缩绿色色阶对比、用共享边缘草叶替换纯色边框；已同步PNG/源 `.pxo`/metadata/hash/8×及三尺寸截图。最终图集SHA以 `grass_dirt_atlas.json` / `pixel_qa.json` 为准，前文早期hash仅对应早期commit。

**WORLD接口（本组独立资源合同，无公共地图代码修改）：**

| TileSet source | 16px atlas坐标 | 内容 | metadata |
|---|---|---|---|
| 0 | 原19格保持 | 三草格、16种NESW窄路 | `grass_dirt_atlas.json` |
| 1 | `(0,0)` / `(1,0)` / `(2,0)` / `(3,0)` | 完整土路 / 未翻土 / 翻土 / 湿土 | `soil_surfaces.json` |
| 2 | `(0,0)` / `(1,0)` / `(2,0)` / `(3,0)` | 草簇 / 白花 / 黄花 / 石子 | `ground_decor.json` |

统一入口仍为 `game/assets/chapter1/terrain/grass_dirt_tileset.tres`；新增source1/2有4格各自的64×16真PNG。source1/2为明确状态/装饰格，无Terrain peering，无新增碰撞或运行状态拥有者。干/湿/翻土状态由WORLD实际数据选择，不能靠地表图推断逻辑。现有source0/canonical grass/dirt IDs不变；新增本组soil/decor IDs由公共manifest持有人串行登记，不擅自改公共manifest。地表anchor `[8,8]`，decor语义脚锚 `[8,14]`；TileMap仍默认格中心绘制，单独Sprite引用时用metadata脚锚布置。

A03材质由已保存的PixelLab土路原生16px种子派生，Pixelorama调整5级干/湿土色板、手工画原生弯折田垄；A07透明草簇/白花/黄花/石子由Pixelorama原生逐像素绘制，参考母版外观，不称AI生成这四张。source、单格切图、可编辑 `.pxo`、rect/content_bounds/anchor/SHA、runtime、8×全部存在。本批总生成仍3/8，未pro、未充值。

本轮最终验证：`verify_atlas.py` 原19格/11色/256兼容边通过，两个新增family各4格的实际源/runtime/hash/rect/二值alpha/8×通过；四surface单格水平/垂直接缝通过，decor透明边检查通过。三个sidecar分别运行 `tools/atlas_contract.py` 均静态PASS。真实Godot重导入exit0；`build_sample.gd` exit0，原920ground cells/46道路solver断言通过，新增100soil cells（四处5×5）及24decor cells断言通过。最终 `capture_sample.gd` 三尺寸原生捕获exit0，2×/3×严格nearest一致；final import/solver/capture日志无ERROR/WARNING，存 `.tmp/issue-88-pixellab/native/*-final.log`。

这是A01/A02/A03/A07**基础可消费切片**：尚缺完整宽路/石路内外角、田格边缘过渡、A07其余变体；正式地图整屏与可玩通路由WORLD验证。视觉仍proposed，不能称accepted/全量完成。加载入口、元数据和运行图现可供开发直接使用。消费最终commit的terrain三目录tree或包含本分支从main起的完整提交链；只cherry-pick最后一个增量commit不能获得早期新增文件。未push/merge/关闭Issue。

## 历史修整 4e75a01：疏草与细石（草格已被下节覆盖）

协调方审阅3e62452的真实图后指出亮密细纹和土底大斑点，因此本轮保留该commit及所有生成原始源，不删除历史PNG；使用Pixelorama原生逐像素重绘当前canonical source/runtime，未新生图、未缩小插画、未使用随机噪声或平滑滤镜。本轮新增费用0，总生成仍3/8。

- 三个草格统一底色占216/256 = **84.375%**；其余各10组4px连通草叶簇，三种位置排列。没有铺满孤立1px噪点或密集棋盘。保留区域名称以兼容消费方，它们现在主要是草簇位置变体。
- 土路以236/256 = **92.1875%**平静底色与少量2×2细石簇构成；去掉大圆/大块明暗斑。完整土路和untilled/tilled/wet材质同步，田垄仍为手绘清楚的像素线。
- 草地实际取色为#93b73c / #6c9b2d / #bdd54a；土路为#e5ba67 / #fdd179 / #c8aa55。六色均真实存在于批准母版，精确xy见pixel_qa.json sparse_redraw.actual_reference_pixel_samples；不是凭经验编造调色值。
- API、source0/1/2、asset_id、region、rect/anchor、16px逻辑格和NESW连接形状不变。TileSet/tres、样板tscn、build/capture脚本及正式世界代码未提交变化。WORLD已消费3e62452时，只需换本轮PNG及其哈希sidecar，避免重新定义布局/接口。

本轮真实验证：verify_atlas 19格/7色（二值alpha含透明）/256兼容边/8×通过；soil与decor各4格源/runtime/hash/rect/alpha/8×通过；surface接缝保持通过。三个atlas_contract静态通过。Godot4.7.2实际重导入exit0，build_sample真实920ground/46roads/100soil/24decor及5×5/直角/T/十字断言exit0；其生成的无意义随机unique_id差异未提交，保留3e62452原TileSet/样板布局，再用同一原场景实际捕获三尺寸exit0。最终640×360、1280×720、1920×1080逐像素1×/2×/3×nearest一致，日志无ERROR/WARNING。日志位于未跟踪 `.tmp/issue-88-sparse/`。

`sparse_before_after.png` 是3e62452与本轮原生640图同布局并排，已实际目视检查：密亮格纹和大斑块明显降低，草叶仍有16px重复；这是针对反馈的可审修整，不能说整个世界画面已通过。源PNG/.pxo、4×/8×、母版局部对照、三尺寸Godot图与最终hash一起提交。最新grass/dirt图集SHA256：c9a68a4cfa78d0d36d44aec009c13a381db7f1c1ef606047f42b111b20391f01。

#88仍OPEN/proposed，未push/merge/关闭；正式地图镜头/人物/可玩通路、全量美术、游戏回归与导出仍由相应任务验证，不以本轮像素机器检查代替视觉签收。

## 当前草格修整：宁静基础草（覆盖历史三草格）

基于4e75a01，仅Pixelorama局部修整已生成MCP草材质；未新生成。source0 `(0,0)` 0个细节像素、256/256底色；`(1,0)`/`(2,0)`各8个细节像素、248/256底色，各两簇2×2明暗草叶。保留原六色母版palette、19格坐标、asset_id/anchor/rect/sourceID、所有道路像素及TileSet/场景/代码。PNG、原生pxo与sidecar源hash已同步。

WORLD消费建议：90%以上宁静tile0，tile1/2稀疏成片点缀；不能继续均匀循环三个变体。宽路使用source1 `(0,0)`完整土路；source0窄路mask15仍有36个不透明绿角像素，本轮不改变其连接几何。没有写WORLD场景或shader。

quiet_grass_before_after.png左=4e75a01、右=当前；首行三单格8×、次行三组5×5 nearest2×、末行105格混铺（95格quiet、10格accent）。已实看对照与Godot640图，点阵明显减少；不是正式整图验收。当前图集SHA256 c95926e8b0e07162b1961c8be81e5901c76ae6d2449a58219fd8bb3f6609eb68。

本轮实际verify_atlas PASS：19格/7色/256兼容边/exact8×，soil/decor各4格hash/rect/alpha通过；grass atlas_contract静态PASS。Godot4.7.2 --headless --path game --editor --quit重导入exit0；--path game --script res://assets/chapter1/terrain/capture_sample.gd -- <review绝对路径>原生三尺寸捕获exit0，严格nearest2×/3×一致，无ERROR/WARNING。日志.tmp/issue-88-quiet/。本轮未重建solver、冷缓存导入、正式WORLD全图/游戏回归或导出；前述solver为历史证据。

仅本地commit，不push/merge/关闭Issue，#88 OPEN/proposed、无本分支PR/CI。
