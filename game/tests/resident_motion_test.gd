extends SceneTree

const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL resident_motion ",label)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	return event

func wait_world() -> bool:
	for tick in range(180):
		await physics_frame
		if app.state==app.State.WORLD:
			return true
		if app.state==app.State.TITLE and not app.last_error.is_empty():
			return false
	return false

func wait_space(space_id:String) -> bool:
	for tick in range(30):
		await physics_frame
		await process_frame
		if app.state==app.State.WORLD and is_instance_valid(app.room) and app.room.has_method("get_space_id") and app.room.get_space_id()==space_id and not app._transition_pending:
			return true
	return false

func resident_row(resident_id:String) -> Dictionary:
	var projection: Dictionary = app.gameplay_session.projection().residents
	for row: Variant in projection.residents:
		if String(row.get("resident_id",""))==resident_id:
			return row
	return {}

func wait_neighbor_arrived(anchor_id:String, max_frames:=240) -> bool:
	for tick in range(max_frames):
		await physics_frame
		var state: Dictionary = app.room.resident_visual_state()
		if String(state.get("anchor_id",""))==anchor_id and String(state.get("movement_state",""))=="arrived":
			return true
	return false

func add_blocker(position:Vector2, size:Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position=position
	body.collision_layer=1
	body.collision_mask=4
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=size
	shape_node.shape=shape
	body.add_child(shape_node)
	app.room.add_child(body)
	return body

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(35).timeout.connect(func(): printerr("RESIDENT_MOTION_TIMEOUT"); quit(1))
	app=MAIN.instantiate()
	app.store.directory="user://resident_motion_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene=app
	app.set_application_focused(true)

	app._on_action("new_game",{})
	app.view.player_name.text="小禾"
	app.view.dog_name.text="阿豆"
	app._on_action("create",{})
	check(await wait_world() and app.room.get_space_id()=="space.farm","new game starts on farm with resident schedule configured")
	if app.state!=app.State.WORLD:
		finish()
		return
	app.set_process(false)
	check(app.gameplay_session.resident_schedule.is_configured() and app.gameplay_session.resident_schedule.has_world_anchors(),"GameplaySession owns validated WORLD-backed resident schedule")

	app.room.get_player().position=app.room.get_anchor_position("VillagePathInteract") + Vector2.DOWN * 20.0
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	check(await wait_space("space.village"),"player reaches village through normal route")
	if app.room.get_space_id()!="space.village":
		finish()
		return

	var neighbor: CharacterBody2D = app.room.neighbor_resident
	neighbor.speed_px_per_sec=120.0
	neighbor.stall_replan_seconds=0.15
	neighbor.wait_retry_seconds=0.15
	check(neighbor.position==Vector2(112,240),"neighbor actor begins at real home anchor, not a UI-only marker")
	var six: Dictionary = resident_row("resident.neighbor")
	check(six.activity_id=="home" and six.anchor_id=="anchor.resident.neighbor.home" and six.space_id=="space.village","06:00 resident projection targets village home")
	check(String(app.room.resident_visual_state().get("movement_state",""))=="arrived","home target is physically arrived")
	check((app.room.get_player().collision_mask & 4)!=0 and (neighbor.collision_mask & 2)!=0,"player and resident bodies participate in mutual collision")

	# Put a real wall on the first horizontal leg. The body must not cross it or
	# teleport; after stalling it changes axis order and walks around.
	var blocker := add_blocker(Vector2(160,240),Vector2(18,22))
	check(app.gameplay_session.advance(120).ok and app.gameplay_session.clock.minute_of_day()==480,"single clock reaches neighbor work start")
	app._refresh_farm_world()
	var eight: Dictionary = resident_row("resident.neighbor")
	check(eight.activity_id=="work" and eight.anchor_id=="anchor.resident.neighbor.work","08:00 schedule target switches to work anchor")
	var start := neighbor.position
	await physics_frame
	await physics_frame
	await physics_frame
	var early := neighbor.position
	check(early!=start and early.distance_to(Vector2(208,208))>2.0,"resident begins walking over physics frames instead of teleporting to schedule target")
	check(await wait_neighbor_arrived("anchor.resident.neighbor.work"),"blocked neighbor replans and physically reaches work anchor")
	var work_state: Dictionary = app.room.resident_visual_state()
	check(Vector2(float(work_state.world_position_px.x),float(work_state.world_position_px.y)).distance_to(Vector2(208,208))<=2.0,"resident arrives at WORLD-owned work marker")
	check(int(work_state.replan_count)>=1,"collision stall triggers deterministic route replan")
	check(neighbor.position.x<632.0 and neighbor.position.y<352.0,"resident route stays inside collision-bounded village")
	blocker.queue_free()
	await physics_frame

	# Later schedule changes update only the target. Position remains continuous,
	# then the same body walks to the public social anchor.
	check(app.gameplay_session.advance(540).ok and app.gameplay_session.clock.minute_of_day()==1020,"single clock reaches social period")
	var before_social := neighbor.position
	app._refresh_farm_world()
	var social_target: Dictionary = resident_row("resident.neighbor")
	check(social_target.activity_id=="social" and social_target.anchor_id=="anchor.resident.neighbor.social","17:00 schedule projects social target")
	check(neighbor.position==before_social,"schedule target update does not mutate resident world position")
	check(await wait_neighbor_arrived("anchor.resident.neighbor.social"),"neighbor physically walks from work to social anchor")
	check(neighbor.position.distance_to(Vector2(288,208))<=2.0,"social arrival uses existing WORLD anchor")

	check(app.gameplay_session.advance(180).ok and app.gameplay_session.clock.minute_of_day()==1200,"single clock reaches home period")
	var before_home := neighbor.position
	app._refresh_farm_world()
	check(neighbor.position==before_home and resident_row("resident.neighbor").activity_id=="home","20:00 switches target without teleport")
	check(await wait_neighbor_arrived("anchor.resident.neighbor.home"),"neighbor physically returns home")
	check(neighbor.position.distance_to(Vector2(112,240))<=2.0,"home return ends at same stable anchor")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("RESIDENT_MOTION_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
