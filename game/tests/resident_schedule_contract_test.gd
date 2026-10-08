extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const SCHEDULE = preload("res://systems/resident_schedule.gd")
const VILLAGE = preload("res://world/village_first_screen.tscn")
const SHOP = preload("res://world/shop_interior.tscn")
const WORKSHOP = preload("res://world/workshop_interior.tscn")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL resident_schedule ",label)

func collect_anchors(scene: PackedScene) -> Array:
	var instance := scene.instantiate()
	var result: Array = []
	if instance != null and instance.has_method("get_resident_anchor_definitions"):
		result = instance.get_resident_anchor_definitions()
	if instance != null:
		instance.free()
	return result

func row(projection: Dictionary, resident_id: String) -> Dictionary:
	for value: Variant in projection.residents:
		if value.get("resident_id","") == resident_id:
			return value
	return {}

func _initialize() -> void:
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok,"content loads with resident schedule table")
	if not loaded.ok:
		finish()
		return
	var content: Dictionary = loaded.data
	check(content.residents.definitions.size()==3,"first playable registers exactly three stable residents")
	check(content.residents.daily_greeting_limit==1 and content.residents.daily_gift_limit==1,"daily social limits live in content version")

	var anchors: Array = []
	anchors.append_array(collect_anchors(VILLAGE))
	anchors.append_array(collect_anchors(SHOP))
	anchors.append_array(collect_anchors(WORKSHOP))
	check(anchors.size()==12,"village shop and workshop expose all resident home work social rain anchors")
	var ids: Dictionary = {}
	for definition: Dictionary in anchors:
		check(not ids.has(definition.anchor_id),"resident anchor id is globally unique: "+definition.anchor_id)
		ids[definition.anchor_id]=definition.space_id

	var schedule = SCHEDULE.new(anchors,content)
	check(schedule.is_configured() and schedule.has_world_anchors() and schedule.resident_count()==3,"schedule resolver validates every content anchor against WORLD")

	var morning: Dictionary = schedule.projection(360,false)
	check(row(morning,"resident.grocer").activity_id=="home" and row(morning,"resident.maker").activity_id=="home" and row(morning,"resident.neighbor").activity_id=="home","06:00 all residents resolve to real home anchors")

	var eight: Dictionary = schedule.projection(480,false)
	check(row(eight,"resident.grocer").activity_id=="work" and row(eight,"resident.grocer").space_id=="space.shop","08:00 grocer schedule resolves to shop work anchor")
	check(row(eight,"resident.neighbor").activity_id=="work" and row(eight,"resident.neighbor").space_id=="space.village","08:00 neighbor work remains on village anchor")
	check(row(eight,"resident.maker").activity_id=="home","maker schedule remains home until its own 09:00 work start")

	var ten: Dictionary = schedule.projection(600,false)
	check(row(ten,"resident.maker").activity_id=="work" and row(ten,"resident.maker").space_id=="space.workshop","10:00 maker schedule resolves to workshop service space")

	var social: Dictionary = schedule.projection(1020,false)
	check(row(social,"resident.grocer").activity_id=="social" and row(social,"resident.maker").activity_id=="social" and row(social,"resident.neighbor").activity_id=="social","17:00 residents resolve to public social anchors")
	check(row(social,"resident.grocer").space_id=="space.village" and row(social,"resident.maker").space_id=="space.village","social schedule returns workers to village rather than duplicating them in interiors")

	var night: Dictionary = schedule.projection(1200,false)
	check(row(night,"resident.grocer").activity_id=="home" and row(night,"resident.maker").activity_id=="home" and row(night,"resident.neighbor").activity_id=="home","20:00 schedule resolves all residents home")
	var after_midnight: Dictionary = schedule.projection(60,false)
	check(row(after_midnight,"resident.grocer").activity_id=="home","pre-06:00 wrap uses last home entry instead of no target")

	var rain: Dictionary = schedule.projection(600,true)
	check(row(rain,"resident.grocer").activity_id=="rain" and row(rain,"resident.grocer").anchor_id=="anchor.resident.grocer.rain" and row(rain,"resident.grocer").space_id=="space.shop","rain schedule uses dedicated grocer indoor anchor")
	check(row(rain,"resident.maker").activity_id=="rain" and row(rain,"resident.maker").space_id=="space.workshop","rain schedule uses dedicated maker indoor anchor")
	check(row(rain,"resident.neighbor").activity_id=="rain" and row(rain,"resident.neighbor").space_id=="space.village","rain schedule uses dedicated neighbor shelter anchor")

	check(ids["anchor.resident.grocer.work"]=="space.shop" and ids["anchor.resident.maker.work"]=="space.workshop","service workers reference real already-playable interiors")
	check(ids["anchor.resident.grocer.work"] != "CounterInteract","resident work anchor is not the player service interaction id")

	var missing: Array = anchors.duplicate(true)
	missing.pop_back()
	var invalid = SCHEDULE.new(missing,content)
	check(not invalid.is_configured() and invalid.configuration_error=="RESIDENT_ANCHOR_MISSING","missing WORLD anchor blocks schedule configuration instead of inventing a destination")

	var unknown: Dictionary = schedule.resolve("resident.missing",480,false)
	check(not unknown.ok and unknown.error_code=="RESIDENT_UNKNOWN","unknown resident id is rejected")

	finish()

func finish() -> void:
	print("RESIDENT_SCHEDULE_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
