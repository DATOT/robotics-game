extends Area2D
class_name DamageZone

@export var damage: int = 1
@export var knockback: Vector2 = Vector2.ZERO

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, knockback)
