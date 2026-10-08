extends RefCounted
## Shared UI theme and semantic text/color tokens.
## Use the pinned, bundled SIL OFL CJK font. No system-font dependency at runtime.

const ROLE_BODY := &"body"
const ROLE_CAPTION := &"caption"
const ROLE_HEADING := &"heading"
const ROLE_QUANTITY := &"quantity"
const ROLE_TOOLTIP := &"tooltip"
const ROLE_ERROR := &"error"

const FONT_BODY := 12
const FONT_CAPTION := 10
const FONT_HEADING := 24
const FONT_QUANTITY := 12
const FONT_TOOLTIP := 11
const FONT_ERROR := 12

## Natural wood, sunlit parchment, and leaf-green focus: approved spring farm UI.
const COLOR_INK := Color("563721")
const COLOR_MUTED := Color("7e644c")
const COLOR_ERROR := Color("a14f38")
const COLOR_ICON := Color("654126")
const COLOR_ICON_DISABLED := Color("aaa08d")
const COLOR_DISABLED := Color("a6967c")
const COLOR_BACKDROP := Color("7eaa79")
const COLOR_SURFACE := Color("f9e9cc")
const COLOR_BUTTON := Color("eed6ab")
const COLOR_BUTTON_ACTIVE := Color("e5bd75")
const COLOR_BORDER := Color("976845")
const COLOR_FOCUS := Color("658745")
const COLOR_HUD_TEXT := Color("fff2d4")
const COLOR_HUD_SURFACE := Color(0.19,0.27,0.18,0.92)
const COLOR_HUD_BORDER := Color("6d8555")
const COLOR_SLOT_SURFACE := Color("f4dfba")
const COLOR_SLOT_SELECTED := Color("ecc36d")
const COLOR_SLOT_BORDER := Color("9e7953")

const PAGE_MINIMUM_SIZE := Vector2(490, 280)
const PAGE_MARGIN := 20.0
const PAGE_RADIUS := 8
const CONTROL_RADIUS := 3
const HUD_RADIUS := 5
const HUD_MARGIN := 6.0
const QUICKBAR_SLOT_SIZE := Vector2(32,34)

static func _control_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BUTTON if state == "normal" else COLOR_BUTTON_ACTIVE
	style.border_color = COLOR_FOCUS if state == "focus" else COLOR_BORDER
	style.set_border_width_all(2 if state == "focus" else 1)
	style.set_corner_radius_all(CONTROL_RADIUS)
	return style

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SURFACE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(PAGE_RADIUS)
	style.set_content_margin_all(PAGE_MARGIN)
	style.set_border_width_all(3)
	style.shadow_color = Color(0.20,0.13,0.08,0.44)
	style.shadow_size = 4
	return style

static func section_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_SURFACE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(CONTROL_RADIUS)
	style.set_content_margin_all(7.0)
	style.shadow_color = Color(0.28,0.16,0.07,0.20)
	style.shadow_size = 2
	return style

static func hud_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_HUD_SURFACE
	style.border_color = COLOR_HUD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(HUD_RADIUS)
	style.set_content_margin_all(HUD_MARGIN)
	return style

static func slot_style(selected: bool, emphasized := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SLOT_SELECTED if selected else COLOR_SLOT_SURFACE
	style.border_color = COLOR_FOCUS if selected or emphasized else COLOR_SLOT_BORDER
	style.set_border_width_all(2 if selected or emphasized else 1)
	style.set_corner_radius_all(CONTROL_RADIUS)
	style.set_content_margin_all(2.0)
	return style

static func menu_action_style(highlighted: bool, focused: bool = false) -> StyleBoxFlat:
	# Texture-independent fallback; final backdrop PNG never owns interactions.
	var style := StyleBoxFlat.new()
	style.bg_color = Color("c9dd8e") if highlighted else Color("efd3a0")
	style.border_color = COLOR_FOCUS if focused else Color("91633e")
	style.set_border_width_all(3 if focused else 2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	style.shadow_color = Color(0.19,0.12,0.07,0.31)
	style.shadow_size = 2
	return style

static func build() -> Theme:
	var theme := Theme.new()
	var font := load("res://assets/fonts/NotoSansCJKsc-Regular.otf") as FontFile
	if font == null:
		push_error("Bundled Noto Sans CJK SC font missing; UI cannot be rendered reliably.")
	else:
		theme.default_font = font
	theme.default_font_size = FONT_BODY
	for kind: String in ["Label", "Button", "CheckBox", "LineEdit"]:
		theme.set_color("font_color", kind, COLOR_INK)
		theme.set_color("font_focus_color", kind, COLOR_INK)
		theme.set_color("font_hover_color", kind, COLOR_INK)
		theme.set_color("font_pressed_color", kind, COLOR_INK)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := _control_style(state)
		theme.set_stylebox(state, "Button", style)
		if state in ["normal", "focus"]:
			theme.set_stylebox(state, "LineEdit", style.duplicate())
	return theme

static func apply_text_role(control: Control, role: StringName) -> void:
	match role:
		ROLE_HEADING:
			control.add_theme_font_size_override("font_size", FONT_HEADING)
			control.add_theme_color_override("font_color", COLOR_INK)
		ROLE_CAPTION:
			control.add_theme_font_size_override("font_size", FONT_CAPTION)
			control.add_theme_color_override("font_color", COLOR_MUTED)
		ROLE_QUANTITY:
			control.add_theme_font_size_override("font_size", FONT_QUANTITY)
			control.add_theme_color_override("font_color", COLOR_INK)
		ROLE_TOOLTIP:
			control.add_theme_font_size_override("font_size", FONT_TOOLTIP)
			control.add_theme_color_override("font_color", COLOR_MUTED)
		ROLE_ERROR:
			control.add_theme_font_size_override("font_size", FONT_ERROR)
			control.add_theme_color_override("font_color", COLOR_ERROR)
		_:
			control.add_theme_font_size_override("font_size", FONT_BODY)
			control.add_theme_color_override("font_color", COLOR_INK)
