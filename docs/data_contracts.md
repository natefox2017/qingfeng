# 数据与命名合同 · QINGFENG-1

以下是新实现的边界合同，不是假称运行API已经存在。所有自有字段 snake_case；第三方 PixelLab 原始字段在适配器边界保留，不污染领域命名。完整动作 payload 随首个实施 PR 增加严格 schema 与样例，不用任意字典隐藏未定义参数。

## 命名
文件/目录/函数/变量/信号 snake_case，类/节点 PascalCase，常量/枚举 CONSTANT_CASE。布尔 is_/has_/can_ 或 _enabled；结果 ok 为固定例外。ID 字段 _id，集合复数或 _ids，数字索引从0开始。
稳定值如 space.farm、space.shop、plot.farm.001、item.radish_seed；显示名改变不换ID。正式路径不含 candidate/trial/current/latest/final 或日期等开发状态；new_game 是语义动作允许。
所有字段新增时写准确拼写、类型、必填/缺省、空值、范围、单位、坐标系、写入者、是否存档与迁移。不混用缺字段/null/0/空串，不以bool冒充int。

## 离散命令/结果
| 字段 | 类型与约束 |
| --- | --- |
| protocol_version | int，1；未知版本拒绝 |
| command_id | string，1–128字符；同会话内唯一 |
| session_id | string，当前世界身份，不由UI改写 |
| actor_id | string，已注册实体 |
| action | string，已登记如inventory.transfer |
| expected_revision | int>=0，操作所依赖的领域修订；跨领域在payload声明所需版本 |
| payload | action的严格结构；未知键/错类型拒绝 |
| ok | bool |
| error_code | string；成功为空，失败稳定大写码 |
| is_retryable | bool；指可在重新验证后再尝试 |
| has_changes | bool；指业务状态，不指回执存储是否变化 |
| revision | int>=0；提交后领域修订，失败不假增 |
| event_ids | string[]；成功事实，失败空列表 |

结果携带原 command_id；对请求的action/actor/payload/version做规范摘要。同ID同请求返回已记录结果；同ID不同请求报 COMMAND_ID_CONFLICT。已记录的可重试失败，条件变化后用新ID重试；提交结果未知时用原ID查询/重放，避免双扣。

首个商店命令：`economy.buy` / `economy.sell` 的 `expected_revision` 是玩家 Inventory revision；payload 严格为 `{item_id:string, quantity:int 1..9999, wallet_revision:int>=0}`。价格和08:00–20:00营业窗口只读 `first_playable_v1`；handler 在同一同步临界段校验营业时间、商品可买/可卖、双方revision、余额/源量/目标容量，再提交 Inventory + Wallet。失败双方不变，交易页即使持有时钟暂停token也以被冻结的 game minute 判断营业状态。
首个采集命令：`forage.collect` 的 `expected_revision` 是 Forage revision；payload 严格为 `{spot_id:string, inventory_revision:int>=0}`。当前日来自唯一 GameClock，奖励 item/quantity/respawn_days 来自 content_version，spot_id/space/几何来自 `space.village` Marker。Forage + Inventory 在同一同步临界段提交；满包、已采、stale 都不改变两边。
居民日程内容合同：`residents.daily_greeting_limit:int>0`、`daily_gift_limit:int>0`、`definitions` 当前恰好三名稳定 `resident_id`。每名居民拥有 `display_name`、`occupation_id`、`home_anchor_id`、`work_anchor_id`、`social_anchor_id`、`rain_anchor_id` 及 `schedule` / `rain_schedule`；schedule entry 严格为 `{start_minute:int, activity_id:string, anchor_id:string}`。普通表只允许 home/work/social，雨天表只允许 home/rain；每个 activity 必须引用该居民声明的对应 anchor，首项从 day_start_minute 开始，末项回 home。WORLD 提供 `{anchor_id, space_id, world_position_px}` Marker 定义；`ResidentSchedule` 只读 Clock/天气并解析目标，不写 Actor 位置、不发模型请求。`ResidentRuntimeState` 与 schedule target 分离，只持有实际 `resident_id/space_id/world_position_px/facing/relationship_points/known_event_ids`；当前 WORLD 在离区与保存前采样真实 Actor，加载/重入区域时恢复实际位置，再由 schedule 决定下一目标。
物理移动不走持久回执。回执生命周期由CORE明确：当前会话保存；未来压缩需防重语义设计，不可悄悄按数量截断。

