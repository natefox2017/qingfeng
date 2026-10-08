extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("YARD_LAYOUT_FAIL ", label)
func _initialize() -> void:
	run.call_deferred()
func opaque_bounds(node: Node) -> Rect2:
	var bounds := Rect2()
	var first := true
	for child: Node in node.find_children("*", "Sprite2D", true, false):
		var sprite := child as Sprite2D
		if sprite.texture == null: continue
		var used: Rect2i = sprite.texture.get_image().get_used_rect()
		var rect := Rect2(sprite.get_rect().position + Vector2(used.position), Vector2(used.size))
		rect = sprite.global_transform * rect
		bounds = rect if first else bounds.merge(rect)
		first = false
	return bounds
func run() -> void:
	var farm := (load("res://world/farm_first_screen.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(farm)
	await physics_frame
	var yard := farm.get_node("FootSorted")
	var dog := yard.get_node("YardDog") as Node2D
	var kennel := yard.get_node("Doghouse") as Node2D
	var bench := yard.get_node("ToolBench") as Node2D
	var coop := yard.get_node("ChickenCoop") as Node2D
	check(not opaque_bounds(dog).intersects(opaque_bounds(farm.get_node("Farmhouse"))), "dog never overlaps the farmhouse opaque facade")
	check(not opaque_bounds(bench).intersects(opaque_bounds(coop)), "coop and workbench have distinct visible silhouettes")
	check(not opaque_bounds(kennel).intersects(opaque_bounds(yard.get_node("YardWell"))), "kennel and well are visually separated")
	for child: Node in yard.get_children():
		if String(child.name).begins_with("YardFenceSouth"):
			check(not opaque_bounds(kennel).intersects(opaque_bounds(child)), "kennel clears south fence " + String(child.name))
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	for node: Node2D in [dog, yard.get_node("YardChicken01"), yard.get_node("YardChicken02")]:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = circle
		query.transform = Transform2D(0, node.global_position)
		query.collision_mask = 1
		check(farm.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(), "static yard animal rests on safe ground " + String(node.name))
	check(farm.get_spawn_position() == Vector2(320,560), "existing player spawn unchanged")
	check(farm.get_anchor_position("HouseDoorInteract") == Vector2(272,472), "existing house door unchanged")
	check(farm.get_plot_definitions().size() == 6, "six gameplay plots unchanged")
	farm.queue_free()
	await process_frame
	print("YARD_LAYOUT_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
