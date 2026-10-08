extends Control
## Single application entry. New saves use the editable farm first screen and one
## authoritative GameplaySession. Schema-1 collision saves remain readable only
## through the explicit legacy fixture.

const REQUEST = preload("res://app/scene_request.gd")
const LOCKS = preload("res://app/input_locks.gd")
const CODEC = preload("res://persistence/session_codec.gd")
const STORE = preload("res://persistence/session_store.gd")
const SETTINGS = preload("res://persistence/settings_store.gd")
const GAMEPLAY = preload("res://app/gameplay_session.gd")
const FARM_ACTION = preload("res://app/farm_action_runner.gd")

const LEGACY_ROOM := "res://tests/fixtures/collision_room.tscn"
const FARM_ROOM := "res://world/farm_first_screen.tscn"
const HOUSE_ROOM := "res://world/house_interior.tscn"
const VILLAGE_ROOM := "res://world/village_first_screen.tscn"
const SHOP_ROOM := "res://world/shop_interior.tscn"
const WORKSHOP_ROOM := "res://world/workshop_interior.tscn"
const DEFAULT_ROOM := FARM_ROOM
const MOVEMENT_ACTIONS := [&"move_left", &"move_right", &"move_up", &"move_down"]
const GAMEPLAY_PAUSE_OWNERS := [&"pause_menu", &"inventory", &"storage", &"trade", &"dialogue", &"focus"]
const QUICK_SLOT_ACTIONS := [&"select_slot_1",&"select_slot_2",&"select_slot_3",&"select_slot_4",&"select_slot_5",&"select_slot_6",&"select_slot_7",&"select_slot_8",&"select_slot_9",&"select_slot_0"]
const RESIDENT_CONVERSATION_START_MINUTE := 480
const RESIDENT_CONVERSATION_END_MINUTE := 540
const RESIDENT_CONVERSATION_DURATION_MINUTES := 10

enum State { TITLE, LOADING, WORLD }

var state: State = State.TITLE
var generation: int = 0
var room: Node2D
var gameplay_session: RefCounted
var farm_action: RefCounted = FARM_ACTION.new()
var locks: RefCounted = LOCKS.new()
var last_error: String = ""
var _request: RefCounted
var _activation_pending: bool = false
var store: RefCounted = STORE.new()
var settings: RefCounted = SETTINGS.new()
var active_snapshot: Dictionary = {}
var active_save_id := ""
var _entry_snapshot: Dictionary = {}
var _entry_creates_save := false
var _entry_requires_gameplay := false
var _page := "title"
var _settings_origin := "title"
var _focus_action := ""
var _names := {"player_name":"", "dog_name":""}
var _import_envelope: Dictionary = {}
var _transition_pending: bool = false
var _transition_generation: int = 0
var _transition_candidate: Node2D
var _resident_handoff_pending := false
var _resident_conversation_demo_day := 0
var _resident_conversation_end_game_minute := -1
var _player_dialogue_conversation_id := ""
var _player_dialogue_resident_id := ""
var _dialogue_context: Dictionary = {}
var _dialogue_feedback := ""

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
		_focus_action = "preview_settings"
		last_error = "设置确认超时，已恢复原设置。"
		_update_interface()
	elif settings.is_previewing and is_instance_valid(view.countdown):
		view.countdown.text = "%d 秒后自动恢复" % ceili(settings.remaining_seconds)
	if farm_action.is_busy():
		_tick_farm_action(_delta)
	if state == State.WORLD and gameplay_session != null and gameplay_session.is_configured():
		var time_result: Dictionary = gameplay_session.advance_real_seconds(_delta)
		if time_result.ok and int(time_result.advanced_minutes) > 0:
			_refresh_farm_world()
			_update_interface()
		_poll_resident_handoff()
		_poll_resident_conversation()
	if state != State.LOADING or _activation_pending or _request == null:
		return
	var status: int = _request.status()
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene: PackedScene = _request.take_scene()
		_activation_pending = true
		_activate_room.call_deferred(scene, generation)
	elif status in [ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED]:
		last_error = "加载失败，可以重试。"
		return_to_title()

func _activate_room(scene: PackedScene, requested_generation: int) -> void:
	if requested_generation != generation or state != State.LOADING:
		return
	var instance: Node = scene.instantiate() if scene != null else null
	if not (instance is Node2D) or not instance.has_method("set_input_enabled") or not instance.has_method("get_player"):
		if instance != null:
			instance.free()
		last_error = "场景缺少世界输入接口，未进入游戏。"
		return_to_title()
		return
	room = instance as Node2D
	add_child(room)
	move_child(room, 0)
	room.set_input_enabled(false)
	await get_tree().physics_frame
	if requested_generation != generation or state != State.LOADING or not is_instance_valid(room):
		return

	var next_gameplay: RefCounted = null
	if _entry_requires_gameplay:
		if not _world_contract_valid(room):
			last_error = "世界布局合同无效，未创建或恢复会话。"
			return_to_title()
			return
		var plot_definitions: Array = _plot_definitions_for_gameplay(room)
		var forage_definitions: Array = _forage_definitions_for_gameplay(room)
		var resident_anchor_definitions: Array = _resident_anchor_definitions_for_gameplay()
		if plot_definitions.is_empty():
			last_error = "无法读取权威农庄田格布局，未创建或恢复会话。"
			return_to_title()
			return
		if forage_definitions.is_empty():
			last_error = "无法读取权威村庄采集点布局，未创建或恢复会话。"
			return_to_title()
			return
		if resident_anchor_definitions.is_empty():
			last_error = "无法读取权威居民日程锚点，未创建或恢复会话。"
			return_to_title()
			return
		next_gameplay = GAMEPLAY.new(plot_definitions,{},forage_definitions,resident_anchor_definitions)
		if not next_gameplay.is_configured():
			last_error = "玩法会话无法从权威农庄布局初始化。"
			return_to_title()
			return
		if _entry_snapshot.has("gameplay"):
			if _entry_snapshot.space_id != room.get_space_id() or not next_gameplay.restore(_entry_snapshot.gameplay):
				last_error = "完整玩法存档与当前世界布局不兼容，未恢复任何状态。"
				return_to_title()
				return
		else:
			var spawn: Vector2 = room.get_spawn_position()
			_entry_snapshot.space_id = room.get_space_id()
			_entry_snapshot.world_position_px = {"x":spawn.x,"y":spawn.y}
			var composed: Dictionary = CODEC.compose_gameplay_snapshot(_entry_snapshot,next_gameplay.snapshot())
			if composed.is_empty():
				last_error = "新玩法快照未通过存档合同，未创建存档。"
				return_to_title()
				return
			_entry_snapshot = composed
	elif _entry_snapshot.has("gameplay"):
		last_error = "完整玩法存档不能进入旧测试场。"
		return_to_title()
		return

	if _entry_snapshot.is_empty():
		# Explicit engineering fixture starts are kept for the native movement/
		# lifecycle regression. A real farm entry always carries identity state.
		if room.has_method("get_plot_definitions"):
			last_error = "正式农庄入口缺少身份快照。"
			return_to_title()
			return
		gameplay_session = null
		active_snapshot.clear()
		state = State.WORLD
		_request = null
		_activation_pending = false
		_clear_movement()
		_apply_input()
		_update_interface()
		return
	var point: Dictionary = _entry_snapshot.world_position_px
	var position := Vector2(float(point.x),float(point.y))
	if _position_is_blocked(position):
		last_error = "存档落点被阻挡，未进入世界，也未改写存档。"
		return_to_title()
		return
	if _entry_creates_save:
		var result: Dictionary = store.write_new(_entry_snapshot)
		if not result.ok:
			last_error = "新档未能保存："+result.error_code
			return_to_title()
			return
		active_save_id = result.save_id

	gameplay_session = next_gameplay
	active_snapshot = _entry_snapshot.duplicate(true)
	if not _apply_resident_runtime_to(room):
		last_error = "居民运行状态无法恢复到当前世界，未进入游戏。"
		return_to_title()
		return
	_refresh_farm_world()
	room.get_player().position = position
	room.get_player().facing = StringName(active_snapshot.facing)
	_entry_snapshot.clear()
	_entry_creates_save = false
	_entry_requires_gameplay = false
	state = State.WORLD
	_request = null
	_activation_pending = false
	_clear_movement()
	_apply_input()
	_update_interface()

