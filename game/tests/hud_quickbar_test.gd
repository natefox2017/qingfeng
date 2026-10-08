extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0
var view: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL hud_quickbar ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	view=VIEW.new()
	root.add_child(view)
	await process_frame

	var slots: Array = []
	slots.resize(12)
	for index in range(12):
		slots[index]=null
	slots[0]={"item_id":"item.hoe","quantity":1}
	slots[9]={"item_id":"item.radish_seed","quantity":12}
	slots[10]={"item_id":"item.wild_herb","quantity":2}
	slots[11]={"item_id":"item.radish","quantity":3}
	var gameplay := {
		"ok":true,
		"clock":{"day":2,"minute_of_day":480},
		"wallet":{"money":195},
		"inventory":{
			"capacity":12,
			"selected_slot_index":9,
			"slots":slots
		},
		"items":{
			"item.hoe":{"display_name":"锄头"},
			"item.radish_seed":{"display_name":"萝卜种子"},
			"item.wild_herb":{"display_name":"野菜"},
			"item.radish":{"display_name":"萝卜"}
		}
	}
	view.show_page("world",{
		"player_name":"小禾",
		"world_label":"村庄第一屏 · 工程美术",
		"space_id":"space.village",
		"has_gameplay":true,
		"gameplay":gameplay,
		"farm_action":{"is_busy":false},
		"error":""
	})
	await process_frame

	check(view.hud_panel.visible and not view.panel.visible,"world HUD uses dedicated visible panel")
	check(view.quickbar_panel!=null and view.quickbar_panel.anchor_top==1.0,"quickbar panel is anchored to bottom")
	check(view.quickbar!=null and view.quickbar.get_child_count()==12,"quickbar renders all twelve authoritative inventory slots")
	var slot_one := view.quickbar.get_child(0) as Button
	var slot_zero := view.quickbar.get_child(9) as Button
	var slot_eleven := view.quickbar.get_child(10) as Button
	var slot_twelve := view.quickbar.get_child(11) as Button
	check(slot_one.text.begins_with("1\n"),"first slot shows keyboard shortcut 1")
	check(slot_zero.text.begins_with("[0]\n") and slot_zero.button_pressed,"tenth selected slot shows non-color selected marker and shortcut 0")
	check(slot_zero.accessibility_name.contains("快捷键 0") and slot_zero.accessibility_name.contains("已选中"),"selected slot accessibility exposes shortcut and selected state")
	check(slot_eleven.text.begins_with("—\n") and slot_eleven.tooltip_text.contains("点击选择"),"eleventh slot does not invent numeric keyboard shortcut")
	check(slot_twelve.text.begins_with("—\n") and slot_twelve.tooltip_text.contains("点击选择"),"twelfth slot does not invent numeric keyboard shortcut")
	check(view.wallet_label.text=="金币 195","wallet value is a distinct HUD field")
	check(view.buttons.has("pause") and view.buttons.has("inventory"),"HUD retains pause and inventory accessible actions")

	view.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("HUD_QUICKBAR_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
