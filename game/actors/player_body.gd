extends CharacterBody2D
## Art-independent body. No inventory, save or animation ownership here.
@export_range(1.0, 500.0) var speed_px_per_sec: float = 96.0
var is_input_enabled: bool = false
var facing: StringName = &"south"

func set_input_enabled(enabled: bool) -> void:
	is_input_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	if not is_input_enabled:
		velocity = Vector2.ZERO
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not direction.is_zero_approx():
		if absf(direction.x) > absf(direction.y):
			facing = &"east" if direction.x > 0 else &"west"
		else:
			facing = &"south" if direction.y > 0 else &"north"
	velocity = direction * speed_px_per_sec
	move_and_slide()
