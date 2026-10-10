# 开发文档导航

所有正文只维护一份；Notion 与 README 只导航，不复制规则或待办状态。目录框架齐备不表示游戏、素材或账号已经完成。

| 阅读顺序 | 正文 | 回答的问题 |
| --- | --- | --- |
| 1 | [产品](product.md) | 第一版玩家做什么，什么不做 |
| 2 | [视觉、地图、UI](visual_and_ui.md) | 星露谷式相机、像素密度、碰撞遮挡、按钮与字体 |
| 3 | [PixelLab 流水线](pixellab_pipeline.md) | 连接、出图、任务去重、动画、下载、QA、Godot 接入 |
| 4 | [技术架构](architecture.md) | 目录、模块边界、状态唯一拥有者、存档与 AI |
| 5 | [数据合同](data_contracts.md) | 每类字段命名、类型、单位、缺省、版本及样例 |
| 6 | [开发协作](development.md) | Linear 唯一任务源/Board 领取、并行所有权、GitHub PR 与完成标准 |
| 7 | [验收](acceptance.md) | 自动测试、三天路线、多尺寸 UI、导出与证据 |
| 8 | [参考与取舍](references.md) | 实际参考项目和官方能力；为什么采用或不采用 |
| 9 | [仓库身份](repository.md) | 唯一 remote、Notion、历史边界、凭据隔离 |

开发任务、Bug、领取、进度、测试结果与临时交接**仅由 [Linear 晴风谷项目](https://linear.app/gengyun/project/晴风谷-qingfeng-development-747beb5958f6) 管理**，实现证据通过关联 GitHub PR/Commit/CI；Markdown 不维护第二套清单。稳定字段与资产契约仍在唯一长期规范里；旧 `docs/tasks.json` 只因脚手架检查兼容保留，不是有效任务源。

[N05运行基础](runtime_foundation.md)记录已实现的启动、移动及取消/输入生命周期；其余玩法/展示接口仍是开发合同，不是假称已存在的 API。角色身份、精确平衡与最终美术须在对应任务的数据和样板中落定。

## 本轮可执行切片与制作细则

- [入口页面/新建/读取导入/设置/暂停保存](entry_pages.md)：代码已建立，目标场景仍是碰撞夹具。
- [具体玩法与三天路线](gameplay_details.md)：后续实施规格，不假称农耕已实现。
- [详细切图/锚点/帧事件/图集工具](asset_slicing.md)：PixelLab交付到Godot的明确边界。
- [第一章美术资源实际验收与交接](chapter1_asset_qa_handoff.md)：四张定版母版、Batch 01 静态测试、未完成的 Godot Native/视觉签收和接手顺序。
- [qingfenggu历史问题与新防线](legacy_lessons.md)：只总结用户提供的历史材料，标清来源与未验范围。
