extends Area2D
class_name Parry

signal parry_success(projectile: Node)

@export var parry_window: float = 0.18
@export var parry_cooldown: float = 0.6
@export var ammo_reward: int = 3
@export var stamina_reward: float = 20.0
@export var reflect_projectile: bool = true

var _weapon_manager: WeaponManager = null
var _stamina: Stamina = null
var _window_timer: float = 0.0
var _cooldown_timer: float = 0.0


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)
	var parent := get_parent()
	if parent:
		_weapon_manager = parent.get_node_or_null("WeaponManager") as WeaponManager
		_stamina = parent.get_node_or_null("Stamina") as Stamina


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


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_projectile"):
		return

	parry_success.emit(area)
	if _weapon_manager:
		_weapon_manager.add_ammo_to_current(ammo_reward)
	if _stamina:
		_stamina.add(stamina_reward)

	if reflect_projectile:
		area.set("is_enemy_projectile", false)
		area.remove_from_group("enemy_projectile")
		area.add_to_group("player_projectile")

		# Safe reflection handling across different projectile scripts
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
