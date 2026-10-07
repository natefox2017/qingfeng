# PixelLab 交付、详细切图与接入规范

本文是**项目采用的制作规则**；不是声称PixelLab输出已经满足所有要求。当前账号连接未验证，没有付费生成或接受的正式素材。官方接口行为以[MCP文档](https://api.pixellab.ai/mcp/docs)当次返回为准：角色画布可能留有动作空间，模式/模板影响实际方向和帧数，不能用请求值替代下载结果。

## 不再“切整张地图”

地图坐标、可走空间、地面/前景与物件足迹在Godot布局中维护。PixelLab只生成图块、可重复对象、角色动作和必要UI图形；位置变化不生成图片。标题页背景与控件分开，纯装饰图不能带可点击按钮/烘焙文字。没有原生墙/屋顶/树冠层时向ART补对应组件，不能从截图抠一块冒充原始分层。

## 首轮资产单元与标尺

| 类型 | 制作起点（候选） | 导出单位/约束 |
| --- | --- | --- |
| 地形 | 16×16源格 | 草/土路、岸/水、干/湿田成套；地形接缝标签随图交付 |
| 玩家/居民 | 内容高度约两格起测，画布按动作留白 | 同角色同动作所有方向保持逻辑画布与脚锚，不自动紧裁 |
| 狗 | 与玩家同像素密度 | 四向真实idle/walk，不能用两张正面动作声明四向 |
| 树/屋/桥 | 整数格占地，贴图可以跨格 | 场景组件与足迹独立；根锚、前后层、门/通路明确 |
| 图标 | 16×16或24×24单套原生规格，先定一个样板 | 按状态或Theme着色，透明背景，无文字；点击区不等于图标矩形 |
| 面板/按钮边框 | 小块九宫格 | 固定四角/边，仅中部拉伸；纹理文字必须分离 |

像素密度不是“全部文件同尺寸”：16px地形格与48/64px动作画布可以共存，但人物可见内容高度须匹配参考和世界格。调相机比例是全局规则，不能单独缩放错比例素材掩盖问题。

## 原始文件与元数据

每个导出包含原始PNG、可编辑源（若工具提供）、实际帧/tileset元数据、工具与模式、脱敏请求/参考hash、原始输出SHA256、许可和可访问来源页。暂存.local，验收后仅运行需要的图进入game/assets，长期源文件在授权私有归档。不要公开带权限下载URL或MCP token。

AtlasTexture区域使用整数`rect_px=[x,y,width,height]`，左上角原点，右/下边界为排他边界。数据必须落在实际PNG范围内；透明边也属于统一逻辑画布。`anchor_px=[x,y]`相对该帧矩形左上角。图集id/region_id使用稳定snake_case，不含final/candidate/日期。

均匀表的计算只能在实际元数据确认后使用：
`x = margin_left + column * (frame_width + separation_x)`；`y = margin_top + row * (frame_height + separation_y)`。
margin、separation是导出数据，不自动假定0/1；没有元数据就先量测并记录。不同画布或Wang布局采用显式rect，不能一律按16格遍历。

## Padding、extrusion与trim

Source rect只选逻辑画布，不把邻图或atlas extrusion算进帧；padding属于图集布局。Nearest/不生成世界mipmap为首轮方案，仍要实际测试采样边缘。
动画不得逐帧按alpha包围盒tight trim；保持同画布/同脚锚，否则走路抖动。确有trim导出时必须补logical_canvas与trim_offset并在适配层恢复；当前切图工具**不支持trim，直接拒绝漂移帧**，不暗中猜偏移。
静态对象允许透明边裁切，但必须同步更新根锚与全部引用，在PR明确旧新变换；不能只改图片。

## 九宫格与对象分层

`nine_patch_px=[left,top,right,bottom]`都为非负整数，左右之和必须小于区域宽，高同理，保证有中心。边框应沿轴平铺或拉伸，不把斜光影和文字切成四角。
树干/树冠必须在同根锚空间注册；人物在树前/树后分别实测。完整房屋侧墙/屋顶/门按遮挡合同组织；可进入门的碰撞开口与图一致。桥面可走、栏杆阻挡、水不可走，不用“整桥一个矩形”粗暴碰撞。

## 动画交付

每个clip：animation_id/action/direction、有序region_ids、逐帧durations_msec、is_looping；工具动作额外`contact={frame,offset_msec}`。frame零基，offset必须处于该帧时长内。prepare→contact→recover只有一个业务提交；实际工具接触才标contact，不按第一/第二帧默认。
方向缺失必须如实登记，不能左右镜像工具/服饰细节仍声称全部原创方向通过。少量真实过渡不足时回到ART，重复同帧不会让动作自然。先通过向下挥锄样板再生成全组。

## Wang地形转换

PixelLab的连接标签与Godot terrain peering模式不是同一套自动契约。读取实际导出角/边标签，在适配中明确corners或sides；不按图片“看起来像”的位置猜位掩码。完整地形所有组合、孤岛、内外角、窄路、岸桥、干湿田边至少一次实际铺图验证；同base tile引用避免不同批次草地接不上。

## 可执行工具

本批新增 `tools/atlas_contract.py`，**离线**校验源hash/PNG头部尺寸/整数区域/帧画布与锚点/九宫格中心/接触事件，然后可发出Godot AtlasTexture `.tres`。它不生图、不重新绘制、不替换源PNG、不自动创建碰撞，也不猜缺失帧。

```sh
python3 tools/atlas_contract.py .local/accepted_export.json
python3 tools/atlas_contract.py .local/accepted_export.json --emit game/assets/generated_regions
```

输出文件已存在时拒绝覆盖，先审diff再显式版本化。输入格式见[模板](../templates/atlas_export.example.json)，模板路径是占位，不是已生成资产，不能直接“通过验证”。结构校验不代替PNG完整解码；导入Godot、帧实际展示和同镜头走路仍是最后的验收。

## 第一批制作顺序

[制作请求清单](../art/requests/entry_batch.json)只处于planned：同套图标/九宫格可先做；玩家四向和挥锄样板、基础地形与树屋桥并行，但共享style_id。不要先生成整村，再发现人物比例/狗方向不对。

提交前登记request_hash，获取job_id后只查询同任务；状态不明先查而不是重复create。明确授权本批预算才调用付费工具。生产、下载、修整、导入、测试分别记时；省的是重复做相同组件和人工整理，不承诺“零作图”或未经实测的提速倍数。
