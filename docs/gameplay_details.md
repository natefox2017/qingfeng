# 首版具体玩法与接入合同

这是**新项目首版玩法的细化规格与当前接入边界**，不是旧项目已有功能清单。当前 Clock、背包/钱包、PlotState、首作物农耕闭环、schema6 存档、第一屏农事输入、农庄↔房屋门、床休息、家庭箱子转移和商店买卖领域已经有实现；WORLD 现已有可编辑 `space.farm`、`space.house`、`space.village`、`space.shop`、`space.workshop` 路线。商店柜台交易页也已直接绑定 `economy.buy` / `economy.sell`；村庄每日可再生采集恢复来源已接入。N08 已开始居民底座：`first_playable_v1` 登记三名稳定 resident_id、职业与普通/雨天 schedule，村庄/商店/工坊提供对应 WORLD-owned home/work/social/rain Marker，纯 `ResidentSchedule` 只把游戏时间与天气解析为目标 anchor/space。**当前三名工程居民都已有运行 Actor**：`resident.neighbor` 在 village 内按 schedule 真实移动；店主/工匠分别在 village↔shop、village↔workshop 复用相同 CharacterBody2D 与门接力。居民必须先实际走到当前 Space 的真实门 Marker，安全 handoff 到目标 Space 的 DoorArrival 后，再从门口继续物理走到 work/social/home/rain 目标；遇静态/玩家碰撞不会穿透，停滞会改轴重规划或等待后重试。未加载的 Space 不伪造后台物理移动，居民会保留在最后合法 runtime 位置，等该区域实际加载后继续。居民会话现已有 transient 生命周期/占用底座，但还没有 WORLD 接近参与、对白 UI 或可观察居民间交流；关系和记忆运行时仍未完成。狗与任务也仍须后续完成。不得把日程解析、工程色块或新档狗名输入当最终人物系统/美术。

## 第一屏与三天目标

固定家门、合法出生点、箱子、菜园、树和一段可过的桥；对象使用同一可编辑布局/足迹。当前工程路线已把 `space.farm` 桥东出口接到独立可编辑 `space.village`，村庄真实门分别进入 `space.shop` 与 `space.workshop`；各场景的碰撞、交互 Marker 与安全落点都由各自 scene 持有，保存可直接从 farm/house/village/shop/workshop 恢复。工坊预留 `WorkbenchInteract` 与 `ServiceAnchor` 给后续居民/委托，当前不伪造 NPC 或服务。村庄/商店/工坊仍是工程布局，不冒充最终 TileSet 或完整公共区域。

第一天目标：起名→进家开箱→与狗出门→工具整地→种子播种→浇水；去店购买/出售可采集物，和两位居民交流，回家床休息。教程成熟田只用于早期反馈，不计玩家自产收成。
第二天目标：观察已浇水作物的变化，再浇水；处理委托/整理箱子，看到居民从工作到公共活动/回家；狗参与一次实际在场经历。
第三天目标：采收自己播种的作物，留存/出售/交付，得到相应钱或任务事实，再补种；保存退出，重启恢复位置、钱物、田、任务和居民记忆。

首个可玩平衡现在由 `game/content/first_playable_v1.json` 唯一给出：12格背包、24格家庭箱子、初始200基础货币、4袋萝卜种子、种子买价20、萝卜卖价35、商店08:00–20:00、2个村庄每日野菜点（各1份、卖价10），以及0.7现实秒/游戏分钟的首版世界时间速率；首作物需要2次有效浇水日结，因此第一天播种浇水、第二天再浇水后第三天成熟。`content_catalog.gd` 严格校验该表，`GameClock` 也从同一表读取日长、06:00日初与现实时间换算。世界激活且没有暂停token时，真实 delta 只通过 GameplaySession→唯一 GameClock 转成 game_minute；背包、家庭箱子、交易、暂停菜单和失焦期间不累计被暂停的现实时间。0.7秒/游戏分钟参考成熟同类单机节奏，只作为 `first_playable_v1` 候选平衡，可后续通过 content_version 调整。视觉、UI和后续农耕/经济不得私设这些数值；正式调整必须改 content_version 并说明三天路线影响。

