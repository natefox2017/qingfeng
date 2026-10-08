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
var hud_panel: PanelContainer
var hud: VBoxContainer
var quickbar_panel: PanelContainer
var quickbar: HBoxContainer
var wallet_label: Label
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
	hud_panel=PanelContainer.new();hud_panel.position=Vector2(8,8);hud_panel.custom_minimum_size=Vector2(624,0);hud_panel.add_theme_stylebox_override("panel",UI_THEME.hud_panel_style());hud_panel.visible=false;add_child(hud_panel)
	hud=VBoxContainer.new();hud.add_theme_constant_override("separation",2);hud_panel.add_child(hud)
	file_dialog=FileDialog.new();file_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;file_dialog.access=FileDialog.ACCESS_FILESYSTEM;file_dialog.filters=PackedStringArray(["*.qfsave ; 晴风谷存档"]);file_dialog.title="选择要导入的存档";file_dialog.size=Vector2i(560,300)
	file_dialog.theme=self.theme;add_child(file_dialog)
	file_dialog.file_selected.connect(func(path:String):emit_action("preview_import",{"path":path}))

func emit_action(name: String, payload: Dictionary = {}) -> void:
	action_requested.emit(name,payload)

func clear_page() -> void:
	panel.custom_minimum_size=UI_THEME.PAGE_MINIMUM_SIZE
	for child in body.get_children(): body.remove_child(child);child.queue_free()
	for child in hud.get_children(): hud.remove_child(child);child.queue_free()
	hud_panel.visible=false
	if is_instance_valid(quickbar_panel): remove_child(quickbar_panel);quickbar_panel.queue_free()
	quickbar_panel=null;quickbar=null;wallet_label=null
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

func _slot_button(parent: Node, slot_index: int, slot: Variant, items: Dictionary, selected: bool, compact: bool) -> Button:
	var node := Button.new()
	var key_text := "—"
	if slot_index < 9:
		key_text = str(slot_index+1)
	elif slot_index == 9:
		key_text = "0"
	var number_text := "["+key_text+"]" if selected else key_text
	var display_name := "空"
	var quantity := 0
	if slot != null:
		var metadata: Dictionary = items.get(String(slot.item_id),{})
		display_name = str(metadata.get("display_name",slot.item_id))
		quantity = int(slot.quantity)
	if compact:
		var short_name := "空" if slot == null else display_name.left(2)
		node.text = number_text+"\n"+short_name+("" if quantity <= 1 else " ×"+str(quantity))
		node.custom_minimum_size = UI_THEME.QUICKBAR_SLOT_SIZE
	else:
		node.text = number_text+"  "+display_name+("" if quantity <= 0 else "  ×"+str(quantity))
		node.custom_minimum_size = Vector2(90,42)
	node.toggle_mode = true
	node.button_pressed = selected
	node.add_theme_stylebox_override("normal",UI_THEME.slot_style(selected))
	node.add_theme_stylebox_override("hover",UI_THEME.slot_style(selected,true))
	node.add_theme_stylebox_override("focus",UI_THEME.slot_style(selected,true))
	node.add_theme_stylebox_override("pressed",UI_THEME.slot_style(true,true))
	var description := "槽位 %d：%s" % [slot_index+1, display_name if slot == null else display_name+" ×"+str(quantity)]
	if slot_index <= 9:
		description += "；快捷键 "+key_text
	else:
		description += "；点击选择"
	node.tooltip_text = description
	node.accessibility_name = description+("，已选中" if selected else "")
	node.pressed.connect(func():emit_action("select_slot",{"slot_index":slot_index}))
	node.mouse_entered.connect(func():notice.text=description)
	node.focus_entered.connect(func():notice.text=description)
	parent.add_child(node)
	if selected and _first_button==null:
		_first_button=node
	return node

