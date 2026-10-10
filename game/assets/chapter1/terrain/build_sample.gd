extends SceneTree
## Offline authoring only: saves editable TileSet and TileMapLayer, never runs in gameplay.
const DIR := "res://assets/chapter1/terrain/"
const SIDES := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]
const STEPS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "grass_dirt_atlas.json"))
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_terrain_set()
	tiles.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	for name: String in ["Spring grass", "Dirt path"]:
		tiles.add_terrain(0)
		tiles.set_terrain_name(0, tiles.get_terrains_count(0) - 1, name)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(DIR + "grass_dirt_atlas_16.png")
	atlas.texture_region_size = Vector2i(16, 16)
	tiles.add_source(atlas, 0)
	for region: Dictionary in metadata.regions:
		var rect: Array = region.rect_px
		var coord := Vector2i(int(rect[0]) / 16, int(rect[1]) / 16)
		atlas.create_tile(coord)
		var data := atlas.get_tile_data(coord, 0)
		data.terrain_set = 0
		data.terrain = int(region.terrain)
		for side in range(4):
			var terrain := 0 if region.mask == null else (1 if int(region.mask) & (1 << side) else 0)
			data.set_terrain_peering_bit(SIDES[side], terrain)
	assert(atlas.get_tiles_count() == 19)
	# Source 0/NESW contract stays intact; explicit soil states and overlays are separate sources.
	for family: String in ["soil_surfaces", "ground_decor"]:
		var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + family + ".json"))
		var extra_atlas := TileSetAtlasSource.new()
		extra_atlas.texture = load(DIR + family + "_16.png")
		extra_atlas.texture_region_size = Vector2i(16, 16)
		tiles.add_source(extra_atlas, int(extra.atlas_source_id))
		for region: Dictionary in extra.regions:
			extra_atlas.create_tile(Vector2i(int(region.rect_px[0]) / 16, 0))
		assert(extra_atlas.get_tiles_count() == 4)
	assert(ResourceSaver.save(tiles, DIR + "grass_dirt_tileset.tres") == OK)
	tiles = load(DIR + "grass_dirt_tileset.tres")
	var sample := Node2D.new()
	sample.name = "Chapter1TerrainSample"
	sample.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ground := TileMapLayer.new()
	ground.name = "TerrainGround"
	ground.tile_set = tiles
	sample.add_child(ground)
	ground.owner = sample
	for y in range(23):
		for x in range(40):
			ground.set_cell(Vector2i(x, y), 0, Vector2i((x + 2 * y + (x * y) % 5) % 3, 0))
	# Three 5x5 repeated regions; base, light tuft and dark tuft variations.
	for variant in range(3):
		for y in range(2, 7):
			for x in range(2 + variant * 7, 7 + variant * 7):
				ground.set_cell(Vector2i(x, y), 0, Vector2i(variant, 0))
	var roads: Array[Vector2i] = []
	for x in range(2, 11): roads.append(Vector2i(x, 10))
	for y in range(8, 14): roads.append(Vector2i(14, y))
	for x in range(15, 21): roads.append(Vector2i(x, 13))
	for y in range(7, 11): roads.append(Vector2i(27, y))
	for x in range(24, 32):
		if x != 27: roads.append(Vector2i(x, 10))
	for x in range(32, 39): roads.append(Vector2i(x, 17))
	for y in range(14, 21):
		if y != 17: roads.append(Vector2i(35, y))
	roads.append(Vector2i(4, 17))
	ground.set_cells_terrain_connect(roads, 0, 1, false)
	ground.update_internals()
	# Verify actual Godot terrain solver results, including endpoint, corner, T and cross.
	var masks: Array[int] = []
	for cell: Vector2i in roads:
		var data := ground.get_cell_tile_data(cell)
		assert(data != null and data.terrain == 1)
		var mask := 0
		for side in range(4):
			var expected := 1 if roads.has(cell + STEPS[side]) else 0
			assert(data.get_terrain_peering_bit(SIDES[side]) == expected)
			if expected: mask |= 1 << side
		if not masks.has(mask): masks.append(mask)
	assert(masks.has(0) and masks.has(2) and masks.has(10) and masks.has(3) and masks.has(11) and masks.has(15))
	assert(ground.get_used_cells().size() == 920)
	# Four 5x5 surface samples: full road, untilled, tilled, wet.
	for state in range(4):
		var origin := Vector2i(17, 16) if state == 0 else Vector2i(23 + (state - 1) * 6, 2)
		for y in range(5):
			for x in range(5):
				ground.set_cell(origin + Vector2i(x, y), 1, Vector2i(state, 0))
	assert(ground.get_used_cells_by_id(1).size() == 100)
	var decor := TileMapLayer.new()
	decor.name = "GroundDecor"
	decor.tile_set = tiles
	sample.add_child(decor)
	decor.owner = sample
	for kind in range(4):
		for placement in range(6):
			decor.set_cell(Vector2i(2 + kind * 9 + placement % 3 * 2, 20 + placement / 3), 2, Vector2i(kind, 0))
	assert(decor.get_used_cells().size() == 24)
	var packed := PackedScene.new()
	assert(packed.pack(sample) == OK)
	assert(ResourceSaver.save(packed, DIR + "terrain_sample.tscn") == OK)
	print("TERRAIN_SAMPLE_PASS tiles=19 cells=920 road_cells=", roads.size(), " masks=", masks)
	print("SURFACE_SAMPLE_PASS soil_cells=100 decor_cells=24 source_ids=1,2")
	sample.free()
	quit(0)
