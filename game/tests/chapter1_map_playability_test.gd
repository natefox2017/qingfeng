extends "res://tests/farm_interaction_test.gd"
## Movement uses real Input actions/CharacterBody2D physics, never teleports.
## Economy/chest three-day coverage remains in full_economy_loop_test.gd.

const PATH_STEP_PX := 8.0
const CONTACT_OFFSET_PX := 20.0

func room_bounds() -> Rect2i:
	if app.room.has_method("get_world_bounds"):
		return app.room.get_world_bounds()
	# Existing interiors expose collision geometry, rather than map extent API.
	var extent := Rect2()
	var found := false
	for node: Node in app.room.get_node("Solids").find_children("*", "CollisionShape2D", true, false):
		var shape := node as CollisionShape2D
		if shape.shape is RectangleShape2D:
			var rect := Rect2(shape.global_position-shape.shape.size/2.0, shape.shape.size)
			extent = extent.merge(rect) if found else rect
			found = true
	return Rect2i(extent)

func build_path(target: Vector2) -> PackedVector2Array:
	var bounds := room_bounds()
	check(bounds.has_point(Vector2i(target)), "target inside authored world bounds")
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(bounds.size / PATH_STEP_PX))
	grid.cell_size = Vector2.ONE * PATH_STEP_PX
	grid.offset = Vector2(bounds.position)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var circle := CircleShape2D.new()
	var player: CharacterBody2D = app.room.get_player()
	var player_shape := player.get_node("CollisionShape2D") as CollisionShape2D
	circle.radius = (player_shape.shape as CircleShape2D).radius + 1.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	for x in range(grid.region.size.x):
		for y in range(grid.region.size.y):
			var cell := Vector2i(x,y)
			query.transform = Transform2D(0.0,grid.get_point_position(cell))
			if not app.room.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty():
				grid.set_point_solid(cell)
	var from := Vector2i(((player.global_position-grid.offset)/PATH_STEP_PX).round())
	var to := Vector2i(((target-grid.offset)/PATH_STEP_PX).round())
	if not grid.region.has_point(from) or not grid.region.has_point(to): return PackedVector2Array()
	return grid.get_point_path(from,to)

func walk(target: Vector2) -> bool:
	if not target.is_finite():
		check(false, "missing required authored route anchor")
		return false
	var points := build_path(target)
	if points.is_empty():
		check(false, "no radius-safe physics fixture route to " + str(target))
		return false
	# Keep corners, remove only collinear grid points; every segment is real Input.
	for index in range(points.size()):
		if index > 0 and index < points.size()-1 and (points[index]-points[index-1]).normalized() == (points[index+1]-points[index]).normalized():
			continue
		if not await walk_segment(points[index]): return false
	return await walk_segment(target)

func plot_position(plot_id: String) -> Vector2:
	for definition: Dictionary in app.room.get_plot_definitions():
		if definition.plot_id == plot_id:
			return Vector2(definition.cell_position.x, definition.cell_position.y) * float(app.room.TILE_SIZE)
	return Vector2.INF

func reach_plot(plot_id: String) -> bool:
	if not await walk(plot_position(plot_id) + Vector2.DOWN * CONTACT_OFFSET_PX): return false
	app.room.get_player().facing = &"north"
	if app.room.resolve_plot_target() != plot_id:
		print("MAP_PLOT_RESOLVER_FAIL expected=",plot_id," resolved=",app.room.resolve_plot_target()," contact=",app.room.get_player().global_position," marker=",plot_position(plot_id))
		var ray := PhysicsRayQueryParameters2D.create(app.room.get_player().global_position,plot_position(plot_id),1)
		var hit: Dictionary = app.room.get_world_2d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): print("MAP_PLOT_RAY_BLOCK ",hit.collider.get_path()," point=",hit.position)
	check(app.room.resolve_plot_target() == plot_id, "walked contact resolves " + plot_id)
	return app.room.resolve_plot_target() == plot_id

func walk_segment(target: Vector2) -> bool:
	var player: CharacterBody2D = app.room.get_player()
	for axis in [0, 1]:
		var action: String = ""
		for tick in range(1200):
			var delta: float = target[axis] - player.position[axis]
			if absf(delta) <= 2.0:
				break
			var next: String = ("move_right" if delta > 0 else "move_left") if axis == 0 else ("move_down" if delta > 0 else "move_up")
			if action != next:
				if not action.is_empty(): Input.action_release(action)
				action = next
				Input.action_press(action)
			await physics_frame
		if not action.is_empty(): Input.action_release(action)
		await physics_frame
	var reached := player.position.distance_to(target) <= 4.0
	if not reached:
		print("MAP_WALK_DIAGNOSTIC enabled=", player.is_input_enabled, " focus_locked=", app.locks.has_owner(&"focus"), " velocity=", player.velocity, " slide_count=", player.get_slide_collision_count(), " input_right=", Input.is_action_pressed("move_right"), " locks=", app.locks._owners)
		for index in range(player.get_slide_collision_count()):
			var hit := player.get_slide_collision(index)
			print("MAP_WALK_COLLIDER ", hit.get_collider(), " point=", hit.get_position())
	check(reached, "physics walk %s reached %s" % [target, player.position])
	return reached

