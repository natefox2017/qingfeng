extends StaticBody2D
## Art-independent layout component. Placeholder fill is derived from the same
## RectangleShape2D used for collision, so debug visuals cannot drift from footprint.

@export var fill_color: Color = Color("46664d")

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null or not (collision.shape is RectangleShape2D):
		return
	var rectangle := collision.shape as RectangleShape2D
	draw_rect(Rect2(-rectangle.size * 0.5, rectangle.size), fill_color)