## 快照与内容
| 结构 | 字段/类型/单位与拥有者 |
| --- | --- |
| SaveEnvelope | save_format:string固定qingfeng；schema_version:int，入口夹具=1、无回执玩法快照=2、持久化命令回执=3；content_version:string；save_id:string；saved_at_utc:string UTC ISO8601；snapshot:严格对象；checksum:sha256；由persistence写 |
| SessionState | session_id:string；generation:int>=0；领域快照；由app/session管理 |
| ClockState | game_minute:int>=0，自第1天00:00累加的游戏分钟；非UTC；由Clock写。现实时间换算率不进快照，来自content_version的real_seconds_per_game_minute:number>0 |
| ActorState | actor_id/display_name/appearance_id/space_id:string；world_position_px:{x:number,y:number}；facing:north/south/east/west；由运动/会话交接 |
| DogState | ActorState加mode:follow/wait，last_safe_anchor_id:string；recall是命令，不是第三份坐标 |
| ContainerState | container_id:string，capacity:int>0，slots:固定容量数组；空槽null，否则item_id:string、quantity:int>0；玩家背包由Inventory写，家庭箱子由Storage写 |
| WalletState | owner_id:string，money:int>=0，基础货币单位；禁浮点钱；由经济写 |
| PlotState | plot_id/space_id:string，cell_position:{x:int,y:int}，state:untilled/tilled/growing/mature，crop_id:string或null，growth_days:int>=0，is_watered:bool，last_settled_day:int>=0；由农耕写 |
| ForageState | revision:int>=0；spots:[{spot_id:string,last_collected_day:int>=0}]；spot几何/forage_id由WORLD Marker定义，状态只记录采集日；由Forage写 |
| QuestState | quest_id:string，status:active/completed，objective_progress:按objective_id的非负int，is_reward_claimed:bool；由任务写 |
| ResidentState | ActorState加occupation_id/activity_id/home_anchor_id:string，known_event_ids:string[]，relationship_points:int；由居民写 |
| FactEvent | event_id:string，source_command_id:string或null（系统事件须另标source_system），kind/space_id:string，game_minute:int，participant_ids:string[]，严格payload；提交后创建 |
| MemorySummary | resident_id:string，source_event_ids:string[]，summary_text:string，updated_at_game_minute:int；主观摘要，不替代事实 |

首个完整玩法存档机器合同见 `schemas/save_v2.schema.json`；当前写入版本为 `schemas/save_v5.schema.json`。schema 5 在 schema 4 基础上加入 `forage` 每日采集状态；旧 schema 4 读取时由当前 WORLD forage definitions 初始化当日可采点，下次保存升级为 schema 5。schema 4 在 schema 3 的幂等回执基础上加入 `storage` 家庭箱子快照；旧 schema 3 读取时显式迁移为空箱子，下一次正常保存升级为 schema 4。schema 3 在 Clock / Inventory / Wallet / Farm 之外保存当前会话 `CommandJournal` 回执（最多512条，仍受256 KiB文件上限约束），使同 command_id 同请求在保存重启后继续回放原结果，同ID异请求继续冲突。schema 2 继续只读兼容，读取时不会伪造历史回执；用户主动导入副本会生成新 session_id，并清空源会话回执，因为指纹绑定原 session_id。地图 plot 坐标的最终合法性仍由加载后的 WORLD 布局 + `GameplaySession.restore()` 再验，存档不能成为第二份地图来源。schema 1 只保留当前碰撞入口夹具兼容。

嵌套对象须在实施前补机器schema；上表未规定的业务上限由content_version表定义，不散落代码。首个运行表是 `first_playable_v1`（机器结构见 `schemas/content_version.schema.json`，运行校验见 `game/content/content_catalog.gd`），当前固定12格背包、24格家庭箱子、200初始货币、4袋首作物种子、2个每日野菜采集点（各1份、卖价10）、三名居民及其普通/雨天日程、06:00日初、0.7现实秒/游戏分钟和08:00–20:00商店窗口；后续领域/UI只读取，不复制。新档发物只一次，所有发布所需领域一起验证/恢复；不得加载旧项目格式或访问旧用户目录。
地形格16px不等于导出屏幕像素。cell_position是整数地图格，source_anchor_px是源图片左上角坐标，world_position_px是未缩放世界像素，viewport_position_px是渲染视口坐标；转换由布局统一。

## 布局对象与UI
Door字段：object_id、space_id、target_space_id、arrival_anchor_id、companion_anchor_id；字符串ID，目标必须实际存在。碰撞足迹/Marker保存在布局组件，不能同时在逻辑JSON重写第二份坐标。
UI只消费 revision、items、selected_slot_index、is_enabled、disabled_reason、pending_command_id 等明确投影。pending只指在途本地操作；关闭页面取消预备动作并释放对应暂停/输入token。

## AI请求
request_id、session_id、generation、resident_id、conversation_id、context_version、source_event_ids是请求身份；timeout_msec为现实毫秒。回包身份不符/上下文失效则丢弃。provider token不在快照/日志中，关键钱物数字由本地UI文本生成。

## 素材与生成
[素材 schema](../schemas/asset_manifest.schema.json) 是运行素材登记的机器合同，[空清单](../art/manifest.json)不是“没有素材也通过视觉验收”。
asset_id/string稳定，runtime_path/仓库相对路径，sha256/64位小写hex，source_url/公开来源页，source_version/string，license_id/string，license_path/本地许可，size_px/{width:int,height:int}，source_anchor_px/{x:number,y:number}，review_status/proposed|validated|accepted|rejected，reviewer/string或null，evidence_paths/string[]。
animations每项：animation_id、direction、frame_count:int>0、frame_durations_msec:正数数组、contact_frame:int或null、contact_offset_msec:number或null、is_looping:bool；实际帧数/事件区间须匹配导出文件。
jobs记录request_hash、asset_id、tool_name、status、attempt:int>=1、submitted_at_utc、各阶段*_msec和failure_reason；token和具下载权限的job URL留私密本地日志。generation_id属于素材供应方，不要与会话generation混用。

## 版本
自有JSON全snake_case；修改结构/语义要升schema或protocol版本和迁移测试。内容平衡改content_version，纯显示文案不重建对象ID。manifest来源哈希验证与游戏存档checksum分开，两者都不证明视觉正确。

字体kind=font，size_px/source_anchor_px为null且animations为空；不得为通过图像校验伪造字体画布/脚锚。其他kind为terrain/object/character/animation/icon，使用真实图像尺寸。
