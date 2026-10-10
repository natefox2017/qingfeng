extends Button
## Temporary native line icons: accessible and replaceable by accepted PixelLab art.
const UI_THEME = preload("res://ui/theme/ui_theme.gd")
var glyph := "play"

func _draw() -> void:
	# Text-labelled buttons already carry their meaning. Drawing a centered glyph
	# underneath the text makes Chinese labels unreadable at every window size.
	if not text.is_empty():
		return
	var center := size * 0.5
	var color := UI_THEME.COLOR_ICON if not disabled else UI_THEME.COLOR_ICON_DISABLED
	var points: Array[Vector2] = []
	match glyph:
		"new":
			draw_line(center-Vector2(9,0),center+Vector2(9,0),color,2)
			draw_line(center-Vector2(0,9),center+Vector2(0,9),color,2)
		"play", "resume":
			draw_colored_polygon(PackedVector2Array([center+Vector2(-6,-10),center+Vector2(9,0),center+Vector2(-6,10)]),color)
		"back", "import":
			draw_line(center+Vector2(9,0),center-Vector2(9,0),color,2)
			draw_line(center-Vector2(9,0),center+Vector2(-2,-7),color,2)
			draw_line(center-Vector2(9,0),center+Vector2(-2,7),color,2)
			if glyph == "import": draw_line(center-Vector2(11,11),center+Vector2(-11,11),color,2)
		"save", "load":
			draw_rect(Rect2(center-Vector2(10,10),Vector2(20,20)),color,false,2)
			draw_rect(Rect2(center-Vector2(5,9),Vector2(10,6)),color,false,2)
			draw_rect(Rect2(center+Vector2(-5,3),Vector2(10,6)),color,false,2)
		"inventory":
			for x in [-7,1]:
				for y in [-7,1]:
					draw_rect(Rect2(center+Vector2(x,y),Vector2(6,6)),color,false,2)
		"storage":
			draw_rect(Rect2(center-Vector2(10,6),Vector2(20,14)),color,false,2)
			draw_line(center+Vector2(-10,-2),center+Vector2(10,-2),color,2)
			draw_line(center+Vector2(-4,1),center+Vector2(4,1),color,2)
		"settings":
			draw_arc(center,7,0,TAU,24,color,2)
			for i in 8:
				var direction := Vector2.from_angle(i*TAU/8)
				draw_line(center+direction*9,center+direction*12,color,2)
			draw_circle(center,2,color)
		"close", "quit":
			draw_line(center-Vector2(8,8),center+Vector2(8,8),color,2)
			draw_line(center+Vector2(-8,8),center+Vector2(8,-8),color,2)
		"gift":
			draw_rect(Rect2(center+Vector2(-10,-3),Vector2(20,13)),color,false,2)
			draw_rect(Rect2(center+Vector2(-12,-7),Vector2(24,5)),color,false,2)
			draw_line(center+Vector2(0,-8),center+Vector2(0,10),color,2)
		"accept":
			draw_polyline(PackedVector2Array([center+Vector2(-10,0),center+Vector2(-2,7),center+Vector2(11,-8)]),color,2)
		"pause":
			draw_line(center-Vector2(4,8),center+Vector2(-4,8),color,3)
			draw_line(center+Vector2(4,-8),center+Vector2(4,8),color,3)
		_:
			draw_circle(center,7,color,false,2)
