extends "res://tests/door_transition_test.gd"
func travel(space:String,anchor:String,facing:String)->bool:
	app._begin_door_transition({"kind":"door","interaction_id":"door.qa.arrival","target_space_id":space,"arrival_anchor_id":anchor,"arrival_facing":facing})
	return await wait_space(space)
func run():
	create_timer(90).timeout.connect(func():printerr("ARRIVAL_APP_TIMEOUT");quit(1))
	app=MAIN.instantiate();app.store.directory="user://arrival_qa_"+Crypto.new().generate_random_bytes(8).hex_encode();root.add_child(app);current_scene=app;app.set_application_focused(true)
	app._on_action("new_game",{});app.view.player_name.text="小禾";app.view.dog_name.text="阿豆";app._on_action("create",{})
	check(await wait_world(),"fresh start")
	for pair in [["space.workshop","resident.maker"],["space.shop","resident.grocer"]]:
		for minute in [600,1200]:
			check(await travel("space.village","FarmArrival","north"),"continuous route to village")
			app.gameplay_session.clock.reset(minute)
			app.gameplay_session.acquire_pause(&"arrival_test")
			# This fixture deliberately reproduces a supported runtime row at the
			# exact shared doorway, without changing any authored player anchor.
			for node in app.room.find_children("*","CharacterBody2D",true,false):
				if node.has_method("is_world_active") and node.resident_id==pair[1]:node.set_world_active(false)
			check(app.gameplay_session.update_resident_runtime({"resident_id":pair[1],"space_id":pair[0],"world_position_px":{"x":320.0,"y":320.0},"facing":"north"}),"coincident runtime fixture")
			check(await travel(pair[0],"DoorArrival","north"),"actual staged app entry "+pair[0]+str(minute))
			var arrival=app.room.get_anchor_position("DoorArrival")
			for frame in range(90):await physics_frame
			check(app.room.get_player().position.distance_to(arrival)<0.1,"app idle arrival remains exact")
			var saved=app.save_progress();check(saved.ok,"save after entry")
			var snapshot=app.store.read_save(saved.save_id).envelope.snapshot.duplicate(true)
			for row in snapshot.gameplay.residents.residents:
				if row.resident_id==pair[1]:row.space_id=pair[0];row.world_position_px={"x":320.0,"y":320.0}
			var written=app.store.write_new(snapshot);check(written.ok,"separate coincident old-runtime fixture writes")
			var original=FileAccess.get_file_as_bytes(app.store.directory.path_join(written.save_id+".qfsave"))
			check(original.size()>0,"original save file exists with real bytes")
			app.return_to_title();app._on_action("read_save",{"save_id":written.save_id})
			check(await wait_world(),"real save reload activates")
			for frame in range(60):await physics_frame
			check(app.room.get_player().position.distance_to(arrival)<0.1,"reloaded idle player is not carried")
			check(FileAccess.get_file_as_bytes(app.store.directory.path_join(written.save_id+".qfsave"))==original,"original save bytes unchanged")
			check(await travel("space.village","WorkshopDoorArrival" if pair[0]=="space.workshop" else "ShopDoorArrival","north"),"return transaction after reload")
	check(await travel("space.village","FarmArrival","north"),"source before cancellation")
	var source=app.room
	var before=source.get_player().position
	var target={"kind":"door","interaction_id":"door.qa.cancel","target_space_id":"space.workshop","arrival_anchor_id":"DoorArrival","arrival_facing":"north"}
	app._begin_door_transition(target)
	await physics_frame
	check(app._transition_pending,"second physics wait is still cancellable")
	app._unhandled_key_input(key(KEY_ESCAPE))
	await physics_frame
	check(app.room==source and source.get_player().position==before,"second-wait cancellation preserves source")
	check(not app.locks.has_owner(&"transition") and source.get_player().is_input_enabled,"second-wait cancellation restores input")
	app.gameplay_session.clock.reset(600)
	for node in source.find_children("*","CharacterBody2D",true,false):
		if node.has_method("is_world_active") and node.resident_id=="resident.maker":node.set_world_active(false)
	app.gameplay_session.update_resident_runtime({"resident_id":"resident.maker","space_id":"space.workshop","world_position_px":{"x":320.0,"y":320.0},"facing":"north"})
	app._begin_door_transition(target)
	var candidate=app._transition_candidate
	var original=candidate.get_node("FootSorted/MakerResident")
	for point in [Vector2(336,304),Vector2(304,304),Vector2(320,304)]:
		var blocker=original.duplicate();candidate.get_node("FootSorted").add_child(blocker);blocker.set_world_active(true);blocker.restore_runtime_position(point,&"south");blocker.clear_schedule_target()
	for frame in range(4):await physics_frame
	check(app.room==source and source.get_player().position==before,"no-candidate transition preserves old scene and position")
	check(not app._transition_pending and not app.locks.has_owner(&"transition") and source.get_player().is_input_enabled,"no-candidate transition unlocks source input")
	check(app.last_error.contains("居民"),"no-candidate rejection explains occupied entrance")
	await finish()
