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
# Constant upward push so move_and_slide() keeps reporting is_on_ceiling().
const CEILING_STICK_SPEED := 60.0
# How long we tolerate not touching the ceiling (tile seam) before falling.
const CEILING_LOSS_GRACE := 0.1
# Left/right are swapped while upside down. This also makes a held key flow naturally
# around corners (see the wall<->ceiling transitions below).
const CEILING_REVERSE_CONTROLS := true
# After wrapping around a corner, how long we wait to touch the new surface.
const CORNER_GRACE := 0.15

var wall_climbing := false
var on_ceiling := false
var wall_normal := Vector2.ZERO
# Highest point (smallest global y) the raycast found on this wall.
var climb_top_y := -INF

var _ceiling_grace := CEILING_LOSS_GRACE
var _wall_grace := 0.0

func _ready() -> void:
	animated_sprite.play("move")

func _exit_tree() -> void:
	# Leaving this state while upside down (damage, laser, fall...): undo the ceiling visuals.
	if on_ceiling and is_instance_valid(animated_sprite):
		animated_sprite.flip_h = not animated_sprite.flip_h
		animated_sprite.rotation = 0.0

func _physics_process(delta: float) -> void:
	if persistent_state.is_on_floor():
		persistent_state.wall_climb_start_valid = false
		wall_climbing = false
		_leave_ceiling()

	var input_dir := (Input.is_action_pressed("ui_right") as int) - (Input.is_action_pressed("ui_left") as int)
	var v_input := (Input.is_action_pressed("ui_down") as int) - (Input.is_action_pressed("ui_up") as int)

	if on_ceiling:
		_process_ceiling(delta, input_dir, v_input)
		return

	if (
		not wall_climbing
		and not persistent_state.is_climb_disabled()
		and persistent_state.is_on_wall()
		and (input_dir != 0.0 or v_input != 0.0)
	):
		var normal = persistent_state.get_wall_normal()
		var pressing_into_wall = (
			(input_dir < 0.0 and normal.x > WALL_NORMAL_THRESHOLD)
			or (input_dir > 0.0 and normal.x < -WALL_NORMAL_THRESHOLD)
		)
		# Resume a climb from a wall hang, OR start a new climb by pressing into the wall.
		if pressing_into_wall or persistent_state.wall_climb_start_valid:
			_start_climbing(normal)

	if wall_climbing:
		_process_climbing(delta, input_dir, v_input)
		return

	if input_dir != 0.0:
		animated_sprite.flip_h = input_dir < 0.0
		persistent_state.velocity.x = move_toward(
			persistent_state.velocity.x,
			input_dir * MOVE_SPEED,
			MOVE_ACCEL * delta
		)
	else:
		persistent_state.velocity.x = move_toward(
			persistent_state.velocity.x,
			0.0,
			MOVE_DECEL * delta
		)

	super._physics_process(delta)

	if not persistent_state.is_on_floor():
		change_state.call("fall")
	elif abs(persistent_state.velocity.x) < 1.0 and input_dir == 0.0:
		change_state.call("idle")

# ---------------------------------------------------------------- wall

func _start_climbing(normal: Vector2, probe_from := 0.0) -> void:
	wall_climbing = true
	wall_normal = normal
	persistent_state.wall_climb_start_valid = true

	# Raycast the wall to see how far up it goes.
	var climb_height: float = persistent_state.detect_climb_height(normal, probe_from)
	climb_top_y = persistent_state.global_position.y - climb_height

	_apply_visual_rotation()

