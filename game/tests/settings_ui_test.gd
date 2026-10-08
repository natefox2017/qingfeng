extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL settings_ui ",label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	var settings := {
		"master_volume":0.65,
		"is_fullscreen":false,
		"is_vsync_enabled":true
	}
	view.show_page("settings",{"settings":settings,"error":""})
	await process_frame

	check(view.panel.custom_minimum_size==Vector2(520,286),"settings page fits the logical viewport")
	check(view.body.find_child("SettingsSoundSection",true,false)!=null and view.body.find_child("SettingsDisplaySection",true,false)!=null,"settings separates sound and display")
	var volume := view.body.find_child("SettingVolume",true,false) as HSlider
	var value_label := view.body.find_child("VolumeValue",true,false) as Label
	check(volume!=null and is_equal_approx(volume.value,0.65) and value_label!=null and value_label.text=="65%","volume control and percentage start from committed setting")
	if volume!=null:
		volume.value=0.35
	await process_frame
	check(value_label!=null and value_label.text=="35%","volume percentage follows the slider draft")
	var fullscreen := view.body.find_child("SettingFullscreen",true,false) as CheckBox
	var vsync := view.body.find_child("SettingVsync",true,false) as CheckBox
	check(fullscreen!=null and fullscreen.tooltip_text!="" and fullscreen.accessibility_name=="全屏显示","fullscreen control keeps tooltip and accessible name")
	check(vsync!=null and vsync.button_pressed and vsync.accessibility_name=="垂直同步","vsync control reflects committed state and accessible name")
	if fullscreen!=null:
		fullscreen.button_pressed=true
	if vsync!=null:
		vsync.button_pressed=false
	var draft: Dictionary = view.settings_draft()
	check(is_equal_approx(float(draft.master_volume),0.35) and draft.is_fullscreen and not draft.is_vsync_enabled,"settings_draft still owns only current control values")
	check(view.buttons.has("preview_settings") and view.buttons.has("back"),"settings retains preview and cancel actions")

	view.show_page("display_confirm",{"error":""})
	await process_frame
	check(view.panel.custom_minimum_size==Vector2(440,230),"display confirmation uses compact focused panel")
	check(view.body.find_child("DisplayConfirmSummary",true,false)!=null,"display confirmation has one explanatory summary")
	check(view.countdown!=null and view.countdown.name=="SettingsCountdown" and view.countdown.text.contains("10 秒"),"confirmation exposes the revert countdown")
	check(view.buttons.has("confirm_settings") and view.buttons.has("revert_settings"),"confirmation keeps explicit confirm and restore actions")

	view.queue_free()
	await process_frame
	print("SETTINGS_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
