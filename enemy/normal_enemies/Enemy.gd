extends CharacterBody2D
class_name Enemy

## Shared base for every enemy. Concrete enemies (Walker, Shooter, Jumper, etc.)
## extend this and override the virtual functions marked below.
## Keeping all shared logic here means each new enemy type is usually
## <30 lines of code — important for a 7-day scope.

signal died(points_value: int, death_position: Vector2)
signal hurt(amount: int)

@export var max_health: int = 3
@export var contact_damage: int = 1
@export var points_value: int = 10
@export var move_speed: float = 60.0
@export var knockback_strength: float = 250.0
@export var gravity_scale: float = 1.0

enum State { IDLE, PATROL, TELEGRAPH, ATTACK, HURT, DEAD }

var state: State = State.IDLE
var health: int
var facing: int = 1  # 1 = right, -1 = left
var _hurt_timer: float = 0.0
var _telegraph_timer: float = 0.0

const GRAVITY: float = 900.0
const HURT_DURATION: float = 0.25

@onready var sprite: Node2D = $Sprite2D if has_node("Sprite2D") else null
@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null


func _ready() -> void:
	health = max_health
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * gravity_scale * delta

	match state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.TELEGRAPH:
			_state_telegraph(delta)
		State.ATTACK:
			_state_attack(delta)
		State.HURT:
			_state_hurt(delta)
		State.DEAD:
			return  # no physics once dead

	move_and_slide()
	_face_from_velocity()


# ---------- Virtual functions: override these in subclasses ----------

## Called every frame while patrolling. Default: do nothing extra.
func _on_patrol(_delta: float) -> void:
	pass

## Called once when an attack telegraph finishes. Do the actual attack here
## (spawn a projectile, lunge, slam, etc.)
func _do_attack() -> void:
	pass

## Return true when this enemy should begin an attack (distance check, timer, etc.)
func _should_attack() -> bool:
	return false

## How long the telegraph (wind-up) lasts before _do_attack() fires.
## Override per-enemy so telegraphs can be tuned individually.
func _telegraph_duration() -> float:
	return 0.4


# ---------- State implementations ----------

func _state_idle(delta: float) -> void:
	state = State.PATROL

func _state_patrol(delta: float) -> void:
	_on_patrol(delta)
	if _should_attack():
		state = State.TELEGRAPH
		_telegraph_timer = _telegraph_duration()
		_on_telegraph_start()

func _state_telegraph(delta: float) -> void:
	velocity.x = 0
	_telegraph_timer -= delta
	if _telegraph_timer <= 0.0:
		state = State.ATTACK
		_do_attack()

func _state_attack(delta: float) -> void:
	# Most attacks are instantaneous (spawn a projectile / apply a hit),
	# so default straight back to patrol next frame. Override if an
	# attack needs to hold this state longer (e.g. a dive that takes time).
	state = State.PATROL

func _state_hurt(delta: float) -> void:
	_hurt_timer -= delta
	if _hurt_timer <= 0.0:
		state = State.PATROL


## Optional hook for subclasses that want a visual wind-up (flash, scale pulse).
func _on_telegraph_start() -> void:
	pass


# ---------- Damage / death ----------

func take_damage(amount: int, source_position: Vector2 = global_position) -> void:
	if state == State.DEAD:
		return

	health -= amount
	hurt.emit(amount)

	var knockback_dir: float = sign(global_position.x - source_position.x)
	if knockback_dir == 0:
		knockback_dir = -facing
	velocity.x = knockback_dir * knockback_strength

	if health <= 0:
		_die()
	else:
		state = State.HURT
		_hurt_timer = HURT_DURATION
		_flash_hurt()


func _die() -> void:
	state = State.DEAD
	died.emit(points_value, global_position)
	# Subclasses/scene can connect to `died` to spawn a points pickup,
	# play a death animation, etc. Queue-free after a short delay so
	# a death animation/particle has time to play if you add one.
	set_physics_process(false)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	queue_free()


func _flash_hurt() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(1, 0.4, 0.4)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, HURT_DURATION)


func _face_from_velocity() -> void:
	if velocity.x > 5:
		facing = 1
	elif velocity.x < -5:
		facing = -1
	if sprite:
		sprite.scale.x = abs(sprite.scale.x) * facing


func _on_hitbox_body_entered(body: Node) -> void:
	if body.has_method("take_damage_from_enemy"):
		body.call("take_damage_from_enemy", contact_damage, global_position)
