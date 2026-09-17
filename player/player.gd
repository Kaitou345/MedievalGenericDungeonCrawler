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
@export var parry_effect_scene: PackedScene # Drag ParryEffect.tscn here in the Inspector

@export_group("Audio Effects")
@export var run_sfx: AudioStream
@export var jump_sfx: AudioStream
@export var land_sfx: AudioStream
@export var dash_sfx: AudioStream
@export var slam_sfx: AudioStream
@export var hurt_sfx: AudioStream
@export var die_sfx: AudioStream
@export var shotgun_sfx: AudioStream
@export var step_interval: float = 0.35 # Frequency of footstep sounds in seconds

var current_health: float
var is_dead: bool = false
var is_staggered: bool = false
var _step_timer: float = 0.0

@onready var movement_x: Node = $MovementX
@onready var movement_y: Node = $MovementY
@onready var dash: Dash = $Dash if has_node("Dash") else null
@onready var ground_slam: Node = $GroundSlam if has_node("GroundSlam") else null
@onready var parry: Parry = $Parry if has_node("Parry") else null
@onready var stamina: Stamina = $Stamina if has_node("Stamina") else null
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx_player: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)

func _physics_process(delta: float) -> void:
	if is_dead or is_staggered:
		velocity.x = 0.0
		_stop_run_sfx()
		if not is_on_floor():
			velocity.y += 980.0 * delta
		move_and_slide()
		return

	_sync_ability_states()

	if parry_enabled:
		_handle_parry_input()

	var facing_dir: float = movement_x.facing if movement_x else 1.0

	# Track previous state for landing audio
	var previously_on_floor := is_on_floor()

	if dash and dash_enabled:
		var was_dashing := dash.is_dashing
		dash.try_start(facing_dir, stamina)
		if not was_dashing and dash.is_dashing:
			_play_sfx(dash_sfx)

	if dash and dash.is_dashing:
		dash.apply(self, delta)
	elif ground_slam_enabled and ground_slam and ground_slam.is_slamming:
		var was_slamming: bool = ground_slam.is_slamming
		ground_slam.apply(self, delta)
		if not was_slamming and ground_slam.is_slamming:
			_play_sfx(slam_sfx)
	else:
		if ground_slam_enabled and ground_slam and not is_on_floor():
			ground_slam.try_start(self)

		if movement_x:
			movement_x.apply(self, delta)

		if movement_y:
			movement_y.apply(self, delta, facing_dir)
			
			# Play jump sound on press ONLY if grounded OR if double jump is enabled
			if Input.is_action_just_pressed("jump") and velocity.y < 0.0:
				if previously_on_floor or double_jump_enabled:
					_play_sfx(jump_sfx)

	move_and_slide()

	# Landing Sound Trigger
	if not previously_on_floor and is_on_floor():
		_play_sfx(land_sfx)

	# Strict Grounded Footstep Sound Loop
	var is_moving_grounded: bool = is_on_floor() and abs(velocity.x) > 10.0
	var is_special_action: bool = (dash and dash.is_dashing) or (ground_slam and ground_slam.is_slamming)

	if is_moving_grounded and not is_special_action:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_play_sfx(run_sfx)
			_step_timer = step_interval
	else:
		_stop_run_sfx()
		_step_timer = 0.0

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

func _play_sfx(stream: AudioStream) -> void:
	if not stream:
		return
	if sfx_player:
		sfx_player.stream = stream
		sfx_player.play()
	else:
		var temp_player := AudioStreamPlayer2D.new()
		temp_player.stream = stream
		temp_player.global_position = global_position
		get_tree().current_scene.add_child(temp_player)
		temp_player.play()
		temp_player.finished.connect(temp_player.queue_free)

func _stop_run_sfx() -> void:
	if sfx_player and sfx_player.playing and sfx_player.stream == run_sfx:
		sfx_player.stop()

func play_shotgun_sfx() -> void:
	_play_sfx(shotgun_sfx)

func _sync_ability_states() -> void:
	if dash:
		dash.enabled = dash_enabled
	if ground_slam:
		ground_slam.set("enabled", ground_slam_enabled)
	if movement_y:
		movement_y.set_max_jumps(2 if double_jump_enabled else 1)

func _handle_parry_input() -> void:
	if is_dead or not parry:
		return
		
	if Input.is_action_just_pressed("parry"):
		parry.start_parry()
		
		if parry_effect_scene:
			var effect = parry_effect_scene.instantiate() as Node2D
			if effect:
				var facing_dir: float = movement_x.facing if movement_x else 1.0
				effect.global_position = global_position + Vector2(facing_dir * 25.0, -10.0)
				get_tree().current_scene.add_child(effect)

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

func take_damage_from_enemy(amount: float, source_position: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0 or is_dead:
		return

	if parry and parry.monitoring:
		print("Parry active! Negating damage.")
		return

	current_health = max(0.0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)
	_flash_hit()

	if current_health <= 0:
		_die()
	else:
		_play_sfx(hurt_sfx)
		_handle_ability_swap()

		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("hurt"):
			is_staggered = true
			animated_sprite.play("hurt")
			await animated_sprite.animation_finished
			if not is_dead:
				is_staggered = false

func _handle_ability_swap() -> void:
	var disabled_abilities: Array[String] = []
	if not dash_enabled: disabled_abilities.append("dash")
	if not double_jump_enabled: disabled_abilities.append("double_jump")
	if not parry_enabled: disabled_abilities.append("parry")
	
	if not disabled_abilities.is_empty():
		disabled_abilities.shuffle()
		set_ability_enabled(disabled_abilities[0], true)
		emit_signal("ability_restored", disabled_abilities[0])
	
	var updated_active: Array[String] = []
	if dash_enabled: updated_active.append("dash")
	if double_jump_enabled: updated_active.append("double_jump")
	if parry_enabled: updated_active.append("parry")
	
	if not updated_active.is_empty():
		updated_active.shuffle()
		set_ability_enabled(updated_active[0], false)
		emit_signal("ability_lost", updated_active[0])

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
	_play_sfx(die_sfx)
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished
		
	emit_signal("player_died")
