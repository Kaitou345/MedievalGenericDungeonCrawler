extends Area2D
class_name Projectile

## Shared projectile for both the player's weapons AND enemy ranged attacks.
## Controlled via `is_enemy_projectile`. Destroys on world terrain and enemies/players.

@export var speed: float = 600.0
@export var damage: int = 1
@export var lifetime: float = 3.0
@export var pierce_count: int = 0  # 0 = dies on first hit; >0 = passes through N targets
@export var is_enemy_projectile: bool = false

var _direction: Vector2 = Vector2.RIGHT
var _pierced: int = 0
var _is_destroying: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var collision: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null


func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("enemy_projectile" if is_enemy_projectile else "player_projectile")
	
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)
	
	body_entered.connect(_on_impact)
	area_entered.connect(_on_impact)


func launch(direction: Vector2) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	if _is_destroying:
		return
		
	global_position += _direction * speed * delta


func _on_impact(target: Node) -> void:
	if _is_destroying or target == self:
		return

	# Ignore self-faction and projectile-to-projectile hits
	if target.is_in_group("projectiles"):
		return
		
	if is_enemy_projectile and (target.is_in_group("enemies") or (target.get_parent() and target.get_parent().is_in_group("enemies"))):
		return
		
	if not is_enemy_projectile and (target.is_in_group("player") or (target.get_parent() and target.get_parent().is_in_group("player"))):
		return

	# Damage Application
	var dealt_damage := false
	
	if is_enemy_projectile:
		if target.has_method("take_damage_from_enemy"):
			target.call("take_damage_from_enemy", damage, global_position)
			dealt_damage = true
		elif target.get_parent() and target.get_parent().has_method("take_damage_from_enemy"):
			target.get_parent().call("take_damage_from_enemy", damage, global_position)
			dealt_damage = true
	else:
		if target.has_method("take_damage"):
			target.call("take_damage", damage, global_position)
			dealt_damage = true
		elif target.get_parent() and target.get_parent().has_method("take_damage"):
			target.get_parent().call("take_damage", damage, global_position)
			dealt_damage = true

	# Always burst on world geometry (Tilemaps, static bodies, objects) OR after piercing limit is reached
	if dealt_damage:
		_consume_pierce_or_die()
	else:
		_destroy()


func _consume_pierce_or_die() -> void:
	_pierced += 1
	if _pierced > pierce_count:
		_destroy()


func _destroy() -> void:
	if _is_destroying:
		return
		
	_is_destroying = true
	
	if collision:
		collision.set_deferred("disabled", true)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("destroy"):
		sprite.play("destroy")
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)
	else:
		queue_free()


func _on_animation_finished() -> void:
	if sprite and sprite.animation == "destroy":
		queue_free()


func _on_lifetime_expired() -> void:
	if is_instance_valid(self) and not _is_destroying:
		queue_free()
