extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const CLOCK = preload("res://app/game_clock.gd")
const INVENTORY = preload("res://systems/inventory_domain.gd")
const WALLET = preload("res://systems/wallet_domain.gd")
const ECONOMY = preload("res://systems/economy_coordinator.gd")
const JOURNAL = preload("res://app/command_journal.gd")
const SESSION = preload("res://app/gameplay_session.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL economy ",label)

func economy_command(id: String, action: String, inventory_revision: int, wallet_revision: int, item_id: String, quantity: int) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"session_id":"session.economy",
		"actor_id":"actor.player",
		"action":action,
		"expected_revision":inventory_revision,
		"payload":{
			"item_id":item_id,
			"quantity":quantity,
			"wallet_revision":wallet_revision
		}
	}

func _initialize() -> void:
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok,"content loads for economy")
	if not loaded.ok:
		finish()
		return
	var content: Dictionary = loaded.data

	var inventory = INVENTORY.new(content)
	var wallet = WALLET.new(content)
	var clock = CLOCK.new(content)
	var economy = ECONOMY.new(inventory,wallet,clock,content)
	var journal = JOURNAL.new()
	check(economy.is_configured() and not economy.is_shop_open(),"shop coordinator configures and starts closed at 06:00")

	var closed_before_inventory := inventory.projection()
	var closed_before_wallet := wallet.projection()
	var closed_buy := journal.execute(economy_command("closed-buy","economy.buy",inventory.revision,wallet.revision,"item.radish_seed",1),economy.handle)
	check(not closed_buy.ok and closed_buy.error_code=="SHOP_CLOSED" and closed_buy.is_retryable and inventory.projection()==closed_before_inventory and wallet.projection()==closed_before_wallet,"closed shop rejects buy without mutation")

	check(clock.advance(120).ok and clock.minute_of_day()==480 and economy.is_shop_open(),"08:00 opens shop from content-version hours")
	var seeds_before: int = inventory.quantity_of("item.radish_seed")
	var money_before: int = wallet.money
	var buy_command := economy_command("buy-seeds","economy.buy",inventory.revision,wallet.revision,"item.radish_seed",2)
	var bought: Dictionary = journal.execute(buy_command,economy.handle)
	check(bought.ok and inventory.quantity_of("item.radish_seed")==seeds_before+2 and wallet.money==money_before-40,"buy atomically exchanges content-price money for items")
	var inventory_after_buy: Dictionary = inventory.projection()
	var wallet_after_buy: Dictionary = wallet.projection()
	var buy_replay: Dictionary = journal.execute(buy_command,economy.handle)
	check(buy_replay==bought and inventory.projection()==inventory_after_buy and wallet.projection()==wallet_after_buy,"buy replay cannot double charge or duplicate items")
	var buy_conflict := journal.execute(economy_command("buy-seeds","economy.buy",inventory.revision,wallet.revision,"item.radish_seed",1),economy.handle)
	check(not buy_conflict.ok and buy_conflict.error_code=="COMMAND_ID_CONFLICT","same buy id with different request conflicts")

	var stale_wallet_before_inventory := inventory.projection()
	var stale_wallet_before_wallet := wallet.projection()
	var stale_wallet := journal.execute(economy_command("stale-wallet","economy.buy",inventory.revision,wallet.revision-1,"item.radish_seed",1),economy.handle)
	check(not stale_wallet.ok and stale_wallet.error_code=="WALLET_STALE_REVISION" and stale_wallet.is_retryable and inventory.projection()==stale_wallet_before_inventory and wallet.projection()==stale_wallet_before_wallet,"stale wallet revision changes neither domain")
	var stale_inventory := journal.execute(economy_command("stale-inventory","economy.buy",inventory.revision-1,wallet.revision,"item.radish_seed",1),economy.handle)
	check(not stale_inventory.ok and stale_inventory.error_code=="STALE_REVISION" and stale_inventory.is_retryable,"stale inventory revision is retryable")

	var unbuyable_before := inventory.projection()
	var unbuyable_wallet_before := wallet.projection()
	var unbuyable := journal.execute(economy_command("buy-hoe","economy.buy",inventory.revision,wallet.revision,"item.hoe",1),economy.handle)
	check(not unbuyable.ok and unbuyable.error_code=="ECONOMY_ITEM_NOT_BUYABLE" and inventory.projection()==unbuyable_before and wallet.projection()==unbuyable_wallet_before,"zero buy-price tool is not silently purchasable")

	var poor_inventory = INVENTORY.new(content)
	var poor_wallet = WALLET.new(content)
	var poor_clock = CLOCK.new(content)
	poor_clock.advance(120)
	var poor_economy = ECONOMY.new(poor_inventory,poor_wallet,poor_clock,content)
	check(poor_wallet.debit(200).ok and poor_wallet.money==0,"test wallet reaches zero through domain API")
	var poor_before_inventory := poor_inventory.projection()
	var poor_before_wallet := poor_wallet.projection()
	var poor_buy := poor_economy.handle(economy_command("poor-buy","economy.buy",poor_inventory.revision,poor_wallet.revision,"item.radish_seed",1))
	check(not poor_buy.ok and poor_buy.error_code=="WALLET_INSUFFICIENT_FUNDS" and poor_inventory.projection()==poor_before_inventory and poor_wallet.projection()==poor_before_wallet,"insufficient funds cannot add item or go negative")

	var full_inventory = INVENTORY.new(content)
	var full_wallet = WALLET.new(content)
	var full_clock = CLOCK.new(content)
	full_clock.advance(120)
	var full_economy = ECONOMY.new(full_inventory,full_wallet,full_clock,content)
	check(full_inventory.add("item.radish_seed",95).ok and full_inventory.add("item.radish_seed",99*9).ok,"test fills player inventory through domain API")
	var full_before_inventory := full_inventory.projection()
	var full_before_wallet := full_wallet.projection()
	var full_buy := full_economy.handle(economy_command("full-buy","economy.buy",full_inventory.revision,full_wallet.revision,"item.radish_seed",1))
	check(not full_buy.ok and full_buy.error_code=="INVENTORY_FULL" and full_inventory.projection()==full_before_inventory and full_wallet.projection()==full_before_wallet,"full inventory rejects buy without charging wallet")

	var sell_inventory = INVENTORY.new(content)
	var sell_wallet = WALLET.new(content)
	var sell_clock = CLOCK.new(content)
	sell_clock.advance(120)
	var sell_economy = ECONOMY.new(sell_inventory,sell_wallet,sell_clock,content)
	var sell_journal = JOURNAL.new()
	check(sell_inventory.add("item.radish",2).ok,"sell fixture adds harvested produce through inventory API")
	var sell_money_before: int = sell_wallet.money
	var sell_command := economy_command("sell-radish","economy.sell",sell_inventory.revision,sell_wallet.revision,"item.radish",1)
	var sold: Dictionary = sell_journal.execute(sell_command,sell_economy.handle)
	check(sold.ok and sell_inventory.quantity_of("item.radish")==1 and sell_wallet.money==sell_money_before+35,"sell atomically removes produce and credits content-price money")
	var sold_inventory := sell_inventory.projection()
	var sold_wallet := sell_wallet.projection()
	check(sell_journal.execute(sell_command,sell_economy.handle)==sold and sell_inventory.projection()==sold_inventory and sell_wallet.projection()==sold_wallet,"sell replay cannot pay twice")
	var unsellable := sell_journal.execute(economy_command("sell-seed","economy.sell",sell_inventory.revision,sell_wallet.revision,"item.radish_seed",1),sell_economy.handle)
	check(not unsellable.ok and unsellable.error_code=="ECONOMY_ITEM_NOT_SELLABLE","zero sell-price item is not sellable")
	var missing_before_inventory := sell_inventory.projection()
	var missing_before_wallet := sell_wallet.projection()
	var missing := sell_journal.execute(economy_command("sell-missing","economy.sell",sell_inventory.revision,sell_wallet.revision,"item.radish",9),sell_economy.handle)
	check(not missing.ok and missing.error_code=="INVENTORY_INSUFFICIENT_ITEM" and sell_inventory.projection()==missing_before_inventory and sell_wallet.projection()==missing_before_wallet,"selling missing quantity changes neither inventory nor wallet")

	check(sell_clock.acquire_pause(&"trade"),"trade UI may pause the single clock")
	var paused_buy := sell_journal.execute(economy_command("paused-trade","economy.buy",sell_inventory.revision,sell_wallet.revision,"item.radish_seed",1),sell_economy.handle)
	check(paused_buy.ok and sell_clock.is_paused(),"paused trade still validates against frozen shop time and commits transaction")
	sell_clock.release_pause(&"trade")
	check(sell_clock.advance(720).ok and sell_clock.minute_of_day()==1200 and not sell_economy.is_shop_open(),"20:00 closes shop at exclusive close minute")
	var closed_sell := sell_journal.execute(economy_command("closed-sell","economy.sell",sell_inventory.revision,sell_wallet.revision,"item.radish",1),sell_economy.handle)
	check(not closed_sell.ok and closed_sell.error_code=="SHOP_CLOSED","closed shop rejects sell")

	var session = SESSION.new([
		{"plot_id":"plot.economy.001","space_id":"space.farm","cell_position":{"x":17,"y":7}}
	],content)
	check(session.is_configured() and not session.projection().shop.is_open,"gameplay session exposes closed shop projection at 06:00")
	check(session.advance(120).ok and session.projection().shop.is_open,"gameplay session shop projection follows single clock")
	var session_seed_before: int = session.inventory.quantity_of("item.radish_seed")
	var session_buy := session.execute(economy_command("session-buy","economy.buy",session.inventory.revision,session.wallet.revision,"item.radish_seed",1))
	check(session_buy.ok and session.inventory.quantity_of("item.radish_seed")==session_seed_before+1 and session.wallet.money==180,"gameplay session routes economy command through shared journal")

	finish()

func finish() -> void:
	print("ECONOMY_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
