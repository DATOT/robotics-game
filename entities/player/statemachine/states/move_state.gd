extends State

class_name MoveState

const MOVE_SPEED := 70.0
const MOVE_ACCEL := 900.0
const MOVE_DECEL := 800.0
const WALL_HOLD_FORCE := 980.0
const CLIMB_SPEED := 60.0
const WALL_NORMAL_THRESHOLD := 0.3

const CEILING_SPEED := 60.0
const CEILING_ACCEL := 900.0
const CEILING_DECEL := 800.0
const CEILING_STICK_SPEED := 60.0
const CEILING_LOSS_GRACE := 0.1
const CEILING_REVERSE_CONTROLS := true
const CORNER_GRACE := 0.15
const WALL_SNAP_EPSILON := 0.5

var wall_climbing := false
var on_ceiling := false
var wall_normal := Vector2.ZERO
# Highest point (smallest global y) found by the wall-height raycast.
var climb_top_y := -INF

var _ceiling_grace := CEILING_LOSS_GRACE
var _wall_grace := 0.0

func _ready() -> void:
	animated_sprite.play("move")

func _exit_tree() -> void:
	if on_ceiling and is_instance_valid(animated_sprite):
		animated_sprite.flip_h = not animated_sprite.flip_h
		animated_sprite.rotation = 0.0

func _physics_process(delta: float) -> void:
	if persistent_state.is_on_floor():
		persistent_state.wall_climb_start_valid = false
		wall_climbing = false
		_leave_ceiling()

	var input_dir := int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	var v_input := int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up"))

	if on_ceiling:
		_process_ceiling(delta, input_dir, v_input)
		return

	if (
		not wall_climbing
		and not persistent_state.is_climb_disabled()
		and persistent_state.is_on_wall()
		and (input_dir != 0 or v_input != 0)
	):
		var normal := persistent_state.get_wall_normal()
		var pressing_into_wall := (
			(input_dir < 0 and normal.x > WALL_NORMAL_THRESHOLD)
			or (input_dir > 0 and normal.x < -WALL_NORMAL_THRESHOLD)
		)
		if pressing_into_wall or persistent_state.wall_climb_start_valid:
			_start_climbing(normal)

	if wall_climbing:
		_process_climbing(delta, input_dir, v_input)
		return

	if input_dir != 0:
		animated_sprite.flip_h = input_dir < 0
		persistent_state.velocity.x = move_toward(
			persistent_state.velocity.x,
			input_dir * MOVE_SPEED,
			MOVE_ACCEL * delta
		)
	else:
		persistent_state.velocity.x = move_toward(persistent_state.velocity.x, 0.0, MOVE_DECEL * delta)

	super._physics_process(delta)

	if not persistent_state.is_on_floor():
		if _try_wrap_floor_to_wall(input_dir):
			return
		change_state.call("fall")
	elif absf(persistent_state.velocity.x) < 1.0 and input_dir == 0:
		change_state.call("idle")

# ---------------------------------------------------------------- wall

func _start_climbing(normal: Vector2, probe_from: float = 0.0) -> void:
	if absf(normal.x) < WALL_NORMAL_THRESHOLD:
		return
	wall_climbing = true
	on_ceiling = false
	wall_normal = normal
	persistent_state.wall_climb_start_valid = true

	# The climb limit is determined by horizontal raycasts scanning upward along the wall.
	var climb_height: float = persistent_state.detect_climb_height(normal, probe_from)
	climb_top_y = persistent_state.global_position.y - climb_height
	_apply_visual_rotation()

