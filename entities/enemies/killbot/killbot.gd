extends DamageZone # Area2D
class_name Killbot

@onready var forwardRay: RayCast2D = $ForwardRayCast
@onready var edgeRay: RayCast2D = $EdgeRayCast
@onready var bottomRay: RayCast2D = $BottomRayCast
@onready var sprite: AnimatedSprite2D = $Sprite

@export var canMove: bool = false
@export var ignoreCliff: bool = true

const MOVE_SPEED := -50.0
const DAMAGE_INTERVAL := 0.1
const FADE_DURATION := 0.5

var velocity: Vector2 = Vector2.ZERO
var direction: int = -1
var health: int = 10

var _hit_lock_timer := 0.0
var _is_dead := false


func _ready() -> void:
	if canMove:
		sprite.play("move")
	else:
		sprite.play("idle")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _hit_lock_timer > 0.0:
		_hit_lock_timer = maxf(_hit_lock_timer - delta, 0.0)
		if _hit_lock_timer > 0.0:
			return

	if not bottomRay.is_colliding():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	if not canMove:
		return

	if not ignoreCliff:
		if forwardRay.is_colliding() or not edgeRay.is_colliding():
			_turn_around()
	elif forwardRay.is_colliding():
		_turn_around()

	velocity.x = direction * MOVE_SPEED
	position.x += velocity.x * delta
	position.y += velocity.y * delta


func _turn_around() -> void:
	direction *= -1
	scale.x *= -1


func take_damage(damage: int) -> void:
	if _is_dead or _hit_lock_timer > 0.0:
		return

	health -= damage
	_hit_lock_timer = DAMAGE_INTERVAL

	if health <= 0:
		_die()
		return

	sprite.play("hurt")


func _die() -> void:
	_is_dead = true
	velocity = Vector2.ZERO

	# Stop detecting or being detected by other collision objects.
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	for ray in [forwardRay, edgeRay, bottomRay]:
		ray.set_deferred("enabled", false)

	sprite.modulate.a = 1.0
	sprite.play("dead")
	await sprite.animation_finished

	var fade := create_tween()
	fade.tween_property(sprite, "modulate:a", 0.0, FADE_DURATION)
	await fade.finished

	queue_free()
