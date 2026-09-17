extends Enemy
class_name Shooter

## Level 1 enemy. Stays put, telegraphs, then fires a horizontal projectile.
## This is the enemy that teaches "you only have X-axis movement, so you
## MUST dash or reposition in time" — the whole point of level 1.

@export var projectile_scene: PackedScene
@export var attack_range: float = 220.0
@export var attack_cooldown: float = 1.6

var _player: Node2D = null
var _cooldown_timer: float = 0.0


func _ready() -> void:
	super._ready()
	move_speed = 0.0  # stationary
	# Simple lookup; swap for a group/autoload reference in your project.
	_player = get_tree().get_first_node_in_group("player") as Node2D


func _on_patrol(delta: float) -> void:
	velocity.x = 0
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func _should_attack() -> bool:
	if _player == null or _cooldown_timer > 0.0:
		return false
	return global_position.distance_to(_player.global_position) <= attack_range


func _telegraph_duration() -> float:
	return 0.5  # generous wind-up — this is your dodge-reaction window


func _on_telegraph_start() -> void:
	if sprite:
		var t := create_tween()
		t.tween_property(sprite, "scale", sprite.scale * 1.15, 0.15)
		t.tween_property(sprite, "scale", sprite.scale, 0.15)


func _do_attack() -> void:
	_cooldown_timer = attack_cooldown
	if projectile_scene == null or _player == null:
		return
	var proj := projectile_scene.instantiate() as Node2D
	get_parent().add_child(proj)
	proj.global_position = global_position
	var dir: float = sign(_player.global_position.x - global_position.x)
	if proj.has_method("launch"):
		proj.call("launch", Vector2(dir, 0))