func _process_climbing(delta: float, input_dir: float, v_input: float) -> void:
	var climb_velocity_y := 0.0
	if v_input != 0.0:
		climb_velocity_y = v_input * CLIMB_SPEED
	elif input_dir != 0.0:
		climb_velocity_y = wall_normal.x * input_dir * CLIMB_SPEED

	if not persistent_state.is_on_wall():
		if climb_velocity_y > 0.0 and _try_wrap_wall_to_ceiling():
			return
		if _wall_grace <= 0.0:
			_end_climb()
			return
		_wall_grace -= delta
	else:
		_wall_grace = 0.0
		var normal := persistent_state.get_wall_normal()
		if absf(normal.x) > WALL_NORMAL_THRESHOLD:
			wall_normal = normal
			_apply_visual_rotation()

	persistent_state.velocity += -wall_normal * WALL_HOLD_FORCE * delta

	if input_dir == 0.0 and v_input == 0.0:
		persistent_state.velocity.y = 0.0
		persistent_state.move_and_slide()
		persistent_state.wall_climb_start_valid = true
		change_state.call("idle")
		return

	var climbing_up := climb_velocity_y < 0.0
	if climbing_up:
		var distance_to_top := persistent_state.global_position.y - climb_top_y
		if distance_to_top <= 0.0:
			if _try_snap_onto_floor():
				return
			# The raycast found the top edge, but there is no walkable floor above it.
			# Hold at the edge instead of forcibly dropping the player.
			persistent_state.velocity = Vector2.ZERO
			persistent_state.move_and_slide()
			return
		climb_velocity_y = maxf(climb_velocity_y, -distance_to_top / delta)

	persistent_state.velocity.y = climb_velocity_y
	persistent_state.move_and_slide()

	if persistent_state.is_on_ceiling():
		_enter_ceiling()
	elif persistent_state.is_on_floor() and not climbing_up:
		_end_climb()
	elif climbing_up and persistent_state.global_position.y <= climb_top_y + WALL_SNAP_EPSILON:
		if not _try_snap_onto_floor():
			persistent_state.velocity = Vector2.ZERO

# Same wall probe pattern as the working floor-to-wall transition.
func _try_wrap_floor_to_wall(input_dir: int) -> bool:
	if input_dir == 0 or persistent_state.is_climb_disabled():
		return false
	var normal := persistent_state.probe_wall_with_offsets(
		Vector2(-signf(input_dir), 0.0),
		[4.0, 12.0, 20.0, 28.0, 36.0]
	)
	if normal == Vector2.ZERO:
		return false
	_start_climbing(normal)
	persistent_state.velocity = Vector2.ZERO
	_wall_grace = CORNER_GRACE
	return true

func _try_snap_onto_floor() -> bool:
	var extents := persistent_state.get_collision_extents()
	var collision_offset := _get_collision_center_offset()
	# Cast down just over the wall edge where the player's feet will land.
	var floor_x := persistent_state.global_position.x - wall_normal.x * (extents.x + 1.0)
	var from := Vector2(floor_x, climb_top_y - 8.0)
	var to := Vector2(floor_x, climb_top_y + extents.y + 24.0)
	var query := PhysicsRayQueryParameters2D.create(
		from,
		to,
		persistent_state.collision_mask,
		[persistent_state.get_rid()]
	)
	var hit := persistent_state.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var floor_normal: Vector2 = hit.get("normal", Vector2.ZERO)
	if floor_normal.dot(Vector2.UP) < 0.7:
		return false

	persistent_state.global_position.y = float(hit.position.y) - collision_offset.y - extents.y
	persistent_state.velocity = Vector2.ZERO
	persistent_state.wall_climb_start_valid = false
	wall_climbing = false
	animated_sprite.rotation = 0.0
	persistent_state.move_and_slide()
	change_state.call("idle")
	return true

func _try_wrap_wall_to_ceiling() -> bool:
	var into_wall := Vector2(-signf(wall_normal.x), 0.0)
	if not persistent_state.has_ceiling_near(into_wall):
		return false
	_enter_ceiling()
	persistent_state.velocity = Vector2(into_wall.x * CEILING_SPEED, -CEILING_STICK_SPEED)
	_ceiling_grace = CORNER_GRACE
	return true

func _apply_visual_rotation() -> void:
	if wall_normal != Vector2.ZERO:
		animated_sprite.rotation = wall_normal.angle() + PI / 2.0

func _end_climb() -> void:
	animated_sprite.rotation = 0.0
	persistent_state.velocity = Vector2.ZERO
	persistent_state.wall_climb_start_valid = false
	wall_climbing = false
	if persistent_state.is_on_floor():
		change_state.call("idle")
	else:
		change_state.call("fall")

# ------------------------------------------------------------- ceiling

func _enter_ceiling() -> void:
	if on_ceiling:
		return
	on_ceiling = true
	wall_climbing = false
	_ceiling_grace = CEILING_LOSS_GRACE
	persistent_state.wall_climb_start_valid = false
	persistent_state.velocity = Vector2.ZERO
	animated_sprite.rotation = PI
	animated_sprite.flip_h = not animated_sprite.flip_h
	animated_sprite.play("idle")