func _world_contract_valid(candidate: Node2D) -> bool:
	if not is_instance_valid(candidate):
		return false
	for method_name: String in ["set_input_enabled","get_player","get_space_id","get_spawn_position","get_anchor_position","layout_contract_valid"]:
		if not candidate.has_method(method_name):
			return false
	return candidate.layout_contract_valid() and not String(candidate.get_space_id()).is_empty()

func _plot_definitions_for_gameplay(candidate: Node2D) -> Array:
	if candidate.has_method("get_plot_definitions"):
		var direct: Array = candidate.get_plot_definitions()
		if not direct.is_empty():
			return direct.duplicate(true)
	var farm_scene := load(FARM_ROOM) as PackedScene
	if farm_scene == null:
		return []
	var farm_instance := farm_scene.instantiate() as Node2D
	if farm_instance == null or not farm_instance.has_method("get_plot_definitions") or not farm_instance.has_method("layout_contract_valid"):
		if farm_instance != null:
			farm_instance.free()
		return []
	if not farm_instance.layout_contract_valid():
		farm_instance.free()
		return []
	var definitions: Array = farm_instance.get_plot_definitions().duplicate(true)
	farm_instance.free()
	return definitions

func _forage_definitions_for_gameplay(candidate: Node2D) -> Array:
	if candidate.has_method("get_forage_definitions"):
		var direct: Array = candidate.get_forage_definitions()
		if not direct.is_empty():
			return direct.duplicate(true)
	var village_scene := load(VILLAGE_ROOM) as PackedScene
	if village_scene == null:
		return []
	var village_instance := village_scene.instantiate() as Node2D
	if village_instance == null or not village_instance.has_method("get_forage_definitions") or not village_instance.has_method("layout_contract_valid"):
		if village_instance != null:
			village_instance.free()
		return []
	if not village_instance.layout_contract_valid():
		village_instance.free()
		return []
	var definitions: Array = village_instance.get_forage_definitions().duplicate(true)
	village_instance.free()
	return definitions

func _resident_anchor_definitions_for_gameplay() -> Array:
	var definitions: Array = []
	for path: String in [VILLAGE_ROOM,SHOP_ROOM,WORKSHOP_ROOM]:
		var packed := load(path) as PackedScene
		if packed == null:
			return []
		var instance := packed.instantiate() as Node2D
		if instance == null or not instance.has_method("get_resident_anchor_definitions") or not instance.has_method("layout_contract_valid"):
			if instance != null:
				instance.free()
			return []
		if not instance.layout_contract_valid():
			instance.free()
			return []
		definitions.append_array(instance.get_resident_anchor_definitions())
		instance.free()
	return definitions

func _scene_path_for_space(space_id: String) -> String:
	match space_id:
		"space.farm":
			return FARM_ROOM
		"space.house":
			return HOUSE_ROOM
		"space.village":
			return VILLAGE_ROOM
		"space.shop":
			return SHOP_ROOM
		"space.workshop":
			return WORKSHOP_ROOM
	return ""

func _position_is_blocked(position: Vector2) -> bool:
	return _position_is_blocked_in(room,position)

func _position_is_blocked_in(candidate: Node2D, position: Vector2) -> bool:
	if not is_instance_valid(candidate):
		return true
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1
	query.transform = Transform2D(0.0,position)
	return not candidate.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _set_room_camera_enabled(candidate: Node2D, enabled: bool) -> void:
	if not is_instance_valid(candidate) or not candidate.has_method("get_player"):
		return
	var camera := candidate.get_player().get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = enabled

func return_to_title() -> void:
	settings.revert()
	if gameplay_session != null and gameplay_session.is_configured():
		gameplay_session.clear_resident_conversations()
	gameplay_session = null
	active_snapshot.clear()
	active_save_id = ""
	_entry_snapshot.clear()
	_entry_creates_save = false
	_entry_requires_gameplay = false
	_page = "title"
	generation += 1
	state = State.TITLE
	_request = null
	_activation_pending = false
	if is_instance_valid(room):
		room.set_input_enabled(false)
		remove_child(room)
		room.queue_free()
	room = null
	_transition_generation += 1
	_transition_pending = false
	_resident_handoff_pending = false
	_resident_conversation_demo_day = 0
	_resident_conversation_end_game_minute = -1
	if is_instance_valid(_transition_candidate):
		_transition_candidate.queue_free()
	_transition_candidate = null
	farm_action = FARM_ACTION.new()
	locks.set_locked(&"farm_action", false)
	locks.set_locked(&"transition", false)
	locks.set_locked(&"pause_menu", false)
	locks.set_locked(&"inventory", false)
	locks.set_locked(&"storage", false)
	locks.set_locked(&"trade", false)
	locks.set_locked(&"dialogue", false)
	_player_dialogue_conversation_id = ""
	_player_dialogue_resident_id = ""
	_dialogue_context.clear()
	_dialogue_feedback = ""
	_clear_movement()
	_update_interface()

func set_pause_menu(enabled: bool) -> void:
	if state != State.WORLD:
		return
	if enabled and (farm_action.is_busy() or _transition_pending or locks.has_owner(&"dialogue")):
		return
	locks.set_locked(&"pause_menu", enabled)
	_update_interface()

