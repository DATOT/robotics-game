extends CharacterBody2D
class_name Player

@onready var sprite: AnimatedSprite2D = $Sprite

var state: State
var state_factory: StateFactory

var wall_climb_start_y: float = 0.0
var wall_climb_start_valid: bool = false

# Wall-height raycast tuning.
const CLIMB_PROBE_STEP := 4.0    # px between probe rays going up the wall
const CLIMB_PROBE_REACH := 24.0  # ray length into the wall; must exceed half the player's width
const CLIMB_PROBE_MAX := 512.0   # never scan higher than this

@onready var laser = $Laser

@onready var phantom_camera_2d: PhantomCamera2D = $PhantomCamera2D
@export var limit_target: NodePath

func _ready() -> void:
	_ensure_input_actions()

	print("Assigned path: ", limit_target)
	if not limit_target.is_empty():
		var target_node = get_node(limit_target)
		phantom_camera_2d.limit_target = phantom_camera_2d.get_path_to(target_node)

	state_factory = StateFactory.new()
	change_state("idle")

# Registers 'disable_climb' (Z) if it isn't already in the Input Map.
func _ensure_input_actions() -> void:
	if InputMap.has_action("disable_climb"):
		return
	InputMap.add_action("disable_climb")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_Z
	InputMap.action_add_event("disable_climb", ev)

func _physics_process(_delta: float) -> void:
	# Z drops the player off any wall/ceiling and blocks re-grabbing while held.
	if is_climb_disabled() and is_climbing():
		release_climb()

func _process(_delta: float) -> void:
	# X starts the laser state. Damage cannot be interrupted by firing.
	if Input.is_key_pressed(KEY_X):
		if not state is LaserState and not state is DamageState:
			change_state("laser")
		return

	if state is LaserState:
		# LaserState handles ending when X is released.
		return

	if Input.is_action_pressed("ui_left"):
		move_left()
	elif Input.is_action_pressed("ui_right"):
		move_right()

func move_left() -> void:
	if state != null:
		state.move_left()

func move_right() -> void:
	if state != null:
		state.move_right()

func change_state(new_state_name: String) -> void:
	if state != null:
		var old_state := state
		state = null
		old_state.set_process(false)
		old_state.set_physics_process(false)
		remove_child(old_state)
		old_state.queue_free()

	print("Changed to state: '%s'" % new_state_name)
	var state_script = state_factory.get_state(new_state_name)
	if state_script == null:
		return

	state = state_script.new()
	state.setup(change_state, $Sprite, self)
	state.name = new_state_name
	add_child(state)

func take_damage(damage: int, knockback: Vector2 = Vector2(0.0, 256.0)) -> void:
	if state is DamageState:
		return

	Global.player_health -= damage
	change_state("damage")
	state.begin(knockback)

# --- Climbing helpers ---

func is_climb_disabled() -> bool:
	return Input.is_action_pressed("disable_climb")

func is_climbing() -> bool:
	if state is MoveState:
		return state.wall_climbing
	if state is IdleState:
		# Hanging on a wall.
		return wall_climb_start_valid and is_on_wall()
	return false

func release_climb() -> void:
	wall_climb_start_valid = false
	velocity = Vector2.ZERO
	change_state("fall")

# Casts rays horizontally into the wall at increasing heights above the player and
# returns how many pixels of wall continue above the player's current position.
# The first ray that misses is the top of the wall (or the underside of a ceiling).
func detect_climb_height(wall_normal: Vector2) -> float:
	var space := get_world_2d().direct_space_state
	var into_wall := Vector2(-signf(wall_normal.x), 0.0)
	var height := 0.0
	var offset := 0.0
	while offset <= CLIMB_PROBE_MAX:
		var from := global_position + Vector2(0.0, -offset)
		var query := PhysicsRayQueryParameters2D.create(
			from,
			from + into_wall * CLIMB_PROBE_REACH,
			collision_mask,
			[get_rid()]
		)
		if space.intersect_ray(query).is_empty():
			break
		height = offset
		offset += CLIMB_PROBE_STEP
	return height

func has_laser_energy() -> bool:
	return true

func consume_laser_energy(_amount: float) -> void:
	pass

func fire_laser() -> void:
	if not laser.is_firing:
		laser.scale.x =  -1 if sprite.flip_h else 1
		laser.fire_rays()

func delete_laser() -> void:
	if laser.is_firing:
		laser.erase_rays()
