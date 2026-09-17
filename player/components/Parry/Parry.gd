extends Area2D
class_name Parry

signal parry_success(source: Node)

@export var parry_window: float = 0.18
@export var parry_cooldown: float = 0.6
@export var reflect_projectile: bool = true

@export_group("Audio")
@export var parry_sfx: AudioStream
## Delay (in seconds) after attempting a parry before playing the sound effect
@export var parry_sfx_delay: float = 0.0
@onready var sfx_player: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null

var _player: Player = null
var _window_timer: float = 0.0
var _cooldown_timer: float = 0.0


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	var parent := get_parent()
	if parent:
		_player = parent as Player

	# Dynamically ignore Layer 1 (Player layer) to prevent self-detection
	set_collision_mask_value(1, false)


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	if _window_timer > 0.0:
		_window_timer -= delta
		if _window_timer <= 0.0:
			monitoring = false


func can_parry() -> bool:
	return _cooldown_timer <= 0.0


func start_parry() -> void:
	if not can_parry():
		return
	monitoring = true
	_window_timer = parry_window
	_cooldown_timer = parry_cooldown
	
	# Play sound on every parry attempt regardless of success
	_schedule_parry_sfx()


func _schedule_parry_sfx() -> void:
	if parry_sfx_delay > 0.0:
		get_tree().create_timer(parry_sfx_delay).timeout.connect(_play_parry_sfx, CONNECT_ONE_SHOT)
	else:
		_play_parry_sfx()


func _play_parry_sfx() -> void:
	if sfx_player:
		if parry_sfx:
			sfx_player.stream = parry_sfx
		if sfx_player.stream:
			sfx_player.play()


func _on_area_entered(area: Area2D) -> void:
	# Ignore player-owned areas
	if _player and (area.owner == _player or area.get_parent() == _player):
		return

	# Handle Enemy Projectiles
	if area.is_in_group("enemy_projectile"):
		parry_success.emit(area)

		if reflect_projectile:
			area.set("is_enemy_projectile", false)
			area.remove_from_group("enemy_projectile")
			area.add_to_group("player_projectile")

			if "direction" in area:
				area.set("direction", -area.get("direction"))
			elif "velocity" in area:
				area.set("velocity", -area.get("velocity"))
			elif area.has_method("launch"):
				var raw_dir: Variant = area.get("_direction")
				var incoming_dir: Vector2 = raw_dir if raw_dir != null else Vector2.LEFT
				area.call("launch", -incoming_dir)
		else:
			area.queue_free()

	# Handle Enemy Attack Hitboxes
	elif area.is_in_group("enemy_hitbox"):
		parry_success.emit(area)
		var boss_owner := area.get_parent()
		if boss_owner and boss_owner.has_method("stagger_from_parry"):
			boss_owner.stagger_from_parry()


func _on_body_entered(body: Node2D) -> void:
	# Ignore local player body
	if body == _player or body.is_in_group("player"):
		return

	# Handle Direct Enemy/Boss Bodies entering the parry window
	if body.is_in_group("boss") or body.is_in_group("enemies"):
		parry_success.emit(body)
		if body.has_method("stagger_from_parry"):
			body.stagger_from_parry()
