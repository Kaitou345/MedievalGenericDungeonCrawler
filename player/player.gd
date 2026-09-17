extends CharacterBody2D
class_name Player

signal health_changed(current_hp: float, max_hp: float)
signal player_died
signal ability_lost(ability_name: String)
signal ability_restored(ability_name: String)

@export_group("Ability Lock States")
@export var ground_slam_enabled: bool = true
@export var dash_enabled: bool = true
@export var double_jump_enabled: bool = true
@export var parry_enabled: bool = true

@export_group("Player Stats")
@export var max_health: float = 100.0
var current_health: float
var is_dead: bool = false
var is_staggered: bool = false

@onready var movement_x: Node = $MovementX
@onready var movement_y: Node = $MovementY
@onready var dash: Dash = $Dash if has_node("Dash") else null
@onready var ground_slam: Node = $GroundSlam if has_node("GroundSlam") else null
@onready var parry: Parry = $Parry if has_node("Parry") else null
@onready var stamina: Stamina = $Stamina if has_node("Stamina") else null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead or is_staggered:
		velocity.x = 0.0
		if not is_on_floor():
			velocity.y += 980.0 * delta
		move_and_slide()
		return

	_sync_ability_states()

	if parry_enabled:
		_handle_parry_input()

	var facing_dir: float = movement_x.facing if movement_x else 1.0

	if dash and dash_enabled:
		dash.try_start(facing_dir, stamina)

	if dash and dash.is_dashing:
		dash.apply(self, delta)
	elif ground_slam_enabled and ground_slam and ground_slam.is_slamming:
		ground_slam.apply(self, delta)
	else:
		if ground_slam_enabled and ground_slam and not is_on_floor():
			ground_slam.try_start(self)

		if movement_x:
			movement_x.apply(self, delta)

		if movement_y:
			movement_y.apply(self, delta, facing_dir)
			
	move_and_slide()

	_update_sprite_facing()
	_update_sprite_animations()


func _update_sprite_facing() -> void:
	if movement_x and animated_sprite:
		if movement_x.facing < 0:
			animated_sprite.flip_h = true
		elif movement_x.facing > 0:
			animated_sprite.flip_h = false


func _update_sprite_animations() -> void:
	if not animated_sprite or is_dead or is_staggered:
		return

	if ground_slam and ground_slam.is_slamming:
		_play_if_exists("slam")
		return

	if dash and dash.is_dashing:
		_play_if_exists("dash")
		return

	if parry and parry.monitoring:
		_play_if_exists("parry")
		return

	if not is_on_floor():
		if velocity.y < 0:
			_play_if_exists("jump")
		else:
			_play_if_exists("fall")
		return

	if abs(velocity.x) > 10.0:
		_play_if_exists("run")
	else:
		_play_if_exists("idle")


func _play_if_exists(anim_name: String) -> void:
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
		if animated_sprite.animation != anim_name:
			animated_sprite.play(anim_name)


func _sync_ability_states() -> void:
	if dash:
		dash.enabled = dash_enabled
	if ground_slam:
		ground_slam.set("enabled", ground_slam_enabled)
	if movement_y:
		movement_y.set_max_jumps(2 if double_jump_enabled else 1)


func _handle_parry_input() -> void:
	if not parry:
		return

	if Input.is_action_just_pressed("parry"):
		parry.start_parry()


func set_ability_enabled(ability_name: String, active: bool) -> void:
	match ability_name.to_lower():
		"ground_slam", "slam":
			ground_slam_enabled = active
		"dash":
			dash_enabled = active
		"double_jump":
			double_jump_enabled = active
		"parry":
			parry_enabled = active


func set_all_abilities_enabled(active: bool) -> void:
	ground_slam_enabled = active
	dash_enabled = active
	double_jump_enabled = active
	parry_enabled = active


func take_damage_from_enemy(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0 or is_dead:
		return

	# If parry is active, negate damage and stagger the boss instead
	if parry and parry.monitoring:
		print("Parry successful! Negating damage and staggering the boss.")
		for boss in get_tree().get_nodes_in_group("boss"):
			if boss.has_method("stagger_from_parry"):
				boss.stagger_from_parry()
		return

	# Normal damage processing
	current_health = max(0.0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)
	
	_flash_hit()

	if current_health <= 0:
		_die()
	else:
		# Dynamic shuffle: Re-enable an old ability and disable a current one
		_handle_ability_swap()

		# Lock player in hurt stagger for the duration of the animation
		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("hurt"):
			is_staggered = true
			animated_sprite.play("hurt")
			await animated_sprite.animation_finished
			
			if not is_dead:
				is_staggered = false


func _handle_ability_swap() -> void:
	var active_abilities: Array[String] = []
	var disabled_abilities: Array[String] = []
	
	# Ground slam is excluded from the random pool, so we only check dash, double_jump, and parry
	if dash_enabled: active_abilities.append("dash")
	else: disabled_abilities.append("dash")
	
	if double_jump_enabled: active_abilities.append("double_jump")
	else: disabled_abilities.append("double_jump")
	
	if parry_enabled: active_abilities.append("parry")
	else: disabled_abilities.append("parry")
	
	# 1. Re-enable a random disabled ability (excluding Ground Slam)
	if not disabled_abilities.is_empty():
		disabled_abilities.shuffle()
		var restored_ability = disabled_abilities[0]
		set_ability_enabled(restored_ability, true)
		emit_signal("ability_restored", restored_ability)
		print("Hit! Restored ability: ", restored_ability)
	
	# 2. Disable a random active ability (excluding Ground Slam)
	var updated_active: Array[String] = []
	if dash_enabled: updated_active.append("dash")
	if double_jump_enabled: updated_active.append("double_jump")
	if parry_enabled: updated_active.append("parry")
	
	if not updated_active.is_empty():
		updated_active.shuffle()
		var lost_ability = updated_active[0]
		set_ability_enabled(lost_ability, false)
		emit_signal("ability_lost", lost_ability)
		print("Hit! Lost ability: ", lost_ability)
func _flash_hit() -> void:
	if animated_sprite:
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate", Color.RED, 0.05)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.05)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	is_staggered = false
	
	print("Player died.")
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished
		
	emit_signal("player_died")
