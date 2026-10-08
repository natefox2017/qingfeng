extends SceneTree

const ASSET_ROOT := "res://assets/chapter1/town/"

func _initialize() -> void:
	get_root().size = Vector2i(640, 360)
	get_root().set_flag(Window.FLAG_NO_FOCUS, true)
	get_root().title = "Issue 93 isolated town asset preview"
	get_root().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	RenderingServer.set_default_clear_color(Color("72956d"))
	call_deferred("_preview")

func _preview() -> void:
	var audio := get_root().get_node_or_null("AudioManager")
	if audio != null:
		audio.shutdown_audio()
	var stage := Node2D.new()
	get_root().add_child(stage)
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(ASSET_ROOT + "plaza_stone_16.png")
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i.ZERO)
	tiles.add_source(atlas, 0)
	var floor_layer := TileMapLayer.new()
	floor_layer.tile_set = tiles
	floor_layer.position = Vector2(144, 96)
	stage.add_child(floor_layer)
	for y in range(12):
		for x in range(22):
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	for pair in [["townhouse_red", Vector2(150, 42)], ["stone_gate", Vector2(304, 46)], ["market_blue_white", Vector2(200, 138)], ["market_orange_white", Vector2(376, 138)], ["street_lamp", Vector2(168, 226)], ["street_lamp", Vector2(448, 226)], ["wood_bench", Vector2(224, 245)], ["blank_sign", Vector2(350, 250)]]:
		_add_sprite(stage, pair[0], pair[1])
	for x in [272, 240, 368, 400]:
		_add_sprite(stage, "stone_wall", Vector2(x, 94))
	# Project's existing player is a scale reference, not a newly approved town character.
	var player := Sprite2D.new()
	player.texture = load("res://assets/phase0/player_4dir.png")
	player.region_enabled = true
	player.region_rect = Rect2(0, 0, 24, 32)
	player.position = Vector2(324, 164)
	stage.add_child(player)
	var packed := PackedScene.new()
	for child in stage.get_children():
		child.owner = stage
	packed.pack(stage)
	ResourceSaver.save(packed, ASSET_ROOT + "town_preview.tscn")
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	var result := image.save_png(ProjectSettings.globalize_path("res://../art/reviews/chapter1/town/godot_native_town.png"))
	print("TOWN_NATIVE_CAPTURE: ", image.get_size(), " save=", result, " TileMapLayer=264 cells, 12 prop sprites")
	stage.queue_free()
	await process_frame
	call_deferred("quit", result)

func _add_sprite(stage: Node2D, asset_name: String, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.name = asset_name.to_pascal_case() + str(stage.get_child_count())
	sprite.texture = load(ASSET_ROOT + asset_name + ".png")
	assert(sprite.texture != null)
	sprite.centered = false
	sprite.position = at
	stage.add_child(sprite)
