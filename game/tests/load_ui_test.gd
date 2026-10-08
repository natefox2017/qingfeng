extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL load_ui ",label)

func find_button_with_tooltip(root_node: Node, needle: String) -> Button:
	for child: Node in root_node.get_children():
		if child is Button and (child as Button).tooltip_text.contains(needle):
			return child as Button
		var nested := find_button_with_tooltip(child,needle)
		if nested != null:
			return nested
	return null

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	var valid := {
		"save_id":"save.valid",
		"ok":true,
		"error_code":"",
		"envelope":{
			"saved_at_utc":"2026-10-08T04:00:00Z",
			"content_version":"first_playable_v1",
			"snapshot":{
				"player_name":"小禾",
				"dog_name":"阿豆",
				"space_id":"space.village",
                "gameplay":{}
			}
		}
	}
	var invalid := {
		"save_id":"save.invalid",
		"ok":false,
		"error_code":"SAVE_CHECKSUM_INVALID",
		"envelope":{}
	}
	view.show_page("load",{"saves":[valid,invalid],"error":""})
	await process_frame

	check(view.title.text=="存档" and view.subtitle.text.contains("本机进度"),"save page explains local progress selection")
	check(view.panel.custom_minimum_size==Vector2(560,286),"save page fits logical viewport")
	var list := view.body.find_child("SaveList",true,false) as ScrollContainer
	var entries := view.body.find_child("SaveEntries",true,false) as VBoxContainer
	check(list!=null and entries!=null and entries.get_child_count()==2,"save page renders one card per save result")
	var text := ""
	for child: Node in view.body.find_children("*","Label",true,false):
		text += (child as Label).text+"\n"
	check(text.contains("小禾") and text.contains("村庄") and text.contains("小狗 阿豆"),"valid save card shows identity and current saved area")
	check(text.contains("2026-10-08T04:00:00Z") and text.contains("first_playable_v1"),"valid save card shows saved timestamp and content version")
	check(not text.contains("第1天") and not text.contains("游戏分钟"),"save page does not invent clock decoding outside gameplay domain")
	var read_button := find_button_with_tooltip(view.body,"读取 小禾")
	check(read_button!=null and not read_button.disabled and read_button.accessibility_name.contains("小禾"),"valid save exposes accessible read action")
	var invalid_button := find_button_with_tooltip(view.body,"无法读取")
	check(invalid_button!=null and invalid_button.disabled and invalid_button.tooltip_text.contains("SAVE_CHECKSUM_INVALID"),"invalid save remains visible but cannot be loaded")
	check(view.buttons.has("choose_import") and view.buttons.has("back"),"save page keeps import and back actions")

	view.show_page("load",{"saves":[],"error":""})
	await process_frame
	var empty_text := ""
	for child: Node in view.body.find_children("*","Label",true,false):
		empty_text += (child as Label).text+"\n"
	check(empty_text.contains("还没有本机存档"),"empty save list has a player-facing empty state")

	view.queue_free()
	await process_frame
	print("LOAD_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
