extends StaticBody2D
class_name LightSensorBody

@export_range(0, 5) var triggerDelay: float = 0

signal detected_light()

func detect_light() -> void:
	await get_tree().create_timer(triggerDelay).timeout
	detected_light.emit()
