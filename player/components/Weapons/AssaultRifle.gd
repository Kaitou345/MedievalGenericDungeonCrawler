extends Weapon
class_name AssaultRifle

## Rapid, low-damage-per-shot, moderate ammo. This is the "default,
## always-available" weapon — set a low fire_cooldown (e.g. 0.12) so
## holding fire feels automatic rather than semi-auto.

@export var spread_degrees: float = 2.0


func _fire(muzzle_position: Vector2, direction: Vector2) -> void:
	var jitter: float = deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	_spawn_projectile(muzzle_position, direction, jitter)