## 输入优先级

Move仅移动；Interact优先当前可达的门/床/箱子/NPC/柜台；UseSelected只对合法田地或物品目标；SelectSlot只改选择；Cancel只关闭最上层操作并释放本层输入/暂停token。E或鼠标的具体绑定在一个input map定义，不让NPC对白、成熟田与农具同时响应。

距离检查使用世界像素、方向与可达/无遮挡条件，不凭鼠标刚好画在物品上。目标不足、走远、离区、被菜单阻塞时不扣时间/钱物。按钮禁用原因从同一命令校验结果投影，不能UI说可点但底层另套规则。

## 种植命令

| 动作 | 前置 | 提交一次的变化 | 必测失败 |
| --- | --- | --- | --- |
| 整地 | 空可耕格、锄头、范围内、未暂停 | state→tilled，记录玩家动作事实 | 非耕地/隔墙/重复contact不变 |
| 播种 | tilled、指定种子有量 | 原子扣1种子，创建crop_instance_id，state→growing | 缺种子/旧revision/取消不变 |
| 浇水 | 合法耕地/生长株、工具有效 | is_watered=true；已有水按规则no-op，不能重复刷关系/经验 | 工具错误/无目标不变 |
| 日结 | 经过新的日边界 | 湿地作物growth_days+1，达到阈值mature；清湿；last_settled_day防重 | 载入或连按休息不重复结算 |
| 采收 | mature、背包能容纳所有产出 | 一次增物、作物清除、耕地保留 | 满包时整笔拒绝，作物和阴影都不消失 |

动作时序为prepare→contact→recover；准备可取消，contact重新检查权威状态，恢复不再发命令。action的command_id绑定本次操作而不是每帧，新转身/失焦可终止表现但不能重复提交已完成动作。像素帧接触标记见[切图规范](asset_slicing.md)。

当前第一屏工程接入把 `E` 作为唯一世界交互键：WORLD 根据玩家脚位、朝向、28px范围和碰撞射线解析前方 plot；GameplaySession 再根据权威 selected slot + PlotState 规划整地/播种/浇水/采收。暂未有已验收人物农事动画，因此 `farm_action_runner.gd` 用 0.12s prepare / contact / 0.12s recover 作为**工程时序占位**；命令只在 contact 发一次，Esc/失焦在 contact 前取消零变化，contact 后只允许结束表现不回滚。N03 动画验收后必须以动画 manifest 的 contact 帧替换固定时长，但不得改变同一命令边界。

## 背包、箱子与买卖

槽位拥有实际item_id/quantity；空槽null。家庭箱子是 `container.home_chest`，容量来自 content_version。首个切片先实现按 item_id/quantity 的玩家↔箱子整组/定量转移：先同时验证双方 revision、源量、目标堆叠/容量，再一次提交；失败两边都不变。同 command_id 重放原结果，不会重复搬运。先交付选择、使用和整组转移，不为首版引入拖拽复杂度；增加拖拽后仍调用相同命令。
买种子走真实柜台，出售走明确界面；NPC闲聊不能让服务永久不可用。当前领域层提供 `economy.buy` / `economy.sell`：用唯一 Inventory、Wallet、GameClock 和 content_version 在同一无 await 临界段校验营业时间、双方 revision、余额/物品/容量与价格，再原子提交；同 command_id 重放不会重复扣钱或付款。`space.shop` 的稳定 CounterInteract 现用 E 打开真实交易页，页面只投影价格/数量/营业状态并发 buy/sell intent，trade token 独立暂停时钟且 E/B/数字键不穿透；柜台服务不依赖未来 NPC/AI 是否在线。没有种子/钱时，`space.village` 两个稳定 Forage Marker 每日各恢复1份野菜：采集走 `forage.collect`，与 Inventory 原子提交，满包时野菜不消失；同一采集点同日不可重复，保存/重启保持已采状态。两份野菜按当前 sell_price=10 出售后恰好得到20，可买回1袋萝卜种子，因此不会因为把钱和种子耗光而只能重开档。数值属于 `first_playable_v1` 候选平衡。

