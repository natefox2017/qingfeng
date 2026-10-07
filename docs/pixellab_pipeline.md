# PixelLab 素材生产与 Godot 接入

## 1. 定位与当前连接状态
PixelLab 是开发期像素素材工具，不是地图坐标权威，不进入发布包，不在玩家进入游戏时生成图片。GitHub 负责版本，Godot 负责地图和物理，PixelLab 负责所缺图块/对象/角色/动画，像素编辑器负责必要局部修整。
本基线已查阅 [官方 MCP 文档](https://api.pixellab.ai/mcp/docs) 与 [使用方式](https://www.pixellab.ai/docs/ways-to-use-pixellab)。当前会话未取得可调用的 PixelLab 连接，账号、预算、真实生成均未验证。加入本流程不等于安装或出图完成。

## 2. 连接与权限
优先使用官方远程 HTTP MCP：`https://api.pixellab.ai/mcp`。按当前客户端在官方设置页取得配置；[连接示意](../templates/pixellab_connection.example.json)不是保证所有客户端通用的可直接执行文件。
Bearer token 只放客户端私密配置或未跟踪环境，不能进 Git、截图、日志、存档。`.env.example` 只是变量名模板，不能假定客户端自动读取。配置好后先确认 list/get 等只读工具和身份；不得为了测连接先发付费生成。
本次只授权建立流程。首次真实生成需确认账号已有额度和本批预算；不自动购买订阅、充值或开启高成本模式。MCP 不需要虚构 npm 包；编辑器插件与 REST API 是不同接入路径，不能拼接工具名当 REST endpoint。没有 MCP 时可用官方 Web 导出同一交付格式；自动 API 适配须另读当前官方 v2 schema，并取得所需授权。
本仓库不锁死某客户端版本或复制带 Key 的一键配置。[官方使用方式](https://www.pixellab.ai/docs/ways-to-use-pixellab)用于实际设置。

## 3. 先定样板，不盲生成
每项任务先填 [素材请求](../templates/asset_request.md)：asset_id、用途、候选 style_id、原生格、目标内容尺寸、方向、脚锚、状态、必要动作、接触目标、来源、预算及验收。
当前 [style_profile](../art/style_profile.json)只是 proposed。16px 地形、角色内容高度和参考相机先用同一小场景对照；不能因模型输出48/64px画布就强行让人占三四格，也不能把48px自动缩成16px宣称统一密度。
从真实有权使用的参考锁定风格。保持同一 character_id/base tile 引用，缺件才增加；允许的现成开源图集先核比例和许可，不因免费而混搭多个画风。

## 4. 工具选择
以下是本轮官方工具说明的采用方向，**每次调用以实际暴露的 schema 为准**，不是仓库实现的函数。

| 任务 | 官方能力与选择 | 项目要求 |
| --- | --- | --- |
| 四向玩家/居民 | create_character，再 get_character | 先定身份和比例再动画；检查模式是否忽略 n_directions |
| 狗 | character 四足配置与 dog 模板（可用时） | 必须审实际四向，不拿正面两帧代替 |
| 行走/工具动作 | animate_character | 使用实际支持模板；自定义挥锄不假称有现成模板 |
| 地形接缝 | create_topdown_tileset / get_topdown_tileset | 同 base tile 串接草地、路、岸；显式设置 view |
| 树、桥、建筑部件 | create_map_object 或适合的图块工具 | 独立透明组件；画面不携带世界坐标/碰撞 |
| 路径/建筑套件扩展 | create_tiles_pro（确有需求且成本批准后） | 先验证结构和兼容性，默认不升级高成本方案 |
| 图标/局部缺陷 | 合适的 image/edit/inpaint 工具 | 同一视觉族，保留编辑前后文件，不生成字体或按钮文案 |

角色与地形工具的默认 view 不一定相同；显式对齐候选视角。模式可能忽略方向/帧数参数，先读返回信息再排产。工具成功不保证一致性。
来源：[MCP](https://api.pixellab.ai/mcp/docs)、[Tileset](https://www.pixellab.ai/docs/tools/create-tileset)、[Tiles Pro](https://www.pixellab.ai/docs/tools/create-tiles-pro)、[字符导出](https://www.pixellab.ai/docs/ways-to-use-pixellab)。

## 5. 小批次排产
批次A：草—土路、草—岸、水、干湿田，以及房屋/树/桥组成第一屏标尺。
批次B：一个玩家和一只狗，四向 idle/walk；玩家向下挥锄 contact 样板。A/B可并行，但用同 style_id。
批次C：其余必需农事方向和状态、少量物品图标、三居民身份；只有A/B问题已定位再扩。不先生成全村全部动作。
先下载并审父资产再扩关联，虽然工具可以排队，也不把未通过的身份扩散到所有方向。任务依赖以接受的组件为粒度，不等待全游戏美术。

## 6. 异步任务、慢与重复费用
项目记录状态：requested → submitted → processing → downloaded → validated → accepted；失败另为 failed/rejected，结果未知标 unknown，不冒充失败后重新下单。
提交前计算规范参数和参考哈希的 request_hash；把返回 job_id 立即存入未跟踪的本地任务日志。恢复工作先查询原任务；网络超时不知道提交结果时先查历史，不自动重新 create。project asset_id 与远端 job_id 分开，换图不换游戏对象 ID。
初始本地策略：最多2个在途任务，查询间隔15/30/60秒逐步退避；这是可调整工作规则，不是厂商配额。读取限流提示/Retry-After；失败重试只针对已确认原因，连续两次同问题退回输入/方法检查。退订/删角色/删远端记录从不自动执行。
分别记录生成、下载、修整、导入、回归时长与重试；没有计时就不说“快几倍”。费用估算和已消费记录分开，credits/generations/USD不可混算。
远端下载链接可能临时有效或凭ID可访问，应尽快保存到获准的私有归档，不能把能力链接公开当长期素材库。记录来源页、输入/输出 SHA、导出版本、必要的私有任务关联；密钥及带权限下载URL不进仓库。

## 7. 下载与验证
官方导出 PNG/帧序列和元数据先放 `.local/art_downloads/`，计算原始 SHA256，再归档可编辑源、导出图集及脱敏收据；新归档不删旧云文件、不放宽共享。仓库只提交需要的运行素材、许可及[清单](../art/manifest.json)。
文件/许可验证：真实大小、alpha、画布/图集边界、帧数量/时长、缺失方向、来源、输入参考权利。不要用 provider 成功状态代替这些检查。
视觉验证：统一像素密度、脚底根锚、轮廓不裁断、工具接触目标、停走/急转、接缝内角外角。像素修整留变更记录，不把截图裁下当新源图。

## 8. Godot 的明确转换边界
Wang tileset 图片不是现成 Godot TileSet。根据导出角点/连接标签建立 terrain 对应，明确采用角点还是边连接模式；不把位掩码数字或图集位置原样猜配。全组合、孤岛、窄路、内外角、桥岸测试后共享外部 .tres。
地图只在原生可编辑场景中铺设；数据引用 asset_id/object_id。图块变化增量导入，移动位置不重新生成图片；禁止运行时重刷布局覆盖编辑。
帧表转换到 SpriteFrames；动画 contact 由实际帧/时长标记驱动，不写死 execute=1。keep_first_frame 等选项可能改变最终帧数，以下载结果为准。本地碰撞足迹、门落点与交互范围不由生成图猜出。
合入前验证：引擎冷导入、实际资源加载、真实通行、同镜头画面、背包多尺寸与导出包。来源SHA检查在制作/构建期，运行只验证导入后的资源可加载。

## 9. 授权与“完成”
[PixelLab条款](https://www.pixellab.ai/termsofservice)说明其服务对生成作品的使用授权，并限制程序化服务入口；仍须核对输入参考和第三方权利，不能把生成结果标为CC0或保证任何司法辖区都产生独占版权。
素材的 validated 表示技术校验，accepted 表示有指定审查与证据；二者不同。manifest 中记录 reviewer、证据、哈希和修订。真实出图/完整动画/平台字体未验时按项保留未验，不以流程文档或样板冒称完成。

## 可执行交付边界补充

实际Atlas导入规则与离线工具见[切图规范](asset_slicing.md)；初次制作请求见[entry_batch](../art/requests/entry_batch.json)。它们尚未提交PixelLab，不含远端任务ID或费用消耗。入口页当前使用原生工程图标，不能称作PixelLab素材。
