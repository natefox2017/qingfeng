# 晴风谷 · Qingfeng

**唯一开发仓库：[natefox2017/qingfeng](https://github.com/natefox2017/qingfeng)。** 从空白开始，不导入旧项目代码、图片、存档或 Git 历史。

一个以星露谷式固定俯视像素表现为目标、结合农庄生活与有记忆居民的单机游戏。首版先完成三天可玩的生活循环；PixelLab 用于开发期制作素材，运行中的游戏不依赖 PixelLab。可选 AI 对白与本地玩法权限分离。

## 当前状态
`foundation`：Godot 4.7.2已接通中文标题、新建身份、读取/导入存档、设置预览回退、可取消加载、碰撞测试场及暂停保存返回。**当前只保存身份与测试场位置；没有正式地图、狗、农耕或背包。PixelLab连接/出图和随包中文字体尚未完成。** 边界见[入口合同](docs/entry_pages.md)，旧基础验证见[历史记录](docs/runtime_foundation.md)。

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
python3 tools/check_scaffold.py
python3 -m unittest discover -s tools/tests -v
```
以上只验证文档/工具。设置 `GODOT_BIN` 指向官方 Godot 4.7.2 后：

```sh
./run_game.sh                    # 根目录一键启动，进入正式标题
python3 tools/runtime.py editor  # 编辑该入口与原生场景
python3 tools/runtime.py test    # 隔离用户数据，冷导入并运行回归
```

`run_game.sh` 已带可执行权限，macOS/Linux 可直接运行，也可执行 `sh run_game.sh`。
它仅调用现有 `tools/runtime.py run`，支持从其他工作目录启动和带空格的仓库路径；
引擎仍通过 `GODOT_BIN`、PATH 中的 `godot`/`godot4`，或 `./run_game.sh --godot "/实际路径/Godot"` 选择。
需先安装 Python 3 和锁定版本的 Godot；脚本不自动下载安装、不拉取代码、不删除文件或修改存档。

启动工具不会自动安装或联网出图。Linux 可显式执行 `python3 tools/install_engine.py --directory .local/godot` 下载并校验锁定引擎；其他系统从官方发行获取相同版本。模板仅锁定元数据，导出包尚未测试。不要把旧仓库设置为 origin 或复制旧的运行目录。

## 已建立目录
`docs/` 规则与任务导航；`game/` 新运行模块及明确标记的测试场；`art/` 素材登记与生成任务；`schemas/` 机器合同；`templates/` 交接与验证模板；`tools/` 本仓库检查；`.github/` Issue、PR 和 CI。

app、actors、ui、persistence与tests已有入口切片，其他领域仍按Issue开发。职责见 [架构](docs/architecture.md)。[仓库身份及迁入边界](docs/repository.md)。

## 入口页面与存档切片

在新运行基础上补充标题、新建名字、存档列表、外部.qfsave导入预览确认、设置预览回退和暂停保存返回。当前只保存身份与碰撞测试场坐标，不是已完成农庄。启动 `./run_game.sh`；测试 `python3 tools/runtime.py test`（固定引擎参数见[入口合同](docs/entry_pages.md)）。新页面使用普通中文无衬线后备字体，字体尚未随包交付；PixelLab未连接/未出图。

[切图细则](docs/asset_slicing.md) · [具体玩法](docs/gameplay_details.md) · [旧项目问题复盘](docs/legacy_lessons.md)。
