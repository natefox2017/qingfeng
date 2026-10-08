extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	print("VILLAGE_FRONTAGE_CHECK ",ok," ",label)
	if not ok: failures+=1
func _initialize(): run.call_deferred()
func run():
	var scene=load("res://world/village_first_screen.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	check(scene.get_world_bounds()==Rect2i(0,0,1280,640),"authored world extent unchanged")
	var fixed={"ShopDoorInteract":Vector2(400,144),"ShopDoorArrival":Vector2(400,168),"WorkshopDoorInteract":Vector2(520,216),"WorkshopDoorArrival":Vector2(520,192),"FarmExitInteract":Vector2(640,576),"FarmArrival":Vector2(640,600)}
	for name in fixed:
		check(scene.get_node("Anchors/"+name).position==fixed[name],"stable doorway "+name)
		var query=PhysicsPointQueryParameters2D.new();query.position=fixed[name];query.collision_mask=1
		check(scene.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"doorway remains clear "+name)
	for y in range(128,577,16):
		var query=PhysicsPointQueryParameters2D.new();query.position=Vector2(640,y);query.collision_mask=1
		check(scene.get_world_2d().direct_space_state.intersect_point(query).is_empty(),"central lane clear y="+str(y))
	for pair in [["ShopFacade","ShopFootprint"],["WorkshopCourt","WorkshopFootprint"]]:
		var sprite=scene.get_node("FootSorted/"+pair[0]+"/Sprite2D") as Sprite2D
		var body=scene.get_node("Solids/"+pair[1]) as StaticBody2D
		var local_pixel=sprite.to_local(body.global_position)-sprite.get_rect().position
		var pixels=sprite.texture.get_image()
		check(pixels.get_pixelv(Vector2i(local_pixel)).a>0.0,"visible native pixels cover existing solid "+pair[1])
		check(sprite.scale==Vector2.ONE and not sprite.centered and sprite.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"native facade scale/anchor "+pair[0])
	var player=scene.get_player()
	player.position=fixed.WorkshopDoorArrival;player.facing=&"south"
	check(scene.resolve_interaction_target().get("target_space_id","")=="space.workshop","north-side courtyard entry keeps south-facing interaction")
	player.position=fixed.ShopDoorArrival;player.facing=&"north"
	check(scene.resolve_interaction_target().get("target_space_id","")=="space.shop","south shop facade keeps north-facing interaction")
	check(scene.get_node("FootSorted/CourtyardWell").position.x>700,"courtyard landmark stays off central lane")
	scene.queue_free();await process_frame
	print("VILLAGE_FRONTAGE_RESULT checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
