# 入口页面与存档流程

本页区分**当前可运行代码**和**最终游戏目标**。基于独立新工程，不恢复qingfenggu代码。新档现在进入唯一 `space.farm` 第一屏工程布局并创建 `GameplaySession`；schema 1 历史入口档仍只进入显式碰撞夹具。农庄当前是可编辑布局与工程皮肤，不冒充最终像素美术。

## 页面与生命周期

| 页面 | 正常路径 | 取消/异常 | 当前实现 |
| --- | --- | --- | --- |
| 标题 | 继续最近有效档、新建、存档、设置、退出 | 无有效档时继续禁用；仍能导入/新建 | 已接通 |
| 新建 | 玩家名1–16字、狗名可空；确认后可取消加载 | 拒绝空名/控制字符；重复点击不再创建；加载取消不写档 | 已接通；没有外观选择或真实狗 |
| 存档列表 | 列出本机.qfsave，可读/坏档分开；选中读取 | 坏档显示错误，不按原路径创建新档覆盖 | 已接通；最多128份，暂不提供删除 |
| 导入 | 文件选择→有界JSON校验→元信息预览→确认新副本 | 取消不写盘；输入文件不变；外来save_id不作本地路径 | 已接通；仅支持当前新格式 |
| 设置 | 主音量、全屏、VSync→预览→10秒内确认落盘 | Esc/失焦/超时恢复；保存失败恢复且提示 | 已接通；无正式音频素材、未做重映射 |
| 加载 | 原生后台资源请求→主线程实例化→物理落点检查→新档提交→世界 | generation拒绝旧结果；缺场景/错误契约/墙内落点留在标题且不覆盖档 | 已接通；玩法档可从 farm/house/village/shop/workshop 当前区域恢复 |
| 世界HUD | 玩家名、当前世界、日时、金币、12格快捷栏、背包入口 | 背包/箱子/交易/暂停/失焦各自持有输入与时钟token | 已接通；农庄、家、村庄、商店、工坊均复用同一 GameplaySession；village 已有首名工程居民实体按 schedule 实际移动，柜台交易继续独立于居民是否在场 |
| 暂停 | 继续、保存新副本、设置、保存并返回 | 保存失败留在会话；关窗提示先保存，不悄悄退出 | 已接通 |
| 交易 | 商店柜台 E 打开；显示营业时段、金币、可买商品与背包可售物；买/卖1件 | 打烊按钮禁用并说明；领域仍重验余额/容量/数量/revision；Esc只关交易页 | 已接通工程版；不依赖NPC/AI，最终图标与商店美术未完成 |

状态由game/app/main.gd管理，menu_view只投影界面并发意图。普通标题按钮保留必要短标签；按钮内部是native line icon，tooltip和无障碍名齐备，不烘焙文字到图。新建、读取等表单保留内容文字，不能为了“全图标”丢失信息。

布局采用原生容器，640×360逻辑视口；1280×720与1920×1080实机分别核对。配色/图标为可替换的工程皮肤，不是已接受PixelLab美术。当前中文通过无衬线SystemFont后备链显示；字体**尚未随包发布**，N07完整字体验收仍未完成，不能把开发机Noto字体当发行资产。

## 新存档协议的具体边界

`session_codec.gd`现在认识六代明确格式：schema 1 / `entry_fixture_v1` 兼容旧碰撞入口；schema 2 保存 Clock/Inventory/Wallet/Farm；schema 3 加入命令幂等回执；schema 4 加入24格家庭箱子 Storage；schema 5 加入村庄 Forage 采集状态；当前新写入的 schema 6 再加入三居民实际运行状态，机器合同见 `schemas/save_v6.schema.json`。schema 1–5 仍可读取；缺后续领域的旧版本按各自迁移规则初始化，并在下一次正常保存升级。

`main.gd` 现在按存档 `space_id` 明确分流：`space.farm`、`space.house`、`space.village`、`space.shop`、`space.workshop` 各自加载唯一可编辑 Godot 场景；场景实例化和物理同步后，GameplaySession 始终使用 farm WORLD 的稳定 plot definitions，完整 restore 成功后才发布会话。schema 1 旧入口档继续进入碰撞夹具且没有 GameplaySession。schema 2 与当前 WORLD 的 Space/plot 几何不一致时整笔拒绝，不会只恢复名字/坐标或把存档中的 plot 坐标当地图来源。

