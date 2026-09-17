extends CharacterBody2D
class_name FireBoss

signal health_changed(current_hp: float, max_hp: float)
signal boss_defeated

enum State { IDLE, CHASE, ATTACK, RECOVER }

@export_group("Boss Stats")
@export var max_health: float = 300.0
@export var move_speed: float = 140.0
@export var attack_damage: float = 25.0
@export var attack_range: float = 75.0
@export var attack_cooldown: float = 1.2

@export_group("Hitbox Settings")
## How far forward the hitbox shifts when facing a direction (in pixels)
@export var hitbox_offset_x: float = 45.0 

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var attack_hitbox: Area2D = $Hitbox if has_node("Hitbox") else null
@onready var attack_shape: CollisionShape2D = $Hitbox/CollisionShape2D if has_node("Hitbox/CollisionShape2D") else null

var current_health: float
var current_state: State = State.IDLE
var target_player: CharacterBody2D = null
var facing_dir: float = -1.0
var _can_attack: bool = true


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	current_health = max_health
	
	# Prevent players from physically pushing the boss body
	motion_mode = MOTION_MODE_GROUNDED
	set_collision_mask_value(1, false)
	
	# Connect the hitbox signal programmatically for reliable collision detection
	if attack_hitbox:
		attack_hitbox.monitoring = false
		if not attack_hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			attack_hitbox.body_entered.connect(_on_hitbox_body_entered)
			
	if attack_shape:
		attack_shape.set_deferred("disabled", false)
		
	emit_signal("health_changed", current_health, max_health)
	_find_player()


func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return

	if not target_player:
		_find_player()

	# Gravity
	if not is_on_floor():
		velocity.y += 980.0 * delta

	match current_state:
		State.IDLE:
			velocity.x = 0.0
			_play_anim("idle")
			if target_player:
				current_state = State.CHASE

		State.CHASE:
			_handle_chase()

		State.ATTACK, State.RECOVER:
			velocity.x = 0.0

	move_and_slide()


func _handle_chase() -> void:
	if not target_player:
		current_state = State.IDLE
		return

	var dist_vec := target_player.global_position - global_position
	var dist_x := dist_vec.x
	
	facing_dir = sign(dist_x) if dist_x != 0 else facing_dir
	
	if sprite:
		sprite.flip_h = (facing_dir > 0)
		
	# Clean Position Flip: Shifts the local X position forward based on facing direction
	if attack_hitbox:
		attack_hitbox.position.x = hitbox_offset_x * facing_dir

	# Attack range check
	if abs(dist_x) <= attack_range:
		if _can_attack:
			_execute_attack()
		else:
			_play_anim("idle")
			velocity.x = 0.0
	else:
		velocity.x = facing_dir * move_speed
		_play_anim("walk")


func _execute_attack() -> void:
	current_state = State.ATTACK
	_can_attack = false
	velocity.x = 0.0
	
	_play_anim("attack")
	
	# Wind-up delay before swing impact
	await get_tree().create_timer(1.2).timeout
	
	# Enable hitbox monitoring for the active strike window
	if attack_hitbox:
		attack_hitbox.monitoring = true

	# Active swing duration window
	await get_tree().create_timer(0.15).timeout

	# Disable monitoring after strike frame ends
	if attack_hitbox:
		attack_hitbox.monitoring = false

	current_state = State.RECOVER
	
	# Recovery wind-down
	await get_tree().create_timer(0.4).timeout
	current_state = State.CHASE
	
	# Attack cooldown
	await get_tree().create_timer(attack_cooldown).timeout
	_can_attack = true


func _on_hitbox_body_entered(body: Node2D) -> void:
	if current_health > 0 and body.is_in_group("player") and body.has_method("take_damage_from_enemy"):
		body.take_damage_from_enemy(attack_damage, global_position)


func take_damage(amount: float, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0:
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


func _play_anim(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0] as CharacterBody2D
func stagger_from_parry() -> void:
	if current_health <= 0:
		return

	# Force the boss into a recovery/stun state and stop movement
	current_state = State.RECOVER
	velocity.x = 0.0
	_can_attack = false
	
	# Optional: Give visual feedback like flashing white or red
	_flash_hit()

	# Play the staggered animation if it exists in your SpriteFrames
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("staggered"):
		sprite.play("staggered")
		await sprite.animation_finished
	else:
		# Fallback duration if the animation isn't created yet
		await get_tree().create_timer(0.8).timeout

	# Resume normal chase behavior after the stagger window ends
	if current_health > 0:
		current_state = State.CHASE
		
	# Wait for the normal attack cooldown before letting it strike again
	await get_tree().create_timer(attack_cooldown).timeout
	_can_attack = true

func _die() -> void:
	emit_signal("boss_defeated")
	set_physics_process(false)
	
	if attack_hitbox:
		attack_hitbox.monitoring = false
		
	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
		
	queue_free()
