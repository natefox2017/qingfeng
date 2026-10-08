extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL new_game_ui ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	view.show_page("new_game",{
		"player_name":"小禾",
		"dog_name":"阿豆",
		"error":""
	})
	await process_frame

	check(view.title.text=="开始新的生活" and view.subtitle.text.contains("小狗"),"new-game page uses player-facing premise")
	check(view.body.find_child("NewGameIdentity",true,false)!=null,"new-game identity fields share one section")
	check(view.player_name!=null and view.player_name.name=="PlayerNameInput" and view.player_name.max_length==16,"player name keeps the authoritative length limit")
	check(view.dog_name!=null and view.dog_name.name=="DogNameInput" and view.dog_name.max_length==16,"dog name keeps the authoritative length limit")
	check(view.player_name.text=="小禾" and view.dog_name.text=="阿豆","new-game page projects current form values")
	check(view.player_name.has_focus(),"player name receives initial focus")
	check(view.player_name.accessibility_name=="玩家名字" and view.dog_name.accessibility_name.contains("可留空"),"identity inputs keep accessible names")
	check(view.buttons.has("create") and view.buttons.has("back"),"new-game page keeps create and cancel actions")
	check((view.buttons["create"] as Button).text=="确认进入" and (view.buttons["back"] as Button).text=="返回","approved entry actions stay clickable and readable")
	check((view.buttons["create"] as Button).tooltip_text.contains("创建独立存档"),"create action explains real save semantics")
	var page_text := ""
	for child: Node in view.body.find_children("*","Label",true,false):
		page_text += (child as Label).text+"\n"
	check(page_text.contains("已有存档不会被覆盖") and not page_text.contains("尚未接入"),"new-game copy explains append-only behavior without engineering status")

	view.queue_free()
	await process_frame
	print("NEW_GAME_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
