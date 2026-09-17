extends Node
class_name WeaponManager

@export_group("Ammo Settings")
@export var max_ammo: int = 90
@export var current_ammo: int = 90

# Assign child weapon nodes (or weapon resources) in the Inspector
@export_group("Equipped Weapons")
@export var weapon_1_node: Node
@export var weapon_2_node: Node
@export var weapon_3_node: Node

enum WeaponType { ASSAULT_RIFLE, SHOTGUN, RAILGUN }
var active_weapon_type: WeaponType = WeaponType.ASSAULT_RIFLE

var _fire_cooldown_timer: float = 0.0


func _process(delta: float) -> void:
	if _fire_cooldown_timer > 0.0:
		_fire_cooldown_timer -= delta

	_handle_weapon_swapping()
	_handle_firing()


func _handle_weapon_swapping() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		active_weapon_type = WeaponType.ASSAULT_RIFLE
	elif Input.is_action_just_pressed("weapon_2"):
		active_weapon_type = WeaponType.SHOTGUN
	elif Input.is_action_just_pressed("weapon_3"):
		active_weapon_type = WeaponType.RAILGUN


func _handle_firing() -> void:
	var trigger: bool = false
	if active_weapon_type == WeaponType.ASSAULT_RIFLE:
		trigger = Input.is_action_pressed("fire")
	else:
		trigger = Input.is_action_just_pressed("fire")

	if trigger and _fire_cooldown_timer <= 0.0 and current_ammo > 0:
		_shoot()


func _shoot() -> void:
	var current_weapon := _get_active_weapon_node()
	if not current_weapon:
		print("ERROR: Active weapon node not assigned in WeaponManager!")
		return

	# Fetch the weapon's OWN projectile scene
	var proj_scene: PackedScene = current_weapon.get("projectile_scene")
	if not proj_scene:
		# Fallback check for property naming variations (e.g. "projectile_scen")
		proj_scene = current_weapon.get("projectile_scen")

	if not proj_scene:
		print("ERROR: Active weapon is missing a assigned projectile scene!")
		return

	var parent_player := get_parent() as Node2D
	if not parent_player:
		return

	# Determine horizontal facing direction directly from player
	var facing_dir_x: float = 1.0
	if "movement_x" in parent_player and parent_player.movement_x:
		facing_dir_x = parent_player.movement_x.facing

	var spawn_pos: Vector2 = parent_player.global_position
	var aim_dir := Vector2(facing_dir_x, 0.0)

	# Pull weapon parameters or fallback to defaults
	var cooldown: float = current_weapon.get("fire_cooldown") if current_weapon.get("fire_cooldown") else 0.2

	match active_weapon_type:
		WeaponType.ASSAULT_RIFLE:
			if current_ammo >= 1:
				current_ammo -= 1
				_fire_cooldown_timer = cooldown
				_spawn_bullet(proj_scene, spawn_pos, aim_dir)

		WeaponType.SHOTGUN:
			if current_ammo >= 3:
				current_ammo -= 3
				_fire_cooldown_timer = cooldown
				for angle_offset in [-0.2, -0.1, 0.0, 0.1, 0.2]:
					var spread_dir := aim_dir.rotated(angle_offset)
					_spawn_bullet(proj_scene, spawn_pos, spread_dir)

		WeaponType.RAILGUN:
			if current_ammo >= 5:
				current_ammo -= 5
				_fire_cooldown_timer = cooldown
				_spawn_bullet(proj_scene, spawn_pos, aim_dir)


func _spawn_bullet(bullet_scene: PackedScene, pos: Vector2, dir: Vector2) -> void:
	var bullet := bullet_scene.instantiate() as Node2D
	get_tree().root.add_child(bullet)
	bullet.global_position = pos

	bullet.add_to_group("player_projectile")
	bullet.set("is_enemy_projectile", false)

	if "direction" in bullet:
		bullet.set("direction", dir)
	elif "velocity" in bullet:
		bullet.set("velocity", dir * 800.0)
	elif bullet.has_method("launch"):
		bullet.call("launch", dir)


func _get_active_weapon_node() -> Node:
	match active_weapon_type:
		WeaponType.ASSAULT_RIFLE:
			return weapon_1_node
		WeaponType.SHOTGUN:
			return weapon_2_node
		WeaponType.RAILGUN:
			return weapon_3_node
	return null


func add_ammo_to_current(amount: int) -> void:
	current_ammo = min(current_ammo + amount, max_ammo)
