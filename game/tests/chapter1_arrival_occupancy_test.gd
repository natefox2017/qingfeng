extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	print("ARRIVAL_CHECK ",ok," ",label)
	if not ok:failures+=1
func _initialize():run.call_deferred()
func run():
	var app=load("res://app/main.tscn").instantiate();root.add_child(app)
	for path in ["res://world/workshop_interior.tscn","res://world/shop_interior.tscn"]:
		for mode in ["day-working","night-leaving","absent"]:
			var scene=load(path).instantiate();root.add_child(scene);await physics_frame
			var player=scene.get_player();var arrival=scene.get_anchor_position("DoorArrival")
			var resident=scene.get_node("FootSorted/MakerResident") if "workshop" in path else scene.get_node("FootSorted/GrocerResident")
			player.position=arrival;resident.set_world_active(mode!="absent")
			resident.restore_runtime_position(arrival,&"north")
			if mode!="absent":resident.set_schedule_target("probe",Vector2(320,256) if mode=="day-working" else Vector2(320,336),"work" if mode=="day-working" else "travel")
			check(app._reserve_player_arrival(scene,arrival),"reserve "+path+" "+mode)
			check(player.position==arrival,"player retains exact door anchor")
			check(mode=="absent" or resident.position.distance_to(arrival)>=8.1,"no active resident overlap")
			if mode!="absent":resident.set_schedule_target("probe",Vector2(320,256) if mode=="day-working" else Vector2(320,336),"work" if mode=="day-working" else "travel")
			await physics_frame
			player.set_input_enabled(true)
			for frame in range(90):await physics_frame
			print("ARRIVAL_POS ",mode," player=",player.position," resident=",resident.position)
			check(player.position.distance_to(arrival)<0.1,"zero input cannot carry player "+mode)
			check(Input.get_vector("move_left","move_right","move_up","move_down")==Vector2.ZERO,"no residual direction")
			player.facing=&"south"
			check(scene._marker_reachable(scene.get_node("Anchors/DoorInteract")),"physical return marker remains reachable")
			scene.queue_free();await process_frame
	await crowded_cases(app)
	app.queue_free();await process_frame
	print("ARRIVAL_OCCUPANCY_RESULT checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)

func crowded_cases(app):
	var scene=load("res://world/workshop_interior.tscn").instantiate();root.add_child(scene);await physics_frame
	var resident=scene.get_node("FootSorted/MakerResident")
	var arrival=Vector2(320,320)
	resident.set_world_active(true);resident.restore_runtime_position(arrival,&"north");resident.set_schedule_target("probe",Vector2(320,256),"work")
	var blockers=[]
	for point in [Vector2(336,304),Vector2(304,304),Vector2(320,304)]:
		var other=resident.duplicate();other.name="ReservedNeighbor"+str(blockers.size());scene.get_node("FootSorted").add_child(other);other.set_world_active(true);other.restore_runtime_position(point,&"south");other.clear_schedule_target();blockers.append(other)
	await physics_frame
	var rejected_before=resident.position
	check(not app._reserve_player_arrival(scene,arrival),"all legal candidate spaces occupied: conservative rejection")
	check(resident.position==rejected_before,"rejected overlap is not forced through a wall/neighbor")
	blockers[1].set_world_active(false)
	check(app._reserve_player_arrival(scene,arrival),"second safe candidate is usable")
	check(resident.position==Vector2(304,304),"occupied first candidate is skipped")
	check(blockers[0].position==Vector2(336,304) and blockers[2].position==Vector2(320,304),"non-overlapping neighbors remain unmoved")
	var stable=resident.position
	check(app._reserve_player_arrival(scene,arrival) and resident.position==stable,"repeated reservation does not move non-overlapping NPC")
	for other in blockers:other.queue_free()
	await process_frame
	resident.restore_runtime_position(arrival,&"north");resident.set_schedule_target("probe",Vector2(320,256),"work");resident.clear_schedule_target()
	var wall=StaticBody2D.new();wall.position=Vector2(320,312);wall.collision_layer=1
	var collision=CollisionShape2D.new();var rectangle=RectangleShape2D.new();rectangle.size=Vector2(50,2);collision.shape=rectangle;wall.add_child(collision);scene.add_child(wall)
	await physics_frame
	check(not app._position_is_blocked_in(scene,Vector2(336,304)),"thin-wall fixture endpoint itself is clear")
	check(not app._reserve_player_arrival(scene,arrival),"cannot relocate through a wall to a clear endpoint")
	check(resident.position==arrival,"rejected wall crossing preserves resident")
	scene.queue_free();await process_frame
