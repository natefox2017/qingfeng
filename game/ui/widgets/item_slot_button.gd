extends Button
## Gameplay quick-slot control. Layout/selection is intended to be final;
## programmatic item pictograms remain replaceable until accepted icon art lands.
const UI_THEME = preload("res://ui/theme/ui_theme.gd")

var slot_index := -1
var item_id := ""
var quantity := 0
var selected := false
var display_name := ""

var _index_label: Label
var _quantity_label: Label

func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(40,42)
	_index_label = Label.new()
	_index_label.position = Vector2(4,1)
	_index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI_THEME.apply_text_role(_index_label,UI_THEME.ROLE_CAPTION)
	add_child(_index_label)
	_quantity_label = Label.new()
	_quantity_label.position = Vector2(24,25)
	_quantity_label.custom_minimum_size = Vector2(12,12)
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI_THEME.apply_text_role(_quantity_label,UI_THEME.ROLE_QUANTITY)
	add_child(_quantity_label)
	_refresh()

func configure(index: int, slot: Variant, metadata: Dictionary, is_selected: bool) -> void:
	slot_index = index
	selected = is_selected
	button_pressed = is_selected
	item_id = ""
	quantity = 0
	display_name = "空"
	if slot != null:
		item_id = String(slot.item_id)
		quantity = int(slot.quantity)
		display_name = String(metadata.get("display_name",item_id))
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	_index_label.text = str(slot_index+1) if slot_index>=0 else ""
	_quantity_label.text = str(quantity) if quantity>1 else ""
	button_pressed = selected
	tooltip_text = "槽位 %d：%s" % [slot_index+1,display_name+(" ×"+str(quantity) if quantity>0 else "")]
	accessibility_name = tooltip_text+("，已选中" if selected else "")
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x*0.5,size.y*0.5+2)
	if selected:
		draw_colored_polygon(PackedVector2Array([
			Vector2(size.x*0.5-4,2),
			Vector2(size.x*0.5+4,2),
			Vector2(size.x*0.5,7)
		]),UI_THEME.COLOR_SELECTION_MARK)
	if item_id.is_empty():
		return
	match item_id:
		"item.hoe":
			draw_line(center+Vector2(-6,8),center+Vector2(5,-7),UI_THEME.COLOR_TOOL_HANDLE,2.0,false)
			draw_rect(Rect2(center+Vector2(2,-9),Vector2(9,4)),UI_THEME.COLOR_TOOL_METAL,true)
		"item.watering_can":
			draw_rect(Rect2(center+Vector2(-8,-2),Vector2(14,10)),UI_THEME.COLOR_TOOL_METAL,true)
			draw_line(center+Vector2(5,-1),center+Vector2(11,-6),UI_THEME.COLOR_TOOL_METAL,2.0,false)
			draw_line(center+Vector2(-7,-3),center+Vector2(-2,-8),UI_THEME.COLOR_TOOL_HANDLE,2.0,false)
			draw_line(center+Vector2(-2,-8),center+Vector2(4,-4),UI_THEME.COLOR_TOOL_HANDLE,2.0,false)
		"item.radish_seed":
			for offset: Vector2 in [Vector2(-5,2),Vector2(0,-3),Vector2(5,3)]:
				draw_circle(center+offset,2.0,UI_THEME.COLOR_SEED)
		"item.radish":
			draw_circle(center+Vector2(0,3),6.0,UI_THEME.COLOR_RADISH)
			draw_line(center+Vector2(-1,-3),center+Vector2(-5,-9),UI_THEME.COLOR_HERB,2.0,false)
			draw_line(center+Vector2(1,-3),center+Vector2(6,-9),UI_THEME.COLOR_HERB,2.0,false)
		"item.wild_herb":
			draw_line(center+Vector2(0,8),center+Vector2(0,-6),UI_THEME.COLOR_HERB,2.0,false)
			draw_line(center+Vector2(0,1),center+Vector2(-7,-4),UI_THEME.COLOR_HERB,2.0,false)
			draw_line(center+Vector2(0,-1),center+Vector2(7,-6),UI_THEME.COLOR_HERB,2.0,false)
		_:
			draw_rect(Rect2(center-Vector2(5,5),Vector2(10,10)),UI_THEME.COLOR_ICON,false,2.0)
