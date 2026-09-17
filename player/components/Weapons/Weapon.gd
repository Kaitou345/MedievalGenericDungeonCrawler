extends Node
class_name Weapon

## Base for every weapon. Concrete weapons (Shotgun, AssaultRifle, Railgun)
## extend this and override `_fire()`. Ammo is deliberately NOT refilled by
## any timer here — the only way to refill is WeaponManager.add_ammo_to_current(),
## which the Parry system calls on a successful parry. That's the whole
## economic loop: shoot, run dry, parry to refuel.

signal fired
signal ammo_changed(current: int, max: int)
signal out_of_ammo

@export var weapon_name: String = "Weapon"
@export var max_ammo: int = 10
@export var fire_cooldown: float = 0.3
@export var damage: int = 1
@export var projectile_scene: PackedScene

var current_ammo: int = 0
var _cooldown_timer: float = 0.0


func _ready() -> void:
	current_ammo = max_ammo


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func can_fire() -> bool:
	return _cooldown_timer <= 0.0 and current_ammo > 0


## Attempts to fire once. Returns true if it actually fired.
func try_fire(muzzle_position: Vector2, direction: Vector2) -> bool:
	if not can_fire():
		if current_ammo <= 0:
			out_of_ammo.emit()
		return false
	_fire(muzzle_position, direction)
	_cooldown_timer = fire_cooldown
	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)
	fired.emit()
	return true


func add_ammo(amount: int) -> void:
	var new_ammo: int = current_ammo + amount
	if new_ammo > max_ammo:
		new_ammo = max_ammo
	current_ammo = new_ammo
	ammo_changed.emit(current_ammo, max_ammo)


## Override in subclasses: spawn whatever projectile(s) this weapon fires.
func _fire(_muzzle_position: Vector2, _direction: Vector2) -> void:
	pass


## Shared helper every weapon subclass can use to spawn one projectile.
## `angle_offset` (radians) lets shotgun-style spread reuse this directly.
func _spawn_projectile(muzzle_position: Vector2, direction: Vector2, angle_offset: float = 0.0) -> void:
	if projectile_scene == null:
		push_warning("%s: no projectile_scene assigned." % weapon_name)
		return
	var proj := projectile_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(proj)
	proj.global_position = muzzle_position
	var fire_dir: Vector2 = direction.rotated(angle_offset)
	if proj.has_method("launch"):
		proj.call("launch", fire_dir)
	# Use set() rather than a direct property assignment: proj is statically
	# typed as Node2D, which doesn't declare `damage` — only Projectile.gd
	# does. set() is always valid on any Object, so this compiles safely
	# regardless of which scene is plugged into projectile_scene.
	proj.set("damage", damage)
