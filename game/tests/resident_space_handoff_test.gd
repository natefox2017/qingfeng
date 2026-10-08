extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const SCHEDULE = preload("res://systems/resident_schedule.gd")
const RUNTIME = preload("res://systems/resident_runtime_state.gd")
const VILLAGE = preload("res://world/village_first_screen.tscn")
const SHOP = preload("res://world/shop_interior.tscn")
const WORKSHOP = preload("res://world/workshop_interior.tscn")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL resident_space_handoff ",label)

func collect_anchors(scene: PackedScene) -> Array:
	var instance := scene.instantiate()
	var rows: Array = instance.get_resident_anchor_definitions()
	instance.free()
	return rows

func runtime_row(runtime: RefCounted, resident_id: String) -> Dictionary:
	for row: Variant in runtime.projection().residents:
		if String(row.get("resident_id",""))==resident_id:
			return row
	return {}

func schedule_row(schedule: RefCounted, resident_id: String, minute: int) -> Dictionary:
	var result: Dictionary = schedule.resolve(resident_id,minute,false)
	return result

func wait_handoff(scene: Node2D, resident_id: String, target_space: String, max_frames := 360) -> Dictionary:
	for tick in range(max_frames):
		await physics_frame
		for request: Variant in scene.resident_handoff_requests():
			if String(request.get("resident_id",""))==resident_id and String(request.get("target_space_id",""))==target_space:
				return request
	return {}

func wait_arrived(scene: Node2D, resident_id: String, anchor_id: String, max_frames := 360) -> bool:
	for tick in range(max_frames):
		await physics_frame
		var state: Dictionary = scene.resident_visual_state(resident_id)
		if String(state.get("anchor_id",""))==anchor_id and String(state.get("movement_state",""))=="arrived":
			return true
	return false

func commit_handoff(runtime: RefCounted, request: Dictionary, arrival: Vector2) -> bool:
	return runtime.update_runtime({
		"resident_id":String(request.resident_id),
		"space_id":String(request.target_space_id),
		"world_position_px":{"x":arrival.x,"y":arrival.y},
		"facing":String(request.arrival_facing)
	})

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(30).timeout.connect(func(): printerr("RESIDENT_SPACE_HANDOFF_TIMEOUT"); quit(1))
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok,"content loads")
	if not loaded.ok:
		finish()
		return
	var anchors: Array = []
	anchors.append_array(collect_anchors(VILLAGE))
	anchors.append_array(collect_anchors(SHOP))
	anchors.append_array(collect_anchors(WORKSHOP))
	var schedule := SCHEDULE.new(anchors,loaded.data)
	var runtime := RUNTIME.new(anchors,loaded.data)
	check(schedule.is_configured() and runtime.is_configured(),"schedule and runtime share WORLD anchors")

	var village := VILLAGE.instantiate()
	root.add_child(village)
	await physics_frame
	village.grocer_resident.speed_px_per_sec=180.0
	village.maker_resident.speed_px_per_sec=180.0
	check(village.apply_resident_runtime(runtime.projection()),"village restores resident runtime")
	check(village.apply_resident_projection(schedule.projection(480,false),runtime.projection()),"08:00 village applies grocer work target")
	var grocer_start := village.grocer_resident.position
	await physics_frame
	await physics_frame
	check(village.grocer_resident.position!=grocer_start,"grocer physically starts toward shop door")
	var to_shop: Dictionary = await wait_handoff(village,"resident.grocer","space.shop")
	check(not to_shop.is_empty(),"grocer reaches village shop door before handoff")
	check(String(to_shop.arrival_anchor_id)=="DoorArrival" and String(to_shop.arrival_facing)=="north","grocer handoff uses existing shop arrival contract")
	check(commit_handoff(runtime,to_shop,Vector2(320,320)),"grocer runtime commits only at target-space arrival")
	check(String(runtime_row(runtime,"resident.grocer").space_id)=="space.shop","grocer runtime now belongs to shop")
	village.queue_free()
	await process_frame

	var shop := SHOP.instantiate()
	root.add_child(shop)
	await physics_frame
	shop.grocer_resident.speed_px_per_sec=180.0
	check(shop.apply_resident_runtime(runtime.projection()),"shop restores grocer at door arrival")
	check(shop.grocer_resident.position.distance_to(Vector2(320,320))<0.1,"shop actor starts at legal DoorArrival")
	check(shop.apply_resident_projection(schedule.projection(480,false),runtime.projection()),"shop applies work anchor after handoff")
	check(await wait_arrived(shop,"resident.grocer","anchor.resident.grocer.work"),"grocer physically walks from shop door to work anchor")

	check(shop.apply_resident_projection(schedule.projection(1020,false),runtime.projection()),"17:00 shop targets village social route")
	var to_village: Dictionary = await wait_handoff(shop,"resident.grocer","space.village")
	check(not to_village.is_empty(),"grocer physically returns to shop exit before handoff")
	check(String(to_village.arrival_anchor_id)=="ShopDoorArrival","shop exit reuses village ShopDoorArrival")
	check(commit_handoff(runtime,to_village,Vector2(400,168)),"grocer commits back to village arrival")
	shop.queue_free()
	await process_frame

	village=VILLAGE.instantiate()
	root.add_child(village)
	await physics_frame
	village.grocer_resident.speed_px_per_sec=180.0
	check(village.apply_resident_runtime(runtime.projection()),"village restores returning grocer")
	check(village.grocer_resident.position.distance_to(Vector2(400,168))<0.1,"returning grocer starts at village door arrival")
	check(village.apply_resident_projection(schedule.projection(1020,false),runtime.projection()),"village applies social target after return")
	check(await wait_arrived(village,"resident.grocer","anchor.resident.grocer.social"),"grocer physically walks from door arrival to social anchor")
	village.queue_free()
	await process_frame

	runtime=RUNTIME.new(anchors,loaded.data)
	village=VILLAGE.instantiate()
	root.add_child(village)
	await physics_frame
	village.maker_resident.speed_px_per_sec=180.0
	check(village.apply_resident_runtime(runtime.projection()),"fresh village restores maker home runtime")
	check(village.apply_resident_projection(schedule.projection(540,false),runtime.projection()),"09:00 village applies maker workshop target")
	var to_workshop: Dictionary = await wait_handoff(village,"resident.maker","space.workshop")
	check(not to_workshop.is_empty(),"maker reaches real workshop door before handoff")
	check(String(to_workshop.arrival_anchor_id)=="DoorArrival","maker handoff uses workshop DoorArrival")
	check(commit_handoff(runtime,to_workshop,Vector2(320,320)),"maker runtime commits into workshop")
	village.queue_free()
	await process_frame

	var workshop := WORKSHOP.instantiate()
	root.add_child(workshop)
	await physics_frame
	workshop.maker_resident.speed_px_per_sec=180.0
	check(workshop.apply_resident_runtime(runtime.projection()),"workshop restores maker at door arrival")
	check(workshop.apply_resident_projection(schedule.projection(540,false),runtime.projection()),"workshop applies maker work anchor")
	check(await wait_arrived(workshop,"resident.maker","anchor.resident.maker.work"),"maker physically walks from workshop door to work anchor")
	workshop.queue_free()
	await process_frame

	finish()

func finish() -> void:
	print("RESIDENT_SPACE_HANDOFF_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
