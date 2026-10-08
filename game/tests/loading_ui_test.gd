extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL loading_ui ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	view.show_page("loading",{"error":""})
	await process_frame

	check(view.title.text=="准备进入晴风谷","loading page uses player-facing title")
	check(view.subtitle.text.contains("加载场景") and view.subtitle.text.contains("安全落点"),"loading page states the real loading stages")
	check(view.panel.custom_minimum_size==Vector2(440,220),"loading page uses compact viewport-safe panel")
	check(view.body.find_child("LoadingSummary",true,false)!=null,"loading page has one focused summary panel")
	var text := ""
	for child: Node in view.body.find_children("*","Label",true,false):
		text += (child as Label).text+"\n"
	check(text.contains("场景、布局合同和落点") and text.contains("不显示无法准确测量的百分比"),"loading copy explains validation without fake progress")
	check(not text.contains("%") and not text.contains("37") and not text.contains("82"),"loading page does not invent a progress percentage")
	check(view.buttons.has("cancel_load"),"loading page keeps the cancel action")
	check((view.buttons["cancel_load"] as Button).tooltip_text.contains("Esc"),"cancel action exposes keyboard escape semantics")
	check((view.buttons["cancel_load"] as Button).has_focus(),"cancel is the only/default loading-page focus target")

	view.queue_free()
	await process_frame
	print("LOADING_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
