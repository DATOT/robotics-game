extends State

class_name FallState

const AIR_SPEED = 180.0
const AIR_ACCEL = 1200.0
const AIR_DECEL = 800.0
const WALL_NORMAL_THRESHOLD = 0.3
const MAX_FALL_SPEED = 800.0

func _ready():
	animated_sprite.play("idle")
	animated_sprite.rotation = 0.0
	persistent_state.velocity.x = -1

func _physics_process(delta):
	persistent_state.velocity.x = 0.0

	if Input.is_action_pressed("ui_left"):
		animated_sprite.flip_h = true
	elif Input.is_action_pressed("ui_right"):
		animated_sprite.flip_h = false

	super._physics_process(delta)
	persistent_state.velocity.x = 0.0
	persistent_state.velocity.y = min(persistent_state.velocity.y, MAX_FALL_SPEED)

	if persistent_state.is_on_floor() and persistent_state.velocity.y >= 0.0:
		change_state.call("idle")

func move_left():
	pass

func move_right():
	pass
