extends TextureProgressBar
class_name StaminaBar

@export var stamina_node: Stamina


func _ready() -> void:
	call_deferred("_connect_to_stamina")


func _connect_to_stamina() -> void:
	if not stamina_node:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			stamina_node = player.get_node_or_null("Stamina") as Stamina

	if stamina_node:
		# Connect the signal dynamically
		if not stamina_node.stamina_changed.is_connected(_on_stamina_changed):
			stamina_node.stamina_changed.connect(_on_stamina_changed)

		# Initial values push
		max_value = stamina_node.max_stamina
		value = stamina_node.current_stamina


func _on_stamina_changed(current: float, max_stam: float) -> void:
	max_value = max_stam
	value = current


func _process(_delta: float) -> void:
	# Continuous fallback frame check
	if stamina_node:
		value = stamina_node.current_stamina
	else:
		_connect_to_stamina()
