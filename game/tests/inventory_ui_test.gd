extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL inventory_ui ",label)

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
	slots[10]={"item_id":"item.radish","quantity":2}
	var gameplay := {
		"ok":true,
		"clock":{"day":2,"minute_of_day":510},
		"wallet":{"money":145},
		"inventory":{"capacity":12,"selected_slot_index":2,"slots":slots},
		"items":{
			"item.hoe":{"display_name":"锄头","buy_price":0,"sell_price":0},
			"item.watering_can":{"display_name":"浇水壶","buy_price":0,"sell_price":0},
			"item.radish_seed":{"display_name":"萝卜种子","buy_price":20,"sell_price":0},
			"item.radish":{"display_name":"萝卜","buy_price":0,"sell_price":35}
		}
	}
	view.show_page("inventory",{
		"gameplay":gameplay,
		"error":""
	})
	await process_frame

	check(view.panel.custom_minimum_size==Vector2(600,286),"inventory uses wide but viewport-safe panel")
	var grid := view.body.find_child("InventoryGrid",true,false) as GridContainer
	check(grid!=null and grid.columns==4 and grid.get_child_count()==12,"inventory keeps all twelve slots in a 4x3 grid")
	if grid!=null and grid.get_child_count()==12:
		var selected := grid.get_child(2) as Button
		var eleventh := grid.get_child(10) as Button
		check(selected!=null and selected.button_pressed,"authoritative selected slot has a non-color pressed state")
		check(selected!=null and selected.tooltip_text.contains("萝卜种子") and selected.tooltip_text.contains("×4"),"selected slot preserves real name and quantity semantics")
		check(eleventh!=null and eleventh.tooltip_text.contains("点击选择") and not eleventh.tooltip_text.contains("快捷键 11"),"slots eleven and twelve do not invent keyboard shortcuts")
		check(selected!=null and selected.has_focus(),"inventory opens with focus on the selected slot")
	var detail := view.body.find_child("InventoryDetail",true,false) as PanelContainer
	check(detail!=null,"selected item detail panel is present")
	if detail!=null:
		var text := ""
		for child: Node in detail.find_children("*","Label",true,false):
			text += (child as Label).text+"\n"
		check(text.contains("萝卜种子") and text.contains("持有 ×4") and text.contains("买入 20币"),"detail panel uses authoritative item metadata")
	check(view.subtitle.text.contains("B / Esc"),"close shortcut remains visible")

	view.queue_free()
	await process_frame
	print("INVENTORY_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