家庭箱子页面在 `space.house` 通过真实可达 Marker 用 E 打开；背包和24格箱子都来自 GameplaySession projection，点击非空槽整组存入/取出并发送 `storage.transfer`，空槽禁用。页面持有独立 `storage` 暂停/输入 token，Esc 只关闭箱子，E/数字键/B 不会穿透到世界。页面使用同套图标，保留数量、售价、名字与物品说明；空包、满包、目标满、余额不足都有确定提示，关闭窗口不能吞物。

## 狗和居民

狗follow/wait由权威状态决定；召回在实际可达网格上重新规划，卡住先局部让路/等候，再使用明确安全重聚规则，不能为了录屏解除世界碰撞。转场先找到双方合法落点后一起提交，失败双方仍在原Space。
居民拥有职业服务时段、工作/休闲/交流/回家和雨天/夜间变体。当前底座已经把三人的 `resident_id`、`occupation_id`、普通/雨天 schedule 放进唯一 content_version，并让 schedule 中每个 home/work/social/rain activity 必须引用该居民声明的对应 anchor；所有 anchor 必须来自现有 `space.village` / `space.shop` / `space.workshop` Marker，缺锚直接拒绝配置。解析器是纯确定性模块，不移动 Actor、不调用 AI，也不会把商店柜台服务绑到店主是否在场：`CounterInteract` 继续独立提供交易。三名居民现在都消费同一 schedule/runtime 合同：GameplaySession 每个游戏分钟只更新 schedule target，WORLD 保留 CharacterBody2D 的实际位置并通过 move_and_slide 行走；目标变化不改当前位置，堵路会重规划/等待。店主和工匠跨 Space 时，当前场景先把目标切到已有门 Marker，只有 Actor 真正到门后，`main` 才加载目标 scene 合同并验证 DoorArrival/碰撞安全，再把 `ResidentRuntimeState` 提交到目标 Space；目标区域加载后从 DoorArrival 继续物理走向 schedule anchor。未加载区域不做假后台移动。居民实际位置仍由 `ResidentRuntimeState` 持久化，旧 schema5 无该字段时从真实 home Marker 初始化。实际位置和图标头像不是两套身份。`ResidentConversationState` 只管理 transient 会话占用：invite→approaching→participating→end/cancel，同一 actor 同刻只能属于一个会话；玩家离开 Space 会释放该区会话，返回标题/换档会清空全部占用，且这些占用不写 schema6。当前还没有把该状态接到 WORLD 的接近动作或对白页面，因此不能把状态机当成已完成交流体验。玩家对话暂停自己会话，NPC之间交流不停止全部世界。
事实event和记忆summary分离。A亲历事件可以提及，B没有观察或被告知就不能全知；交付/赠礼是不同意图，成功事实才触发进度和关系，重复寒暄和重复礼物有日限，不能无限刷。

## 任务与可选AI

三条指引为安顿、邻里、收成，可任意顺序；奖励领取去重。委托有受理、所需物品、交付、奖励和回访；故事不是只弹“完成”，后续居民行为或对白要反映玩家行动。前置睡觉/居民/室内必须在对应任务前实际可用，不能再发生文档要求未开发功能。

AI仅在居民知情事实范围内增强表达。模型结果带request_id、session、generation、conversation和context_version，迟到/切档/离区丢弃。不给模型钱物、任务完成、价格或位置写权限。无Key/断网/超时使用作者对白，整个三天循环照常可玩。