.qfsave为纯UTF-8 JSON，不调用ResourceLoader、str_to_var、load/save Resource或对象反序列化。最大256 KiB，嵌套最多12层，容器成员有界；拒绝重复key（包括Unicode转义同名）、未知字段/版本、错误类型、bool坐标、非有限坐标、非UTF-8和无效标记。校验JSON数字时规范化整数值，解决Godot解码为float后1/1.0校验码不一致的问题。

SHA256用于损坏检测，**不是防作弊签名/信任认证**。通过校验的坐标仍在世界实际物理空间中检查；落在墙内时拒绝读取，不悄悄传送到别处。不支持旧项目存档或未知content_version。schema 1 仍只允许碰撞夹具 Space；schema 2 允许正式 Space 字符串，但文件层只做结构/数值检查，加载后仍必须由真实 WORLD 布局验证 Space、落点和 plot 几何，不能凭存档移动地图。

`session_store.gd`写入user://qingfeng/saves：临时文件→flush/关闭→读回验证→新随机ID文件rename。采取最多128份的追加式保存，不覆盖已有文件；每次导入是新本地save_id和新session_id。schema 3 导入时会清空源会话 command receipts，因为回执指纹绑定原 session_id，不能复制成新会话的幂等历史。没有自动删除或按大小淘汰，达到上限会明确失败。列表按写入时间排序；导入重新写本机时间，原文件保留。

新游戏在农庄场景、WORLD layout、GameplaySession 和出生点全部验证后才写第一份当前 gameplay 档；写盘失败不进入会话。加载原档不自动重写。当前 schema 5 保存会同时更新位置/朝向以及 Clock、Inventory、Storage、Wallet、Farm、Forage 和 CommandJournal；schema 1 兼容档仍只保存原身份/测试场位置。导入预览保存已验证的内容副本，确认时再次验证，不重读可能已被外部修改的源路径。

## 设置语义

只有一个settings_store，没有标题/世界两套服务。draft→preview→confirm；未确认不持久化，独立于游戏存档。声音改真实Master总线，显示只在有DisplayServer的原生环境操作；headless仅验证状态。正式音频、更多设置与跨平台显示体验仍需要后续任务。

## 操作与复现

```sh
python3 tools/runtime.py run --godot /path/to/Godot_v4.7.2-stable_linux.x86_64
python3 tools/runtime.py test --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 --report-dir reports/runtime
```

测试从隔离的user://和冷工程副本开始，旧236项物理/生命周期断言保留；新增入口存档用例另计数。实际原生捕获脚本：

```sh
"$GODOT_BIN" --path game --audio-driver Dummy --script res://tests/page_capture.gd -- /tmp/qingfeng-pages
```

捕获覆盖标题、新建、加载、世界、暂停、设置、列表与导入确认的两种窗口尺寸。调用页面信号用于确定性复现，不冒充完整鼠标自由试玩。发布包、正式美术和三天农耕路线尚未验收。

## 本批验证记录（待远端CI绑定提交）

本地Linux、固定Godot4.7.2：保留236项原入口/物理断言，新增51项页面/JSON/导入/设置/存档断言均通过；34项Python检查器/切图工具测试通过。新旧用例在同一隔离工程一次冷导入后执行，原始日志检查引擎/脚本/Shader错误。

X11/Xvfb+Mesa软件渲染原生捕获八类页面的1280×720和1920×1080；保留不支持VSync的环境warning，不声称稳定60FPS。所有截图是工程皮肤而非PixelLab最终设计。远端CI以PR实际head为准，不把本地结果冒充远端结果。

保留的开发失败记录：首版校验码发现Godot的1/1.0序列化差异，已通过数值规范化修复；窗口auto_accept_quit属SceneTree而非Window，已修复。未删除失败反例或让错误日志被PASS掩盖。
