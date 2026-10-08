extends SceneTree
## Phase0 static+native scene regression. Run via manual/N11 suite.
## It does not by itself approve the visual design or replace a played route.

const FARM = preload("res://world/farm_first_screen.tscn")
const HOUSE = preload("res://world/house_interior.tscn")
const VILLAGE = preload("res://world/village_first_screen.tscn")
const SHOP = preload("res://world/shop_interior.tscn")
const WORKSHOP = preload("res://world/workshop_interior.tscn")

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("CHECK_FAIL phase0_visual ",message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var farm := FARM.instantiate() as Node2D
	root.add_child(farm)
	await physics_frame

	check(farm.layout_contract_valid(),"farm layout and original plot/door markers validate")
	var ground := farm.get_node("TerrainGround") as TileMapLayer
	var details := farm.get_node("GroundDetails") as TileMapLayer
	var plot_tiles := farm.get_node("PlotStates") as TileMapLayer
	check(ground != null and ground.tile_set != null and ground.get_used_cells().size()==6144,"editable 96x64 ground tiles import")
	check(ground.get_used_rect()==Rect2i(0,0,96,64) and farm.get_world_bounds()==Rect2i(0,0,1536,1024),"authorable world geometry exceeds one viewport")
	check(details != null and details.tile_set == ground.tile_set and details.get_used_cells().size()>0,"ground detail tiles use shared TileSet")
	check(plot_tiles != null and plot_tiles.get_used_cells().is_empty(),"field layer starts empty and waits for gameplay projection")
	check(ground.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and details.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,"tile texture filtering remains pixel-sharp")

	var plot_rows: Array = []
	for entry: Dictionary in farm.get_plot_definitions():
		var tilled := String(entry.plot_id)=="plot.farm.004"
		plot_rows.append({
			"plot_id":String(entry.plot_id),
			"state":"tilled" if tilled else "untilled",
			"is_watered":tilled
		})
	check(plot_rows.size()==6 and farm.get_node("FarmPlots/Plot004").position==Vector2(272,128),"six authority plot IDs and positions survive")
	check(farm.apply_farm_projection({"plots":plot_rows}),"field state applies using authoritative marker positions")
	check(plot_tiles.get_used_cells().size()==6,"six crop plot cells are separate from baked terrain")
	check(plot_tiles.get_cell_atlas_coords(Vector2i(17,8))==Vector2i(2,2),"watered tilled field maps to wet-soil atlas")
	check(plot_tiles.get_cell_atlas_coords(Vector2i(17,7))==Vector2i(0,2),"untilled field maps to unworked-soil atlas")

	var home := farm.get_node("Farmhouse/Sprite2D") as Sprite2D
	var oak := farm.get_node("FootSorted/OakTree") as Sprite2D
	check(home != null and home.texture != null and home.texture.get_size()==Vector2(192,152),"farmhouse has authored non-placeholder texture")
	check(oak != null and oak.texture != null and oak.texture.get_size()==Vector2(80,96) and oak.position==Vector2(400,204),"oak is foot-aligned with its retained collision root")
	var solids := farm.get_node("Solids") as Node2D
	var house_collision := farm.get_node("Farmhouse/Footprint/CollisionShape2D") as CollisionShape2D
	check(not solids.visible and not house_collision.disabled,"diagnostic solid fills are hidden but physical collision survives")
	check(farm.get_anchor_position("HouseDoorInteract")==Vector2(144,144) and farm.get_anchor_position("VillagePathInteract")==Vector2(608,208),"farm house door and village exit anchors stay put")

	var player := farm.get_player() as CharacterBody2D
	var sprite := player.get_node("Sprite2D") as Sprite2D
	check(sprite != null and sprite.texture != null and sprite.texture.get_size()==Vector2(96,128),"player square is replaced by pixel sprite atlas")
	check(sprite.hframes==4 and sprite.vframes==4 and sprite.offset==Vector2(0,-16),"player four-by-four frame grid uses the same foot origin")
	check(player.get_node_or_null("DiagnosticGlyph")==null,"farm player has no engineering square")
	player.set_input_enabled(true)
	Input.action_press("move_right")
	for frame in range(10):
		await physics_frame
	check(player.facing==&"east" and sprite.frame_coords.y==2 and sprite.frame_coords.x>=1,"movement selects east walk row and a non-idle frame")
	Input.action_release("move_right")
	await physics_frame
	check(player.velocity.is_zero_approx() and sprite.frame_coords==Vector2i(0,2),"release stops physics and restores east idle frame")

	# The authored farmhouse footprint is solid from y=40..136. This setup
	# places the player's feet below it; holding Up must not moonwalk into it.
	player.position = Vector2(144,160)
	Input.action_press("move_up")
	for frame in range(22):
		await physics_frame
	var stopped_at_house: Vector2 = player.position
	for frame in range(4):
		await physics_frame
	check(player.position.distance_squared_to(stopped_at_house)<0.0001 and stopped_at_house.y>=139.9,"farmhouse wall stops actual northward movement")
	check(player.facing==&"north" and sprite.frame_coords==Vector2i(0,3),"held input against solid uses north-facing idle, not walk")
	Input.action_release("move_up")
	Input.action_press("move_down")
	for frame in range(4):
		await physics_frame
	check(player.position.y>stopped_at_house.y+1.0 and sprite.frame_coords.y==0 and sprite.frame_coords.x>=1,"leaving collision resumes south walk on real displacement")
	Input.action_release("move_down")
	await physics_frame
	check(sprite.frame_coords==Vector2i(0,0),"releasing movement restores south idle")
	player.set_input_enabled(false)

	for scene: PackedScene in [HOUSE,VILLAGE,SHOP,WORKSHOP]:
		var interior := scene.instantiate() as Node2D
		var interior_sprite := interior.get_node("FootSorted/Player/Sprite2D") as Sprite2D
		check(interior_sprite != null and interior_sprite.texture != null and interior_sprite.texture.get_size()==Vector2(96,128),"same player pixel identity is used in every other playable space")
		check(interior.get_node_or_null("FootSorted/Player/DiagnosticGlyph")==null,"no other world player reverts to the square")
		interior.free()

	farm.queue_free()
	await process_frame
	print("PHASE0_VISUAL_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
