extends State

class_name DamageState

const DAMAGE_DURATION := 2.0
const X_FRICTION = 0.5

var time_remaining := DAMAGE_DURATION

func _ready() -> void:
	animated_sprite.play("hurt")

func begin(knockback: Vector2) -> void:
	persistent_state.velocity = knockback
	time_remaining = DAMAGE_DURATION
	print(persistent_state.velocity)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	time_remaining -= delta
	persistent_state.velocity.x *= X_FRICTION

	if time_remaining <= 0.0:
		if persistent_state.is_on_floor():
			change_state.call("idle")
		else:
			change_state.call("fall")
