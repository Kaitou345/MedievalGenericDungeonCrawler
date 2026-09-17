extends Node
class_name Stamina

signal stamina_changed(current: float, max_stamina: float)

@export var max_stamina: float = 100.0
@export var current_stamina: float = 100.0
@export var regen_rate: float = 15.0
@export var regen_delay: float = 1.0

var _regen_timer: float = 0.0


func _ready() -> void:
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)


func _process(delta: float) -> void:
	if _regen_timer > 0.0:
		_regen_timer -= delta
		return

	if current_stamina < max_stamina:
		current_stamina = min(current_stamina + (regen_rate * delta), max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)


func spend(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		_regen_timer = regen_delay
		stamina_changed.emit(current_stamina, max_stamina)
		return true

	return false
