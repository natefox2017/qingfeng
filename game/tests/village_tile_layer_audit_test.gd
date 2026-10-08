extends SceneTree

const VILLAGE = preload("res://world/village_first_screen.tscn")

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print("VILLAGE_LAYER_CHECK ", ok, " ", label)
	if not ok:
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(15).timeout.connect(func(): printerr("VILLAGE_LAYER_AUDIT_TIMEOUT"); quit(1))
	var scene := VILLAGE.instantiate() as Node2D
	root.add_child(scene)
	await physics_frame

	var layers: Array[Node] = scene.find_children("*", "TileMapLayer", true, false)
	var names: Array[String] = []
	for layer: Node in layers:
		names.append(layer.name)
	names.sort()
	check(names == ["GroundDetails", "GroundPaths", "PlazaStone", "TerrainGround", "TownDetails"], "village tile layers have explicit semantic names")
	check(scene.get_node_or_null("@TileMapLayer@2") == null and scene.get_node_or_null("@TileMapLayer@3") == null, "empty anonymous tile layers are removed")

	var ground := scene.get_node("TerrainGround") as TileMapLayer
	var paths := scene.get_node("GroundPaths") as TileMapLayer
	var plaza := scene.get_node("PlazaStone") as TileMapLayer
	var town_details := scene.get_node("TownDetails") as TileMapLayer
	var details := scene.get_node("GroundDetails") as TileMapLayer
	check(ground.tile_set != null and not ground.get_used_cells().is_empty(), "TerrainGround remains the authored world extent")
	check(paths.tile_set == ground.tile_set and not paths.get_used_cells().is_empty(), "GroundPaths remains an editable path overlay")
	check(plaza.tile_set != null and not plaza.get_used_cells().is_empty(), "PlazaStone retains town plaza tiles")
	check(not town_details.get_used_cells().is_empty() and details.get_used_cells().is_empty(), "TownDetails stays distinct from the currently empty GroundDetails layer")

	var bounds: Rect2i = scene.get_world_bounds()
	var expected_bounds := Rect2i(ground.get_used_rect().position * scene.TILE_SIZE, ground.get_used_rect().size * scene.TILE_SIZE)
	var camera := scene.get_node("FootSorted/Player/Camera2D") as Camera2D
	check(bounds == expected_bounds, "world extent derives from TerrainGround cells only")
	check(camera.limit_left == bounds.position.x and camera.limit_top == bounds.position.y and camera.limit_right == bounds.end.x and camera.limit_bottom == bounds.end.y, "camera limits match the TerrainGround extent")
	for side: String in ["North", "South", "West", "East"]:
		var body := scene.get_node("Solids/" + side) as StaticBody2D
		var shape := body.get_node("CollisionShape2D").shape as RectangleShape2D
		var expected_size := Vector2(bounds.size.x, 16) if side in ["North", "South"] else Vector2(16, bounds.size.y)
		check(shape.size == expected_size, "perimeter collision follows TerrainGround on " + side)

	scene.queue_free()
	await process_frame
	print("VILLAGE_LAYER_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
