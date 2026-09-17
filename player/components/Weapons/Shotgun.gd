extends Weapon
class_name Shotgun

## Multiple pellets across a spread cone. Low ammo capacity is expected —
## set max_ammo low (e.g. 4-6) in the Inspector so it feels like a
## high-commitment, close-range panic button rather than a main weapon.

@export var pellet_count: int = 5
@export var spread_angle_degrees: float = 40.0


func _fire(muzzle_position: Vector2, direction: Vector2) -> void:
	var half_spread: float = deg_to_rad(spread_angle_degrees) * 0.5
	for i in pellet_count:
		var t: float = 0.5
		if pellet_count > 1:
			t = float(i) / float(pellet_count - 1)
		var angle_offset: float = lerpf(-half_spread, half_spread, t)
		_spawn_projectile(muzzle_position, direction, angle_offset)
