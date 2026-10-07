# 晴风谷 · Qingfeng

**唯一开发仓库：[natefox2017/qingfeng](https://github.com/natefox2017/qingfeng)。** 从空白开始，不导入旧项目代码、图片、存档或 Git 历史。

一个以星露谷式固定俯视像素表现为目标、结合农庄生活与有记忆居民的单机游戏。首版先完成三天可玩的生活循环；PixelLab 用于开发期制作素材，运行中的游戏不依赖 PixelLab。可选 AI 对白与本地玩法权限分离。

## 当前状态
`foundation`：现在有可启动的 Godot 4.7.2 工程：标题 → 可取消加载 → 移动/碰撞测试场 → 暂停/继续 → 返回标题。**这是工程夹具，不是正式农庄或可玩首版；没有最终美术、狗、农耕、背包和存档实现。PixelLab 连接与实际付费出图仍未验证。** 进度看 Issue #6，结果与边界见[运行基础](docs/runtime_foundation.md)。

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
python3 tools/runtime.py run     # 唯一主入口
python3 tools/runtime.py editor  # 编辑该入口与原生场景
python3 tools/runtime.py test    # 隔离用户数据，冷导入并运行回归
```

启动工具不会自动安装或联网出图。Linux 可显式执行 `python3 tools/install_engine.py --directory .local/godot` 下载并校验锁定引擎；其他系统从官方发行获取相同版本。模板仅锁定元数据，导出包尚未测试。不要把旧仓库设置为 origin 或复制旧的运行目录。

## 已建立目录
`docs/` 规则与任务导航；`game/` 新运行模块及明确标记的测试场；`art/` 素材登记与生成任务；`schemas/` 机器合同；`templates/` 交接与验证模板；`tools/` 本仓库检查；`.github/` Issue、PR 和 CI。

app、actors 和 tests 已有首个工程切片，其余领域目录仍占位。职责见 [架构](docs/architecture.md)。[仓库身份及迁入边界](docs/repository.md)。
