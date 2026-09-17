extends Weapon
class_name Railgun

## Hold-to-charge, high-damage, piercing shot. Set max_ammo very low (1-2)
## in the Inspector — this is meant to feel precious. Releasing the fire
## button before charge_time completes cancels the shot without consuming
## ammo, which is the intended risk/reward: committing to a charge in the
## middle of a fight is dangerous.

@export var charge_time: float = 0.6
@export var pierce_count: int = 5  # how many enemies a shot passes through before stopping

var _charging: bool = false
var _charge_timer: float = 0.0
var _charge_muzzle: Vector2 = Vector2.ZERO
var _charge_direction: Vector2 = Vector2.RIGHT


func is_charging() -> bool:
	return _charging


func charge_progress() -> float:
	if charge_time <= 0.0:
		return 1.0
	return clampf(_charge_timer / charge_time, 0.0, 1.0)


## Call once when the fire button is first pressed.
func start_charge(muzzle_position: Vector2, direction: Vector2) -> bool:
	if not can_fire():
		if current_ammo <= 0:
			out_of_ammo.emit()
		return false
	_charging = true
	_charge_timer = 0.0
	_charge_muzzle = muzzle_position
	_charge_direction = direction
	return true


## Call every frame the fire button stays held. Returns true the frame it
## actually fires (fully charged).
func update_charge(delta: float, muzzle_position: Vector2, direction: Vector2) -> bool:
	if not _charging:
		return false
	_charge_timer += delta
	_charge_muzzle = muzzle_position
	_charge_direction = direction
	if _charge_timer >= charge_time:
		_release_charge()
		return true
	return false


## Call when the fire button is released early — cancels with no ammo cost.
func cancel_charge() -> void:
	_charging = false
	_charge_timer = 0.0


func _release_charge() -> void:
	_charging = false
	try_fire(_charge_muzzle, _charge_direction)


func _fire(muzzle_position: Vector2, direction: Vector2) -> void:
	if projectile_scene == null:
		push_warning("%s: no projectile_scene assigned." % weapon_name)
		return
	var proj := projectile_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(proj)
	proj.global_position = muzzle_position
	if proj.has_method("launch"):
		proj.call("launch", direction)
	proj.set("damage", damage)
	proj.set("pierce_count", pierce_count)