func _storage_slot_button(parent: Node, source_container_id: String, slot_index: int, slot: Variant, items: Dictionary, direction_label: String) -> Button:
	var node := Button.new()
	node.custom_minimum_size = Vector2(50,34)
	var display_name := "空"
	var quantity := 0
	if slot != null:
		var metadata: Dictionary = items.get(String(slot.item_id),{})
		display_name = str(metadata.get("display_name",slot.item_id))
		quantity = int(slot.quantity)
	node.text = "%d\n%s" % [slot_index+1, "空" if slot == null else display_name.left(2)+("×"+str(quantity) if quantity > 1 else "")]
	node.disabled = slot == null
	node.add_theme_stylebox_override("normal",UI_THEME.slot_style(false))
	node.add_theme_stylebox_override("hover",UI_THEME.slot_style(false,true))
	node.add_theme_stylebox_override("focus",UI_THEME.slot_style(false,true))
	node.add_theme_stylebox_override("pressed",UI_THEME.slot_style(true,true))
	node.add_theme_stylebox_override("disabled",UI_THEME.slot_style(false))
	var description := "槽位 %d：%s" % [slot_index+1, display_name if slot == null else display_name+" ×"+str(quantity)]
	if slot != null:
		description += "；"+direction_label
	node.tooltip_text = description
	node.accessibility_name = description
	if slot != null:
		var item_id := String(slot.item_id)
		var transfer_quantity := int(slot.quantity)
		node.pressed.connect(func():emit_action("transfer_storage",{
			"source_container_id":source_container_id,
			"item_id":item_id,
			"quantity":transfer_quantity
		}))
	if _first_button == null and not node.disabled:
		_first_button = node
	parent.add_child(node)
	return node

func _used_slot_count(slots: Array) -> int:
	var count := 0
	for slot: Variant in slots:
		if slot != null:
			count += 1
	return count

func _minute_text(value: int) -> String:
	return "%02d:%02d" % [value/60,value%60]

func _trade_button(parent: Node, action: String, item_id: String, quantity: int, display_name: String, unit_price: int, enabled: bool, closed_reason: String) -> Button:
	var node := Button.new()
	node.custom_minimum_size = Vector2(245,38)
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_stylebox_override("normal",UI_THEME.slot_style(false))
	node.add_theme_stylebox_override("hover",UI_THEME.slot_style(false,true))
	node.add_theme_stylebox_override("focus",UI_THEME.slot_style(false,true))
	node.add_theme_stylebox_override("pressed",UI_THEME.slot_style(true,true))
	node.add_theme_stylebox_override("disabled",UI_THEME.slot_style(false))
	var verb := "买" if action == "trade_buy" else "卖"
	node.text = "%s %d · %s · %d币" % [verb,quantity,display_name,unit_price*quantity]
	var description := node.text
	if not enabled and not closed_reason.is_empty():
		description += "；"+closed_reason
	node.tooltip_text = description
	node.accessibility_name = description
	node.disabled = not enabled
	node.pressed.connect(func():emit_action(action,{"item_id":item_id,"quantity":quantity}))
	node.mouse_entered.connect(func():notice.text=description)
	node.focus_entered.connect(func():notice.text=description)
	parent.add_child(node)
	if _first_button == null and enabled:
		_first_button = node
	return node

func _clock_text(clock: Dictionary) -> String:
	var minute_of_day := int(clock.get("minute_of_day",0))
	return "第%d天  %02d:%02d" % [int(clock.get("day",1)),minute_of_day/60,minute_of_day%60]

