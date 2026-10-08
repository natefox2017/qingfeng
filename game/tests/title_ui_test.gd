extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL title_ui ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	view.show_page("title",{"saves":[],"error":""})
	await process_frame
	check(view.title.text=="晴风谷" and view.title.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,"title page centers the game brand")
	check(view.subtitle.text.contains("一段新的乡居生活"),"title page keeps the player-facing premise")
	check(view.body.find_child("TitleMenu",true,false)!=null and view.body.find_child("TitleActions",true,false)!=null,"title page has one shared menu surface")
	check(view.body.find_child("TitleActions",true,false) is VBoxContainer,"approved title menu uses a readable vertical stack of live controls")
	check((view.buttons["new_game"] as Button).text=="开始游戏" and (view.buttons["continue"] as Button).text=="继续游戏","approved Chinese menu wording uses actual buttons")
	check(view.approved_art_backdrop!=null and view.approved_art_backdrop.mouse_filter==Control.MOUSE_FILTER_IGNORE,"optional approved PNG does not block real menu inputs")
	check(view.buttons.size()==5 and view.buttons.has("continue") and view.buttons.has("new_game") and view.buttons.has("load") and view.buttons.has("settings") and view.buttons.has("quit"),"title page exposes the five real entry actions")
	check((view.buttons["continue"] as Button).disabled,"continue is disabled without a recent save")
	check((view.buttons["new_game"] as Button).has_focus(),"new game receives default focus when continue is unavailable")
	var page_text := view.title.text+"\n"+view.subtitle.text
	for child: Node in view.body.find_children("*","Label",true,false):
		page_text += (child as Label).text+"\n"
	check(not page_text.contains("开发版") and not page_text.contains("仍在制作"),"player-facing title no longer exposes engineering status copy")

	view.show_page("title",{"saves":[],"recent_id":"save.test","error":""})
	await process_frame
	check(not (view.buttons["continue"] as Button).disabled and (view.buttons["continue"] as Button).has_focus(),"recent save enables and focuses continue")
	check((view.buttons["continue"] as Button).tooltip_text.contains("最近"),"continue action keeps clear accessible intent")

	view.queue_free()
	await process_frame
	print("TITLE_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
