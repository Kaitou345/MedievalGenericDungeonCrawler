extends Node
class_name Dash

@export_group("Dash Settings")
@export var dash_distance: float = 200.0
@export var dash_time: float = 0.2
@export var cooldown_time: float = 0.5
@export var dash_stamina_cost: float = 25.0
@export var enabled: bool = true

@export_subgroup("Collision Bypass")
## Collision layer index for enemies in Project Settings (1-indexed, default Layer 2)
@export var enemy_collision_layer: int = 2 

@export_group("Gothic Effects")
@export var ghost_interval: float = 0.04
@export var shadow_color: Color = Color(0.1, 0.0, 0.15, 0.6)
@export var shadow_particles: GPUParticles2D = null
@export var camera: Camera2D = null
@export var shake_intensity: float = 4.0

var is_dashing: bool = false
var _timer: float = 0.0
var _cooldown_timer: float = 0.0
var _ghost_timer: float = 0.0
var _velocity: Vector2 = Vector2.ZERO

@onready var player: CharacterBody2D = get_parent() as CharacterBody2D


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	if is_dashing:
		_timer -= delta
		_ghost_timer -= delta
		
		if _ghost_timer <= 0.0:
			_spawn_ghost_trail()
			_ghost_timer = ghost_interval
			
		if _timer <= 0.0:
			_end_dash()


func try_start(facing: float, stamina: Stamina = null) -> void:
	if not enabled or is_dashing or _cooldown_timer > 0.0:
		return

	if Input.is_action_just_pressed("dash"):
		var active_stamina: Stamina = stamina
		if not active_stamina and get_parent():
			active_stamina = get_parent().get_node_or_null("Stamina") as Stamina

		if active_stamina:
			var success: bool = active_stamina.spend(dash_stamina_cost)
			if not success:
				return

		is_dashing = true
		_timer = dash_time
		_cooldown_timer = cooldown_time
		_ghost_timer = 0.0
		
		var dir := Input.get_axis("move_left", "move_right")
		if dir == 0.0:
			dir = facing
			
		# Linear, fixed-distance velocity override
		_velocity = Vector2(dir * (dash_distance / dash_time), 0.0)
		
		if player:
			# Instantly snap velocity and wipe out falling/jumping gravity momentum
			player.velocity.x = _velocity.x
			player.velocity.y = 0.0
			
			# Disable collision mask for enemies so player phases straight through without pushing
			player.set_collision_mask_value(enemy_collision_layer, false)
		
		_start_dash_effects()


func apply(p: CharacterBody2D, _delta: float) -> void:
	if is_dashing:
		# Lock horizontal velocity to dash speed and freeze vertical movement completely
		p.velocity.x = _velocity.x
		p.velocity.y = 0.0


func _end_dash() -> void:
	is_dashing = false
	
	if shadow_particles:
		shadow_particles.emitting = false
		
	if player:
		# Reset sprite self_modulate back to normal white/default
		if player.has_node("AnimatedSprite2D"):
			var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
			var reset_tween := create_tween()
			reset_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.1)

		# Restore enemy collision detection upon dash exit
		player.set_collision_mask_value(enemy_collision_layer, true)
		
		# Zero out horizontal momentum if no directional keys are held
		if Input.get_axis("move_left", "move_right") == 0.0:
			player.velocity.x = 0.0


# --- Visual & Juice Effects ---

func _start_dash_effects() -> void:
	if shadow_particles:
		shadow_particles.emitting = true

	if player and player.has_node("AnimatedSprite2D"):
		var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
		var tween := create_tween()
		tween.parallel().tween_property(sprite, "modulate", Color(0.5, 0.2, 0.8, 1.0), 0.05)
		tween.parallel().tween_property(sprite, "self_modulate", Color(2.5, 1.5, 3.0, 1.0), 0.05) # Adds a glowing neon tint
		
		tween.tween_property(sprite, "modulate", Color.WHITE, dash_time)

	if camera and camera.has_method("apply_shake"):
		camera.call("apply_shake", shake_intensity)


func _spawn_ghost_trail() -> void:
	if not player or not player.has_node("AnimatedSprite2D"):
		return
		
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	if not sprite.visible:
		return

	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.global_scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = shadow_color

	get_tree().current_scene.add_child(ghost)

	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
