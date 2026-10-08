extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const INVENTORY = preload("res://systems/inventory_domain.gd")
const STORAGE = preload("res://systems/storage_domain.gd")
const TRANSFER = preload("res://systems/storage_transfer.gd")
const JOURNAL = preload("res://app/command_journal.gd")
const SESSION = preload("res://app/gameplay_session.gd")
const CODEC = preload("res://persistence/session_codec.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL storage ",label)

func transfer_command(id: String, inventory_revision: int, storage_revision: int, source_id: String, target_id: String, item_id: String, quantity: int) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"session_id":"session.storage",
		"actor_id":"actor.player",
		"action":"storage.transfer",
		"expected_revision":inventory_revision,
		"payload":{
			"source_container_id":source_id,
			"target_container_id":target_id,
			"item_id":item_id,
			"quantity":quantity,
			"storage_revision":storage_revision
		}
	}

func _initialize() -> void:
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok,"content loads")
	if not loaded.ok:
		finish()
		return
	var content: Dictionary = loaded.data
	var inventory = INVENTORY.new(content)
	var storage = STORAGE.new(content)
	var transfer = TRANSFER.new(inventory,storage)
	var journal = JOURNAL.new()
	check(inventory.is_configured() and storage.is_configured() and transfer.is_configured(),"inventory and home chest configure")
	check(storage.capacity == 24 and storage.slots.size() == 24 and storage.slots.all(func(slot): return slot == null),"home chest starts empty at content-version capacity")

	var deposit := transfer_command("deposit-seed",inventory.revision,storage.revision,inventory.container_id,storage.container_id,"item.radish_seed",2)
	var deposited: Dictionary = journal.execute(deposit,transfer.handle)
	check(deposited.ok and inventory.quantity_of("item.radish_seed")==2 and storage.quantity_of("item.radish_seed")==2,"deposit atomically moves quantity from player to chest")
	var inventory_revision_after: int = inventory.revision
	var storage_revision_after: int = storage.revision
	var replay: Dictionary = journal.execute(deposit,transfer.handle)
	check(replay==deposited and inventory.revision==inventory_revision_after and storage.revision==storage_revision_after,"deposit replay does not move items twice")
	var conflict: Dictionary = journal.execute(transfer_command("deposit-seed",inventory_revision_after,storage_revision_after,inventory.container_id,storage.container_id,"item.radish_seed",1),transfer.handle)
	check(not conflict.ok and conflict.error_code=="COMMAND_ID_CONFLICT" and inventory.quantity_of("item.radish_seed")==2 and storage.quantity_of("item.radish_seed")==2,"same transfer id cannot change request")

	var withdraw := transfer_command("withdraw-seed",inventory.revision,storage.revision,storage.container_id,inventory.container_id,"item.radish_seed",1)
	var withdrawn: Dictionary = journal.execute(withdraw,transfer.handle)
	check(withdrawn.ok and inventory.quantity_of("item.radish_seed")==3 and storage.quantity_of("item.radish_seed")==1,"withdraw atomically moves quantity back to player")
	var before_stale_inventory := inventory.projection()
	var before_stale_storage := storage.projection()
	var stale := journal.execute(transfer_command("stale-storage",inventory.revision,storage.revision-1,storage.container_id,inventory.container_id,"item.radish_seed",1),transfer.handle)
	check(not stale.ok and stale.error_code=="STORAGE_STALE_REVISION" and inventory.projection()==before_stale_inventory and storage.projection()==before_stale_storage,"stale cross-container revision changes neither side")

	check(inventory.add("item.radish_seed",96).ok and inventory.add("item.radish_seed",99*9).ok,"player inventory can be filled for target-full regression")
	var full_inventory_before := inventory.projection()
	var chest_before_full_withdraw := storage.projection()
	var full_withdraw := journal.execute(transfer_command("full-withdraw",inventory.revision,storage.revision,storage.container_id,inventory.container_id,"item.radish_seed",1),transfer.handle)
	check(not full_withdraw.ok and full_withdraw.error_code=="INVENTORY_FULL" and inventory.projection()==full_inventory_before and storage.projection()==chest_before_full_withdraw,"full player inventory rejects withdrawal without losing chest item")

	var inventory2 = INVENTORY.new(content)
	var storage2 = STORAGE.new(content)
	var transfer2 = TRANSFER.new(inventory2,storage2)
	var full_slots: Array = storage2.slots.duplicate(true)
	for index in range(full_slots.size()):
		full_slots[index] = {"item_id":"item.radish_seed","quantity":99}
	check(storage2.commit_slots(full_slots,storage2.revision),"test fills chest through validated commit")
	var player_before_full_deposit := inventory2.projection()
	var storage_before_full_deposit := storage2.projection()
	var full_deposit := transfer2.handle(transfer_command("chest-full",inventory2.revision,storage2.revision,inventory2.container_id,storage2.container_id,"item.hoe",1))
	check(not full_deposit.ok and full_deposit.error_code=="STORAGE_FULL" and inventory2.projection()==player_before_full_deposit and storage2.projection()==storage_before_full_deposit,"full chest rejects deposit without losing player item")

	var plots := [{"plot_id":"plot.storage.001","space_id":"space.farm","cell_position":{"x":17,"y":7}}]
	var session = SESSION.new(plots,content)
	check(session.is_configured() and session.storage.capacity==24,"gameplay session owns home chest")
	var session_transfer: Dictionary = session.execute(transfer_command("session-deposit",session.inventory.revision,session.storage.revision,session.inventory.container_id,session.storage.container_id,"item.radish_seed",1))
	check(session_transfer.ok and session.storage.quantity_of("item.radish_seed")==1,"session routes storage transfer through shared command journal")
	var snapshot: Dictionary = session.snapshot()
	check(snapshot.storage.container_id=="container.home_chest" and snapshot.storage.slots.size()==24,"complete gameplay snapshot persists home chest")
	var restored = SESSION.new(plots,content)
	check(restored.restore(snapshot) and restored.storage.quantity_of("item.radish_seed")==1,"gameplay restore preserves home chest")

	var legacy_v3: Dictionary = snapshot.duplicate(true)
	legacy_v3.erase("storage")
	var migrated = SESSION.new(plots,content)
	check(migrated.restore(legacy_v3) and migrated.storage.quantity_of("item.radish_seed")==0,"legacy gameplay snapshot migrates to an empty new chest")

	var identity: Dictionary = CODEC.new_snapshot("小禾","阿豆")
	identity.space_id="space.farm"
	identity.world_position_px={"x":144.0,"y":176.0}
	var full_save: Dictionary = CODEC.compose_gameplay_snapshot(identity,snapshot)
	var decoded_v4: Dictionary = CODEC.decode(CODEC.encode(full_save,Crypto.new().generate_random_bytes(16).hex_encode()))
	check(decoded_v4.ok and int(decoded_v4.envelope.schema_version)==4,"persistent chest upgrades new gameplay save to schema four")
	var legacy_save: Dictionary = CODEC.compose_gameplay_snapshot(identity,legacy_v3)
	var decoded_v3: Dictionary = CODEC.decode(CODEC.encode(legacy_save,Crypto.new().generate_random_bytes(16).hex_encode()))
	check(decoded_v3.ok and int(decoded_v3.envelope.schema_version)==3,"legacy schema three remains explicitly readable")

	finish()

func finish() -> void:
	print("STORAGE_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
