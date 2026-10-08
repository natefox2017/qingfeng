# 外部参考与取舍

查阅日期：2026-10-07。开工再核对动态工具schema/许可；本页不是把所有参考项目都称商业成功，也不是转载代码。流程取自现有产品与工具能力，不取自旧项目自己的阶段堆叠。

| 来源 | 本轮采用 | 明确不采用 |
| --- | --- | --- |
| [Stardew官方](https://www.stardewvalley.net/press/) | 农庄/邻里完整循环及官方画面作比例对照 | 不分发原游戏图集，不声称空架子已匹配 |
| [Stardew日周期](https://stardewvalleywiki.com/Day_Cycle) | 单机世界时间约0.7现实秒/游戏分钟，菜单/对话等交互暂停时间；作为首版节奏与暂停语义对照 | 不复制其20小时日制、事件规则或具体实现代码；晴风谷仍由自己的content_version与单一Clock决定 |
| [Tiled的tBIN说明](https://doc.mapeditor.org/en/latest/manual/export-tbin/) | 可编辑分层地图的数据思路；其文档说明Stardew使用tIDE | 不因此增加Tiled/tIDE导入链 |
| [a16z架构](https://github.com/a16z-infra/ai-town/blob/main/ARCHITECTURE.md) | 玩家/agent输入、状态写入边界、会话与慢请求分开、generation失效 | 不搬Convex/PixiJS/Web栈，不给本地操作增加服务端批处理延迟 |
| [a16z许可](https://github.com/a16z-infra/ai-town/blob/main/LICENSE) | 实际移植MIT代码须保留版权与许可证 | 不能外推为所有图片/音乐的许可 |
| [my_ai_town](https://github.com/mewamew/my_ai_town/blob/main/README.md) | 职业/场所/经历驱动交流、客观事实与私人理解分离 | README说明统一许可未发布，先不复制其源码、提示词和自有图 |
| [Godot场景](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) | 小场景、明确依赖、职责组合 | 不创建深层候选继承链 |
| [Godot地图](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilemaps.html) | TileMapLayer、外部共享TileSet、编辑布局/碰撞 | 不用生成效果图充当地图，不维护第二套手写墙坐标 |
| [PixelLab MCP](https://api.pixellab.ai/mcp/docs) | 官方资产工具、异步任务、关联角色/地形引用 | 不把MCP工具名当REST、不让运行游戏必须生图 |
| [PixelLab使用方式](https://www.pixellab.ai/docs/ways-to-use-pixellab) | 远程MCP、Web/编辑器导出，按实际客户端配置 | 不虚构安装包，不泄露token |
| [PixelLab Tileset](https://www.pixellab.ai/docs/tools/create-tileset) | 先可连接地形组，匹配Godot模式后使用 | 不假定返回图已包含游戏碰撞 |
| [PixelLab Tiles Pro](https://www.pixellab.ai/docs/tools/create-tiles-pro) | 缺明确连接/建筑组件时评估 | 不默认购买高成本方案 |
| [PixelLab条款](https://www.pixellab.ai/termsofservice) | 使用前留条款版本与输入权利记录 | 不标CC0，不保证独占版权，不转售服务 |
| [Noto CJK字体许可](https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE) | 核验具体无衬线文件与OFL后随包提供 | 不把字体安装在开发机当交付 |

my_ai_town本轮读取README blob为20db3eef86072db785470b104a7078e49d405b01。a16z架构是实现参考，具体复制时须另登记commit与文件；本基线没有导入这些项目的运行代码。
每项新依赖记录版本/文件hash、许可证、用途、替代方案、维护代价。生成风格、软件协议和法规可能变化，以开工时实际官方返回为准，不把工具宣传的时间估计写成项目性能承诺。
