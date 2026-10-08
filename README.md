# 晴风谷 · Qingfeng

**唯一开发仓库：[natefox2017/qingfeng](https://github.com/natefox2017/qingfeng)。** 从空白开始，不导入旧项目代码、图片、存档或 Git 历史。

一个以星露谷式固定俯视像素表现为目标、结合农庄生活与有记忆居民的单机游戏。首版先完成三天可玩的生活循环；PixelLab 用于开发期制作素材，运行中的游戏不依赖 PixelLab。可选 AI 对白与本地玩法权限分离。

## 当前状态
`foundation`：**正式新档已进入 `space.farm` 门前菜园**，使用 Godot 4.7.2 可编辑的 16px TileMapLayer、农舍/树木 PNG、玩家四向 idle/walk 像素精灵，并有真实六块田格、种植/浇水/采收、村庄与室内门、背包/箱子/交易、日时与 schema7 保存。旧 schema1 碰撞测试档**只从读档列表显式进入**，不会被「继续游戏」当成正式存档。

这些是 **Phase0 原创可玩美术候选**，不是已验收的第一章设计稿或 PixelLab 正式成品。第一章总地图、正式人犬动画、最终 TileSet 美术、中文随包字体、对照权威设计稿的人工审查仍未完成。当前 Phase0 已有固定 Godot 4.7.2 的原生冷导入/农庄碰撞/田格/门转场自动回归；**脚本验证与最终视觉验收不可混称**。进度以 [总任务 Phase0 验收清单](https://github.com/natefox2017/qingfeng/issues/1) 为准；入口细节见 [入口合同](docs/entry_pages.md)。

## 入口
- [Notion 唯一人类入口](https://app.notion.com/p/3eee1df1f5a78150879fe4bc1c3151db)
- [完整开发文档](docs/README.md)
- [开发总任务 #1](https://github.com/natefox2017/qingfeng/issues/1)
- [Agent 开工规则](AGENTS.md)
- [PixelLab 制作与 Godot 接入](docs/pixellab_pipeline.md)

## 本地准备
```sh
git clone https://github.com/natefox2017/qingfeng.git
cd qingfeng
git pull --ff-only                       # 已安装过旧版时先同步 main
python3 tools/check_scaffold.py
python3 -m unittest discover -s tools/tests -v
```
以上只验证文档/工具。设置 `GODOT_BIN` 指向官方 Godot 4.7.2 后：

```sh
./run_game.sh                       # 自动检查首次 PNG 导入，显示标题后可新建游戏试玩
./run_game.sh --test                # Phase 0：独立新档/农庄/移动/耕作/桥与门的原生回归
./run_game.sh --test-all            # 完整领域/UI/三天闭环回归（耗时更长）
./run_game.sh --editor              # Godot 编辑器，编辑 TileMapLayer / 角色
./run_game.sh --capture ./captures  # 在有图形显示的电脑生成两张原生 P0 截图
```

`run_game.sh` 已带可执行权限，macOS/Linux 可直接运行，也可执行 `sh run_game.sh`。
它调用同一个 `tools/runtime.py` 入口，支持带空格的目录；通过 `GODOT_BIN`、PATH、仓库内已安装的 `.local/godot/Godot_v4.7.2-stable_linux.x86_64` 或 `./run_game.sh --godot "/实际路径/Godot"` 选择**精确版本**的 Godot 4.7.2。第一次从 GitHub 拉取 PNG 后，没有有效的 `.godot/imported` 缓存时会先执行 Godot `--headless --import`。导入失败则**停止启动**并记录 `reports/runtime/asset_import.log`，不会在贴图缺失时悄悄展示工程方块。更新代码不会删除存档或自动下载付费素材。

`--test` 和 `--test-all` 使用隔离的临时游戏副本、用户数据目录，输出可核对的 `reports/runtime/` 日志；不会读取或覆盖你真实游戏存档。`--capture` 使用原生图形渲染、独立测试存档，输出 `phase0_farm_1280.png` 和 `phase0_farm_1920.png`，**不是 headless 伪截图**，也不代替设计稿审查。完整的两尺寸 CI 验证可在 [Phase 0 native evidence](https://github.com/natefox2017/qingfeng/actions/workflows/phase0-native.yml) 查看。

启动工具不会自动安装或联网出图。Linux 可显式执行 `python3 tools/install_engine.py --directory .local/godot` 下载并校验锁定引擎；其他系统从官方发行获取相同版本。模板仅锁定元数据，导出包尚未测试。不要把旧仓库设置为 origin 或复制旧的运行目录。

## 已建立目录
`docs/` 规则与任务导航；`game/` 新运行模块及明确标记的测试场；`art/` 素材登记与生成任务；`schemas/` 机器合同；`templates/` 交接与验证模板；`tools/` 本仓库检查；`.github/` Issue、PR 和 CI。

app、actors、ui、persistence与tests已有入口切片，其他领域仍按Issue开发。职责见 [架构](docs/architecture.md)。[仓库身份及迁入边界](docs/repository.md)。

## Phase 0 首屏怎么验收

在最新 `main` 运行 `./run_game.sh`，选「**新建游戏**」并创建新档，应在 **农庄 · 门前菜园** 看到地形、水岸、农舍、树木、六块田，以及完整像素人物（不是黄色方块）。用 WASD/方向键四向走动；验证农舍前行走、田格 E 互动、树干碰撞和从桥通往村庄。读档列表中带「旧版碰撞测试档」标识的文件是旧兼容夹具，不代表正式农庄存档。

需要留存**实际引擎画面**时，在带图形显示的桌面环境运行 `./run_game.sh --capture ./captures`。该命令通过与正常启动相同的 Godot 版本检查与资源导入，先创建真实新档、验证 `space.farm` 地图/四向精灵并用按键走路，然后输出 `phase0_farm_1280.png` / `phase0_farm_1920.png`。**无图形桌面会明确失败**，不会把 headless 或测试场当成实机截图。正式截图需要审美术构图、遮挡与中文 UI；中文仍为系统字体后备，最终字体、原设计图还原与完整人物/狗动画待 N01/N02/N03/N05 验收。

[切图细则](docs/asset_slicing.md) · [具体玩法](docs/gameplay_details.md) · [旧项目问题复盘](docs/legacy_lessons.md)。
