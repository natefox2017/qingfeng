# 当前运行入口

唯一入口res://app/main.tscn，固定Godot4.7.2。中文标题、新建、存档列表/导入、设置预览、暂停保存返回已经接通；保存仅包含身份与明确的碰撞测试场位置，非完整游戏存档。

运行方法见[根README](../README.md)，实际行为见[入口合同](../docs/entry_pages.md)。界面使用native工程图标和无衬线系统字体；正式PixelLab图、随包字体、农庄/狗/种植/背包仍待对应任务。

测试只访问隔离user://，正式写入限于user://qingfeng/，不接入旧项目存档。主场景不新增深继承；UI发意图，session_store唯一写盘，settings_store拥有显示/声音预览。
