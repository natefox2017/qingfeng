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
	var requested_actions: Array[String] = []
	view.action_requested.connect(func(action: String, _payload: Dictionary): requested_actions.append(action))

	view.show_page("title",{"saves":[],"error":""})
	await process_frame
	var has_approved_art := view.approved_art_backdrop != null and view.approved_art_backdrop.visible
	if has_approved_art:
		check(view.approved_art_backdrop.texture.get_size()==Vector2(1672,941),"title uses the approved 1672x941 source artwork")
		check(not view.center.visible and view.title_overlay.visible,"approved title uses an image-aligned overlay without a second panel")
		check(not view.title.visible and not view.subtitle.visible,"baked title logo and premise are not duplicated by live labels")
		check(view.body.find_child("TitleMenu",true,false)==null and view.body.find_child("TitleActions",true,false)==null,"approved title has no competing centered menu panel")
		var live_labels := {"new_game":"开始游戏","continue":"继续游戏","settings":"设置","quit":"退出"}
		for action in live_labels:
			var hotspot := view.buttons[action] as Button
			var normal_style := hotspot.get_theme_stylebox("normal") as StyleBoxFlat
			check(hotspot!=null and hotspot.text==live_labels[action] and hotspot.accessibility_name!="" and hotspot.focus_mode==Control.FOCUS_ALL and normal_style.bg_color.a==1.0,"%s label is live text on an accessible, focusable Button covering the baked copy" % action)
		check(is_equal_approx((view.buttons["new_game"] as Button).anchor_left,0.416) and is_equal_approx((view.buttons["new_game"] as Button).anchor_top,0.397),"new-game hit target aligns to the approved first menu row")
		check((view.buttons["load"] as Button).text=="选择存档" and (view.buttons["load"] as Button).anchor_top>0.85,"live save button replaces the non-interactive click-anywhere banner")
		var first_button := view.buttons["new_game"] as Button
		check(first_button.get_node(first_button.focus_neighbor_bottom)==view.buttons["continue"],"down navigation follows the artwork menu order")
	else:
		check(view.title.text=="晴风谷" and view.title.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,"fallback title page centers the game brand")
		check(view.subtitle.text.contains("一段新的乡居生活"),"fallback title page keeps the player-facing premise")
		check(view.body.find_child("TitleMenu",true,false)!=null and view.body.find_child("TitleActions",true,false) is VBoxContainer,"missing artwork keeps the native fallback menu")
		check((view.buttons["new_game"] as Button).text=="开始游戏" and (view.buttons["continue"] as Button).text=="继续游戏","fallback Chinese menu wording uses actual buttons")
	check(view.approved_art_backdrop!=null and view.approved_art_backdrop.mouse_filter==Control.MOUSE_FILTER_IGNORE,"approved PNG never blocks real menu inputs")
	check(view.buttons.size()==5 and view.buttons.has("continue") and view.buttons.has("new_game") and view.buttons.has("load") and view.buttons.has("settings") and view.buttons.has("quit"),"title page exposes the five real entry actions")
	check((view.buttons["continue"] as Button).disabled,"continue is disabled without a recent save")
	check((view.buttons["new_game"] as Button).has_focus(),"new game receives default focus when continue is unavailable")
	(view.buttons["load"] as Button).pressed.emit()
	check(requested_actions==["load"],"live title Button emits the real save-list action")
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
