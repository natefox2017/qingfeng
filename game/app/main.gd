extends Control
## A single entry point. The current destination is explicitly a test fixture.
const REQUEST = preload("res://app/scene_request.gd")
const LOCKS = preload("res://app/input_locks.gd")
const DEFAULT_ROOM := "res://tests/fixtures/collision_room.tscn"
const MOVEMENT_ACTIONS := [&"move_left", &"move_right", &"move_up", &"move_down"]
enum State { TITLE, LOADING, WORLD }
var state: State = State.TITLE
var generation: int = 0
var room: Node2D
var locks: RefCounted = LOCKS.new()
var last_error: String = ""
var _request: RefCounted
var _activation_pending: bool = false
const CODEC = preload("res://persistence/session_codec.gd")
const STORE = preload("res://persistence/session_store.gd")
const SETTINGS = preload("res://persistence/settings_store.gd")
var store: RefCounted = STORE.new()
var settings: RefCounted = SETTINGS.new()
var active_snapshot: Dictionary = {}
var active_save_id := ""
var _entry_snapshot: Dictionary = {}
var _entry_creates_save := false
var _page := "title"
var _settings_origin := "title"
var _names := {"player_name":"", "dog_name":""}
var _import_envelope: Dictionary = {}
@onready var view: Control = $Interface/Screen

func _ready() -> void:
	locks.changed.connect(_apply_input)
	settings.initialize()
	view.action_requested.connect(_on_action)
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_close_requested)
	_update_interface()

func start_world(path: String = DEFAULT_ROOM, request_override: RefCounted = null) -> bool:
	if state != State.TITLE:
		return false
	generation += 1
	last_error = ""
	_activation_pending = false
	_request = request_override if request_override != null else REQUEST.new()
	var error: Error = _request.begin(path)
	if error != OK:
		_request = null
		last_error = "场景不可用（%s），没有创建会话。" % error
		_update_interface()
		return false
	state = State.LOADING
	_apply_input()
	_update_interface()
	return true

func _process(_delta: float) -> void:
	if settings.tick(_delta):
		_page = "settings"
		last_error = "设置确认超时，已恢复原设置。"
		_update_interface()
	elif settings.is_previewing and is_instance_valid(view.countdown):
		view.countdown.text = "%d 秒后自动恢复" % ceili(settings.remaining_seconds)
	if state != State.LOADING or _activation_pending or _request == null:
		return
	var status: int = _request.status()
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene: PackedScene = _request.take_scene()
		_activation_pending = true
		_activate_room.call_deferred(scene, generation)
	elif status in [ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED]:
		return_to_title()
		last_error = "加载失败，可以重试。"
		_update_interface()

func _activate_room(scene: PackedScene, requested_generation: int) -> void:
	if requested_generation != generation or state != State.LOADING:
		return
	var instance: Node = scene.instantiate() if scene != null else null
	if not instance is Node2D or not instance.has_method("set_input_enabled") or not instance.has_method("get_player"):
		if instance != null:
			instance.free()
		return_to_title()
		last_error = "场景缺少世界输入接口，未进入游戏。"
		_update_interface()
		return
	room = instance as Node2D
	add_child(room)
	move_child(room, 0)
	# Physics-space synchronization is required before validating a restored point.
	# The world cannot process movement or commit a new save until this completes.
	room.set_input_enabled(false)
	await get_tree().physics_frame
	if requested_generation != generation or state != State.LOADING or not is_instance_valid(room):
		return
	if not _entry_snapshot.is_empty():
		var point: Dictionary = _entry_snapshot.world_position_px
		var position := Vector2(point.x,point.y)
		var circle := CircleShape2D.new();circle.radius = 4.0
		var query := PhysicsShapeQueryParameters2D.new();query.shape=circle
		query.collision_mask = 1;query.transform = Transform2D(0,position)
		if not room.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
			return_to_title();last_error = "存档落点被阻挡，未进入世界，也未改写存档。";_update_interface();return
		if _entry_creates_save:
			var result: Dictionary = store.write_new(_entry_snapshot)
			if not result.ok:
				return_to_title();last_error="新档未能保存："+result.error_code;_update_interface();return
			active_save_id = result.save_id
		active_snapshot = _entry_snapshot.duplicate(true)
		room.get_player().position = position
		room.get_player().facing = StringName(active_snapshot.facing)
	_entry_snapshot.clear();_entry_creates_save=false
	state = State.WORLD
	_request = null
	_activation_pending = false
	_clear_movement()
	_apply_input()
	_update_interface()

