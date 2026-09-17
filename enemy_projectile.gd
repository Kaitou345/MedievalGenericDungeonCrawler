extends Area2D
class_name EnemyProjectile

@export var speed: float = 300.0
@export var damage: float = 10.0
var direction: Vector2 = Vector2.ZERO
var shooter: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation("default"):
			sprite.play("default")
		elif sprite.sprite_frames.has_animation("fly"):
			sprite.play("fly")

func setup(dir: Vector2, p_shooter: Node2D = null) -> void:
	direction = dir.normalized()
	rotation = direction.angle()
	shooter = p_shooter

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body is Player or body.is_in_group("player"):
		# Check if player is parrying
		if body.has_node("Parry") and body.get_node("Parry").monitoring:
			print("Projectile parried! Negated without staggering shooter.")
			queue_free() # Simply destroys the projectile on parry (or you can code a reflection here)
			return
			
		# Normal damage if the player is not parrying
		if body.has_method("take_damage_from_enemy"):
			body.take_damage_from_enemy(damage, global_position)
		queue_free()
		
	elif body.is_in_group("tilemap") or body.name.to_lower().contains("tilemap"):
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