func door(anchor: String, facing: StringName, expected: String) -> bool:
	var direction: Vector2 = {&"north":Vector2.UP,&"south":Vector2.DOWN,&"east":Vector2.RIGHT,&"west":Vector2.LEFT}[facing]
	var point: Vector2 = app.room.get_anchor_position(anchor) - direction * CONTACT_OFFSET_PX
	if not await walk(point): return false
	app.room.get_player().facing = facing
	var target: Dictionary = app.room.resolve_interaction_target()
	var expected_id := "door.%s.%s" % [app.room.get_space_id().trim_prefix("space."), expected.trim_prefix("space.")]
	check(target.get("target_space_id", "") == expected and target.get("interaction_id", "") == expected_id and target.size() == 5, "exact stable door resolver " + expected_id)
	var session_identity: RefCounted = app.gameplay_session
	app._unhandled_key_input(key(KEY_E))
	for tick in range(180):
		await physics_frame
		if app.room.get_space_id() == expected and not app._transition_pending:
			check(app.gameplay_session == session_identity, "same session through " + expected_id)
			check(app.room.get_player().position.distance_to(app.room.get_anchor_position(target.arrival_anchor_id))<=4.0 and app.room.get_player().facing == StringName(target.arrival_facing), "target owns safe arrival " + expected_id)
			check(true, "door commit " + expected)
			return true
	check(false, "door commit " + expected)
	return false

func run() -> void:
	create_timer(360).timeout.connect(func(): printerr("MAP_PLAYABILITY_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	var isolated := "user://chapter1_map_" + Crypto.new().generate_random_bytes(8).hex_encode()
	app.store.directory = isolated + "/saves"
	app.settings.path = isolated + "/settings.json"
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)
	app._on_action("new_game", {})
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create", {})
	check(await wait_world(), "fresh farm starts")
	if app.state != app.State.WORLD:
		await finish()
		return
	app.set_process(false)
	check(app.room.get_plot_definitions().size() == 6, "six stable gameplay plots")
	for index in range(1,7):
		if not await reach_plot("plot.farm.%03d" % index):
			await finish()
			return
	if not await reach_plot("plot.farm.003"):
		await finish()
		return
	app.room.get_player().facing = &"north"
	check(app.room.resolve_plot_target() == "plot.farm.003", "walking reaches mature tutorial plot")
	use_plot()
	check(app.gameplay_session.inventory.quantity_of("item.radish") == 1 and app.gameplay_session.farm.get_plot("plot.farm.003").state == "tilled", "003 harvest gives exactly one radish")
	if not await reach_plot("plot.farm.004"):
		await finish()
		return
	app.room.get_player().facing = &"north"
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "tilled", "004 till at walked contact")
	app._unhandled_key_input(key(KEY_3))
	var seeds: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	use_plot()
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed") == seeds-1, "004 plant consumes one seed")
	app._unhandled_key_input(key(KEY_2))
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered, "004 water")
	if not await door("HouseDoorInteract", &"north", "space.house") or not await exercise_storage() or not await door("DoorInteract", &"south", "space.farm"):
		await finish()
		return
	var bridge_west: Vector2 = app.room.get_anchor_position("BridgeWest")
	var bridge_east: Vector2 = app.room.get_anchor_position("BridgeEast")
	check(absf(bridge_east.y-bridge_west.y)<=2.0, "authored horizontal bridge bank alignment")
	if not await walk(bridge_west) or not await walk_segment(bridge_east):
		await finish()
		return
	check(app.room.get_player().position.distance_to(bridge_east)<=4.0, "full eastbound bridge traversal reaches authored bank")
	if not await walk_segment(bridge_west):
		await finish()
		return
	check(app.room.get_player().position.distance_to(bridge_west)<=4.0, "full westbound bridge traversal reaches authored bank")
	# New non-bridge probe names await WORLD's frozen scene API/checkpoint.
	if not await verify_river_probe():
		await finish()
		return
	if not await door("VillagePathInteract", &"north", "space.village") or not await door("ShopDoorInteract", &"north", "space.shop") or not await exercise_trade() or not await door("DoorInteract", &"south", "space.village") or not await door("WorkshopDoorInteract", &"south", "space.workshop") or not await door("DoorInteract", &"south", "space.village") or not await door("FarmExitInteract", &"north", "space.farm"):
		await finish()
		return
	var expected_seeds: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	var expected_chest: int = app.gameplay_session.storage.quantity_of("item.radish_seed")
	var expected_money: int = app.gameplay_session.wallet.money
	var saved: Dictionary = app.save_progress()
	check(saved.ok, "save walked route")
	if saved.ok:
		app.set_process(true)
		app.return_to_title()
		app._on_action("read_save", {"save_id":saved.save_id})
		var loaded := await wait_world()
		check(loaded, "reload walked route error=" + app.last_error)
		if loaded:
			check(app.gameplay_session.inventory.quantity_of("item.radish")==0 and app.gameplay_session.inventory.quantity_of("item.radish_seed")==expected_seeds and app.gameplay_session.storage.quantity_of("item.radish_seed")==expected_chest and app.gameplay_session.wallet.money==expected_money and app.gameplay_session.farm.get_plot("plot.farm.004").is_watered, "reload preserves sold radish, seed/chest quantities, money and watered practice plot")
	await finish()

