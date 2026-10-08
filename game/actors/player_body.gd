extends CharacterBody2D
## Shared physical player body. Four-direction sprite art is presentation-only;
## movement, collision and persisted facing remain authored here.
@export_range(1.0,500.0) var speed_px_per_sec: float = 96.0
var is_input_enabled: bool = false
var facing: StringName = &"south"
var _walk_elapsed := 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

func set_input_enabled(enabled: bool) -> void:
	is_input_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
		_sync_sprite(false,0.0)

func _physics_process(delta: float) -> void:
	if not is_input_enabled:
		velocity = Vector2.ZERO
		_sync_sprite(false,delta)
		return
	var direction := Input.get_vector("move_left","move_right","move_up","move_down")
	if not direction.is_zero_approx():
		if absf(direction.x)>absf(direction.y):
			facing = &"east" if direction.x>0 else &"west"
		else:
			facing = &"south" if direction.y>0 else &"north"
	velocity = direction*speed_px_per_sec
	move_and_slide()
	_sync_sprite(not direction.is_zero_approx(),delta)

func _sync_sprite(walking: bool, delta: float) -> void:
	if sprite==null:
		return
	var direction_row := 0
	match facing:
		&"west":
			direction_row=1
		&"east":
			direction_row=2
		&"north":
			direction_row=3
	if walking:
		_walk_elapsed += delta
		sprite.frame_coords=Vector2i(1+int(_walk_elapsed*8.0)%3,direction_row)
	else:
		_walk_elapsed=0.0
		sprite.frame_coords=Vector2i(0,direction_row)
