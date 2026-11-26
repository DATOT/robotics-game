extends Area2D
class_name Sign

@onready var label: Label = $Label

func _ready() -> void:
	label.hide()
	label.visible = false;

func _on_body_entered(body: Node2D) -> void:
	print(body)
	label.show()

func _on_body_exited(body: Node2D) -> void:
	label.hide()