func return_to_title() -> void:
	settings.revert()
	active_snapshot.clear();active_save_id=""
	_entry_snapshot.clear();_entry_creates_save=false
	_page="title"
	generation += 1
	state = State.TITLE
	_request = null
	_activation_pending = false
	if is_instance_valid(room):
		room.set_input_enabled(false)
		remove_child(room)
		room.queue_free()
	room = null
	locks.set_locked(&"pause_menu", false)
	_clear_movement()
	_update_interface()

func set_pause_menu(enabled: bool) -> void:
	if state != State.WORLD:
		return
	locks.set_locked(&"pause_menu", enabled)
	_update_interface()

func set_application_focused(focused: bool) -> void:
	if not focused and settings.is_previewing:
		settings.revert();_page="settings"
		last_error="窗口失焦，已恢复原显示设置。"
		_update_interface()
	locks.set_locked(&"focus", not focused)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		set_application_focused(false)
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		set_application_focused(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause_menu"):
		return
	if view.file_dialog.visible:
		view.file_dialog.hide()
	elif _page == "display_confirm":
		_on_action("revert_settings",{})
	elif _page == "settings":
		_on_action("back",{})
	elif state == State.LOADING:
		return_to_title()
	elif state == State.WORLD:
		set_pause_menu(not locks.has_owner(&"pause_menu"))
	elif _page != "title":
		_on_action("back",{})
	get_viewport().set_input_as_handled()

func _apply_input() -> void:
	var enabled: bool = state == State.WORLD and not locks.is_locked()
	# Lock transitions discard input collected behind a menu or while unfocused.
	_clear_movement()
	if is_instance_valid(room):
		room.set_input_enabled(enabled)

func _clear_movement() -> void:
	for action: StringName in MOVEMENT_ACTIONS:
		Input.action_release(action)

func _update_interface() -> void:
	if not is_node_ready(): return
	var page := _page
	if state == State.LOADING: page="loading"
	elif state == State.WORLD and _page not in ["settings","display_confirm"]:
		page="pause" if locks.has_owner(&"pause_menu") else "world"
	var context := {"error":last_error,"settings":settings.committed,"player_name":_names.player_name,
		"dog_name":_names.dog_name,"can_save":not active_snapshot.is_empty(),"envelope":_import_envelope}
	if state == State.WORLD:context.player_name=active_snapshot.get("player_name","")
	if page in ["title","load"]:
		context["saves"] = store.list_saves()
		for entry: Dictionary in context.saves:
			if entry.ok:context["recent_id"]=entry.save_id;break
	view.show_page(page,context)

func save_progress() -> Dictionary:
	if state != State.WORLD or active_snapshot.is_empty(): return CODEC.failure("SAVE_NO_SESSION")
	var candidate: Dictionary = active_snapshot.duplicate(true)
	var player: CharacterBody2D = room.get_player()
	candidate.world_position_px = {"x":player.position.x,"y":player.position.y}
	candidate.facing = str(player.facing)
	var result: Dictionary = store.write_new(candidate)
	if result.ok:
		active_snapshot = candidate
		active_save_id = result.save_id
	return result

func _on_action(action: String, payload: Dictionary) -> void:
	# Ignore stale UI signals from a previous page or a double-click that arrives
	# after the first click started loading and destroyed the form.
	if action in ["new_game","load","continue","read_save"] and state != State.TITLE: return
	if action == "create" and (state != State.TITLE or _page != "new_game"): return
	if action in ["preview_import","choose_import"] and (state != State.TITLE or _page != "load"): return
	if action in ["confirm_import","cancel_import"] and _page != "import_review": return
	if action == "preview_settings" and _page != "settings": return
	if action in ["confirm_settings","revert_settings"] and _page != "display_confirm": return
	if action in ["pause","resume","save","save_return"] and state != State.WORLD: return
	if state == State.LOADING and action not in ["cancel_load","quit"]: return
	last_error=""
	match action:
		"new_game": _page="new_game"
		"load": _page="load"
		"create":
			_names=view.form_names()
			_names.player_name=_names.player_name.strip_edges();_names.dog_name=_names.dog_name.strip_edges()
			if not CODEC.name_is_valid(_names.player_name) or not CODEC.name_is_valid(_names.dog_name,true):
				last_error="请输入1–16字的玩家名；狗名可留空，不接受控制字符。"
			else:
				_entry_snapshot=CODEC.new_snapshot(_names.player_name,_names.dog_name)
				_entry_creates_save=true
				start_world()
		"continue":
			for entry:Dictionary in store.list_saves():
				if entry.ok:
					_on_action("read_save",{"save_id":entry.save_id});return
			last_error="没有有效存档，可以新建或导入。"
		"read_save":
			var result: Dictionary=store.read_save(str(payload.get("save_id","")))
			if result.ok:
				_entry_snapshot=result.envelope.snapshot.duplicate(true)
				_entry_creates_save=false;active_save_id=payload.save_id
				start_world()
			else: last_error="无法读取存档："+result.error_code
		"choose_import":
			view.file_dialog.popup_centered(Vector2i(560,300));return
		"preview_import":
			var result: Dictionary=store.import_preview(str(payload.get("path","")))
			if result.ok:
				_import_envelope=result.envelope.duplicate(true);_page="import_review"
			else: last_error="导入已拒绝，原文件未修改："+result.error_code;_page="load"
		"confirm_import":
			var result: Dictionary=store.confirm_import(_import_envelope)
			if result.ok:_import_envelope.clear();_page="load";last_error="已创建独立副本，请选择读取。"
			else:last_error="导入未保存："+result.error_code
		"cancel_import":_import_envelope.clear();_page="load"
		"settings":
			_settings_origin="pause" if state==State.WORLD else _page
			if state==State.WORLD:set_pause_menu(true)
			_page="settings"
		"preview_settings":
			var result:Dictionary=settings.begin_preview(view.settings_draft())
			if result.ok:_page="display_confirm"
			else:last_error=result.error_code
		"confirm_settings":
			var result:Dictionary=settings.confirm()
			if result.ok:_page="title" if state==State.WORLD else _settings_origin
			else:settings.revert();_page="settings";last_error="设置保存失败，已恢复："+result.error_code
		"revert_settings":settings.revert();_page="settings"
		"back":
			if _page=="settings":settings.revert();_page="title" if state==State.WORLD else _settings_origin
			else:_import_envelope.clear();_page="title"
		"cancel_load":return_to_title()
		"pause":set_pause_menu(true)
		"resume":_page="title";set_pause_menu(false)
		"save", "save_return":
			var result:Dictionary=save_progress()
			if result.ok:
				if action=="save_return":return_to_title()
				last_error="已保存；已有存档未被覆盖。"
			else:last_error="未能保存，仍保留当前会话："+result.error_code
		"quit":
			if state==State.TITLE:get_tree().quit()
	_update_interface()

func _close_requested() -> void:
	if state==State.WORLD:
		settings.revert();_page="title"
		set_pause_menu(true)
		last_error="请保存并返回标题后退出，以免丢失未保存的移动。"
		_update_interface()
	else:
		settings.revert();get_tree().quit()

func _exit_tree() -> void:
	settings.revert()
	generation += 1
	_clear_movement()