func _process_climbing(delta: float, input_dir: float, v_input: float) -> void:
	# Vertical climb direction:
	#  - v_input (ui_up/ui_down) takes priority when given.
	#  - otherwise horizontal input toward the wall = up, away from wall = down.
	var climb_velocity_y := 0.0
	if v_input != 0.0:
		climb_velocity_y = v_input * CLIMB_SPEED
	elif input_dir != 0.0:
		climb_velocity_y = wall_normal.x * input_dir * CLIMB_SPEED

	if not persistent_state.is_on_wall():
		# Climbing down past the bottom edge of a platform: wrap onto its underside.
		if climb_velocity_y > 0.0 and _try_wrap_wall_to_ceiling():
			return
		if _wall_grace <= 0.0:
			_end_climb()
			return
		_wall_grace -= delta
	else:
		_wall_grace = 0.0
		var normal = persistent_state.get_wall_normal()
		if normal != Vector2.ZERO:
			wall_normal = normal
			_apply_visual_rotation()

	# Pull toward the wall to hold position.
	persistent_state.velocity += -wall_normal * WALL_HOLD_FORCE * delta

	# No input -> stop and hang in Idle, keeping rotation.
	if input_dir == 0.0 and v_input == 0.0:
		persistent_state.velocity.y = 0.0
		persistent_state.move_and_slide()
		persistent_state.wall_climb_start_valid = true
		change_state.call("idle")
		return

	var climbing_up := climb_velocity_y < 0.0

	# Reached the top of the wall found by the raycast: stop going up.
	if climbing_up and persistent_state.global_position.y <= climb_top_y:
		climb_velocity_y = 0.0
		climbing_up = false

	persistent_state.velocity.y = climb_velocity_y
	persistent_state.move_and_slide()

	if persistent_state.is_on_ceiling():
		_enter_ceiling()
	elif persistent_state.is_on_floor() and not climbing_up:
		_end_climb()

func _try_wrap_wall_to_ceiling() -> bool:
	var into_wall := Vector2(-signf(wall_normal.x), 0.0)
	if not persistent_state.has_ceiling_near(into_wall):
		return false
	_enter_ceiling()
	# Slide in under the platform; the ceiling needs a moment to be touched.
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
	# Rotated by PI the sprite is mirrored in world space, so toggle flip_h to keep the
	# same world-facing direction. _leave_ceiling() / _exit_tree() undo this.
	animated_sprite.flip_h = not animated_sprite.flip_h
	animated_sprite.play("idle")

func _leave_ceiling(keep_rotation := false) -> void:
	if not on_ceiling:
		return
	on_ceiling = false
	animated_sprite.flip_h = not animated_sprite.flip_h
	if not keep_rotation:
		animated_sprite.rotation = 0.0

func _process_ceiling(delta: float, input_dir: int, v_input: int) -> void:
	var dir := -input_dir if CEILING_REVERSE_CONTROLS else input_dir

	if dir != 0:
		# Upside down: facing right in the world means flip_h = true.
		animated_sprite.flip_h = dir > 0
		animated_sprite.play("move")
		persistent_state.velocity.x = move_toward(
			persistent_state.velocity.x,
			dir * CEILING_SPEED,
			CEILING_ACCEL * delta
		)
	else:
		animated_sprite.play("idle")
		persistent_state.velocity.x = move_toward(persistent_state.velocity.x, 0.0, CEILING_DECEL * delta)

	persistent_state.velocity.y = -CEILING_STICK_SPEED
	persistent_state.move_and_slide()

	if persistent_state.is_on_ceiling():
		_ceiling_grace = CEILING_LOSS_GRACE
	else:
		# Moved past the edge of a platform: wrap around onto its side wall.
		if _try_wrap_ceiling_to_wall(dir):
			return
		_ceiling_grace -= delta
		if _ceiling_grace <= 0.0:
			_drop()
			return

	# Inner corner: climb down the wall. Down key always works; with reversed controls
	# simply holding the direction into the wall works too.
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
	if dir == 0:
		return false
	# The platform we just left is behind us (opposite to the travel direction).
	var normal: Vector2 = persistent_state.probe_wall_normal(Vector2(-signf(dir), 0.0))
	if normal == Vector2.ZERO:
		return false
	_leave_ceiling(true)
	_start_climbing(normal, persistent_state.CORNER_PROBE_UP)
	_wall_grace = CORNER_GRACE
	return true

func _drop() -> void:
	_leave_ceiling()
	persistent_state.velocity = Vector2.ZERO
	change_state.call("fall")

# ------------------------------------------------------------- input

func move_left() -> void:
	if on_ceiling:
		return
	animated_sprite.flip_h = true

func move_right() -> void:
	if on_ceiling:
		return
	animated_sprite.flip_h = false
