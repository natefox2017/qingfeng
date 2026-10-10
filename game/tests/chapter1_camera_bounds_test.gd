extends SceneTree
## Native Camera2D canvas mapping, not just checking its limit properties.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("CAMERA_BOUNDS_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.get_node("AudioManager").shutdown_audio()
	await process_frame
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1366,768)]:
		root.size = size
		await process_frame
		var scale: Vector2 = root.get_final_transform().get_scale()
		check(scale.x == scale.y and scale.x == floorf(scale.x), "uniform integer display scale " + str(size))
		for name: String in ["farm_first_screen", "village_first_screen"]:
			var scene := (load("res://world/"+name+".tscn") as PackedScene).instantiate() as Node2D
			root.add_child(scene)
			await physics_frame
			scene.set_input_enabled(false)
			var player: CharacterBody2D = scene.get_player()
			var camera := player.get_node("Camera2D") as Camera2D
			var bounds: Rect2i = scene.get_world_bounds()
			var arrival: Vector2 = player.position
			var points: Array[Vector2] = [arrival, Vector2(bounds.position)+Vector2(24,24), Vector2(bounds.end)+Vector2(-24,-24), Vector2(bounds.end.x-24,bounds.position.y+24), Vector2(bounds.position.x+24,bounds.end.y-24), Vector2(bounds.get_center()), arrival]
			var first_center := Vector2.INF
			for i in range(points.size()):
				player.position = points[i]
				camera.force_update_scroll()
				await physics_frame
				await process_frame
				var inverse := root.get_canvas_transform().affine_inverse()
				var view: Rect2 = root.get_visible_rect()
				var corners := [view.position, Vector2(view.end.x,view.position.y), view.end, Vector2(view.position.x,view.end.y)]
				for corner: Vector2 in corners:
					var world: Vector2 = inverse * corner
					check(world.x >= bounds.position.x-0.01 and world.y >= bounds.position.y-0.01 and world.x <= bounds.end.x+0.01 and world.y <= bounds.end.y+0.01, "%s %s point%d screen corner maps inside ground: %s" % [name,size,i,world])
				check(player.position == points[i], "camera never moves physical player")
				if i == 0: first_center = camera.get_screen_center_position()
				if i == points.size()-1: check(camera.get_screen_center_position() == first_center, "same arrival restores same framing without smoothing")
			check(camera.zoom == Vector2.ONE and not camera.position_smoothing_enabled, "world scale and smoothing unchanged")
			scene.free()
			await process_frame
		# The three small interiors are exactly one 640×360 logical viewport.
		# Keep-aspect integer stretch must not ask for extra world area at 1366px.
		for name: String in ["house_interior", "shop_interior", "workshop_interior"]:
			var scene := (load("res://world/"+name+".tscn") as PackedScene).instantiate()
			root.add_child(scene)
			await process_frame
			var inverse := root.get_canvas_transform().affine_inverse()
			var view: Rect2 = root.get_visible_rect()
			check(inverse * view.position == Vector2.ZERO and inverse * view.end == Vector2(640,360), "small interior retains its exact logical viewport " + name + str(size))
			scene.free()
			await process_frame
	print("CAMERA_BOUNDS_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
