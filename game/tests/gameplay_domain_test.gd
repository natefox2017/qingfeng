extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const JOURNAL = preload("res://app/command_journal.gd")
const INVENTORY = preload("res://systems/inventory_domain.gd")
const WALLET = preload("res://systems/wallet_domain.gd")

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
	var select_revision := inventory.revision
	var first := journal.execute(command("select-1",select_revision,2), inventory.handle_select)
	check(first.ok and first.has_changes and inventory.selected_slot_index == 2, "selection changes through command handler")
	var revision_after_select := inventory.revision
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

	finish()

func finish() -> void:
	print("GAMEPLAY_PASS checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
