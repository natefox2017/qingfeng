extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("GATE_PASSAGE_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for entry: Array in [["farm_first_screen","FarmVillageGate",70.0],["village_first_screen","SouthTownGate",22.0]]:
		var scene := (load("res://world/"+entry[0]+".tscn") as PackedScene).instantiate() as Node2D
		root.add_child(scene)
		await physics_frame
		var gate := scene.get_node("FootSorted/"+entry[1]) as Node2D
		var player: CharacterBody2D = scene.get_player()
		player.position = gate.position + Vector2(0,entry[2])
		scene.set_input_enabled(true)
		Input.action_press("move_up")
		for frame in range(100): await physics_frame
		Input.action_release("move_up")
		await physics_frame
		check(player.position.y < gate.position.y-64, "real input walks straight under arch " + entry[0] + " final=" + str(player.position))
		for side: String in ["LeftPost","RightPost"]:
			var query := PhysicsPointQueryParameters2D.new()
			query.position = gate.get_node(side).global_position
			query.collision_mask = 1
			check(not scene.get_world_2d().direct_space_state.intersect_point(query,1).is_empty(), "stone pillar remains solid " + entry[0] + side)
		scene.free()
		await process_frame
	print("GATE_PASSAGE_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
