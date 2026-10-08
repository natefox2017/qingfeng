extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL hud_ui_contract ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	var slots: Array = []
	slots.resize(12)
	slots[0]={"item_id":"item.hoe","quantity":1}
	slots[1]={"item_id":"item.watering_can","quantity":1}
	slots[2]={"item_id":"item.radish_seed","quantity":4}
	var gameplay := {
		"ok":true,
		"clock":{"day":1,"minute_of_day":480},
		"wallet":{"money":180},
		"inventory":{"capacity":12,"selected_slot_index":2,"slots":slots},
		"items":{
			"item.hoe":{"display_name":"锄头"},
			"item.watering_can":{"display_name":"浇水壶"},
			"item.radish_seed":{"display_name":"萝卜种子"}
		}
	}
	view.show_page("world",{
		"player_name":"小禾",
		"world_label":"农庄第一屏",
		"space_id":"space.farm",
		"has_gameplay":true,
		"gameplay":gameplay,
		"farm_action":{"is_busy":false},
		"error":""
	})
	await process_frame

	check(view.panel.visible==false,"world hides modal page surface")
	check(view.hud_status!=null and view.hud_status.position==Vector2(480,8),"day/time/money status stays in top-right gameplay-safe area")
	check(view.hud_hint!=null and view.hud_hint.position==Vector2(150,270),"interaction hint sits above quickbar instead of covering world center")
	check(view.quickbar_panel!=null and view.quickbar_panel.position==Vector2(65,304),"quickbar stays bottom-centered at 640x360 logical viewport")
	check(view.quickbar!=null and view.quickbar.get_child_count()==12,"quickbar renders all authoritative inventory slots")
	var selected: Button = view.quickbar.get_child(2)
	check(selected.button_pressed and selected.accessibility_name.contains("已选中"),"selected quick slot has non-color pressed and accessibility state")
	check(selected.tooltip_text.contains("萝卜种子") and selected.tooltip_text.contains("×4"),"quick slot keeps item name and quantity text semantics")
	check(view.wallet_label!=null and view.wallet_label.text.contains("第1天") and view.wallet_label.text.contains("08:00"),"status card projects authoritative day and time")

	view.queue_free()
	await process_frame
	print("HUD_UI_CONTRACT_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