func _build_quickbar(gameplay: Dictionary) -> void:
	var inventory: Dictionary = gameplay.inventory
	var items: Dictionary = gameplay.items
	quickbar_panel = PanelContainer.new()
	quickbar_panel.anchor_left=0.5
	quickbar_panel.anchor_right=0.5
	quickbar_panel.anchor_top=1.0
	quickbar_panel.anchor_bottom=1.0
	quickbar_panel.offset_left=-248
	quickbar_panel.offset_right=248
	quickbar_panel.offset_top=-58
	quickbar_panel.offset_bottom=-6
	quickbar_panel.add_theme_stylebox_override("panel",UI_THEME.hud_panel_style())
	add_child(quickbar_panel)
	quickbar = HBoxContainer.new()
	quickbar.alignment=BoxContainer.ALIGNMENT_CENTER
	quickbar.add_theme_constant_override("separation",2)
	quickbar_panel.add_child(quickbar)
	for index in range(inventory.slots.size()):
		_slot_button(quickbar,index,inventory.slots[index],items,index==inventory.selected_slot_index,true)

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
			title.text="设置";subtitle.text="先预览，再确认 · 未确认的显示变更会自动恢复"
			panel.custom_minimum_size=Vector2(520,286)

			var sound_panel:=PanelContainer.new();sound_panel.name="SettingsSoundSection";sound_panel.add_theme_stylebox_override("panel",UI_THEME.section_style());body.add_child(sound_panel)
			var sound_column:=VBoxContainer.new();sound_column.add_theme_constant_override("separation",5);sound_panel.add_child(sound_column)
			var sound_title:=label("声音",sound_column);UI_THEME.apply_text_role(sound_title,UI_THEME.ROLE_HEADING)
			var volume_row:=row(sound_column)
			var volume_name:=label("主音量",volume_row);volume_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var volume_value:=label("%d%%" % roundi(float(context.settings.master_volume)*100.0),volume_row);volume_value.name="VolumeValue";UI_THEME.apply_text_role(volume_value,UI_THEME.ROLE_QUANTITY)
			volume=HSlider.new();volume.name="SettingVolume";volume.min_value=0;volume.max_value=1;volume.step=0.05;volume.value=context.settings.master_volume;volume.tooltip_text="调整主音量";volume.accessibility_name="主音量";sound_column.add_child(volume)
			volume.value_changed.connect(func(value:float):volume_value.text="%d%%" % roundi(value*100.0))

			var display_panel:=PanelContainer.new();display_panel.name="SettingsDisplaySection";display_panel.add_theme_stylebox_override("panel",UI_THEME.section_style());body.add_child(display_panel)
			var display_column:=VBoxContainer.new();display_column.add_theme_constant_override("separation",4);display_panel.add_child(display_column)
			var display_title:=label("显示",display_column);UI_THEME.apply_text_role(display_title,UI_THEME.ROLE_HEADING)
			fullscreen=CheckBox.new();fullscreen.name="SettingFullscreen";fullscreen.text="全屏显示";fullscreen.button_pressed=context.settings.is_fullscreen;fullscreen.tooltip_text="切换全屏显示";fullscreen.accessibility_name="全屏显示";display_column.add_child(fullscreen)
			vsync=CheckBox.new();vsync.name="SettingVsync";vsync.text="垂直同步";vsync.button_pressed=context.settings.is_vsync_enabled;vsync.tooltip_text="切换垂直同步";vsync.accessibility_name="垂直同步";display_column.add_child(vsync)

			var settings_note:=label("预览只临时应用；确认后才写入设置文件。");UI_THEME.apply_text_role(settings_note,UI_THEME.ROLE_CAPTION)
			var actions:=row();button(actions,"preview_settings","accept","预览设置");button(actions,"back","back","放弃未应用更改")
			volume.grab_focus()
		"display_confirm":
			title.text="保留显示设置？";subtitle.text="确认前仍是临时预览"
			panel.custom_minimum_size=Vector2(440,230)
			var confirm_panel:=PanelContainer.new();confirm_panel.name="DisplayConfirmSummary";confirm_panel.add_theme_stylebox_override("panel",UI_THEME.section_style());body.add_child(confirm_panel)
			var confirm_column:=VBoxContainer.new();confirm_column.add_theme_constant_override("separation",6);confirm_panel.add_child(confirm_column)
			var confirm_text:=label("画面设置已经临时应用。若窗口失焦、按 Esc 或倒计时结束，将恢复之前的设置。",confirm_column);confirm_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			countdown=label("10 秒后自动恢复",confirm_column);countdown.name="SettingsCountdown";UI_THEME.apply_text_role(countdown,UI_THEME.ROLE_HEADING)
			var actions:=row();button(actions,"confirm_settings","accept","保留并保存设置");button(actions,"revert_settings","back","立即恢复")
		"loading":
			title.text="准备进入";subtitle.text="正在加载场景和校验落点；操作取消前不会创建新档。"
			label("请稍候…")
			button(row(),"cancel_load","back","取消加载，返回标题")
		"pause":
			title.text="暂歇一下";subtitle.text="世界已暂停 · Esc 返回游戏"
			panel.custom_minimum_size=Vector2(520,280)
			var summary_panel:=PanelContainer.new();summary_panel.name="PauseSummary";summary_panel.add_theme_stylebox_override("panel",UI_THEME.section_style());body.add_child(summary_panel)
			var summary_column:=VBoxContainer.new();summary_column.add_theme_constant_override("separation",4);summary_panel.add_child(summary_column)
			if context.get("has_gameplay",false):
				var gameplay: Dictionary=context.get("gameplay",{})
				var place:=label(String(context.get("world_label","当前区域")),summary_column);UI_THEME.apply_text_role(place,UI_THEME.ROLE_HEADING)
				var state_row:=row(summary_column)
				var time_text:=label(_clock_text(gameplay.clock),state_row);time_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				var money_text:=label(str(gameplay.wallet.money)+" 币",state_row);UI_THEME.apply_text_role(money_text,UI_THEME.ROLE_QUANTITY)
				var save_note:=label("保存会写入当前位置、时间、钱物、背包、田地与居民运行状态；每次保存生成新的本地文件。",summary_column);UI_THEME.apply_text_role(save_note,UI_THEME.ROLE_CAPTION)
			else:
				var legacy_note:=label("旧入口碰撞测试存档 · 只保存身份与测试场位置",summary_column);UI_THEME.apply_text_role(legacy_note,UI_THEME.ROLE_CAPTION)

			var actions:=HBoxContainer.new();actions.alignment=BoxContainer.ALIGNMENT_CENTER;actions.add_theme_constant_override("separation",12);body.add_child(actions)
			for entry: Array in [
				["resume","resume","继续","继续游戏"],
				["save","save","保存","保存到新的独立文件"],
				["settings","settings","设置","设置"],
				["save_return","back","返回","保存并返回标题"]
			]:
				var cell:=VBoxContainer.new();cell.custom_minimum_size=Vector2(78,58);actions.add_child(cell)
				var enabled:=true
				if entry[0] in ["save","save_return"]:
					enabled=bool(context.get("can_save",false))
				button(cell,String(entry[0]),String(entry[1]),String(entry[3]),{},enabled)
				var caption:=label(String(entry[2]),cell);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;UI_THEME.apply_text_role(caption,UI_THEME.ROLE_CAPTION)
		"inventory":
			title.text="背包";subtitle.text="选择随身物品 · B / Esc 关闭"
			panel.custom_minimum_size=Vector2(600,286)
			var gameplay: Dictionary = context.get("gameplay",{})
			if gameplay.get("ok",false):
				var summary:=row()
				var time_label:=label(_clock_text(gameplay.clock),summary);time_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				var money_label:=label(str(gameplay.wallet.money)+" 币",summary);UI_THEME.apply_text_role(money_label,UI_THEME.ROLE_QUANTITY)

				var content_row:=HBoxContainer.new();content_row.add_theme_constant_override("separation",10);body.add_child(content_row)
				var grid:=GridContainer.new();grid.name="InventoryGrid";grid.columns=4;grid.add_theme_constant_override("h_separation",5);grid.add_theme_constant_override("v_separation",5);grid.custom_minimum_size=Vector2(375,145);content_row.add_child(grid)
				for index in range(gameplay.inventory.slots.size()):
					_slot_button(grid,index,gameplay.inventory.slots[index],gameplay.items,index==gameplay.inventory.selected_slot_index,false)

				var detail_panel:=PanelContainer.new();detail_panel.name="InventoryDetail";detail_panel.custom_minimum_size=Vector2(155,145);detail_panel.add_theme_stylebox_override("panel",UI_THEME.panel_style());content_row.add_child(detail_panel)
				var detail:=VBoxContainer.new();detail.add_theme_constant_override("separation",5);detail_panel.add_child(detail)
				var selected_index:=int(gameplay.inventory.selected_slot_index)
				var selected: Variant=gameplay.inventory.slots[selected_index]
				var selected_title:=Label.new();UI_THEME.apply_text_role(selected_title,UI_THEME.ROLE_HEADING);detail.add_child(selected_title)
				var selected_quantity:=Label.new();UI_THEME.apply_text_role(selected_quantity,UI_THEME.ROLE_QUANTITY);detail.add_child(selected_quantity)
				var value_label:=Label.new();value_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;UI_THEME.apply_text_role(value_label,UI_THEME.ROLE_CAPTION);detail.add_child(value_label)
				if selected==null:
					selected_title.text="空槽"
					selected_quantity.text="槽位 %d" % [selected_index+1]
					value_label.text="当前没有选择物品。"
				else:
					var selected_meta: Dictionary=gameplay.items.get(String(selected.item_id),{})
					selected_title.text=String(selected_meta.get("display_name",selected.item_id))
					selected_quantity.text="持有 ×%d" % int(selected.quantity)
					var values: Array[String]=[]
					var buy_price:=int(selected_meta.get("buy_price",0))
					var sell_price:=int(selected_meta.get("sell_price",0))
					if buy_price>0: values.append("买入 %d币" % buy_price)
					if sell_price>0: values.append("出售 %d币" % sell_price)
					value_label.text=(" · ".join(values) if not values.is_empty() else "不可直接买卖")+"\n已选为当前快捷物品。"
				var slot_hint:=label("槽位 %d · %s" % [selected_index+1,("快捷键 "+str(selected_index+1) if selected_index<9 else ("快捷键 0" if selected_index==9 else "点击选择"))],detail)
				UI_THEME.apply_text_role(slot_hint,UI_THEME.ROLE_TOOLTIP)
			else:
				label("当前存档没有玩法背包状态。")
			button(row(),"close_inventory","back","关闭背包 / B / Esc")
		"storage":
			title.text="家中木箱";subtitle.text="整理随身物品 · 点击非空槽整组移动 · Esc 关闭"
			panel.custom_minimum_size=Vector2(610,292)
			var gameplay: Dictionary = context.get("gameplay",{})
			if gameplay.get("ok",false) and gameplay.has("storage"):
				var capacity_row:=row()
				var bag_capacity:=label("背包  %d / %d格" % [_used_slot_count(gameplay.inventory.slots),int(gameplay.inventory.capacity)],capacity_row);bag_capacity.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				var chest_capacity:=label("木箱  %d / %d格" % [_used_slot_count(gameplay.storage.slots),int(gameplay.storage.capacity)],capacity_row);chest_capacity.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

				var sections:=HBoxContainer.new();sections.add_theme_constant_override("separation",8);body.add_child(sections)
				var bag_panel:=PanelContainer.new();bag_panel.name="StorageBagSection";bag_panel.custom_minimum_size=Vector2(218,165);bag_panel.add_theme_stylebox_override("panel",UI_THEME.section_style());sections.add_child(bag_panel)
				var bag_column:=VBoxContainer.new();bag_column.add_theme_constant_override("separation",4);bag_panel.add_child(bag_column)
				var bag_title:=label("随身背包  →  木箱",bag_column);UI_THEME.apply_text_role(bag_title,UI_THEME.ROLE_CAPTION)
				var bag_grid:=GridContainer.new();bag_grid.name="StorageBagGrid";bag_grid.columns=4;bag_grid.add_theme_constant_override("h_separation",3);bag_grid.add_theme_constant_override("v_separation",3);bag_column.add_child(bag_grid)
				for index in range(gameplay.inventory.slots.size()):
					_storage_slot_button(bag_grid,String(gameplay.inventory.container_id),index,gameplay.inventory.slots[index],gameplay.items,"存入木箱")

				var chest_panel:=PanelContainer.new();chest_panel.name="StorageChestSection";chest_panel.custom_minimum_size=Vector2(318,165);chest_panel.add_theme_stylebox_override("panel",UI_THEME.section_style());sections.add_child(chest_panel)
				var chest_column:=VBoxContainer.new();chest_column.add_theme_constant_override("separation",4);chest_panel.add_child(chest_column)
				var chest_title:=label("家中木箱  →  背包",chest_column);UI_THEME.apply_text_role(chest_title,UI_THEME.ROLE_CAPTION)
				var chest_grid:=GridContainer.new();chest_grid.name="StorageChestGrid";chest_grid.columns=6;chest_grid.add_theme_constant_override("h_separation",3);chest_grid.add_theme_constant_override("v_separation",3);chest_column.add_child(chest_grid)
				for index in range(gameplay.storage.slots.size()):
					_storage_slot_button(chest_grid,String(gameplay.storage.container_id),index,gameplay.storage.slots[index],gameplay.items,"取回背包")
				var rule:=label("整组移动；容量不足或状态已变化时不会扣走任何物品。");UI_THEME.apply_text_role(rule,UI_THEME.ROLE_TOOLTIP)
			else:
				label("当前存档没有可用的家庭箱子状态。")
			button(row(),"close_storage","storage","关闭木箱 / Esc")
		"trade":
			title.text="杂货铺柜台";subtitle.text="购买种子与出售收成 · Esc 关闭"
			panel.custom_minimum_size=Vector2(600,292)
			var gameplay: Dictionary = context.get("gameplay",{})
			if gameplay.get("ok",false) and gameplay.has("shop"):
				var shop: Dictionary = gameplay.shop
				var is_open: bool = bool(shop.get("is_open",false))
				var hours := _minute_text(int(shop.open_minute))+"–"+_minute_text(int(shop.close_minute))
				var summary:=row()
				var status:=label(_clock_text(gameplay.clock)+"  ·  "+("营业中" if is_open else "已打烊")+"  "+hours,summary);status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				if not is_open: UI_THEME.apply_text_role(status,UI_THEME.ROLE_CAPTION)
				var money:=label(str(gameplay.wallet.money)+" 币",summary);UI_THEME.apply_text_role(money,UI_THEME.ROLE_QUANTITY)

				var sections:=HBoxContainer.new();sections.add_theme_constant_override("separation",8);body.add_child(sections)
				var buy_panel:=PanelContainer.new();buy_panel.name="TradeBuySection";buy_panel.custom_minimum_size=Vector2(260,155);buy_panel.add_theme_stylebox_override("panel",UI_THEME.section_style());sections.add_child(buy_panel)
				var buy_column:=VBoxContainer.new();buy_column.add_theme_constant_override("separation",5);buy_panel.add_child(buy_column)
				var buy_title:=label("购买",buy_column);UI_THEME.apply_text_role(buy_title,UI_THEME.ROLE_HEADING)
				var buy_hint:=label("价格来自当前内容版本",buy_column);UI_THEME.apply_text_role(buy_hint,UI_THEME.ROLE_CAPTION)
				var buy_rows:=VBoxContainer.new();buy_rows.name="TradeBuyRows";buy_rows.add_theme_constant_override("separation",4);buy_column.add_child(buy_rows)
				var buy_count := 0
				for item_id: Variant in gameplay.items:
					var metadata: Dictionary = gameplay.items[item_id]
					var buy_price := int(metadata.get("buy_price",0))
					if buy_price <= 0:
						continue
					buy_count += 1
					_trade_button(buy_rows,"trade_buy",String(item_id),1,String(metadata.get("display_name",item_id)),buy_price,is_open,"商店已打烊")
				if buy_count == 0:
					label("当前没有可购买商品。",buy_rows)

				var sell_panel:=PanelContainer.new();sell_panel.name="TradeSellSection";sell_panel.custom_minimum_size=Vector2(260,155);sell_panel.add_theme_stylebox_override("panel",UI_THEME.section_style());sections.add_child(sell_panel)
				var sell_column:=VBoxContainer.new();sell_column.add_theme_constant_override("separation",5);sell_panel.add_child(sell_column)
				var sell_title:=label("出售",sell_column);UI_THEME.apply_text_role(sell_title,UI_THEME.ROLE_HEADING)
				var sell_hint:=label("只列出背包中可出售的物品",sell_column);UI_THEME.apply_text_role(sell_hint,UI_THEME.ROLE_CAPTION)
				var sell_rows:=VBoxContainer.new();sell_rows.name="TradeSellRows";sell_rows.add_theme_constant_override("separation",3);sell_column.add_child(sell_rows)
				var quantities: Dictionary = {}
				for slot: Variant in gameplay.inventory.slots:
					if slot != null:
						quantities[String(slot.item_id)] = int(quantities.get(String(slot.item_id),0))+int(slot.quantity)
				var sell_count := 0
				for item_id: Variant in quantities:
					var metadata: Dictionary = gameplay.items.get(item_id,{})
					var sell_price := int(metadata.get("sell_price",0))
					if sell_price <= 0:
						continue
					sell_count += 1
					_trade_button(sell_rows,"trade_sell",String(item_id),1,String(metadata.get("display_name",item_id)),sell_price,is_open,"商店已打烊")
					var held:=label("持有 ×"+str(quantities[item_id]),sell_rows);UI_THEME.apply_text_role(held,UI_THEME.ROLE_CAPTION)
				if sell_count == 0:
					label("背包里没有可出售物品。",sell_rows)
				var rule:=label("余额、容量、物品数量与价格会在提交时再次校验。");UI_THEME.apply_text_role(rule,UI_THEME.ROLE_TOOLTIP)
			else:
				label("当前存档没有可用的交易状态。")
			button(row(),"close_trade","back","关闭交易 / Esc")
		"world":
			panel.hide();get_node("Backdrop").hide();hud_panel.visible=true
			var status:=row(hud)
			button(status,"pause","pause","暂停 / Esc")
			if context.get("has_gameplay",false):
				button(status,"inventory","inventory","背包 / B")
			var text:=Label.new();text.text=context.get("player_name","")+"  ·  "+str(context.get("world_label","世界"));text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text.add_theme_color_override("font_color",UI_THEME.COLOR_HUD_TEXT);status.add_child(text)
			var gameplay: Dictionary = context.get("gameplay",{})
			if gameplay.get("ok",false):
				var clock_label:=Label.new();clock_label.text=_clock_text(gameplay.clock);clock_label.add_theme_color_override("font_color",UI_THEME.COLOR_HUD_TEXT);status.add_child(clock_label)
				wallet_label=Label.new();wallet_label.text="金币 "+str(gameplay.wallet.money);wallet_label.add_theme_color_override("font_color",UI_THEME.COLOR_HUD_TEXT);status.add_child(wallet_label)
				var action_state: Dictionary = context.get("farm_action",{})
				var hint:=Label.new()
				if action_state.get("is_busy",false):
					hint.text=String(action_state.get("label","操作"))+(" · 准备中，Esc取消" if action_state.get("phase","")=="prepare" else " · 已提交，收势中")
				else:
					if context.get("space_id","")=="space.house":
						hint.text="E 与门 / 床 / 箱子交互 · B 背包"
					elif context.get("space_id","")=="space.shop":
						hint.text="E 与柜台 / 门交互 · B 背包"
					elif context.get("space_id","")=="space.village":
						hint.text="E 采集 / 商店门 / 工坊门 / 农庄出口 · B 背包"
					elif context.get("space_id","")=="space.workshop":
						hint.text="E 与工坊门交互 · B 背包"
					else:
						var selected: Variant=gameplay.inventory.slots[gameplay.inventory.selected_slot_index]
						var selected_name:="空手"
						if selected!=null:
							selected_name=str(gameplay.items.get(String(selected.item_id),{}).get("display_name",selected.item_id))
						hint.text="E 使用 "+selected_name+" · B 背包"
				hint.add_theme_color_override("font_color",UI_THEME.COLOR_HUD_TEXT);hud.add_child(hint)
				_build_quickbar(gameplay)
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
