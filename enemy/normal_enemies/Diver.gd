extends Enemy
class_name Diver

## Level 2 enemy. Hovers above the arena, tracks the player's X position,
## then telegraphs and slams straight down. The slam is intentionally
## un-dodgeable with X-movement alone — you must jump away or be elsewhere
## vertically. This is the enemy that "requires" the Y-axis unlock.

@export var hover_height: float = 170.0
@export var dive_speed: float = 500.0
@export var slam_radius: float = 48.0
@export var slam_damage: int = 1
@export var reposition_speed: float = 90.0
@export var attack_range_x: float = 20.0  # how close to player's X before diving
@export var attack_height_tolerance: float = 24.0  # must be near hover height to dive
@export var attack_cooldown: float = 1.0  # forces real time in PATROL between dives

var _player: Node2D = null
var _home_y: float
var _has_landed: bool = false
var _cooldown_timer: float = 0.0


func _ready() -> void:
	super._ready()
	gravity_scale = 0.0  # flies, ignores normal gravity in base class
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_home_y = global_position.y - hover_height


func _on_patrol(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	if _player == null:
		print("No player found")
		return
	# Return to hover height, track player's X while airborne.
	var target := Vector2(_player.global_position.x, _home_y)
	var to_target := target - global_position
	velocity = (to_target.normalized() * reposition_speed) if to_target.length() > 4 else Vector2.ZERO


func _should_attack() -> bool:
	if _player == null or _cooldown_timer > 0.0:
		return false
	var x_aligned : float = abs(global_position.x - _player.global_position.x) <= attack_range_x

	return x_aligned


func _telegraph_duration() -> float:
	return 0.6  # long wind-up — this is the "get out of the way" window


func _on_telegraph_start() -> void:
	if sprite:
		sprite.modulate = Color(1, 0.8, 0.5)


func _do_attack() -> void:
	_has_landed = false
	velocity = Vector2(0, dive_speed)


func _state_attack(delta: float) -> void:
	# Override base: hold ATTACK state until we actually hit the floor,
	# since the dive takes real time to resolve (unlike an instant projectile).
	if is_on_floor() and not _has_landed:
		_has_landed = true
		_on_slam_impact()
	elif is_on_floor() and _has_landed:
		state = State.PATROL
		_cooldown_timer = attack_cooldown
		if sprite:
			sprite.modulate = Color.WHITE


func _on_slam_impact() -> void:
	# Simple overlap check for AoE damage. Swap for an Area2D + shape if
	# you want visual-accurate hit detection instead of a raw distance check.
	if _player and global_position.distance_to(_player.global_position) <= slam_radius:
		if _player.has_method("take_damage_from_enemy"):
			_player.call("take_damage_from_enemy", slam_damage, global_position)
	if sprite:
		var t := create_tween()
		t.tween_property(sprite, "scale", sprite.scale * 1.4, 0.08)
		t.tween_property(sprite, "scale", sprite.scale, 0.12)
