extends Enemy
class_name Blinker

## Level 3 enemy. Teleports to a random point near the player at normal
## speed (deliberately hard to track), pauses briefly, then lunges.
## This is the enemy that makes slow-mo feel necessary rather than optional —
## at 1x speed the blink-to-lunge window is intentionally tight.

@export var teleport_interval: float = 1.2
@export var teleport_radius: float = 120.0
@export var min_teleport_distance: float = 60.0
@export var lunge_speed: float = 260.0
@export var lunge_duration: float = 0.3

var _player: Node2D = null
var _teleport_timer: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _lunge_timer: float = 0.0


func _ready() -> void:
	super._ready()
	gravity_scale = 0.0  # floats; teleport-and-lunge doesn't need ground physics
	_player = get_tree().get_first_node_in_group("player") as Node2D
	_teleport_timer = teleport_interval


func _on_patrol(delta: float) -> void:
	velocity = Vector2.ZERO
	_teleport_timer -= delta
	if _teleport_timer <= 0.0:
		_teleport_near_player()
		_teleport_timer = teleport_interval


func _teleport_near_player() -> void:
	if _player == null:
		return
	var attempt := 0
	var new_pos := global_position
	# Pick a point in an annulus around the player so it doesn't spawn
	# on top of them or absurdly far away.
	while attempt < 8:
		var angle := randf() * TAU
		var dist := randf_range(min_teleport_distance, teleport_radius)
		new_pos = _player.global_position + Vector2(cos(angle), sin(angle)) * dist
		attempt += 1
		break  # single attempt is fine for a jam; loop left in for easy raycast validation later
	global_position = new_pos
	if sprite:
		sprite.modulate = Color(0.7, 0.7, 1.0)
		var t := create_tween()
		t.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	state = State.TELEGRAPH
	_telegraph_timer = _telegraph_duration()


func _telegraph_duration() -> float:
	return 0.35  # this is the "punish window" — short on purpose


func _do_attack() -> void:
	if _player == null:
		return
	_lunge_dir = (_player.global_position - global_position).normalized()
	_lunge_timer = lunge_duration
	state = State.ATTACK


func _state_attack(delta: float) -> void:
	velocity = _lunge_dir * lunge_speed
	_lunge_timer -= delta
	if _lunge_timer <= 0.0:
		state = State.PATROL
