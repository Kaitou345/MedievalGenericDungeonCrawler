extends CharacterBody2D
class_name FlyingEnemy

signal health_changed(current_hp: float, max_hp: float)
signal enemy_died

@export_group("Stats")
@export var max_health: float = 30.0
@export var flight_speed: float = 150.0
@export var detection_range: float = 400.0
@export var min_height_above_ground: float = 200.0 # Tweakable minimum height clearance
@export var preferred_combat_distance: float = 250.0 # Personal space buffer to prevent crowding the player

@export_group("Combat")
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 2.0
var can_shoot: bool = true
var is_attacking: bool = false

var current_health: float
var is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var floor_ray: RayCast2D = $FloorRay if has_node("FloorRay") else null

func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health
	emit_signal("health_changed", current_health, max_health)
	
	if floor_ray:
		# Ensure the ray extends past the minimum height threshold
		floor_ray.target_position = Vector2(0, min_height_above_ground + 100)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Freeze completely while executing the attack animation
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var player = _get_player()
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player <= detection_range:
			var target_pos = player.global_position
			
			# 1. Maintain personal space (prevent brushing up against the player)
			var horizontal_dir = (global_position - player.global_position)
			horizontal_dir.y = 0 
			if distance_to_player < preferred_combat_distance:
				target_pos = global_position + horizontal_dir.normalized() * 50.0

			# 2. Enforce minimum height clearance above ground
			if floor_ray and floor_ray.is_colliding():
				var collision_point = floor_ray.get_collision_point()
				var current_height = abs(global_position.y - collision_point.y)
				
				if current_height < min_height_above_ground:
					target_pos.y = collision_point.y - min_height_above_ground

			var direction = (target_pos - global_position).normalized()
			velocity = direction * flight_speed
			
			# Face the player horizontally
			if sprite:
				sprite.flip_h = (player.global_position.x < global_position.x)
				
			# Try shooting
			if can_shoot:
				_shoot_projectile((player.global_position - global_position).normalized())
		else:
			velocity = Vector2.ZERO

		move_and_slide()

	_update_animations()

func _update_animations() -> void:
	if is_dead or is_attacking:
		return

	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("idle") and sprite.animation != "idle":
			sprite.play("idle")

func _get_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null

func _shoot_projectile(dir: Vector2) -> void:
	if not projectile_scene:
		print("ERROR: Projectile Scene is not assigned to the Flyer inspector!")
		return
		
	can_shoot = false
	is_attacking = true
	velocity = Vector2.ZERO
	
	# Play attack animation (ensure Loop is OFF in SpriteFrames)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")
		# Wait until the animation finishes playing its frames
		await sprite.animation_finished
	else:
		# Fallback timer if no attack animation exists
		await get_tree().create_timer(0.4).timeout
		
	# --- PROJECTILE SPAWNS HERE AFTER THE ANIMATION ENDS ---
	var proj = projectile_scene.instantiate() as Node2D
	if proj:
		proj.global_position = global_position + (dir * 40.0) # Spawn offset
		if proj.has_method("setup"):
			proj.setup(dir)
		get_tree().current_scene.add_child(proj)
		
	is_attacking = false
	
	# Cooldown before the flyer can trigger the next attack cycle
	await get_tree().create_timer(attack_cooldown).timeout
	can_shoot = true

func take_damage(amount: float, dir: Vector2) -> void:
	if is_dead:
		return
		
	current_health = max(0.0, current_health - amount)
	emit_signal("health_changed", current_health, max_health)
	_flash_hit()
	
	if current_health <= 0:
		_die()

func _flash_hit() -> void:
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	is_attacking = false
	emit_signal("enemy_died")
	
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	
	queue_free()
