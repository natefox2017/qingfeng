extends Node2D
# Isolated ART rendering fixture; never imported into the formal WORLD scene.
func _ready() -> void:
	get_window().unfocusable = true
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	var source := TileSetAtlasSource.new()
	source.texture = load("res://assets/water_animation.png")
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i.ZERO)
	source.set_tile_animation_columns(Vector2i.ZERO, 2)
	source.set_tile_animation_frames_count(Vector2i.ZERO, 2)
	source.set_tile_animation_frame_duration(Vector2i.ZERO, 0, 0.15)
	source.set_tile_animation_frame_duration(Vector2i.ZERO, 1, 0.15)
	tiles.add_source(source, 0)
	var water := TileMapLayer.new()
	water.tile_set = tiles
	water.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(water)
	for y in range(12):
		for x in range(20):
			water.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	for y in range(32, 192, 32):
		place("bank_cliff", Vector2(0, y))
		place("bank_cliff", Vector2(288, y))
	for x in range(0, 320, 32):
		place("bank_north", Vector2(x, 0))
	for x in range(32, 288, 32):
		place("bridge_deck", Vector2(x, 64))
		place("bridge_rail", Vector2(x, 57))
		place("bridge_rail", Vector2(x, 73))
	for x in range(32, 289, 32):
		place("bridge_post", Vector2(x - 8, 59))
	for y in range(112, 161, 16):
		for x in range(32, 65, 16):
			place("dock_deck", Vector2(x, y))
	place("boat", Vector2(88, 128))
	place("reeds", Vector2(8, 126))
	place("reeds", Vector2(272, 135))
	place("waterfall_mouth", Vector2(216, 0))
	place("waterfall_middle", Vector2(216, 16))
	place("waterfall_splash", Vector2(216, 48))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png("res://native_sample.png")
	var initial_bytes := image.get_data()
	var changed := false
	var samples := 0
	for sample in range(16):
		await get_tree().create_timer(0.04).timeout
		await RenderingServer.frame_post_draw
		var second := get_viewport().get_texture().get_image()
		samples += 1
		if initial_bytes != second.get_data():
			second.save_png("res://native_animation_second.png")
			changed = true
			break
	print("RIVER_NATIVE_ANIMATION_DISTINCT: ", changed, " samples=", samples)
	if not changed:
		get_tree().quit(1)
		return
	print("RIVER_NATIVE_CAPTURE: ", result, " ", image.get_size(), " tiles=240 rendered_unique_assets=12 runtime_pngs=14")
	get_tree().quit(result)

func place(asset_name: String, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/" + asset_name + ".png")
	sprite.centered = false
	sprite.position = at
	add_child(sprite)
