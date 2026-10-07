extends SceneTree
const MAIN = preload("res://app/main.tscn")
const LOCKS = preload("res://app/input_locks.gd")
const ROOM = preload("res://tests/fixtures/collision_room.tscn")
var checks := 0
var failures: Array[String] = []
var app: Control

class DelayedRequest:
	extends RefCounted
	var is_ready := false
	func begin(_path: String) -> Error:
		return OK
	func status() -> int:
		return ResourceLoader.THREAD_LOAD_LOADED if is_ready else ResourceLoader.THREAD_LOAD_IN_PROGRESS
	func take_scene() -> PackedScene:
		return load("res://tests/fixtures/collision_room.tscn")

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CHECK_FAIL ", label)

func steps(count: int) -> void:
	for tick in range(count):
		await physics_frame
		await process_frame

func wait_world() -> bool:
	for tick in range(180):
		await process_frame
		if app.state == app.State.WORLD:
			await steps(2)
			return true
	return false

func clear_keys() -> void:
	for key: StringName in app.MOVEMENT_ACTIONS:
		Input.action_release(key)

func run() -> void:
	create_timer(30).timeout.connect(func(): printerr("FOUNDATION_TIMEOUT"); quit(1))
	for pair: Array in [[KEY_A, "move_left"], [KEY_D, "move_right"], [KEY_W, "move_up"], [KEY_S, "move_down"], [KEY_LEFT, "move_left"], [KEY_RIGHT, "move_right"], [KEY_UP, "move_up"], [KEY_DOWN, "move_down"]]:
		var event := InputEventKey.new()
		event.physical_keycode = pair[0]
		check(InputMap.event_is_action(event, pair[1]), "physical key binding %s -> %s" % pair)
	var locks := LOCKS.new()
	locks.set_locked(&"menu", true)
	locks.set_locked(&"focus", true)
	locks.set_locked(&"menu", false)
	check(locks.is_locked() and locks.has_owner(&"focus"), "releasing menu preserves focus lock")
	locks.set_locked(&"focus", false)
	check(not locks.is_locked(), "all owners release independently")
	app = MAIN.instantiate()
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)
	check(app.state == app.State.TITLE, "real entry starts at title")
	check(not app.start_world("res://tests/fixtures/missing.tscn"), "missing scene rejected")
	check(app.state == app.State.TITLE and not app.last_error.is_empty(), "load failure stays recoverable")
	check(app.start_world("res://tests/fixtures/invalid_room.tscn"), "invalid contract resource can be loaded")
	for tick in range(20): await process_frame
	check(app.state == app.State.TITLE and app.room == null, "invalid world contract never becomes active")
	var delayed := DelayedRequest.new()
	check(app.start_world(app.DEFAULT_ROOM, delayed), "delayed request accepted")
	check(not app.start_world(), "double start rejected")
	app.return_to_title()
	delayed.is_ready = true
	await steps(2)
	check(app.state == app.State.TITLE and app.room == null, "cancel ignores late background completion")
	# Simulate completion queued on the main thread immediately before cancellation.
	var old_generation: int = app.generation
	app.return_to_title()
	app.start_world(app.DEFAULT_ROOM, DelayedRequest.new())
	app._activate_room(ROOM, old_generation)
	check(app.room == null and app.state == app.State.LOADING, "old generation cannot replace a newer loading request")
	app.return_to_title()
	Input.action_press("move_right")
	app.start_world()
	if not await wait_world():
		check(false, "native room initialized")
		finish(); return
	var player: CharacterBody2D = app.room.get_player()
	check(not Input.is_action_pressed("move_right"), "held title/loading input cleared")
	var spawn := player.position
	await steps(4)
	check(player.position == spawn, "no movement leaked from title")
	var straight_start_tick := Engine.get_physics_frames()
	Input.action_press("move_right")
	await steps(30)
	Input.action_release("move_right")
	var straight := player.position.distance_to(spawn)
	var straight_ticks := Engine.get_physics_frames() - straight_start_tick
	var straight_rate := straight / float(straight_ticks)
	check(absf(straight_rate - player.speed_px_per_sec / Engine.physics_ticks_per_second) < 0.01, "cardinal motion uses speed in world px/sec")
	player.position = spawn
	var diagonal_start_tick := Engine.get_physics_frames()
	Input.action_press("move_right"); Input.action_press("move_down")
	await steps(30)
	clear_keys()
	var diagonal := player.position.distance_to(spawn)
	var diagonal_ticks := Engine.get_physics_frames() - diagonal_start_tick
	check(absf(straight_rate - diagonal / float(diagonal_ticks)) < 0.01, "diagonal motion is not faster")
	await steps(1)
	check(player.velocity.is_zero_approx(), "release stops physical velocity")
	player.position = Vector2(140, 140)
	Input.action_press("move_right")
	await steps(40)
	clear_keys()
	check(player.position.x <= 156.1 and player.position.x >= 155, "world wall blocks actor body")
	player.position = Vector2(300, 164)
	Input.action_press("move_right")
	await steps(35)
	clear_keys()
	check(player.position.x > 340, "real movement crosses the open gap")
	player.position = Vector2(300, 130)
	Input.action_press("move_right")
	await steps(35)
	clear_keys()
	check(player.position.x <= 316.1, "adjacent wall is not a visual-only barrier")
	player.position = Vector2(188, 244)
	Input.action_press("move_right"); Input.action_press("move_down")
	await steps(25)
	clear_keys()
	check(player.position.x < 200.0 or player.position.y < 256.0, "diagonal cannot cut through solid corner")
	# Blocking input resets both held actions and body velocity.
	player.position = Vector2(96, 96)
	Input.action_press("move_right")
	await steps(2)
	app.set_pause_menu(true)
	var paused_position := player.position
	await steps(3)
	check(player.position == paused_position and player.velocity.is_zero_approx(), "pause stops movement")
	check(not Input.is_action_pressed("move_right"), "pause clears held action")
	app.set_application_focused(false)
	app.set_pause_menu(false)
	Input.action_press("move_right")
	await steps(2)
	check(player.position == paused_position, "closing menu cannot release focus lock")
	app.set_application_focused(true)
	await steps(2)
	check(player.position == paused_position, "keys pressed during lost focus cannot leak on resume")
	check(player.is_input_enabled, "focus return enables world without clearing other owners")
	app.set_pause_menu(true)
	app.set_application_focused(false)
	app.set_application_focused(true)
	check(not player.is_input_enabled, "focus return cannot close an open pause menu")
	app.set_pause_menu(false)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE; escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(app.locks.has_owner(&"pause_menu"), "actual Escape input opens pause menu")
	escape = InputEventKey.new(); escape.physical_keycode = KEY_ESCAPE; escape.pressed = false
	Input.parse_input_event(escape)
	app.return_to_title()
	check(app.room == null and app.state == app.State.TITLE, "return removes world and resets route")
	for cycle in range(100):
		check(app.start_world(), "repeat start %d" % cycle)
		if not await wait_world():
			check(false, "repeat world ready %d" % cycle); break
		app.return_to_title()
		await process_frame
		check(app.get_child_count() == 1, "no orphan room after return %d" % cycle)
	finish()

func finish() -> void:
	clear_keys()
	app.queue_free()
	await process_frame
	print("FOUNDATION_PASS checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
