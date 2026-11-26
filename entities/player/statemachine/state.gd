# state.gd

extends Node2D

class_name State

var change_state: Callable
var animated_sprite: AnimatedSprite2D
var persistent_state: Player
var velocity: Vector2 = Vector2.ZERO

func _physics_process(delta):
	if not persistent_state.is_on_floor():
		persistent_state.velocity.y += 980.0 * delta # Adjust gravity strength as needed
		
	persistent_state.move_and_slide()
	
	if persistent_state.is_on_wall_only() or persistent_state.is_on_ceiling():
		if persistent_state.is_on_ceiling():
			change_state.call("fall")

func setup(change_state, animated_sprite, persistent_state):
	self.change_state = change_state
	self.animated_sprite = animated_sprite
	self.persistent_state = persistent_state

func move_left():
	pass

func move_right():
	pass
