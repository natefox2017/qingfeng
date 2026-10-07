extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const JOURNAL = preload("res://app/command_journal.gd")
const INVENTORY = preload("res://systems/inventory_domain.gd")
const WALLET = preload("res://systems/wallet_domain.gd")
const FARM = preload("res://systems/farm_domain.gd")
const FARMING = preload("res://systems/farming_coordinator.gd")
const SESSION = preload("res://app/gameplay_session.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL gameplay ", label)

func command(id: String, expected_revision: int, slot_index: int) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"session_id":"session.gameplay",
		"actor_id":"actor.player",
		"action":"inventory.select",
		"expected_revision":expected_revision,
		"payload":{"slot_index":slot_index}
	}

func farm_command(id: String, action: String, expected_revision: int, payload: Dictionary) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"session_id":"session.gameplay",
		"actor_id":"actor.player",
		"action":action,
		"expected_revision":expected_revision,
		"payload":payload
	}

func _initialize() -> void:
	var content_result: Dictionary = CONTENT.load_current()
	check(content_result.ok, "content is available for gameplay domains")
	if not content_result.ok:
		finish()
		return
	var content: Dictionary = content_result.data
	var inventory = INVENTORY.new(content)
	var wallet = WALLET.new(content)
	check(inventory.is_configured() and wallet.is_configured(), "inventory and wallet configure from content")
	check(inventory.capacity == 12 and inventory.slots.size() == 12, "inventory uses configured fixed capacity")
	check(inventory.quantity_of("item.hoe") == 1 and inventory.quantity_of("item.watering_can") == 1 and inventory.quantity_of("item.radish_seed") == 4, "new-game items initialize once in inventory")
	check(wallet.money == 200, "wallet initializes from content")

	var projection := inventory.projection()
	projection.slots[0] = null
	check(inventory.slots[0] != null, "inventory projection cannot mutate authoritative slots")

	var add_stack := inventory.add("item.radish_seed",95)
	check(add_stack.ok and inventory.quantity_of("item.radish_seed") == 99, "add fills existing stack to item limit")
	var fill_remaining := inventory.add("item.radish_seed",99*9)
	check(fill_remaining.ok and inventory.slots.all(func(slot): return slot != null), "add fills remaining capacity with bounded stacks")
	var before_full := inventory.projection()
	var full := inventory.add("item.radish_seed",1)
	check(not full.ok and full.error_code == "INVENTORY_FULL" and inventory.projection() == before_full, "full inventory rejects whole add without mutation")
	var remove := inventory.remove("item.radish_seed",100)
	check(remove.ok and inventory.quantity_of("item.radish_seed") == 890, "remove spans stacks deterministically")
	var before_missing := inventory.projection()
	var missing := inventory.remove("item.radish",1)
	check(not missing.ok and missing.error_code == "INVENTORY_INSUFFICIENT_ITEM" and inventory.projection() == before_missing, "missing item removal is atomic")

	var journal = JOURNAL.new()
	var select_revision: int = inventory.revision
	var first := journal.execute(command("select-1",select_revision,2), inventory.handle_select)
	check(first.ok and first.has_changes and inventory.selected_slot_index == 2, "selection changes through command handler")
	var revision_after_select: int = inventory.revision
	var replay := journal.execute(command("select-1",select_revision,2), inventory.handle_select)
	check(replay == first and inventory.revision == revision_after_select, "selection command replay is idempotent")
	var conflict := journal.execute(command("select-1",select_revision,3), inventory.handle_select)
	check(not conflict.ok and conflict.error_code == "COMMAND_ID_CONFLICT" and inventory.selected_slot_index == 2, "same id cannot select a different slot")
	var stale := journal.execute(command("select-stale",select_revision,1), inventory.handle_select)
	check(not stale.ok and stale.error_code == "STALE_REVISION" and stale.is_retryable, "stale selection revision is retryable and unchanged")

	var debit := wallet.debit(40)
	check(debit.ok and wallet.money == 160, "wallet debit uses integer money")
	var before_insufficient := wallet.projection()
	var insufficient := wallet.debit(1000)
	check(not insufficient.ok and insufficient.error_code == "WALLET_INSUFFICIENT_FUNDS" and wallet.projection() == before_insufficient, "insufficient funds never go negative")
	var credit := wallet.credit(35)
	check(credit.ok and wallet.money == 195, "wallet credit commits once")
	var wallet_projection := wallet.projection()
	wallet_projection.money = 9999
	check(wallet.money == 195, "wallet projection cannot mutate authoritative money")

	var farm_inventory = INVENTORY.new(content)
	var farm = FARM.new([
		{"plot_id":"plot.farm.001","space_id":"space.farm","cell_position":{"x":6,"y":8}}
	],content)
	var farming = FARMING.new(farm_inventory,farm,content)
	var farm_journal = JOURNAL.new()
	check(farm.is_configured() and farming.is_configured(), "farm domain configures from layout plus content")
	var farm_projection := farm.projection()
	farm_projection.plots[0].state = "mature"
	check(farm.get_plot("plot.farm.001").state == "untilled", "farm projection cannot mutate authoritative plot")

	var till := farm_journal.execute(farm_command("farm-till","farm.till",farm.revision,{"plot_id":"plot.farm.001"}),farming.handle)
	check(till.ok and farm.get_plot("plot.farm.001").state == "tilled", "hoe tills an untilled plot")
	var plant := farm_journal.execute(farm_command("farm-plant","farm.plant",farm.revision,{
		"plot_id":"plot.farm.001","crop_id":"crop.radish","inventory_revision":farm_inventory.revision
	}),farming.handle)
	check(plant.ok and farm.get_plot("plot.farm.001").state == "growing" and farm_inventory.quantity_of("item.radish_seed") == 3, "plant atomically consumes one seed and creates crop")
	var water := farm_journal.execute(farm_command("farm-water-1","farm.water",farm.revision,{"plot_id":"plot.farm.001"}),farming.handle)
	check(water.ok and water.has_changes and farm.get_plot("plot.farm.001").is_watered, "watering marks growing plot")
	var repeat_water_revision: int = farm.revision
	var repeat_water := farm_journal.execute(farm_command("farm-water-repeat","farm.water",repeat_water_revision,{"plot_id":"plot.farm.001"}),farming.handle)
	check(repeat_water.ok and not repeat_water.has_changes and farm.revision == repeat_water_revision, "watering already wet plot is a no-op")

	var day2 := farm.settle_day(2)
	check(day2.ok and farm.get_plot("plot.farm.001").growth_days == 1 and not farm.get_plot("plot.farm.001").is_watered, "day settlement advances only watered crop and clears water")
	var after_day2_revision: int = farm.revision
	var duplicate_day2 := farm.settle_day(2)
	check(duplicate_day2.ok and not duplicate_day2.has_changes and farm.revision == after_day2_revision, "same day settlement cannot advance twice")
	var water2 := farm_journal.execute(farm_command("farm-water-2","farm.water",farm.revision,{"plot_id":"plot.farm.001"}),farming.handle)
	check(water2.ok, "second-day watering succeeds")
	var day3 := farm.settle_day(3)
	check(day3.ok and farm.get_plot("plot.farm.001").state == "mature" and farm.get_plot("plot.farm.001").growth_days == 2, "two watered settlements mature first crop on day three")

	check(farm_inventory.add("item.radish_seed",96).ok and farm_inventory.add("item.radish_seed",99*9).ok, "test inventory can be filled without debug mutation")
	var mature_before_full := farm.get_plot("plot.farm.001")
	var inventory_before_full_harvest := farm_inventory.projection()
	var harvest_full := farm_journal.execute(farm_command("farm-harvest-full","farm.harvest",farm.revision,{
		"plot_id":"plot.farm.001","inventory_revision":farm_inventory.revision
	}),farming.handle)
	check(not harvest_full.ok and harvest_full.error_code == "INVENTORY_FULL" and farm.get_plot("plot.farm.001") == mature_before_full and farm_inventory.projection() == inventory_before_full_harvest, "full inventory rejects harvest without deleting crop")
	check(farm_inventory.remove("item.radish_seed",99).ok, "freeing one stack creates harvest capacity")
	var harvest := farm_journal.execute(farm_command("farm-harvest","farm.harvest",farm.revision,{
		"plot_id":"plot.farm.001","inventory_revision":farm_inventory.revision
	}),farming.handle)
	check(harvest.ok and farm_inventory.quantity_of("item.radish") == 1 and farm.get_plot("plot.farm.001").state == "tilled", "harvest adds produce and preserves tilled soil")

	var stale_inventory_before := farm_inventory.projection()
	var stale_plant := farm_journal.execute(farm_command("farm-plant-stale","farm.plant",farm.revision,{
		"plot_id":"plot.farm.001","crop_id":"crop.radish","inventory_revision":farm_inventory.revision-1
	}),farming.handle)
	check(not stale_plant.ok and stale_plant.error_code == "INVENTORY_STALE_REVISION" and farm_inventory.projection() == stale_inventory_before and farm.get_plot("plot.farm.001").state == "tilled", "cross-domain stale revision changes nothing")
	var plant2 := farm_journal.execute(farm_command("farm-plant-2","farm.plant",farm.revision,{
		"plot_id":"plot.farm.001","crop_id":"crop.radish","inventory_revision":farm_inventory.revision
	}),farming.handle)
	check(plant2.ok, "replant succeeds after harvest")
	var day4 := farm.settle_day(4)
	check(day4.ok and farm.get_plot("plot.farm.001").state == "growing" and farm.get_plot("plot.farm.001").growth_days == 0, "missing water pauses growth without killing crop")

	var session = SESSION.new([
		{"plot_id":"plot.farm.session","space_id":"space.farm","cell_position":{"x":2,"y":3}}
	],content)
	check(session.is_configured(), "gameplay session composes all authoritative domains")
	var session_projection: Dictionary = session.projection()
	session_projection.inventory.slots[0] = null
	check(session.inventory.slots[0] != null, "session projection is read-only by copy")
	var session_select: Dictionary = session.execute(command("session-select",session.inventory.revision,2))
	check(session_select.ok and session.inventory.selected_slot_index == 2, "session routes inventory commands through one journal")
	var session_till: Dictionary = session.execute(farm_command("session-till","farm.till",session.farm.revision,{"plot_id":"plot.farm.session"}))
	check(session_till.ok, "session routes farm till command")
	var session_plant: Dictionary = session.execute(farm_command("session-plant","farm.plant",session.farm.revision,{
		"plot_id":"plot.farm.session","crop_id":"crop.radish","inventory_revision":session.inventory.revision
	}))
	check(session_plant.ok and session.inventory.quantity_of("item.radish_seed") == 3, "session plant atomically uses inventory")
	var session_water1: Dictionary = session.execute(farm_command("session-water-1","farm.water",session.farm.revision,{"plot_id":"plot.farm.session"}))
	check(session_water1.ok, "session water command succeeds")
	var rest2: Dictionary = session.rest_to_next_day()
	check(rest2.ok and session.clock.current_day() == 2 and session.farm.get_plot("plot.farm.session").growth_days == 1, "session rest advances clock and settles farm together")
	check(session.acquire_pause(&"inventory"), "session exposes clock pause ownership")
	var paused_rest: Dictionary = session.rest_to_next_day()
	check(not paused_rest.ok and paused_rest.error_code == "CLOCK_PAUSED" and session.clock.current_day() == 2, "paused session cannot rest")
	check(session.release_pause(&"inventory"), "session releases only requested pause owner")
	var session_water2: Dictionary = session.execute(farm_command("session-water-2","farm.water",session.farm.revision,{"plot_id":"plot.farm.session"}))
	check(session_water2.ok, "session second-day water succeeds")
	var rest3: Dictionary = session.rest_to_next_day()
	check(rest3.ok and session.clock.current_day() == 3 and session.farm.get_plot("plot.farm.session").state == "mature", "session reaches third-day maturity without separate clocks")
	var replay_till: Dictionary = session.execute(farm_command("session-till","farm.till",0,{"plot_id":"plot.farm.session"}))
	check(replay_till == session_till and session.farm.get_plot("plot.farm.session").state == "mature", "session command journal replays original result without reapplying old action")

	var saved_session: Dictionary = session.snapshot()
	var restored = SESSION.new([
		{"plot_id":"plot.farm.session","space_id":"space.farm","cell_position":{"x":2,"y":3}}
	],content)
	check(restored.restore(saved_session) and restored.snapshot() == saved_session, "complete gameplay snapshot restores all domains exactly")
	var before_bad_restore: Dictionary = restored.snapshot()
	var bad_inventory_snapshot: Dictionary = saved_session.duplicate(true)
	bad_inventory_snapshot.inventory.capacity = 99
	check(not restored.restore(bad_inventory_snapshot) and restored.snapshot() == before_bad_restore, "invalid inventory snapshot cannot partially mutate live session")
	var bad_layout_snapshot: Dictionary = saved_session.duplicate(true)
	bad_layout_snapshot.farm.plots[0].cell_position.x = 999
	check(not restored.restore(bad_layout_snapshot) and restored.snapshot() == before_bad_restore, "farm restore cannot move layout-owned plot coordinates")
	var bad_clock_snapshot: Dictionary = saved_session.duplicate(true)
	bad_clock_snapshot.clock.game_minute = -1
	check(not restored.restore(bad_clock_snapshot) and restored.snapshot() == before_bad_restore, "invalid clock snapshot leaves all domains unchanged")

	finish()

func finish() -> void:
	print("GAMEPLAY_PASS checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
