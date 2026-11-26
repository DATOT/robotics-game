extends State

class_name IdleState

const WALL_HOLD_FORCE := 980.0
const WALL_NORMAL_THRESHOLD := 0.3

var floor_grace := 0.1

func _ready() -> void:
	animated_sprite.play("idle")

	persistent_state.velocity = Vector2.ZERO
	if not persistent_state.wall_climb_start_valid:
		animated_sprite.rotation = 0.0

func _physics_process(delta: float) -> void:
	if persistent_state.is_on_floor():
		persistent_state.wall_climb_start_valid = false
		animated_sprite.rotation = 0.0

	if persistent_state.wall_climb_start_valid and persistent_state.is_on_wall():
		var normal = persistent_state.get_wall_normal()
		persistent_state.velocity += -normal * WALL_HOLD_FORCE * delta

		var v_input := 0.0
		if Input.is_action_pressed("ui_down"):
			v_input = 1.0
		elif Input.is_action_pressed("ui_up"):
			v_input = -1.0

		if v_input != 0.0:
			change_state.call("move")
			return

		persistent_state.velocity.y = 0.0
		persistent_state.move_and_slide()
		return

	super._physics_process(delta)
	if persistent_state.is_on_floor():
		floor_grace = 0.1
	else:
		floor_grace -= delta
		if floor_grace <= 0.0:
			change_state.call("fall")

func _flip_direction() -> void:
	animated_sprite.flip_h = not animated_sprite.flip_h

func move_left() -> void:
	if persistent_state.is_on_wall():
		var normal = persistent_state.get_wall_normal()
		# The wall is on the left, so left input is into the wall.
		if normal.x > WALL_NORMAL_THRESHOLD:
			change_state.call("move")
			return

	if animated_sprite.flip_h:
		change_state.call("move")
	else:
		_flip_direction()

func move_right() -> void:
	if persistent_state.is_on_wall():
		var normal = persistent_state.get_wall_normal()
		if normal.x < -WALL_NORMAL_THRESHOLD:
			change_state.call("move")
			return

	if not animated_sprite.flip_h:
		change_state.call("move")
	else:
		_flip_direction()
