extends Control
## Pages project intents, never open arbitrary saves or own game state.
signal action_requested(action: String, payload: Dictionary)
const ACTION_BUTTON = preload("res://ui/widgets/action_button.gd")
const UI_THEME = preload("res://ui/theme/ui_theme.gd")
var title: Label
var subtitle: Label
var body: VBoxContainer
var notice: Label
var countdown: Label
var panel: PanelContainer
var center: CenterContainer
var hud: HBoxContainer
var player_name: LineEdit
var dog_name: LineEdit
var volume: HSlider
var fullscreen: CheckBox
var vsync: CheckBox
var buttons: Dictionary = {}
var file_dialog: FileDialog
var _first_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	self.theme = UI_THEME.build()
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop";backdrop.color = UI_THEME.COLOR_BACKDROP;backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
	center = CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);center.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(center)
	panel = PanelContainer.new();panel.custom_minimum_size=UI_THEME.PAGE_MINIMUM_SIZE;center.add_child(panel)
	panel.add_theme_stylebox_override("panel",UI_THEME.panel_style())
	var column := VBoxContainer.new();column.add_theme_constant_override("separation",9);panel.add_child(column)
	title=Label.new();UI_THEME.apply_text_role(title,UI_THEME.ROLE_HEADING);column.add_child(title)
	subtitle=Label.new();UI_THEME.apply_text_role(subtitle,UI_THEME.ROLE_CAPTION);subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(subtitle)
	body=VBoxContainer.new();body.add_theme_constant_override("separation",8);body.size_flags_vertical=Control.SIZE_EXPAND_FILL;column.add_child(body)
	notice=Label.new();notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;UI_THEME.apply_text_role(notice,UI_THEME.ROLE_ERROR);column.add_child(notice)
	hud=HBoxContainer.new();hud.position=Vector2(10,8);add_child(hud)
	file_dialog=FileDialog.new();file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;file_dialog.access=FileDialog.ACCESS_FILESYSTEM;file_dialog.filters=PackedStringArray(["*.qfsave ; 晴风谷存档"]);file_dialog.title="选择要导入的存档";file_dialog.size=Vector2i(560,300)
	file_dialog.theme=self.theme;add_child(file_dialog)
	file_dialog.file_selected.connect(func(path:String):emit_action("preview_import",{"path":path}))

func emit_action(name: String, payload: Dictionary = {}) -> void:
	action_requested.emit(name,payload)

func clear_page() -> void:
	for child in body.get_children(): body.remove_child(child);child.queue_free()
	for child in hud.get_children(): hud.remove_child(child);child.queue_free()
	buttons.clear();_first_button=null;player_name=null;dog_name=null;countdown=null
	notice.text="";panel.visible=true;get_node("Backdrop").visible=true

func label(text: String, parent: Node = null) -> Label:
	var node:=Label.new();node.text=text;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UI_THEME.apply_text_role(node,UI_THEME.ROLE_BODY)
	(parent if parent != null else body).add_child(node)
	return node

func row(parent: Node = null) -> HBoxContainer:
	var node:=HBoxContainer.new();node.add_theme_constant_override("separation",8)
	(parent if parent != null else body).add_child(node);return node

func button(parent: Node, action: String, glyph: String, description: String, payload: Dictionary = {}, enabled := true) -> Button:
	var node: Button=ACTION_BUTTON.new();node.glyph=glyph;node.custom_minimum_size=Vector2(44,36)
	node.tooltip_text=description;node.accessibility_name=description;node.disabled=not enabled
	node.pressed.connect(func():emit_action(action,payload))
	node.mouse_entered.connect(func():notice.text=description)
	node.focus_entered.connect(func():notice.text=description)
	parent.add_child(node);buttons[action]=node
	if _first_button == null and enabled:_first_button=node
	return node

