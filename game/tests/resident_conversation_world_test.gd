extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const SCHEDULE = preload("res://systems/resident_schedule.gd")
const RUNTIME = preload("res://systems/resident_runtime_state.gd")
const CONVERSATIONS = preload("res://systems/resident_conversation_state.gd")
const VILLAGE = preload("res://world/village_first_screen.tscn")
const SHOP = preload("res://world/shop_interior.tscn")
const WORKSHOP = preload("res://world/workshop_interior.tscn")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL resident_conversation_world ",label)

func collect_anchors(scene: PackedScene) -> Array:
	var instance := scene.instantiate()
	var rows: Array = instance.get_resident_anchor_definitions()
	instance.free()
	return rows

func wait_ready(village: Node2D, conversation_id: String, max_frames := 360) -> bool:
	for tick in range(max_frames):
		await physics_frame
		if village.conversation_participants_arrived(conversation_id):
			return true
	return false

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(25).timeout.connect(func(): printerr("RESIDENT_CONVERSATION_WORLD_TIMEOUT"); quit(1))
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
	var conversations := CONVERSATIONS.new(loaded.data)
	check(schedule.is_configured() and runtime.is_configured() and conversations.is_configured(),"resident domains configure")

	var village := VILLAGE.instantiate()
	root.add_child(village)
	await physics_frame
	village.maker_resident.speed_px_per_sec=180.0
	village.neighbor_resident.speed_px_per_sec=180.0
	check(village.apply_resident_runtime(runtime.projection()),"village restores resident runtime")
	check(village.apply_resident_projection(schedule.projection(480,false),runtime.projection()),"08:00 applies current schedule targets before the morning chat")

	var invitation: Dictionary = conversations.invite(
		"conversation.test.maker-neighbor",
		"resident.maker",
		"resident.neighbor",
		"space.village"
	)
	check(invitation.ok,"maker and neighbor occupy one resident conversation")
	check(conversations.mark_approaching("conversation.test.maker-neighbor").ok,"conversation enters approaching")
	check(village.apply_conversation_projection(conversations.projection()),"conversation projection overrides schedule with meeting positions")

	var maker_before: Vector2 = village.maker_resident.position
	var neighbor_before: Vector2 = village.neighbor_resident.position
	await physics_frame
	await physics_frame
	check(village.maker_resident.position!=maker_before and village.neighbor_resident.position!=neighbor_before,"both residents physically approach rather than teleport")
	check(await wait_ready(village,"conversation.test.maker-neighbor"),"both residents reach distinct conversation stands")
	check(village.maker_resident.position.distance_to(village.get_node("ConversationAnchors/Left").position)<=2.0,"maker arrives at left conversation stand")
	check(village.neighbor_resident.position.distance_to(village.get_node("ConversationAnchors/Right").position)<=2.0,"neighbor arrives at right conversation stand")

	check(conversations.begin_participation("conversation.test.maker-neighbor").ok,"conversation begins only after approach")
	check(village.apply_conversation_projection(conversations.projection()),"participating state is projected into WORLD")
	var visual: Dictionary = village.conversation_visual_state()
	check(visual.is_visible and visual.state=="participating","resident-resident exchange is visibly active")
	check(village.maker_resident.facing==&"east" and village.neighbor_resident.facing==&"west","participants face each other while talking")

	check(conversations.end("conversation.test.maker-neighbor").ok,"conversation ends and releases occupancy")
	check(village.apply_resident_projection(schedule.projection(480,false),runtime.projection()),"schedule target is restored after conversation")
	check(village.apply_conversation_projection(conversations.projection()),"empty conversation projection clears visible exchange")
	check(not village.conversation_visual_state().is_visible,"conversation indicator disappears after end")
	check(String(village.maker_resident.projection().anchor_id)=="anchor.resident.maker.home","maker resumes its pre-work home target")
	check(String(village.neighbor_resident.projection().anchor_id)=="anchor.resident.neighbor.work","neighbor resumes its work target")

	var cancel_invite: Dictionary = conversations.invite(
		"conversation.test.cancel",
		"resident.maker",
		"resident.neighbor",
		"space.village"
	)
	check(cancel_invite.ok and conversations.mark_approaching("conversation.test.cancel").ok,"released residents can start another approach")
	check(village.apply_conversation_projection(conversations.projection()),"cancel test approach reaches WORLD")
	check(conversations.cancel("conversation.test.cancel").ok,"cancel releases approaching conversation")
	check(village.apply_resident_projection(schedule.projection(480,false),runtime.projection()),"cancel restores current schedule targets")
	check(village.apply_conversation_projection(conversations.projection()) and not village.conversation_visual_state().is_visible,"cancel leaves no stale conversation visual")

	village.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("RESIDENT_CONVERSATION_WORLD_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
