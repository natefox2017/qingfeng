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
@onready var panel: PanelContainer = $Interface/Center/Panel
@onready var title: Label = $Interface/Center/Panel/Margin/Column/Title
@onready var description: Label = $Interface/Center/Panel/Margin/Column/Description
@onready var start_button: Button = $Interface/Center/Panel/Margin/Column/Start
@onready var resume_button: Button = $Interface/Center/Panel/Margin/Column/Resume
@onready var back_button: Button = $Interface/Center/Panel/Margin/Column/Back
@onready var hint: Label = $Interface/Hint

func _ready() -> void:
	locks.changed.connect(_apply_input)
	start_button.pressed.connect(start_world)
	resume_button.pressed.connect(func(): set_pause_menu(false))
	back_button.pressed.connect(return_to_title)
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
		last_error = "The scene is unavailable (%s). No session was created." % error
		_update_interface()
		return false
	state = State.LOADING
	_apply_input()
	_update_interface()
	return true

func _process(_delta: float) -> void:
	if state != State.LOADING or _activation_pending or _request == null:
		return
	var status: int = _request.status()
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene: PackedScene = _request.take_scene()
		_activation_pending = true
		_activate_room.call_deferred(scene, generation)
	elif status in [ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED]:
		return_to_title()
		last_error = "Loading failed; you can retry."
		_update_interface()

func _activate_room(scene: PackedScene, requested_generation: int) -> void:
	if requested_generation != generation or state != State.LOADING:
		return
	var instance: Node = scene.instantiate() if scene != null else null
	if not instance is Node2D or not instance.has_method("set_input_enabled") or not instance.has_method("get_player"):
		if instance != null:
			instance.free()
		return_to_title()
		last_error = "The scene does not implement the world input contract."
		_update_interface()
		return
	room = instance as Node2D
	add_child(room)
	move_child(room, 0)
	state = State.WORLD
	_request = null
	_activation_pending = false
	_clear_movement()
	_apply_input()
	_update_interface()

func return_to_title() -> void:
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
	locks.set_locked(&"focus", not focused)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		set_application_focused(false)
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		set_application_focused(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause_menu"):
		return
	if state == State.LOADING:
		return_to_title()
	elif state == State.WORLD:
		set_pause_menu(not locks.has_owner(&"pause_menu"))
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
	if not is_node_ready():
		return
	var is_paused: bool = locks.has_owner(&"pause_menu")
	panel.visible = state != State.WORLD or is_paused
	start_button.visible = state == State.TITLE
	resume_button.visible = state == State.WORLD and is_paused
	back_button.visible = state != State.TITLE
	title.text = "QINGFENG / ENGINE FOUNDATION"
	description.text = "Engineering fixture. Not final game art.\nNo farming, dog, inventory or saves in this build."
	hint.text = "WASD / ARROWS: move   |   ESC: pause\nCOLLISION FIXTURE - NOT THE FARM"
	if state == State.LOADING:
		description.text = "Loading resources. Esc or Cancel returns to title."
		back_button.text = "Cancel"
		back_button.grab_focus()
	elif state == State.WORLD:
		description.text = "Paused. This build does not write player saves."
		back_button.text = "Return to title"
		if is_paused:
			resume_button.grab_focus()
	else:
		if not last_error.is_empty():
			description.text = last_error
		start_button.grab_focus()
	hint.visible = state == State.WORLD

func _exit_tree() -> void:
	generation += 1
	_clear_movement()