func show_page(page: String, context: Dictionary) -> void:
	clear_page()
	match page:
		"title":
			title.text="晴风谷";subtitle.text="QINGFENG  /  一段新的乡居生活"
			label("入口与存档开发版\n地图、美术与完整玩法仍在制作中。")
			var actions:=row()
			for entry: Array in [["continue","play","继续","继续最近的有效存档"],["new_game","new","新建","新建游戏"],["load","load","存档","读取 / 导入存档"],["settings","settings","设置","设置"],["quit","quit","退出","退出游戏"]]:
				var cell:=VBoxContainer.new();cell.custom_minimum_size.x=44;actions.add_child(cell)
				button(cell,entry[0],entry[1],entry[3],{},entry[0]!="continue" or context.has("recent_id"))
				var caption:=label(entry[2],cell);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;UI_THEME.apply_text_role(caption,UI_THEME.ROLE_CAPTION)

		"new_game":
			title.text="开始新的生活";subtitle.text="名字会写入新存档；不会覆盖已有进度。"
			label("你的名字（1–16字）")
			player_name=LineEdit.new();player_name.max_length=16;player_name.placeholder_text="请输入名字";player_name.text=context.get("player_name","");body.add_child(player_name)
			label("狗的名字（可留空，伙伴系统尚未接入）")
			dog_name=LineEdit.new();dog_name.max_length=16;dog_name.placeholder_text="可稍后确定";dog_name.text=context.get("dog_name","");body.add_child(dog_name)
			var actions:=row();button(actions,"create","accept","创建独立存档并进入农庄第一屏");button(actions,"back","back","返回标题，不创建存档")
			player_name.grab_focus()
		"load":
			title.text="存档";subtitle.text="读取本机进度，或导入经过校验的 .qfsave 文件。"
			var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(440,118);body.add_child(scroll)
			var entries:=VBoxContainer.new();entries.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(entries)
			if context.saves.is_empty():label("还没有存档。先新建游戏，或使用下方导入。",entries)
			for item:Dictionary in context.saves:
				var line:=row(entries)
				var text:String=(item.envelope.snapshot.player_name+"  ·  "+item.envelope.saved_at_utc) if item.ok else ("无法读取 · "+item.error_code)
				var name_label:=label(text,line);name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				button(line,"read_save","play","读取这个存档",{"save_id":item.save_id},item.ok)
			var actions:=row();button(actions,"choose_import","import","选择存档文件");button(actions,"back","back","返回标题")
		"import_review":
			title.text="确认导入";subtitle.text="将创建一份本机副本，原文件与已有存档不变。"
			label("玩家："+context.envelope.snapshot.player_name+"\n狗名："+context.envelope.snapshot.dog_name+"\n保存时间："+context.envelope.saved_at_utc+"\n内容版本："+context.envelope.content_version)
			var actions:=row();button(actions,"confirm_import","accept","确认创建本机副本");button(actions,"cancel_import","back","取消导入，不写入任何存档")
		"settings":
			title.text="设置";subtitle.text="更改后先预览，10秒内确认；否则自动恢复。"
			label("主音量（当前没有正式音乐与音效素材）")
			volume=HSlider.new();volume.min_value=0;volume.max_value=1;volume.step=0.05;volume.value=context.settings.master_volume;body.add_child(volume)
			fullscreen=CheckBox.new();fullscreen.text="全屏显示";fullscreen.button_pressed=context.settings.is_fullscreen;body.add_child(fullscreen)
			vsync=CheckBox.new();vsync.text="垂直同步";vsync.button_pressed=context.settings.is_vsync_enabled;body.add_child(vsync)
			var actions:=row();button(actions,"preview_settings","accept","预览设置");button(actions,"back","back","放弃未应用更改")
		"display_confirm":
			title.text="保留显示设置？";subtitle.text="Esc、失焦或超时会恢复之前的设置。"
			countdown=label("10 秒后自动恢复")
			var actions:=row();button(actions,"confirm_settings","accept","保留并保存设置");button(actions,"revert_settings","back","立即恢复")
		"loading":
			title.text="准备进入";subtitle.text="正在加载场景和校验落点；操作取消前不会创建新档。"
			label("请稍候…")
			button(row(),"cancel_load","back","取消加载，返回标题")
		"pause":
			title.text="暂歇一下";subtitle.text="暂停中 · 游戏输入与游戏时钟已锁定"
			if context.get("has_gameplay",false):
				label("保存会记录位置、时间、背包、钱物和田地状态。\n当前画面仍是工程美术；狗、村庄和最终素材尚未接入。")
			else:
				label("这是旧入口碰撞测试存档；只保存身份和测试场位置。")
			var actions:=row();button(actions,"resume","resume","继续游戏");button(actions,"save","save","保存到新的独立文件",{},context.get("can_save",false));button(actions,"settings","settings","设置");button(actions,"save_return","back","保存并返回标题",{},context.get("can_save",false))
		"world":
			panel.hide();get_node("Backdrop").hide()
			button(hud,"pause","pause","暂停 / Esc")
			var text:=Label.new();text.text=context.get("player_name","")+"  ·  "+str(context.get("world_label","世界"));text.add_theme_color_override("font_color",UI_THEME.COLOR_HUD_TEXT);hud.add_child(text)
	if not context.get("error","").is_empty():notice.text=context.error
	var preferred_action := str(context.get("focus_action",""))
	if not preferred_action.is_empty() and buttons.has(preferred_action):
		var preferred_button: Button = buttons[preferred_action] as Button
		if preferred_button != null and not preferred_button.disabled:
			preferred_button.grab_focus()
			return
	if _first_button != null and page != "new_game":_first_button.grab_focus()

func form_names() -> Dictionary:
	return {"player_name":player_name.text,"dog_name":dog_name.text}

func settings_draft() -> Dictionary:
	return {"master_volume":volume.value,"is_fullscreen":fullscreen.button_pressed,"is_vsync_enabled":vsync.button_pressed}
