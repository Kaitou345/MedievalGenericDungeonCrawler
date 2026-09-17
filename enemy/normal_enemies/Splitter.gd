extends Enemy
class_name Splitter

## Level 3 enemy. Ordinary walker in life, but death starts a short fuse
## before it explodes in an AoE. If the player is caught in the blast,
## the intended "out" is a rewind — the fuse is deliberately too short to
## just walk away from at range, but easily undone with a rewind charge.

@export var fuse_time: float = 0.8
@export var explosion_radius: float = 70.0
@export var explosion_damage: int = 2
@export var patrol_distance: float = 60.0

var _patrol_origin: float
var _patrol_dir: int = 1


func _ready() -> void:
	super._ready()
	_patrol_origin = global_position.x


func _on_patrol(delta: float) -> void:
	velocity.x = _patrol_dir * move_speed
	if abs(global_position.x - _patrol_origin) >= patrol_distance:
		_patrol_dir *= -1


func _die() -> void:
	# Don't queue_free immediately like the base class — we need to survive
	# (invisibly/inertly) long enough to detonate. Skip Enemy's _die() logic.
	state = State.DEAD
	died.emit(points_value, global_position)
	set_physics_process(false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	if sprite:
		sprite.modulate = Color(1, 0.3, 0.3)

	var timer := get_tree().create_timer(fuse_time)
	timer.timeout.connect(_detonate)


func _detonate() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and global_position.distance_to(player.global_position) <= explosion_radius:
		if player.has_method("take_damage_from_enemy"):
			player.call("take_damage_from_enemy", explosion_damage, global_position)
	# Hook your explosion VFX/SFX here before freeing.
	queue_free()
