@tool
extends LightSensorBody
class_name DestructibleObstacle

@onready var explosion: CPUParticles2D = $Explosion
var sprite: Node2D = null
var collision: Node2D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		child_order_changed.connect(update_configuration_warnings)
		return
		
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			sprite = child
			break
		if child is CollisionShape2D or child is CollisionPolygon2D:
			collision = child

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []

	var has_required_sprite := false
	var has_required_collision := false
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			has_required_sprite = true
			break

		if child is CollisionShape2D or child is CollisionPolygon2D:
			has_required_collision = true
			break

	if not has_required_sprite:
		warnings.append("Missing required sprite.\nConsider adding a Sprite2D or AnimatedSprite2D child node.")
	if not has_required_collision:
		warnings.append("Missing required collision.\nConsider adding a CollisionShape2D or CollisionPolygon2D child node.")
		
	return warnings

func _on_detected_light() -> void:
	explosion.emitting = true

	print(collision)
	if collision != null:
		collision.disabled = true

	if sprite != null:
		sprite.hide()
	
	await explosion.finished
	queue_free()
