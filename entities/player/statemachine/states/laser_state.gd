extends State

class_name LaserState

const ENERGY_PER_SECOND := 10.0

var _laser_active: bool = false

func _ready() -> void:
	animated_sprite.play("laser")
	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "laser":
		_laser_active = true
		persistent_state.fire_laser()

func _physics_process(delta: float) -> void:
	if not Input.is_key_pressed(KEY_X) or not persistent_state.has_laser_energy():
		_end_laser()
		return

	if not _laser_active:
		super._physics_process(delta)
		return

	persistent_state.consume_laser_energy(ENERGY_PER_SECOND * delta)

	super._physics_process(delta)

func _end_laser() -> void:
	if animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_animation_finished)
	if _laser_active:
		persistent_state.delete_laser()
		_laser_active = false
	if persistent_state.is_on_floor():
		change_state.call("idle")
	else:
		change_state.call("fall")

func _exit_tree() -> void:
	if animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_animation_finished)
	# Safety: clean up laser if state is exited without _end_laser (e.g. damage)
	if _laser_active:
		persistent_state.delete_laser()

