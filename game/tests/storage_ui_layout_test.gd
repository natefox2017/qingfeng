extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL storage_ui_layout ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	var bag: Array = []
	bag.resize(12)
	bag[0]={"item_id":"item.hoe","quantity":1}
	bag[2]={"item_id":"item.radish_seed","quantity":4}
	var chest: Array = []
	chest.resize(24)
	chest[1]={"item_id":"item.radish","quantity":2}
	var gameplay := {
		"ok":true,
		"inventory":{"capacity":12,"container_id":"container.player","slots":bag},
		"storage":{"capacity":24,"container_id":"container.home_chest","slots":chest},
		"items":{
			"item.hoe":{"display_name":"锄头"},
			"item.radish_seed":{"display_name":"萝卜种子"},
			"item.radish":{"display_name":"萝卜"}
		}
	}
	view.show_page("storage",{"gameplay":gameplay,"error":""})
	await process_frame

	check(view.panel.custom_minimum_size==Vector2(610,292),"storage page stays within the 640x360 logical viewport")
	var bag_grid := view.body.find_child("StorageBagGrid",true,false) as GridContainer
	var chest_grid := view.body.find_child("StorageChestGrid",true,false) as GridContainer
	check(bag_grid!=null and bag_grid.columns==4 and bag_grid.get_child_count()==12,"bag side shows twelve slots in a compact grid")
	check(chest_grid!=null and chest_grid.columns==6 and chest_grid.get_child_count()==24,"chest side shows twenty-four slots without scrolling")
	if bag_grid!=null:
		var filled := bag_grid.get_child(0) as Button
		var empty := bag_grid.get_child(1) as Button
		check(filled!=null and not filled.disabled and filled.tooltip_text.contains("存入木箱"),"filled bag slot keeps deposit intent semantics")
		check(empty!=null and empty.disabled,"empty bag slot is a visible but disabled capacity position")
	if chest_grid!=null:
		var filled_chest := chest_grid.get_child(1) as Button
		check(filled_chest!=null and not filled_chest.disabled and filled_chest.tooltip_text.contains("取回背包"),"filled chest slot keeps withdrawal intent semantics")
	var text := ""
	for child: Node in view.body.find_children("*","Label",true,false):
		text += (child as Label).text+"\n"
	check(text.contains("背包  2 / 12格") and text.contains("木箱  1 / 24格"),"capacity counters derive from live slot occupancy")
	check(view.buttons.has("close_storage") and view.buttons["close_storage"].accessibility_name.contains("Esc"),"storage close action remains explicit and accessible")

	view.queue_free()
	await process_frame
	print("STORAGE_UI_LAYOUT_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
