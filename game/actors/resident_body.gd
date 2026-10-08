extends CharacterBody2D
## Engineering resident body: schedule gives target anchors, WORLD collision owns
## actual movement. No teleport, inventory, relationship or AI ownership here.

@export var resident_id := "resident.neighbor"
@export_range(1.0,200.0) var speed_px_per_sec := 40.0
@export_range(0.05,2.0) var stall_replan_seconds := 0.45
@export_range(0.05,2.0) var wait_retry_seconds := 0.60
@export_range(0.5,8.0) var arrival_tolerance_px := 2.0

var activity_id := "home"
var anchor_id := ""
var movement_state := "idle"
var facing: StringName = &"south"

var _target_position := Vector2.ZERO
var _has_target := false
var _route_variant := 0
var _waypoints: Array[Vector2] = []
var _waypoint_index := 0
var _stall_elapsed := 0.0
var _wait_elapsed := 0.0
var _replan_count := 0

func set_schedule_target(target_anchor_id: String, target_position: Vector2, target_activity_id: String) -> bool:
	if target_anchor_id.is_empty() or not is_finite(target_position.x) or not is_finite(target_position.y):
		return false
	var target_changed := target_anchor_id != anchor_id or not target_position.is_equal_approx(_target_position)
	anchor_id = target_anchor_id
	activity_id = target_activity_id
	_target_position = target_position
	_has_target = true
	if target_changed:
		_route_variant = 0
		_replan_count = 0
		_build_route()
	elif position.distance_to(_target_position) <= arrival_tolerance_px:
		_arrive()
	return true

func clear_schedule_target() -> void:
	_has_target = false
	_waypoints.clear()
	_waypoint_index = 0
	velocity = Vector2.ZERO
	movement_state = "idle"

func set_world_active(active: bool) -> void:
	visible = active
	collision_layer = 4 if active else 0
	collision_mask = 3 if active else 0
	set_physics_process(active)
	if not active:
		clear_schedule_target()

func is_world_active() -> bool:
	return visible and collision_layer == 4 and is_physics_processing()

func projection() -> Dictionary:
	return {
		"resident_id":resident_id,
		"activity_id":activity_id,
		"anchor_id":anchor_id,
		"movement_state":movement_state,
		"world_position_px":{"x":position.x,"y":position.y},
		"target_position_px":{"x":_target_position.x,"y":_target_position.y},
		"replan_count":_replan_count
	}

func runtime_snapshot(space_id: String) -> Dictionary:
	return {
		"resident_id":resident_id,
		"space_id":space_id,
		"world_position_px":{"x":position.x,"y":position.y},
		"facing":str(facing)
	}

func face_toward(world_position: Vector2) -> void:
	_update_facing(position.direction_to(world_position))

func restore_runtime_position(world_position: Vector2, restored_facing: StringName) -> bool:
	if not is_finite(world_position.x) or not is_finite(world_position.y) or restored_facing not in [&"north",&"south",&"east",&"west"]:
		return false
	position = world_position
	facing = restored_facing
	velocity = Vector2.ZERO
	_has_target = false
	_waypoints.clear()
	_waypoint_index = 0
	_stall_elapsed = 0.0
	_wait_elapsed = 0.0
	movement_state = "idle"
	return true

func _physics_process(delta: float) -> void:
	if not _has_target:
		velocity = Vector2.ZERO
		return
	if position.distance_to(_target_position) <= arrival_tolerance_px:
		_arrive()
		return
	if movement_state == "waiting":
		velocity = Vector2.ZERO
		_wait_elapsed += delta
		if _wait_elapsed >= wait_retry_seconds:
			_wait_elapsed = 0.0
			_route_variant = 1-_route_variant
			_replan_count += 1
			_build_route()
		return
	if _waypoints.is_empty() or _waypoint_index >= _waypoints.size():
		_build_route()
		if _waypoints.is_empty():
			_arrive()
			return
	var waypoint: Vector2 = _waypoints[_waypoint_index]
	if position.distance_to(waypoint) <= arrival_tolerance_px:
		_waypoint_index += 1
		if _waypoint_index >= _waypoints.size():
			if position.distance_to(_target_position) <= arrival_tolerance_px:
				_arrive()
			else:
				_build_route()
			return
		waypoint = _waypoints[_waypoint_index]
	var direction := position.direction_to(waypoint)
	_update_facing(direction)
	velocity = direction*speed_px_per_sec
	var before := position
	move_and_slide()
	var moved := position.distance_to(before)
	if moved < maxf(0.05,speed_px_per_sec*delta*0.08):
		_stall_elapsed += delta
		if _stall_elapsed >= stall_replan_seconds:
			_replan_after_stall()
	else:
		_stall_elapsed = 0.0
		movement_state = "moving"

func _build_route() -> void:
	_waypoints.clear()
	_waypoint_index = 0
	_stall_elapsed = 0.0
	if not _has_target or position.distance_to(_target_position) <= arrival_tolerance_px:
		_arrive()
		return
	var first := Vector2(_target_position.x,position.y) if _route_variant == 0 else Vector2(position.x,_target_position.y)
	if first.distance_to(position) > arrival_tolerance_px and first.distance_to(_target_position) > arrival_tolerance_px:
		_waypoints.append(first)
	_waypoints.append(_target_position)
	movement_state = "moving"

func _replan_after_stall() -> void:
	_stall_elapsed = 0.0
	if _replan_count % 2 == 0:
		_route_variant = 1-_route_variant
		_replan_count += 1
		_build_route()
	else:
		_replan_count += 1
		_wait_elapsed = 0.0
		velocity = Vector2.ZERO
		movement_state = "waiting"

func _arrive() -> void:
	velocity = Vector2.ZERO
	_waypoints.clear()
	_waypoint_index = 0
	_stall_elapsed = 0.0
	_wait_elapsed = 0.0
	movement_state = "arrived"

func _update_facing(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	if absf(direction.x) > absf(direction.y):
		facing = &"east" if direction.x > 0.0 else &"west"
	else:
		facing = &"south" if direction.y > 0.0 else &"north"
