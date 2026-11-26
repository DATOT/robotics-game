extends Node2D
class_name Laser

@export var raysCount: int = 0
const RAY_SCN = preload("res://interactables/laser/ray/ray.tscn")

var rays: Array[Ray] = []
var is_firing = false

func erase_rays() -> void:
	is_firing = false
	for ray in rays:
		ray.erase_ray()
	rays.clear()

func fire_rays() -> void:
	is_firing = true
	for i in range(raysCount):
		var new_ray: Ray = RAY_SCN.instantiate()
		new_ray.position = Vector2(0, i)
		self.add_child(new_ray)
		rays.push_back(new_ray)
