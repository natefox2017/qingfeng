extends Node2D
## Engineering fixture only: no world identity, farming data or final art.
@onready var player: CharacterBody2D = $FootSorted/Player

func set_input_enabled(enabled: bool) -> void:
	player.set_input_enabled(enabled)

func get_player() -> CharacterBody2D:
	return player

func get_gameplay_layout() -> Array:
	# One deterministic plot keeps gameplay/session persistence testable while this
	# scene remains an engineering fixture. Formal farm layout will replace it.
	return [
		{"plot_id":"plot.fixture.001","space_id":"space.collision_fixture","cell_position":{"x":40,"y":20}}
	]

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 640), Color(0.10, 0.13, 0.17))
	for x in range(0, 961, 16):
		draw_line(Vector2(x, 0), Vector2(x, 640), Color(0.14, 0.17, 0.21))
	for y in range(0, 641, 16):
		draw_line(Vector2(0, y), Vector2(960, y), Color(0.14, 0.17, 0.21))
