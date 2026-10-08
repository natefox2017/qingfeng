extends RefCounted
## Shared Qingfeng UI theme. Layout/colors are the intended shipped visual
## language; bundled CJK font and accepted icon art replace current fallbacks later.

const ROLE_BODY := &"body"
const ROLE_CAPTION := &"caption"
const ROLE_HEADING := &"heading"
const ROLE_QUANTITY := &"quantity"
const ROLE_TOOLTIP := &"tooltip"
const ROLE_ERROR := &"error"

const FONT_BODY := 12
const FONT_CAPTION := 9
const FONT_HEADING := 22
const FONT_QUANTITY := 10
const FONT_TOOLTIP := 10
const FONT_ERROR := 11

const COLOR_INK := Color("3b2f24")
const COLOR_MUTED := Color("786a56")
const COLOR_ERROR := Color("a04e3d")
const COLOR_ICON := Color("4b3a2b")
const COLOR_ICON_DISABLED := Color("9a907d")
const COLOR_BACKDROP := Color("d9c89e")
const COLOR_SURFACE := Color("f3e5bd")
const COLOR_SURFACE_ALT := Color("e2ca96")
const COLOR_BUTTON := Color("ead8aa")
const COLOR_BUTTON_HOVER := Color("f3e4bd")
const COLOR_BUTTON_ACTIVE := Color("d9bd7e")
const COLOR_BUTTON_DISABLED := Color("cfc3a6")
const COLOR_BORDER := Color("6b4b2e")
const COLOR_FOCUS := Color("82945b")
const COLOR_HUD_PANEL := Color("3b3025")
const COLOR_HUD_BORDER := Color("7a5a38")
const COLOR_HUD_TEXT := Color("fff1ca")
const COLOR_SELECTION_MARK := Color("f0c65a")
const COLOR_TOOL_HANDLE := Color("76502f")
const COLOR_TOOL_METAL := Color("9aa5a0")
const COLOR_SEED := Color("8b6134")
const COLOR_RADISH := Color("c86a58")
const COLOR_HERB := Color("668554")

const PAGE_MINIMUM_SIZE := Vector2(500, 286)
const PAGE_MARGIN := 18.0
const PAGE_RADIUS := 2
const CONTROL_RADIUS := 1

static func _control_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match state:
		"hover":
			style.bg_color = COLOR_BUTTON_HOVER
		"pressed":
			style.bg_color = COLOR_BUTTON_ACTIVE
		"disabled":
			style.bg_color = COLOR_BUTTON_DISABLED
		_:
			style.bg_color = COLOR_BUTTON
	style.border_color = COLOR_FOCUS if state=="focus" else COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(CONTROL_RADIUS)
	style.set_content_margin_all(4)
	return style

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(PAGE_RADIUS)
	style.set_content_margin_all(PAGE_MARGIN)
	style.shadow_color = Color(0.15,0.10,0.06,0.28)
	style.shadow_size = 3
	style.shadow_offset = Vector2(2,2)
	return style

static func hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_HUD_PANEL
	style.border_color = COLOR_HUD_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(1)
	style.set_content_margin_all(5)
	style.shadow_color = Color(0,0,0,0.32)
	style.shadow_size = 2
	style.shadow_offset = Vector2(1,2)
	return style

static func quickbar_panel_style() -> StyleBoxFlat:
	var style := hud_panel_style()
	style.set_content_margin_all(4)
	return style

static func slot_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE_ALT if state!="pressed" else COLOR_BUTTON_ACTIVE
	style.border_color = COLOR_SELECTION_MARK if state=="pressed" else (COLOR_FOCUS if state=="focus" else COLOR_BORDER)
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(2)
	return style

static func build() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC","Source Han Sans SC","Microsoft YaHei","PingFang SC","sans-serif"])
	theme.default_font = font
	theme.default_font_size = FONT_BODY
	for kind: String in ["Label","Button","CheckBox","LineEdit"]:
		theme.set_color("font_color",kind,COLOR_INK)
		theme.set_color("font_focus_color",kind,COLOR_INK)
		theme.set_color("font_hover_color",kind,COLOR_INK)
		theme.set_color("font_pressed_color",kind,COLOR_INK)
		theme.set_color("font_disabled_color",kind,COLOR_MUTED)
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		var style := _control_style(state)
		theme.set_stylebox(state,"Button",style)
		if state in ["normal","focus"]:
			theme.set_stylebox(state,"LineEdit",style.duplicate())
	return theme

static func apply_quick_slot_style(button: Button) -> void:
	for state: String in ["normal","hover","disabled"]:
		button.add_theme_stylebox_override(state,slot_style("normal"))
	button.add_theme_stylebox_override("pressed",slot_style("pressed"))
	button.add_theme_stylebox_override("focus",slot_style("focus"))
	button.add_theme_color_override("font_color",COLOR_INK)
	button.add_theme_color_override("font_pressed_color",COLOR_INK)

static func apply_text_role(control: Control, role: StringName) -> void:
	match role:
		ROLE_HEADING:
			control.add_theme_font_size_override("font_size",FONT_HEADING)
			control.add_theme_color_override("font_color",COLOR_INK)
		ROLE_CAPTION:
			control.add_theme_font_size_override("font_size",FONT_CAPTION)
			control.add_theme_color_override("font_color",COLOR_MUTED)
		ROLE_QUANTITY:
			control.add_theme_font_size_override("font_size",FONT_QUANTITY)
			control.add_theme_color_override("font_color",COLOR_INK)
		ROLE_TOOLTIP:
			control.add_theme_font_size_override("font_size",FONT_TOOLTIP)
			control.add_theme_color_override("font_color",COLOR_MUTED)
		ROLE_ERROR:
			control.add_theme_font_size_override("font_size",FONT_ERROR)
			control.add_theme_color_override("font_color",COLOR_ERROR)
		_:
			control.add_theme_font_size_override("font_size",FONT_BODY)
			control.add_theme_color_override("font_color",COLOR_INK)
