# 晴风谷 · Qingfeng

**唯一开发仓库：[natefox2017/qingfeng](https://github.com/natefox2017/qingfeng)。** 从空白开始，不导入旧项目代码、图片、存档或 Git 历史。

一个以星露谷式固定俯视像素表现为目标、结合农庄生活与有记忆居民的单机游戏。首版先完成三天可玩的生活循环；PixelLab 用于开发期制作素材，运行中的游戏不依赖 PixelLab。可选 AI 对白与本地玩法权限分离。

## 当前状态
`scaffold`：文档、目录职责、数据合同、素材流水线、任务与检查工具已经建立。**还没有可启动的 Godot 工程，没有已验收游戏图片。PixelLab 连接与实际付费出图未验证。** 所有功能进度只看 Issue，不以本 README 推断完成。

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
以上只验证开发基础，不启动游戏、不联网出图、不消耗额度。Godot 精确版本、实际启动入口和导出模板由 WORLD 任务核验后锁定。不要把旧仓库设置为 origin 或复制旧的运行目录。

## 已建立目录
`docs/` 规则与任务导航；`game/` 未来运行模块；`art/` 素材登记与生成任务；`schemas/` 机器合同；`templates/` 交接与验证模板；`tools/` 本仓库检查；`.github/` Issue、PR 和 CI。

游戏模块目录当前仅占位，职责见 [架构](docs/architecture.md)。[仓库身份及迁入边界](docs/repository.md)。
