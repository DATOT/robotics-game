extends Node2D
class_name Ray

@onready var raycast: RayCast2D = $RayCast2D
@onready var line: Line2D = $Line
@onready var particles: CPUParticles2D = $Particles

const RAY_LENGTH := 350.0
const REFLECTION_LIMIT := 15
const RAY_SPEED := 1000.0 # Pixels per second
const DAMAGE_DELAY := 0.15
const MAX_BEAM_DISTANCE := RAY_LENGTH * (REFLECTION_LIMIT + 1)

var points: Array[Vector2] = []
var beam_distance := 0.0   # head: how far the beam has been emitted
var erase_distance := 0.0  # tail: how far the erase has travelled along the path
var path_length := 0.0     # actual length of the current path
var damage_elapsed := 0.0
var is_erasing := false

func fire_and_reflect(
	time: int,
	global_from: Vector2,
	direction: float,
	distance_left: float,
	delta: float,
	apply_damage: bool = true
) -> void:
	if time > REFLECTION_LIMIT or distance_left <= 0.0:
		return

	var dir_vector := Vector2.from_angle(direction)
	var segment_length := minf(distance_left, RAY_LENGTH)

	raycast.global_position = global_from
	raycast.target_position = raycast.to_local(
		global_from + dir_vector * segment_length
	)
	raycast.force_raycast_update()

	if not raycast.is_colliding():
		points.push_back(to_local(global_from + dir_vector * segment_length))
		return

	var collision_point := raycast.get_collision_point()
	points.push_back(to_local(collision_point))

	var collided_object: Object = raycast.get_collider()

	if apply_damage and collided_object.has_method("detect_light"):
		damage_elapsed += delta
		if damage_elapsed >= DAMAGE_DELAY:
			collided_object.detect_light()
	
	if apply_damage and collided_object.has_method("take_damage"):
		damage_elapsed += delta
		if damage_elapsed >= DAMAGE_DELAY:
			collided_object.take_damage(1)

	var distance_to_collision := global_from.distance_to(collision_point)
	var remaining_distance := distance_left - distance_to_collision
	if remaining_distance <= 0.0:
		return

	if not collided_object is StaticBody2D:
		return
	if collided_object.get("canReflect") != true:
		return

	if collided_object.get("reflectOneWay") == true:
		var surface_forward := Vector2.RIGHT.rotated(collided_object.global_rotation)

		if dir_vector.dot(surface_forward) >= 0.0:
			var next_from := collision_point + dir_vector * 0.01
			fire_and_reflect(
				time + 1,
				next_from,
				direction,
				remaining_distance,
				delta,
				apply_damage
			)
			return

	var normal := raycast.get_collision_normal()
	var reflected := dir_vector.bounce(normal)
	var next_from := collision_point + reflected * 0.01
	fire_and_reflect(
		time + 1,
		next_from,
		reflected.angle(),
		remaining_distance,
		delta,
		apply_damage
	)

func _refresh_ray(delta: float, apply_damage: bool = true) -> void:
	points = [Vector2.ZERO]
	fire_and_reflect(
		0,
		global_position,
		global_rotation,
		beam_distance,
		delta,
		apply_damage
	)

	path_length = _polyline_length(points)

	# The tail can never pass the end of the path
	erase_distance = minf(erase_distance, path_length)

	var visible_points := _trim_start(points, erase_distance)
	line.points = visible_points

	if beam_distance > 0.0 and not visible_points.is_empty():
		particles.global_position = to_global(visible_points[-1])
		particles.emitting = true
	else:
		particles.emitting = false


func _head_reached_end() -> bool:
	# The path ended early (wall / non-reflective hit / no collision),
	# or the beam hit its maximum distance.
	return path_length < beam_distance - 0.5 or beam_distance >= MAX_BEAM_DISTANCE


func _polyline_length(pts: Array[Vector2]) -> float:
	var total := 0.0
	for i in range(pts.size() - 1):
		total += pts[i].distance_to(pts[i + 1])
	return total

func _trim_start(pts: Array[Vector2], dist: float) -> Array[Vector2]:
	if dist <= 0.0 or pts.size() < 2:
		return pts

	var result: Array[Vector2] = []
	var remaining := dist

	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]

		if not result.is_empty():
			result.push_back(b)
			continue

		var seg := a.distance_to(b)

		if remaining >= seg:
			remaining -= seg
			continue

		result.push_back(a.lerp(b, remaining / seg))
		result.push_back(b)

	return result


func erase_ray() -> void:
	is_erasing = true


func _physics_process(delta: float) -> void:
	beam_distance = minf(beam_distance + RAY_SPEED * delta, MAX_BEAM_DISTANCE)

	if is_erasing:
		erase_distance += RAY_SPEED * delta

	_refresh_ray(delta)
	#print("Erase distance: {0} ; Path length: {1}".format([erase_distance, path_length]))

	if is_erasing and _head_reached_end() and erase_distance >= path_length:
		particles.emitting = false
		queue_free()
