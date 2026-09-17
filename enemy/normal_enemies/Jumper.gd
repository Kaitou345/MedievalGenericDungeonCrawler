extends Enemy
class_name Jumper

## Level 2 enemy. Walks toward the player, hops periodically to close distance,
## and triggers a close-range attack when within reach.

@export var hop_interval: float = 1.4
@export var hop_force_x: float = 180.0
@export var hop_force_y: float = 340.0
@export var detect_range: float = 1400.0

@export_group("Melee Attack")
@export var attack_range: float = 50.0      # Trigger range for close-quarters attack
@export var attack_lunge_x: float = 250.0   # Forward surge during attack
@export var attack_cooldown: float = 1.2

var _player: Node2D = null
var _hop_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0


func _ready() -> void:
	super._ready()
	move_speed = 45.0  # Slow ground shuffle toward player
	_hop_timer = hop_interval
	_find_player()


func _find_player() -> void:
	if not is_instance_valid(_player):
		var found_node := get_tree().get_first_node_in_group("player")
		if found_node:
			# Handles case where "player" group is on parent Node2D instead of CharacterBody2D
			if found_node is CharacterBody2D:
				_player = found_node as Node2D
			elif found_node.has_node("CharacterBody2D"):
				_player = found_node.get_node("CharacterBody2D") as Node2D
			else:
				_player = found_node as Node2D


func _on_patrol(delta: float) -> void:
	_find_player()
	
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta

	if not is_instance_valid(_player):
		velocity.x = 0
		return

	var dist := global_position.distance_to(_player.global_position)
	var dir: float = sign(_player.global_position.x - global_position.x)

	# Only move/hop if within detection range
	if dist <= detect_range:
		# Ground shuffle toward player if on the floor
		if is_on_floor():
			velocity.x = dir * move_speed

		# Handle periodic hop
		_hop_timer -= delta
		if _hop_timer <= 0.0 and is_on_floor():
			_hop(dir)
	else:
		velocity.x = 0
		_hop_timer = hop_interval  # Reset timer outside detection range


func _should_attack() -> bool:
	_find_player()
	if not is_instance_valid(_player) or _attack_cooldown_timer > 0.0:
		return false

	var dist := global_position.distance_to(_player.global_position)
	return dist <= attack_range


func _telegraph_duration() -> float:
	return 0.35  # Short wind-up before close-range lunge


func _on_telegraph_start() -> void:
	# Flash red during attack wind-up
	if sprite:
		sprite.modulate = Color(1.0, 0.3, 0.3)


func _do_attack() -> void:
	if not is_instance_valid(_player):
		return

	# Perform a sharp forward lunge toward the player
	var dir: float = sign(_player.global_position.x - global_position.x)
	if dir == 0:
		dir = facing
		
	velocity.x = dir * attack_lunge_x
	
	# Apply contact damage manually if player is within strike distance at attack frame
	if global_position.distance_to(_player.global_position) <= attack_range * 1.2:
		if _player.has_method("take_damage_from_enemy"):
			_player.call("take_damage_from_enemy", contact_damage, global_position)


func _state_attack(_delta: float) -> void:
	# Hold attack state briefly before returning to patrol/movement
	_attack_cooldown_timer = attack_cooldown
	state = State.PATROL
	if sprite:
		sprite.modulate = Color.WHITE


func _hop(dir: float) -> void:
	velocity.x = dir * hop_force_x
	velocity.y = -hop_force_y
	_hop_timer = hop_interval
	if sprite:
		var t := create_tween()
		t.tween_property(sprite, "scale:y", sprite.scale.y * 1.3, 0.1)
		t.tween_property(sprite, "scale:y", Vector2.ONE.y, 0.15)
