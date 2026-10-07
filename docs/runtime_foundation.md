# N05 第一切片：可运行入口与物理夹具

基线 3364eff31553daa5c00674f3ae1875971534b6eb；用户要求继续实施。先读 AGENTS、架构、N05 Issue #6，再实现。

本切片把新仓库从只有文档推进到可启动引擎：标题→可取消加载→碰撞测试场→暂停/继续→返回标题。几何图形和英文按钮是工程诊断，不是正式农庄、像素美术或中文字体交付。正式美术继续等 #2–#4，领域/保存接口仍属于 #5；不迁入任何旧代码、图或用户档。

## 实施前依据

- [Godot 4.7.2 官方稳定发行](https://godotengine.org/download/archive/4.7.2-stable/)及官方godot-builds release metadata：锁定同版本引擎与模板SHA。模板仅记录来源和checksum，本切片未下载1.28GB全平台模板，不宣称已验证导出。
- [后台资源加载](https://docs.godotengine.org/en/4.7/tutorials/io/background_loading.html)：只在线程状态LOADED后取结果，场景实例化和节点操作仍在主线程。取消让当前generation失效，不谎称可以强行终止Godot后台I/O。
- [CharacterBody2D](https://docs.godotengine.org/en/4.7/classes/class_characterbody2d.html)：浮动运动模式、move_and_slide；[Input](https://docs.godotengine.org/en/4.7/classes/class_input.html)：get_vector限制斜向幅度，暂停/失焦后清理输入。

没有引入外部运行库、商业资源或LLM调用。测试场只为验证物理与入口，不建立新的地图生成链。

## 公共边界

`main.gd`持有标题/加载/世界状态和加载generation。`scene_request.gd`仅包装原生资源加载，不拥有业务状态。`input_locks.gd`按命名owner独立持有输入阻塞；释放pause不能解除focus阻塞。`player_body.gd`只拥有身体运动，初始禁用。

房间使用场景中的CollisionShape2D为碰撞真值，测试可视矩形直接读取该shape，编辑形状不需更新另一份坐标。测试场名明确为fixture，不把它叫农庄。只保留一个project.godot主入口；以后把正式区域接入此入口，不再建另一条候选继承链。

用户数据：本切片没有业务写盘，不读取/覆盖任何旧存档。测试HOME/XDG目录隔离。字体/图标、狗跟随、TileSet、正式跨门/三日循环均未完成。

## 本次验证

本地Linux、Godot4.7.2.stable.official.ed1daf0bf：冷导入通过，236个原生断言0失败（其中200个是100次启动/返回的生命周期断言，不代表100次人犬跨门）。22项Python工具自测通过；包含故意超时用例，输出RUNNER_TIMEOUT但自测预期如此，不把它误报为游戏通过。

新增回归先暴露并修复了恢复焦点时泄漏暂停期间按键的问题，以及左右箭头键映射错误。早期距离测试在headless调度下使用等待循环次数不稳定，改为实际physics frame计数校准距离；没有放宽斜向速度要求。原失败日志保留在验证证据中。

X11/Xvfb + Mesa llvmpipe原生窗口实际捕获1280×720、1920×1080标题/暂停及用箭头键绕墙穿开口的画面。路线没有传送；自动测试中的定位用于隔离碰撞例子，不宣称完整村庄体验。软件渲染不支持VSync的warning保留，未声称稳定60FPS。没有最终美术或导出验收。

```sh
# GODOT_BIN须指向官方4.7.2；从仓库根运行
python3 tools/runtime.py run
python3 tools/runtime.py editor
python3 tools/runtime.py test --report-dir reports/runtime
# 需有X11/正常窗口渲染环境，不能用headless截图替代
"$GODOT_BIN" --path game --audio-driver Dummy --script res://tests/capture_foundation.gd -- /tmp/qingfeng-captures
```

主入口来自project.godot，不接受启动器任意替换地图；测试使用同一main.tscn。相机和速度仅为工程测试标尺，不是用户接受的最终美术比例。服务端CI按实际PR head写入commit与源文件树，再下载校验锁定引擎、冷导入并运行同一回归；远端结果必须读真实运行，不能用本地结果代替。