func _leave_ceiling(keep_rotation: bool = false) -> void:
	if not on_ceiling:
		return
	on_ceiling = false
	animated_sprite.flip_h = not animated_sprite.flip_h
	if not keep_rotation:
		animated_sprite.rotation = 0.0

func _process_ceiling(delta: float, input_dir: int, v_input: int) -> void:
	var dir := -input_dir if CEILING_REVERSE_CONTROLS else input_dir

	if dir != 0:
		animated_sprite.flip_h = dir > 0
		animated_sprite.play("move")
		persistent_state.velocity.x = move_toward(
			persistent_state.velocity.x,
			dir * CEILING_SPEED,
			CEILING_ACCEL * delta
		)
	else:
		animated_sprite.play("idle")
		persistent_state.velocity.x = move_toward(
			persistent_state.velocity.x,
			0.0,
			CEILING_DECEL * delta
		)

	persistent_state.velocity.y = -CEILING_STICK_SPEED
	persistent_state.move_and_slide()

	if persistent_state.is_on_ceiling():
		_ceiling_grace = CEILING_LOSS_GRACE
	else:
		# Mirror the floor-to-wall scan: probe toward the edge at several offsets,
		# then snap flush to the wall rather than letting the player fall/mantle.
		if _try_wrap_ceiling_to_wall(dir):
			return
		_ceiling_grace -= delta
		if _ceiling_grace <= 0.0:
			_drop()
			return

	if persistent_state.is_on_wall():
		var normal := persistent_state.get_wall_normal()
		var into_wall := (
			(dir < 0 and normal.x > WALL_NORMAL_THRESHOLD)
			or (dir > 0 and normal.x < -WALL_NORMAL_THRESHOLD)
		)
		if v_input > 0 or (CEILING_REVERSE_CONTROLS and into_wall):
			_leave_ceiling(true)
			_start_climbing(normal)

func _try_wrap_ceiling_to_wall(dir: int) -> bool:
	if dir == 0 or persistent_state.is_climb_disabled():
		return false

	# Use the same probe direction and vertical scan as floor-to-wall. Ceiling
	# controls are already reversed in `dir`, so this keeps movement semantics aligned.
	var probe_direction := Vector2(-signf(dir), 0.0)
	var offsets: Array = [4.0, 12.0, 20.0, 28.0, 36.0]
	var space := persistent_state.get_world_2d().direct_space_state
	var hit: Dictionary = {}
	var hit_offset := 0.0

	for offset in offsets:
		var ray_origin := persistent_state.global_position + Vector2(0.0, offset)
		var query := PhysicsRayQueryParameters2D.create(
			ray_origin,
			ray_origin + probe_direction * persistent_state.CLIMB_PROBE_REACH,
			persistent_state.collision_mask,
			[persistent_state.get_rid()]
		)
		var result := space.intersect_ray(query)
		if result.is_empty():
			continue
		var normal: Vector2 = result.get("normal", Vector2.ZERO)
		if absf(normal.x) > WALL_NORMAL_THRESHOLD:
			hit = result
			hit_offset = offset
			break

	if hit.is_empty():
		return false

	var normal_found: Vector2 = hit.get("normal", Vector2.ZERO)
	var extents := persistent_state.get_collision_extents()
	var center_offset := _get_collision_center_offset()
	var point: Vector2 = hit.get("position", persistent_state.global_position)
	# Align the player's collision box with the ray hit. This is a position snap,
	# not a mantle; the wall can be below the ceiling tile we just left.
	persistent_state.global_position = Vector2(
		point.x + normal_found.x * (extents.x + WALL_SNAP_EPSILON) - center_offset.x,
		point.y - center_offset.y
	)

	_leave_ceiling(true)
	_start_climbing(normal_found)
	persistent_state.velocity = Vector2.ZERO
	_wall_grace = CORNER_GRACE
	return true

func _get_collision_center_offset() -> Vector2:
	for child in persistent_state.get_children():
		if child is CollisionShape2D:
			return child.position
	return Vector2.ZERO

func _drop() -> void:
	_leave_ceiling()
	persistent_state.velocity = Vector2.ZERO
	change_state.call("fall")

# ------------------------------------------------------------- input

func move_left() -> void:
	if not on_ceiling:
		animated_sprite.flip_h = true

func move_right() -> void:
	if not on_ceiling:
		animated_sprite.flip_h = false
