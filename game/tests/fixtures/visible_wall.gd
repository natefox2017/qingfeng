@tool
extends StaticBody2D
## Diagnostic rendering reads the actual collider, not a second wall rectangle.
func _ready() -> void:
	$CollisionShape2D.shape.changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var shape := $CollisionShape2D.shape as RectangleShape2D
	if shape != null:
		draw_rect(Rect2(-shape.size / 2, shape.size), Color(0.35, 0.39, 0.44))