func set_application_focused(focused: bool) -> void:
	if not focused:
		if _transition_pending:
			_cancel_transition("窗口失焦，门转场已取消；玩家仍留在原位置。")
		if farm_action.is_before_contact():
			_cancel_farm_action("窗口失焦，未到接触点，农事动作已取消。")
		elif farm_action.is_busy():
			_finish_farm_recovery()
		if settings.is_previewing:
			settings.revert()
			_page = "settings"
			last_error = "窗口失焦，已恢复原显示设置。"
			_update_interface()
	locks.set_locked(&"focus", not focused)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		set_application_focused(false)
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		set_application_focused(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("interact"):
		if state == State.WORLD and gameplay_session != null and not locks.has_owner(&"pause_menu") and not locks.has_owner(&"inventory") and not locks.has_owner(&"storage") and not locks.has_owner(&"trade") and not locks.has_owner(&"dialogue") and not locks.has_owner(&"focus") and not farm_action.is_busy() and not _transition_pending:
			_interact_world()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory_menu"):
		if state == State.WORLD and gameplay_session != null and not farm_action.is_busy() and not _transition_pending and not locks.has_owner(&"pause_menu") and not locks.has_owner(&"storage") and not locks.has_owner(&"trade") and not locks.has_owner(&"dialogue") and not locks.has_owner(&"focus"):
			set_inventory_menu(not locks.has_owner(&"inventory"))
			get_viewport().set_input_as_handled()
		return
	if state == State.WORLD and gameplay_session != null and not farm_action.is_busy() and not _transition_pending and not locks.has_owner(&"pause_menu") and not locks.has_owner(&"storage") and not locks.has_owner(&"trade") and not locks.has_owner(&"dialogue") and not locks.has_owner(&"focus"):
		for index in range(QUICK_SLOT_ACTIONS.size()):
			if event.is_action_pressed(QUICK_SLOT_ACTIONS[index]):
				_select_inventory_slot(index)
				get_viewport().set_input_as_handled()
				return
	if not event.is_action_pressed("pause_menu"):
		return
	if _transition_pending:
		_cancel_transition("门转场已取消；玩家仍留在原位置。")
	elif farm_action.is_before_contact():
		_cancel_farm_action("动作已取消，田地和背包没有变化。")
	elif farm_action.is_busy():
		_finish_farm_recovery()
	elif view.file_dialog.visible:
		view.file_dialog.hide()
	elif locks.has_owner(&"dialogue"):
		_finish_player_resident_dialogue()
	elif locks.has_owner(&"trade"):
		set_trade_menu(false)
	elif locks.has_owner(&"storage"):
		set_storage_menu(false)
	elif locks.has_owner(&"inventory"):
		set_inventory_menu(false)
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

func set_inventory_menu(enabled: bool) -> void:
	if state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured() or (enabled and (farm_action.is_busy() or _transition_pending or locks.has_owner(&"storage") or locks.has_owner(&"trade") or locks.has_owner(&"dialogue"))):
		return
	locks.set_locked(&"inventory",enabled)
	_page = "inventory" if enabled else "title"
	_update_interface()

func set_storage_menu(enabled: bool) -> void:
	if state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured() or (enabled and (farm_action.is_busy() or _transition_pending or locks.has_owner(&"inventory") or locks.has_owner(&"trade") or locks.has_owner(&"dialogue"))):
		return
	if enabled:
		if not is_instance_valid(room) or not room.has_method("get_space_id") or room.get_space_id() != "space.house":
			return
	locks.set_locked(&"storage",enabled)
	_page = "storage" if enabled else "title"
	_update_interface()

func set_trade_menu(enabled: bool) -> void:
	if state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured() or (enabled and (farm_action.is_busy() or _transition_pending or locks.has_owner(&"inventory") or locks.has_owner(&"storage") or locks.has_owner(&"dialogue"))):
		return
	if enabled:
		if not is_instance_valid(room) or not room.has_method("get_space_id") or room.get_space_id() != "space.shop":
			return
	locks.set_locked(&"trade",enabled)
	_page = "trade" if enabled else "title"
	_update_interface()

func _begin_player_resident_dialogue(target: Dictionary) -> void:
	if state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured() or locks.has_owner(&"dialogue"):
		return
	if not is_instance_valid(room) or not room.has_method("get_space_id"):
		return
	var room_space_id := String(room.get_space_id())
	var resident_id := String(target.get("resident_id",""))
	var expected_interaction := "dialogue.%s.%s" % [room_space_id.trim_prefix("space."),resident_id.trim_prefix("resident.")]
	if not resident_id.begins_with("resident.") or String(target.get("interaction_id",""))!=expected_interaction:
		last_error = "对话目标无效。"
		_update_interface()
		return
	var context: Dictionary = gameplay_session.player_resident_dialogue_context(resident_id)
	if not context.ok or String(context.get("space_id",""))!=room_space_id:
		last_error = "现在还不能交谈："+String(context.get("error_code","DIALOGUE_SPACE_INVALID"))
		_update_interface()
		return
	var conversation_id := _new_command_id("conversation.player")
	var invited: Dictionary = gameplay_session.invite_resident_conversation(conversation_id,"actor.player",resident_id,String(room.get_space_id()))
	if not invited.ok:
		last_error = "对方现在正忙着。"
		_update_interface()
		return
	var approaching: Dictionary = gameplay_session.approach_resident_conversation(conversation_id)
	if not approaching.ok:
		gameplay_session.cancel_resident_conversation(conversation_id)
		last_error = "没有开始交谈。"
		_update_interface()
		return
	var participating: Dictionary = gameplay_session.begin_resident_conversation(conversation_id)
	if not participating.ok:
		gameplay_session.cancel_resident_conversation(conversation_id)
		last_error = "没有开始交谈。"
		_update_interface()
		return
	_player_dialogue_conversation_id = conversation_id
	_player_dialogue_resident_id = resident_id
	_dialogue_context = context.duplicate(true)
	_dialogue_feedback = ""
	locks.set_locked(&"dialogue",true)
	_page = "dialogue"
	last_error = ""
	_refresh_farm_world()
	_update_interface()

func _gift_selected_to_resident() -> void:
	if state!=State.WORLD or gameplay_session==null or not locks.has_owner(&"dialogue") or _player_dialogue_resident_id.is_empty():
		return
	var offer: Dictionary = gameplay_session.resident_gift_offer(_player_dialogue_resident_id)
	if not bool(offer.get("can_gift",false)):
		last_error = "现在不能赠礼：" + _resident_gift_error_text(String(offer.get("reason","")))
		_update_interface()
		return
	var command := {
		"protocol_version":1,
		"command_id":_new_command_id("resident.gift"),
		"session_id":String(active_snapshot.get("session_id","")),
		"actor_id":"actor.player",
		"action":"resident.gift",
		"expected_revision":int(gameplay_session.inventory.revision),
		"payload":{
			"resident_id":_player_dialogue_resident_id,
			"item_id":String(offer.item_id),
			"quantity":1
		}
	}
	var result: Dictionary = gameplay_session.execute(command)
	if result.ok:
		_dialogue_feedback = "已送出%s，关系 +%d。今日赠礼已完成。" % [String(offer.item_name),int(offer.relationship_points)]
		last_error = ""
	else:
		last_error = "赠礼未完成：" + _resident_gift_error_text(String(result.error_code))
	_update_interface()

func _resident_gift_error_text(code: String) -> String:
	match code:
		"RESIDENT_GIFT_FIRST_MEETING_REQUIRED":
			return "先认识对方，下次交谈再送礼。"
		"RESIDENT_GIFT_DAILY_LIMIT":
			return "今天已经送过礼了，明天再来。"
		"RESIDENT_GIFT_ITEM_NOT_ALLOWED":
			return "当前物品不能赠送；请选择萝卜或野菜。"
		"RESIDENT_GIFT_SELECTED_EMPTY":
			return "当前快捷槽没有物品。"
		"STALE_REVISION":
			return "背包状态已变化，请重新尝试。"
		"INVENTORY_INSUFFICIENT_ITEM":
			return "背包里没有足够的物品。"
		_:
			return code

func _finish_player_resident_dialogue() -> void:
	if not locks.has_owner(&"dialogue") or gameplay_session == null or _player_dialogue_conversation_id.is_empty():
		return
	var completed: Dictionary = gameplay_session.complete_player_resident_dialogue(
		_player_dialogue_resident_id,
		String(_dialogue_context.get("dialogue_id",""))
	)
	if not completed.ok:
		last_error = "对话事实未能提交："+String(completed.error_code)
		_update_interface()
		return
	var ended: Dictionary = gameplay_session.end_resident_conversation(_player_dialogue_conversation_id)
	if not ended.ok:
		gameplay_session.cancel_resident_conversation(_player_dialogue_conversation_id)
	_player_dialogue_conversation_id = ""
	_player_dialogue_resident_id = ""
	_dialogue_context.clear()
	_dialogue_feedback = ""
	locks.set_locked(&"dialogue",false)
	_page = "title"
	last_error = ""
	_refresh_farm_world()
	_update_interface()

func _new_command_id(prefix: String) -> String:
	return prefix+"."+Crypto.new().generate_random_bytes(16).hex_encode()

func _transfer_storage(payload: Dictionary) -> void:
	if state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured() or not locks.has_owner(&"storage"):
		return
	var projection: Dictionary = gameplay_session.projection()
	if not projection.ok or not projection.has("storage"):
		last_error = "箱子状态不可用。"
		_update_interface()
		return
	var source_id := String(payload.get("source_container_id",""))
	var item_id := String(payload.get("item_id",""))
	var quantity := int(payload.get("quantity",0))
	var inventory_id := String(projection.inventory.container_id)
	var storage_id := String(projection.storage.container_id)
	var target_id := ""
	if source_id == inventory_id:
		target_id = storage_id
	elif source_id == storage_id:
		target_id = inventory_id
	else:
		last_error = "箱子转移来源无效。"
		_update_interface()
		return
	if item_id.is_empty() or quantity <= 0:
		last_error = "箱子转移数量无效。"
		_update_interface()
		return
	var command := {
		"protocol_version":1,
		"command_id":_new_command_id("storage.transfer"),
		"session_id":str(active_snapshot.get("session_id","")),
		"actor_id":"actor.player",
		"action":"storage.transfer",
		"expected_revision":int(projection.inventory.revision),
		"payload":{
			"source_container_id":source_id,
			"target_container_id":target_id,
			"item_id":item_id,
			"quantity":quantity,
			"storage_revision":int(projection.storage.revision)
		}
	}
	var result: Dictionary = gameplay_session.execute(command)
	last_error = ("已存入箱子。" if source_id == inventory_id else "已从箱子取出。") if result.ok else "箱子转移失败："+String(result.error_code)
	_update_interface()

func _trade_item(action: String, payload: Dictionary) -> void:
	if state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured() or not locks.has_owner(&"trade"):
		return
	if action not in ["economy.buy","economy.sell"]:
		last_error = "交易动作无效。"
		_update_interface()
		return
	var item_id := String(payload.get("item_id",""))
	var quantity := int(payload.get("quantity",0))
	if item_id.is_empty() or quantity <= 0:
		last_error = "交易数量无效。"
		_update_interface()
		return
	var projection: Dictionary = gameplay_session.projection()
	if not projection.ok:
		last_error = "交易状态不可用。"
		_update_interface()
		return
	var command := {
		"protocol_version":1,
		"command_id":_new_command_id(action),
		"session_id":str(active_snapshot.get("session_id","")),
		"actor_id":"actor.player",
		"action":action,
		"expected_revision":int(projection.inventory.revision),
		"payload":{
			"item_id":item_id,
			"quantity":quantity,
			"wallet_revision":int(projection.wallet.revision)
		}
	}
	var result: Dictionary = gameplay_session.execute(command)
	if result.ok:
		last_error = "购买完成。" if action == "economy.buy" else "出售完成。"
	else:
		last_error = "交易失败："+String(result.error_code)
	_update_interface()

func _interact_world() -> void:
	if not is_instance_valid(room):
		return
	if room.has_method("resolve_interaction_target"):
		var target: Variant = room.resolve_interaction_target()
		if target is Dictionary and not target.is_empty():
			match String(target.get("kind","")):
				"door":
					_begin_door_transition(target)
					return
				"bed":
					_rest_at_bed(target)
					return
				"storage":
					if target.get("interaction_id","") == "storage.house.main":
						set_storage_menu(true)
					return
				"trade":
					if target.get("interaction_id","") == "trade.shop.counter":
						set_trade_menu(true)
					return
				"forage":
					_collect_forage(target)
					return
				"resident_dialogue":
					_begin_player_resident_dialogue(target)
					return
	_begin_farm_action()

func _collect_forage(target: Dictionary) -> void:
	if state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured():
		return
	if target.get("interaction_id","") != "forage.village.pickup":
		last_error = "采集目标无效。"
		_update_interface()
		return
	var spot_id := String(target.get("spot_id",""))
	if spot_id.is_empty():
		last_error = "采集点缺少稳定ID。"
		_update_interface()
		return
	var projection: Dictionary = gameplay_session.projection()
	var command := {
		"protocol_version":1,
		"command_id":_new_command_id("forage.collect"),
		"session_id":str(active_snapshot.get("session_id","")),
		"actor_id":"actor.player",
		"action":"forage.collect",
		"expected_revision":int(projection.forage.revision),
		"payload":{
			"spot_id":spot_id,
			"inventory_revision":int(projection.inventory.revision)
		}
	}
	var result: Dictionary = gameplay_session.execute(command)
	if result.ok:
		last_error = "采到一份野菜。可以带去商店出售。"
	else:
		match String(result.error_code):
			"INVENTORY_FULL":
				last_error = "背包已满，野菜仍留在原地。"
			"FORAGE_ALREADY_COLLECTED":
				last_error = "这个采集点今天已经采过了。"
			_:
				last_error = "采集失败："+String(result.error_code)
	_refresh_farm_world()
	_update_interface()

func _rest_at_bed(target: Dictionary) -> void:
	if state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured():
		return
	if not is_instance_valid(room) or not room.has_method("get_space_id") or room.get_space_id() != "space.house":
		return
	if target.size() != 2 or target.get("kind","") != "bed" or target.get("interaction_id","") != "bed.house.main":
		last_error = "床交互目标无效，没有推进时间。"
		_update_interface()
		return
	var result: Dictionary = gameplay_session.rest_to_next_day()
	if not result.ok:
		last_error = "休息未完成："+String(result.error_code)
		_update_interface()
		return
	last_error = "休息完成，已到第%d天 06:00。" % gameplay_session.clock.current_day()
	_refresh_farm_world()
	_update_interface()

func _begin_door_transition(target: Dictionary) -> void:
	if _transition_pending or _resident_handoff_pending or farm_action.is_busy() or state != State.WORLD or not _valid_door_target(target):
		return
	var path := _scene_path_for_space(String(target.target_space_id))
	if path.is_empty():
		last_error = "目标区域不存在，仍留在当前位置。"
		_update_interface()
		return
	var packed := load(path) as PackedScene
	if packed == null:
		last_error = "目标区域无法加载，仍留在当前位置。"
		_update_interface()
		return
	var candidate := packed.instantiate() as Node2D
	if candidate == null:
		last_error = "目标区域实例化失败，仍留在当前位置。"
		_update_interface()
		return
	_transition_pending = true
	_transition_generation += 1
	var token := _transition_generation
	_transition_candidate = candidate
	candidate.visible = false
	add_child(candidate)
	move_child(candidate,0)
	candidate.set_input_enabled(false)
	_set_room_camera_enabled(candidate,false)
	locks.set_locked(&"transition",true)
	last_error = "正在通过门进入目标区域……Esc 可在提交前取消。"
	_update_interface()
	await get_tree().physics_frame
	if token != _transition_generation or not _transition_pending or state != State.WORLD:
		if is_instance_valid(candidate):
			candidate.queue_free()
		return
	if not _world_contract_valid(candidate) or String(candidate.get_space_id()) != String(target.target_space_id):
		_fail_transition(candidate,"目标区域合同无效，仍留在原位置。")
		return
	var arrival: Vector2 = candidate.get_anchor_position(String(target.arrival_anchor_id))
	if arrival == Vector2.INF or _position_is_blocked_in(candidate,arrival):
		_fail_transition(candidate,"目标门落点无效或被阻挡，仍留在原位置。")
		return

	if not _capture_room_resident_runtime(room):
		_fail_transition(candidate,"当前区域居民运行状态无法提交，仍留在原位置。")
		return
	if not _apply_resident_runtime_to(candidate):
		_fail_transition(candidate,"目标区域无法恢复居民运行状态，仍留在原位置。")
		return

	gameplay_session.release_resident_conversations_for_space(String(room.get_space_id()))
	_resident_conversation_end_game_minute = -1
	var old_room := room
	room = candidate
	_transition_candidate = null
	_transition_pending = false
	room.get_player().position = arrival
	room.get_player().facing = StringName(String(target.arrival_facing))
	room.visible = true
	_set_room_camera_enabled(room,true)
	active_snapshot.space_id = String(room.get_space_id())
	active_snapshot.world_position_px = {"x":arrival.x,"y":arrival.y}
	active_snapshot.facing = String(target.arrival_facing)
	_refresh_farm_world()
	if is_instance_valid(old_room):
		old_room.set_input_enabled(false)
		remove_child(old_room)
		old_room.queue_free()
	locks.set_locked(&"transition",false)
	last_error = ""
	_clear_movement()
	_apply_input()
	_update_interface()

func _valid_door_target(target: Dictionary) -> bool:
	var required := ["kind","interaction_id","target_space_id","arrival_anchor_id","arrival_facing"]
	if target.size() != required.size():
		return false
	for key: String in required:
		if not target.has(key) or not (target[key] is String) or String(target[key]).is_empty():
			return false
	return target.kind == "door" and target.arrival_facing in ["north","south","east","west"]

func _fail_transition(candidate: Node2D, message: String) -> void:
	if is_instance_valid(candidate):
		candidate.queue_free()
	_transition_candidate = null
	_transition_pending = false
	_transition_generation += 1
	locks.set_locked(&"transition",false)
	last_error = message
	_apply_input()
	_update_interface()

func _cancel_transition(message: String) -> bool:
	if not _transition_pending:
		return false
	_transition_generation += 1
	_transition_pending = false
	if is_instance_valid(_transition_candidate):
		_transition_candidate.queue_free()
	_transition_candidate = null
	locks.set_locked(&"transition",false)
	last_error = message
	_apply_input()
	_update_interface()
	return true

func _begin_farm_action() -> void:
	if gameplay_session == null or not gameplay_session.is_configured() or not is_instance_valid(room) or not room.has_method("resolve_plot_target"):
		return
	var plot_id := String(room.resolve_plot_target())
	if plot_id.is_empty():
		last_error = "前方没有可达的菜地。请面向相邻田格再按 E。"
		_update_interface()
		return
	var prepared: Dictionary = gameplay_session.prepare_farm_action(plot_id)
	if not prepared.ok:
		last_error = _farm_error_text(String(prepared.error_code))
		_update_interface()
		return
	var command := {
		"protocol_version":1,
		"command_id":_new_command_id(String(prepared.action)),
		"session_id":str(active_snapshot.get("session_id","")),
		"actor_id":"actor.player",
		"action":String(prepared.action),
		"expected_revision":int(prepared.expected_revision),
		"payload":prepared.payload.duplicate(true)
	}
	var label := _farm_action_label(String(prepared.action))
	if not farm_action.begin(command,plot_id,label):
		last_error = "已有农事动作正在进行。"
		_update_interface()
		return
	locks.set_locked(&"farm_action",true)
	last_error = "准备"+label+"……Esc 可在接触前取消。"
	_update_interface()

func _tick_farm_action(delta: float) -> void:
	var event: Dictionary = farm_action.advance(delta)
	if event.event == "contact":
		var result: Dictionary = gameplay_session.execute(event.command)
		if result.ok:
			last_error = String(event.label)+("完成。" if result.has_changes else "没有产生新的变化。")
		else:
			last_error = _farm_error_text(String(result.error_code))
		_refresh_farm_world()
		_update_interface()
	elif event.event == "finished":
		locks.set_locked(&"farm_action",false)
		_update_interface()

func _cancel_farm_action(message: String) -> bool:
	if not farm_action.cancel_before_contact():
		return false
	locks.set_locked(&"farm_action",false)
	last_error = message
	_update_interface()
	return true

func _finish_farm_recovery() -> bool:
	if not farm_action.finish_recovery():
		return false
	locks.set_locked(&"farm_action",false)
	_update_interface()
	return true

func _capture_room_resident_runtime(candidate: Node2D) -> bool:
	if gameplay_session == null or not gameplay_session.is_configured() or not is_instance_valid(candidate) or not candidate.has_method("capture_resident_runtime"):
		return true
	var rows: Variant = candidate.capture_resident_runtime()
	if not (rows is Array):
		return false
	for row: Variant in rows:
		if not gameplay_session.update_resident_runtime(row):
			return false
	return true

func _apply_resident_runtime_to(candidate: Node2D) -> bool:
	if gameplay_session == null or not gameplay_session.is_configured() or not is_instance_valid(candidate) or not candidate.has_method("apply_resident_runtime"):
		return true
	return candidate.apply_resident_runtime(gameplay_session.resident_runtime.projection())

func _refresh_farm_world() -> void:
	if gameplay_session == null or not gameplay_session.is_configured() or not is_instance_valid(room):
		return
	var projection: Dictionary = gameplay_session.projection()
	if room.has_method("apply_farm_projection"):
		room.apply_farm_projection(projection.farm)
	if room.has_method("apply_forage_projection"):
		room.apply_forage_projection(projection.forage)
	if room.has_method("apply_resident_projection"):
		room.apply_resident_projection(projection.residents,projection.resident_runtime)
	if room.has_method("apply_conversation_projection"):
		room.apply_conversation_projection(projection.conversations)

func _poll_resident_conversation() -> void:
	if _transition_pending or _resident_handoff_pending or state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured():
		return
	if not is_instance_valid(room) or not room.has_method("get_space_id") or String(room.get_space_id())!="space.village":
		return
	if not room.has_method("conversation_participants_arrived"):
		return
	var projection: Dictionary = gameplay_session.projection()
	var active: Dictionary = {}
	for row: Variant in projection.conversations.conversations:
		if row is Dictionary and String(row.get("space_id",""))=="space.village":
			active = row
			break
	if not active.is_empty():
		var conversation_id := String(active.get("conversation_id",""))
		var conversation_state := String(active.get("state",""))
		if conversation_state=="invited":
			var approaching: Dictionary = gameplay_session.approach_resident_conversation(conversation_id)
			if approaching.ok:
				_refresh_farm_world()
			return
		if conversation_state=="approaching" and room.conversation_participants_arrived(conversation_id):
			var participating: Dictionary = gameplay_session.begin_resident_conversation(conversation_id)
			if participating.ok:
				_resident_conversation_demo_day = gameplay_session.clock.current_day()
				_resident_conversation_end_game_minute = gameplay_session.clock.game_minute+RESIDENT_CONVERSATION_DURATION_MINUTES
				_refresh_farm_world()
			return
		if conversation_state=="participating" and _resident_conversation_end_game_minute>=0 and gameplay_session.clock.game_minute>=_resident_conversation_end_game_minute:
			var ended: Dictionary = gameplay_session.end_resident_conversation(conversation_id)
			if ended.ok:
				_resident_conversation_end_game_minute = -1
				_refresh_farm_world()
			return
		return

	var day: int = int(gameplay_session.clock.current_day())
	var minute: int = int(gameplay_session.clock.minute_of_day())
	if day==_resident_conversation_demo_day or minute<RESIDENT_CONVERSATION_START_MINUTE or minute>=RESIDENT_CONVERSATION_END_MINUTE:
		return
	if _resident_runtime_space(projection.resident_runtime,"resident.maker")!="space.village" or _resident_runtime_space(projection.resident_runtime,"resident.neighbor")!="space.village":
		return
	var conversation_id := "conversation.village.morning.day.%d" % day
	var invited: Dictionary = gameplay_session.invite_resident_conversation(
		conversation_id,
		"resident.maker",
		"resident.neighbor",
		"space.village"
	)
	if not invited.ok:
		return
	var approaching: Dictionary = gameplay_session.approach_resident_conversation(conversation_id)
	if approaching.ok:
		_refresh_farm_world()

func _resident_runtime_space(runtime_projection: Dictionary, resident_id: String) -> String:
	for row: Variant in runtime_projection.residents:
		if row is Dictionary and String(row.get("resident_id",""))==resident_id:
			return String(row.get("space_id",""))
	return ""

func _poll_resident_handoff() -> void:
	if _resident_handoff_pending or _transition_pending or state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured():
		return
	if not is_instance_valid(room) or not room.has_method("resident_handoff_requests"):
		return
	var requests: Variant = room.resident_handoff_requests()
	if not (requests is Array) or requests.is_empty():
		return
	_resident_handoff_pending = true
	_commit_resident_handoff.call_deferred(requests[0])

func _commit_resident_handoff(request: Variant) -> void:
	if not (request is Dictionary):
		_resident_handoff_pending = false
		return
	for key: String in ["resident_id","source_space_id","target_space_id","arrival_anchor_id","arrival_facing"]:
		if not request.has(key) or not (request[key] is String) or String(request[key]).is_empty():
			_resident_handoff_pending = false
			return
	if state != State.WORLD or not is_instance_valid(room) or String(room.get_space_id()) != String(request.source_space_id):
		_resident_handoff_pending = false
		return
	var path := _scene_path_for_space(String(request.target_space_id))
	if path.is_empty():
		_resident_handoff_pending = false
		return
	var packed := load(path) as PackedScene
	if packed == null:
		_resident_handoff_pending = false
		return
	var candidate := packed.instantiate() as Node2D
	if candidate == null:
		_resident_handoff_pending = false
		return
	candidate.visible=false
	add_child(candidate)
	move_child(candidate,0)
	candidate.set_input_enabled(false)
	_set_room_camera_enabled(candidate,false)
	await get_tree().physics_frame
	if state != State.WORLD or not is_instance_valid(room) or String(room.get_space_id()) != String(request.source_space_id):
		candidate.queue_free()
		_resident_handoff_pending = false
		return
	if not _world_contract_valid(candidate) or String(candidate.get_space_id()) != String(request.target_space_id):
		candidate.queue_free()
		_resident_handoff_pending = false
		return
	var arrival: Vector2 = candidate.get_anchor_position(String(request.arrival_anchor_id))
	if arrival == Vector2.INF or _position_is_blocked_in(candidate,arrival):
		candidate.queue_free()
		_resident_handoff_pending = false
		return
	var updated: bool = bool(gameplay_session.update_resident_runtime({
		"resident_id":String(request.resident_id),
		"space_id":String(request.target_space_id),
		"world_position_px":{"x":arrival.x,"y":arrival.y},
		"facing":String(request.arrival_facing)
	}))
	candidate.queue_free()
	_resident_handoff_pending = false
	if updated:
		_refresh_farm_world()

func _farm_action_label(action: String) -> String:
	match action:
		"farm.till":
			return "整地"
		"farm.plant":
			return "播种"
		"farm.water":
			return "浇水"
		"farm.harvest":
			return "采收"
	return "操作"

func _farm_error_text(code: String) -> String:
	match code:
		"FARM_SELECTED_ITEM_REQUIRED":
			return "请先在快捷栏选择锄头、种子或浇水壶。"
		"FARM_SELECTED_ITEM_INVALID":
			return "当前选中物品不能用于这块田。"
		"INVENTORY_INSUFFICIENT_ITEM":
			return "种子数量不足。"
		"INVENTORY_FULL":
			return "背包已满，作物仍留在田里。"
		"STALE_REVISION", "INVENTORY_STALE_REVISION", "FARM_REVISION_CONFLICT", "INVENTORY_REVISION_CONFLICT":
			return "田地或背包状态刚刚变化，请重新操作。"
		"FARM_NOT_UNTILLED", "FARM_NOT_TILLED", "FARM_NOT_WATERABLE", "FARM_NOT_MATURE":
			return "这块田当前不能执行该动作。"
		"FARM_TOOL_MISSING":
			return "缺少所需工具。"
		"COMMAND_RECEIPT_CAPACITY":
			return "本次试玩的操作回执已达到安全上限，请保存后结束本次会话。"
	return "农事操作未完成："+code

func _select_inventory_slot(slot_index: int) -> void:
	if state != State.WORLD or gameplay_session == null or not gameplay_session.is_configured() or farm_action.is_busy() or _transition_pending:
		return
	var projection: Dictionary = gameplay_session.projection()
	if not projection.ok or slot_index < 0 or slot_index >= int(projection.inventory.capacity):
		return
	var command := {
		"protocol_version":1,
		"command_id":_new_command_id("ui.select"),
		"session_id":str(active_snapshot.get("session_id","")),
		"actor_id":"actor.player",
		"action":"inventory.select",
		"expected_revision":int(projection.inventory.revision),
		"payload":{"slot_index":slot_index}
	}
	var result: Dictionary = gameplay_session.execute(command)
	if not result.ok:
		last_error = "无法选择物品栏："+result.error_code
	_update_interface()

func _apply_input() -> void:
	var enabled: bool = state == State.WORLD and not locks.is_locked()
	_clear_movement()
	if is_instance_valid(room):
		room.set_input_enabled(enabled)
	_sync_gameplay_pauses()

func _sync_gameplay_pauses() -> void:
	if gameplay_session == null or not gameplay_session.is_configured():
		return
	for owner: StringName in GAMEPLAY_PAUSE_OWNERS:
		if locks.has_owner(owner):
			gameplay_session.acquire_pause(owner)
		else:
			gameplay_session.release_pause(owner)

func _clear_movement() -> void:
	for action: StringName in MOVEMENT_ACTIONS:
		Input.action_release(action)

func _update_interface() -> void:
	if not is_node_ready():
		return
	var page := _page
	if state == State.LOADING:
		page = "loading"
	elif state == State.WORLD:
		if _page in ["settings","display_confirm"]:
			page = _page
		elif locks.has_owner(&"dialogue"):
			page = "dialogue"
		elif locks.has_owner(&"trade"):
			page = "trade"
		elif locks.has_owner(&"storage"):
			page = "storage"
		elif locks.has_owner(&"inventory"):
			page = "inventory"
		else:
			page = "pause" if locks.has_owner(&"pause_menu") else "world"
	var has_gameplay: bool = gameplay_session != null and gameplay_session.is_configured()
	var context := {
		"error":last_error,
		"settings":settings.committed,
		"player_name":_names.player_name,
		"dog_name":_names.dog_name,
		"can_save":not active_snapshot.is_empty(),
		"envelope":_import_envelope,
		"focus_action":_focus_action,
		"has_gameplay":has_gameplay,
		"world_label":_world_label(has_gameplay),
		"space_id":String(room.get_space_id()) if is_instance_valid(room) and room.has_method("get_space_id") else "",
		"farm_action":farm_action.projection()
	}
	if has_gameplay:
		context["gameplay"] = gameplay_session.projection()
	if locks.has_owner(&"dialogue"):
		context["dialogue"] = _dialogue_context.duplicate(true)
		context["gift_offer"] = gameplay_session.resident_gift_offer(_player_dialogue_resident_id)
		context["dialogue_feedback"] = _dialogue_feedback
	if state == State.WORLD:
		context.player_name = active_snapshot.get("player_name","")
	if page in ["title","load"]:
		context["saves"] = store.list_saves()
		for entry: Dictionary in context.saves:
			if entry.ok and entry.envelope.snapshot.has("gameplay"):
				context["recent_id"] = entry.save_id
				break
	view.show_page(page,context)
	_focus_action = ""

func _world_label(has_gameplay: bool) -> String:
	if not has_gameplay or not is_instance_valid(room) or not room.has_method("get_space_id"):
		return "旧入口碰撞测试场"
	match String(room.get_space_id()):
		"space.house":
			return "家内部 · 工程美术"
		"space.village":
			return "村庄第一屏 · 工程美术"
		"space.shop":
			return "商店内部 · 工程美术"
		"space.workshop":
			return "工坊内部 · 工程美术"
	return "农庄 · 门前菜园"

func save_progress() -> Dictionary:
	if state != State.WORLD or active_snapshot.is_empty():
		return CODEC.failure("SAVE_NO_SESSION")
	if farm_action.is_busy():
		return CODEC.failure("SAVE_ACTION_BUSY")
	if _transition_pending:
		return CODEC.failure("SAVE_TRANSITION_BUSY")
	if _resident_handoff_pending:
		return CODEC.failure("SAVE_RESIDENT_HANDOFF_BUSY")
	if locks.has_owner(&"dialogue"):
		return CODEC.failure("SAVE_DIALOGUE_BUSY")
	if not _capture_room_resident_runtime(room):
		return CODEC.failure("SAVE_RESIDENT_RUNTIME_INVALID")
	var candidate: Dictionary = active_snapshot.duplicate(true)
	var player: CharacterBody2D = room.get_player()
	candidate.space_id = String(room.get_space_id()) if room.has_method("get_space_id") else candidate.space_id
	candidate.world_position_px = {"x":player.position.x,"y":player.position.y}
	candidate.facing = str(player.facing)
	if gameplay_session != null:
		candidate.gameplay = gameplay_session.snapshot()
	if not CODEC.validate_snapshot(candidate):
		return CODEC.failure("SAVE_SNAPSHOT_INVALID")
	var result: Dictionary = store.write_new(candidate)
	if result.ok:
		active_snapshot = candidate
		active_save_id = result.save_id
	return result

func _on_action(action: String, payload: Dictionary) -> void:
	if action in ["new_game","load","continue","read_save"] and state != State.TITLE:
		return
	if action == "create" and (state != State.TITLE or _page != "new_game"):
		return
	if action in ["preview_import","choose_import"] and (state != State.TITLE or _page != "load"):
		return
	if action in ["confirm_import","cancel_import"] and _page != "import_review":
		return
	if action == "preview_settings" and _page != "settings":
		return
	if action in ["confirm_settings","revert_settings"] and _page != "display_confirm":
		return
	if action in ["pause","resume","save","save_return","inventory","close_inventory","select_slot","close_storage","transfer_storage","close_trade","trade_buy","trade_sell","close_dialogue","gift_resident"] and state != State.WORLD:
		return
	if state == State.LOADING and action not in ["cancel_load","quit"]:
		return
	last_error = ""
	match action:
		"new_game":
			_page = "new_game"
		"load":
			_page = "load"
		"create":
			_names = view.form_names()
			_names.player_name = _names.player_name.strip_edges()
			_names.dog_name = _names.dog_name.strip_edges()
			if not CODEC.name_is_valid(_names.player_name) or not CODEC.name_is_valid(_names.dog_name,true):
				last_error = "请输入1–16字的玩家名；狗名可留空，不接受控制字符。"
			else:
				_entry_snapshot = CODEC.new_snapshot(_names.player_name,_names.dog_name)
				_entry_creates_save = true
				_entry_requires_gameplay = true
				start_world(FARM_ROOM)
		"continue":
			for entry: Dictionary in store.list_saves():
				if entry.ok and entry.envelope.snapshot.has("gameplay"):
					_on_action("read_save",{"save_id":entry.save_id})
					return
			last_error = "没有正式游戏进度，请新建游戏或从存档页选择。"
		"read_save":
			var result: Dictionary = store.read_save(str(payload.get("save_id","")))
			if result.ok:
				_entry_snapshot = result.envelope.snapshot.duplicate(true)
				_entry_creates_save = false
				_entry_requires_gameplay = result.envelope.snapshot.has("gameplay")
				active_save_id = str(payload.get("save_id",""))
				var target_path := LEGACY_ROOM
				if _entry_requires_gameplay:
					target_path = _scene_path_for_space(String(_entry_snapshot.space_id))
					if target_path.is_empty():
						_entry_snapshot.clear()
						_entry_requires_gameplay = false
						last_error = "存档区域暂不受支持，未进入世界。"
						return
				start_world(target_path)
			else:
				last_error = "无法读取存档："+result.error_code
		"choose_import":
			view.file_dialog.popup_centered(Vector2i(560,300))
			return
		"preview_import":
			var result: Dictionary = store.import_preview(str(payload.get("path","")))
			if result.ok:
				_import_envelope = result.envelope.duplicate(true)
				_page = "import_review"
			else:
				last_error = "导入已拒绝，原文件未修改："+result.error_code
				_page = "load"
		"confirm_import":
			var result: Dictionary = store.confirm_import(_import_envelope)
			if result.ok:
				_import_envelope.clear()
				_page = "load"
				last_error = "已创建独立副本，请选择读取。"
			else:
				last_error = "导入未保存："+result.error_code
		"cancel_import":
			_import_envelope.clear()
			_page = "load"
			_focus_action = "choose_import"
		"settings":
			_settings_origin = "pause" if state == State.WORLD else _page
			if state == State.WORLD:
				set_pause_menu(true)
			_page = "settings"
		"preview_settings":
			var result: Dictionary = settings.begin_preview(view.settings_draft())
			if result.ok:
				_page = "display_confirm"
			else:
				last_error = result.error_code
		"confirm_settings":
			var result: Dictionary = settings.confirm()
			if result.ok:
				_page = "title" if state == State.WORLD else _settings_origin
				_focus_action = "settings"
			else:
				settings.revert()
				_page = "settings"
				_focus_action = "preview_settings"
				last_error = "设置保存失败，已恢复："+result.error_code
		"revert_settings":
			settings.revert()
			_page = "settings"
			_focus_action = "preview_settings"
		"back":
			var closing_page := _page
			if closing_page == "settings":
				settings.revert()
				_page = "title" if state == State.WORLD else _settings_origin
				_focus_action = "settings"
			elif closing_page == "import_review":
				_import_envelope.clear()
				_page = "load"
				_focus_action = "choose_import"
			else:
				_import_envelope.clear()
				_page = "title"
				if closing_page == "new_game":
					_focus_action = "new_game"
				elif closing_page == "load":
					_focus_action = "load"
		"close_dialogue":
			_finish_player_resident_dialogue()
		"gift_resident":
			_gift_selected_to_resident()
		"cancel_load":
			return_to_title()
		"inventory":
			set_inventory_menu(true)
		"close_inventory":
			set_inventory_menu(false)
		"select_slot":
			_select_inventory_slot(int(payload.get("slot_index",-1)))
		"close_storage":
			set_storage_menu(false)
		"transfer_storage":
			_transfer_storage(payload)
		"close_trade":
			set_trade_menu(false)
		"trade_buy":
			_trade_item("economy.buy",payload)
		"trade_sell":
			_trade_item("economy.sell",payload)
		"pause":
			set_pause_menu(true)
		"resume":
			_page = "title"
			set_pause_menu(false)
		"save", "save_return":
			var result: Dictionary = save_progress()
			if result.ok:
				if action == "save_return":
					return_to_title()
				else:
					last_error = "已保存；已有存档未被覆盖。"
			else:
				last_error = "未能保存，仍保留当前会话："+result.error_code
		"quit":
			if state == State.TITLE:
				get_tree().quit()
	_update_interface()

func _close_requested() -> void:
	if state == State.WORLD:
		settings.revert()
		if _transition_pending:
			_cancel_transition("关闭请求取消了尚未提交的门转场。")
		if farm_action.is_before_contact():
			_cancel_farm_action("关闭请求取消了尚未提交的农事动作。")
		elif farm_action.is_busy():
			_finish_farm_recovery()
		if locks.has_owner(&"inventory"):
			locks.set_locked(&"inventory",false)
		if locks.has_owner(&"storage"):
			locks.set_locked(&"storage",false)
		if locks.has_owner(&"trade"):
			locks.set_locked(&"trade",false)
		_page = "title"
		set_pause_menu(true)
		last_error = "请保存并返回标题后退出，以免丢失未保存的进度。"
		_update_interface()
	else:
		settings.revert()
		get_tree().quit()

func _exit_tree() -> void:
	settings.revert()
	generation += 1
	_clear_movement()
