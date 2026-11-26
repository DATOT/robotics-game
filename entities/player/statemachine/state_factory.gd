class_name StateFactory

var states: Dictionary

func _init() -> void:
	states = {
		"idle": IdleState,
		"move": MoveState,
		"ceiling": CeilingState,
		"fall": FallState,
		"laser": LaserState,
		"damage": DamageState
	}

func get_state(state_name: String):
	if states.has(state_name):
		return states[state_name]

	printerr("No state ", state_name, " in state factory!")
	return null