func contact(anchor: String, kind: String) -> bool:
	if not await walk(app.room.get_anchor_position(anchor)+Vector2.DOWN*CONTACT_OFFSET_PX): return false
	app.room.get_player().facing = &"north"
	check(app.room.resolve_interaction_target().get("kind","") == kind, "walked " + kind + " resolver")
	app._unhandled_key_input(key(KEY_E))
	return app.locks.has_owner(StringName(kind))

func exercise_storage() -> bool:
	if not await contact("ChestInteract", "storage"):
		check(false, "real chest opens at walked anchor")
		return false
	var before: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	var stored: int = app.gameplay_session.storage.quantity_of("item.radish_seed")
	app._on_action("transfer_storage", {"source_container_id":"container.player", "item_id":"item.radish_seed", "quantity":1})
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed")==before-1 and app.gameplay_session.storage.quantity_of("item.radish_seed")==stored+1, "walked chest transfers exactly one seed atomically")
	app._unhandled_key_input(key(KEY_ESCAPE))
	return not app.locks.has_owner(&"storage")

func exercise_trade() -> bool:
	app._process(84.001)
	check(app.gameplay_session.projection().shop.is_open, "clock naturally reaches shop opening")
	if not await contact("CounterInteract", "trade"):
		check(false, "real counter opens at walked anchor")
		return false
	var money: int = app.gameplay_session.wallet.money
	var seeds: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	app._on_action("trade_sell", {"item_id":"item.radish", "quantity":1})
	check(app.gameplay_session.inventory.quantity_of("item.radish")==0 and app.gameplay_session.wallet.money==money+35, "sell exactly harvested radish at configured price")
	app._on_action("trade_buy", {"item_id":"item.radish_seed", "quantity":1})
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed")==seeds+1 and app.gameplay_session.wallet.money==money+35-20, "buy exactly one replacement seed at configured price")
	app._unhandled_key_input(key(KEY_ESCAPE))
	return not app.locks.has_owner(&"trade")

func verify_river_probe() -> bool:
	var bank: Vector2 = app.room.get_anchor_position("RiverBankProbe")
	var blocked: Vector2 = app.room.get_anchor_position("RiverBlockedProbe")
	if not bank.is_finite() or not blocked.is_finite():
		check(false, "required non-bridge river probe anchors not frozen/present")
		return false
	if not await walk(bank): return false
	var ray := PhysicsRayQueryParameters2D.create(bank,blocked,1)
	var hit: Dictionary = app.room.get_world_2d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty(), "authored non-bridge river probe intersects actual collision")
	var direction := blocked-bank
	var action := ("move_right" if direction.x>0 else "move_left") if absf(direction.x)>absf(direction.y) else ("move_down" if direction.y>0 else "move_up")
	var player: CharacterBody2D = app.room.get_player()
	Input.action_press(action)
	var seconds: float = (direction.length()+32.0)/player.speed_px_per_sec
	var ticks := ceili(seconds * Engine.physics_ticks_per_second)
	var stopped_by_river := false
	for tick in range(ticks):
		await physics_frame
		for index in range(player.get_slide_collision_count()):
			if not hit.is_empty() and player.get_slide_collision(index).get_collider() == hit.collider:
				stopped_by_river = true
	Input.action_release(action)
	await physics_frame
	check(player.position.distance_to(blocked)>4.0 and stopped_by_river, "real input is stopped outside bridge river")
	return not hit.is_empty() and player.position.distance_to(blocked)>4.0 and stopped_by_river

func use_plot() -> void:
	app._unhandled_key_input(key(KEY_E))
	finish_action()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	root.get_node("AudioManager").shutdown_audio()
	await process_frame
	print("MAP_PLAYABILITY_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
