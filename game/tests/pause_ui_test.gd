extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL pause_ui ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	var gameplay := {
		"ok":true,
		"clock":{"day":3,"minute_of_day":750},
		"wallet":{"money":260}
	}
	view.show_page("pause",{
		"has_gameplay":true,
		"gameplay":gameplay,
		"world_label":"村庄第一屏 · 工程美术",
		"can_save":true,
		"error":""
	})
	await process_frame

	check(view.title.text=="暂歇一下" and view.subtitle.text.contains("Esc"),"pause page states its game-layer close shortcut")
	check(view.body.find_child("PauseSummary",true,false)!=null,"pause page has one live-state summary panel")
	var text := ""
	for child: Node in view.body.find_children("*","Label",true,false):
		text += (child as Label).text+"\n"
	check(text.contains("村庄第一屏") and text.contains("第3天") and text.contains("12:30") and text.contains("260 币"),"pause summary projects current area time and wallet")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1366,768)]:
		root.size = size
		await process_frame
		await process_frame
		var found := false
		for child: Node in view.body.find_children("*","Label",true,false):
			var value := child as Label
			if value.text == "260 币":
				found = true
				check(value.autowrap_mode == TextServer.AUTOWRAP_OFF and value.get_line_count() == 1 and value.size.x >= value.get_combined_minimum_size().x, "currency stays one readable line at " + str(size))
		check(found, "wallet label is present at " + str(size))
	check(view.buttons.has("resume") and view.buttons.has("save") and view.buttons.has("settings") and view.buttons.has("save_return"),"pause page exposes the four first-playable actions")
	check((view.buttons["resume"] as Button).has_focus(),"pause opens with focus on continue")
	check(not (view.buttons["save"] as Button).disabled and not (view.buttons["save_return"] as Button).disabled,"save actions are enabled only when a session can save")

	view.show_page("pause",{
		"has_gameplay":false,
		"gameplay":{},
		"world_label":"旧入口碰撞测试场",
		"can_save":false,
		"error":""
	})
	await process_frame
	check((view.buttons["save"] as Button).disabled and (view.buttons["save_return"] as Button).disabled,"unsavable fixture disables both save actions")
	check((view.buttons["resume"] as Button).has_focus(),"continue remains the default focus in fixture pause")

	view.queue_free()
	await process_frame
	print("PAUSE_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
