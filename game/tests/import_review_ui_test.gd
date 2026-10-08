extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL import_review_ui ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	var envelope := {
		"saved_at_utc":"2026-10-08T04:10:00Z",
		"content_version":"first_playable_v1",
		"snapshot":{
			"player_name":"小禾",
			"dog_name":"阿豆",
			"space_id":"space.shop"
		}
	}
	view.show_page("import_review",{"envelope":envelope,"error":""})
	await process_frame

	check(view.title.text=="确认导入" and view.subtitle.text.contains("外部存档"),"import review clearly identifies external save review")
	check(view.panel.custom_minimum_size==Vector2(500,276),"import review fits logical viewport")
	check(view.body.find_child("ImportSummary",true,false)!=null,"import review has one metadata summary card")
	var text := ""
	for child: Node in view.body.find_children("*","Label",true,false):
		text += (child as Label).text+"\n"
	check(text.contains("小禾") and text.contains("小狗 阿豆") and text.contains("杂货铺"),"import summary shows identity and saved area")
	check(text.contains("2026-10-08T04:10:00Z") and text.contains("first_playable_v1"),"import summary shows frozen envelope metadata")
	check(text.contains("新的本机存档副本") and text.contains("原文件") and text.contains("已有存档"),"import review explains copy semantics before write")
	check(view.buttons.has("confirm_import") and view.buttons.has("cancel_import"),"import review keeps confirm and cancel actions")
	check((view.buttons["confirm_import"] as Button).tooltip_text.contains("独立副本"),"confirm action describes the write result")
	check((view.buttons["cancel_import"] as Button).accessibility_name.contains("不写入"),"cancel action explicitly promises no write")

	view.queue_free()
	await process_frame
	print("IMPORT_REVIEW_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
