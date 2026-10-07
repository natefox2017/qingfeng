# 新运行基础
当前唯一入口 `res://app/main.tscn`，Godot4.7.2；主界面明确说明只有工程测试场，不是最终画面。启动方法见[根README](../README.md)，结果与边界见[运行基础](../docs/runtime_foundation.md)。

app：取消安全的场景加载/命名输入锁；actors：无美术依赖的身体运动；tests/fixtures：可编辑障碍和原生诊断画面；tests：生命周期/实际按键/物理回归与渲染捕获。正式world、systems、persistence、dialogue、ui、content、assets仍按各自Issue开发；不把此夹具复制成一条长期候选继承链。

本切片不写业务存档、不访问旧项目数据、不包含图片或字体文件。工程英文按钮不代表正式图标UI/中文字体已经交付。
