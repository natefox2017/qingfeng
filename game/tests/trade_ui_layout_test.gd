extends SceneTree

const VIEW = preload("res://ui/pages/menu_view.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL trade_ui_layout ",label)

func find_button_with_prefix(root_node: Node, prefix: String) -> Button:
	for child: Node in root_node.get_children():
		if child is Button and String((child as Button).text).begins_with(prefix):
			return child as Button
		var nested := find_button_with_prefix(child,prefix)
		if nested != null:
			return nested
	return null

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var view := VIEW.new()
	root.add_child(view)
	await process_frame

	var slots: Array = []
	slots.resize(12)
	slots[0]={"item_id":"item.radish","quantity":2}
	slots[1]={"item_id":"item.hoe","quantity":1}
	var gameplay := {
		"ok":true,
		"clock":{"day":2,"minute_of_day":600},
		"wallet":{"money":145},
		"inventory":{"slots":slots},
		"shop":{"is_open":true,"open_minute":480,"close_minute":1200},
		"items":{
			"item.radish_seed":{"display_name":"萝卜种子","buy_price":20,"sell_price":0},
			"item.radish":{"display_name":"萝卜","buy_price":0,"sell_price":35},
			"item.hoe":{"display_name":"锄头","buy_price":0,"sell_price":0}
		}
	}
	view.show_page("trade",{"gameplay":gameplay,"error":""})
	await process_frame

	check(view.panel.custom_minimum_size==Vector2(600,292),"trade page fits the logical viewport")
	var buy_section := view.body.find_child("TradeBuySection",true,false) as PanelContainer
	var sell_section := view.body.find_child("TradeSellSection",true,false) as PanelContainer
	check(buy_section!=null and sell_section!=null,"trade page uses distinct buy and sell sections")
	var buy_button := find_button_with_prefix(view.body,"买 1")
	var sell_button := find_button_with_prefix(view.body,"卖 1")
	check(buy_button!=null and not buy_button.disabled and buy_button.text.contains("萝卜种子") and buy_button.text.contains("20币"),"buy section exposes configured purchasable seed")
	check(sell_button!=null and not sell_button.disabled and sell_button.text.contains("萝卜") and sell_button.text.contains("35币"),"sell section exposes held sellable produce")
	var page_text := ""
	for child: Node in view.body.find_children("*","Label",true,false):
		page_text += (child as Label).text+"\n"
	check(page_text.contains("持有 ×2") and page_text.contains("145 币"),"trade page shows live holdings and wallet")
	check(not page_text.contains("持有 ×1\n锄头"),"non-sellable tools do not become sell actions")

	gameplay.shop.is_open=false
	gameplay.clock.minute_of_day=1200
	view.show_page("trade",{"gameplay":gameplay,"error":""})
	await process_frame
	var closed_buy := find_button_with_prefix(view.body,"买 1")
	check(closed_buy!=null and closed_buy.disabled and closed_buy.tooltip_text.contains("已打烊"),"closed shop keeps disabled buy action with textual reason")
	check(view.buttons.has("close_trade") and view.buttons["close_trade"].accessibility_name.contains("Esc"),"trade close action remains explicit and accessible")

	view.queue_free()
	await process_frame
	print("TRADE_UI_LAYOUT_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
