extends Enemy
class_name Walker

## Level 1 enemy. Paces between two points and reverses at ledges/walls.
## No ranged attack — pure spacing/contact-damage lesson. This is your
## simplest possible enemy; good first one to get fully working.

@export var patrol_distance: float = 80.0

var _patrol_origin: float
var _patrol_dir: int = 1


func _ready() -> void:
	super._ready()
	_patrol_origin = global_position.x


func _on_patrol(delta: float) -> void:
	velocity.x = _patrol_dir * move_speed

	var traveled := global_position.x - _patrol_origin
	if abs(traveled) >= patrol_distance:
		_patrol_dir *= -1

	# Reverse at ledges so it doesn't walk off platforms.
	if is_on_floor() and not _has_floor_ahead():
		_patrol_dir *= -1


func _has_floor_ahead() -> bool:
	# Simple raycast-free ledge check using a small forward offset probe.
	# Swap for a RayCast2D node if you want more reliable ledge detection.
	var probe := global_position + Vector2(_patrol_dir * 12, 20)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(probe, probe + Vector2(0, 10))
	var result := space_state.intersect_ray(query)
	return result.size() > 0
