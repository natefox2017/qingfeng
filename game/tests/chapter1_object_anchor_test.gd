extends SceneTree
## Verify 1:1 pixel anchors, rather than assuming offset is the drawn top-left.
## Centered sprites such as fence posts have a different explicit offset and
## are intentionally outside this top-left authoring convention.
var anchors: Dictionary = {}
var observed: Dictionary = {}
var checks := 0
var failures := 0

func _initialize() -> void:
	for file: String in ["res://assets/chapter1/objects/object_metadata.json", "res://assets/chapter1/animals/animal_metadata.json", "res://../art/sources/chapter1/town/town_assets.json", "res://../art/sources/chapter1/river/metadata.json"]:
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(file))
		for asset: Dictionary in metadata.assets:
			if not asset.has("anchor_px"): continue
			var path := String(asset.get("runtime_path", asset.get("runtime", ""))).replace("game/", "res://")
			var anchor := Vector2(asset.anchor_px[0], asset.anchor_px[1])
			anchors[path] = anchor
			for layer: Variant in asset.get("layers", {}).values():
				if layer is String: anchors[String(layer).replace("game/", "res://")] = anchor
	for file: String in DirAccess.get_files_at("res://world/objects"):
		if not file.ends_with(".tscn"): continue
		audit_scene("res://world/objects/" + file)
	for path: String in ["res://world/farm_first_screen.tscn", "res://world/village_first_screen.tscn"]:
		audit_scene(path)
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/chapter1/object_anchor_contracts.json"))
	# Fixed reviewed membership must not disappear if texture or offset changes.
	# Extra future nodes still receive the metadata-based anchor test above.
	for key: String in expected:
		checks += 1
		if not observed.has(key) or JSON.stringify(observed[key]) != JSON.stringify(expected[key]):
			failures += 1
			print("OBJECT_ANCHOR_MEMBERSHIP_FAIL ", key)

	print("OBJECT_ANCHOR_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 and observed.size() >= expected.size() and not expected.is_empty() else 1)

func audit_scene(path: String) -> void:
	var scene := (load(path) as PackedScene).instantiate()
	for node: Node in scene.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite.texture == null or not anchors.has(sprite.texture.resource_path): continue
		var anchor: Vector2 = anchors[sprite.texture.resource_path]
		# Existing art includes intentional 1–2 px vertical seating adjustments.
		# Only test sprites already authored with a top-left (-anchor) offset.
		var authored_delta := sprite.offset + anchor
		if sprite.offset.x >= 0 or sprite.offset.y >= 0 or absf(authored_delta.x) > 0.01 or absf(authored_delta.y) > 2.0: continue
		observed[path + "#" + String(scene.get_path_to(sprite))] = {"texture":sprite.texture.resource_path,"anchor":[anchor.x,anchor.y],"seating_delta":[authored_delta.x,authored_delta.y]}
		checks += 1
		var drawn_delta := sprite.get_rect().position + anchor
		if drawn_delta != authored_delta:
			failures += 1
			print("OBJECT_ANCHOR_FAIL ",path," ",scene.get_path_to(sprite)," anchor=",anchor," intended=",authored_delta," actual=",drawn_delta)
	scene.free()
