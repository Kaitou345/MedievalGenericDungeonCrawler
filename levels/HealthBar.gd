extends TextureProgressBar
class_name HealthBar

@export_group("Target Reference")
## Path to the entity node (Player or Boss) that has max_health, current_health, and a health_changed signal.
@export var target_path: NodePath

@export_group("Animation Settings")
@export var animate_hp_change: bool = true
@export var tween_duration: float = 0.25

var target_ref: Node = null


func _ready() -> void:
	if target_path and not target_path.is_empty():
		target_ref = get_node_or_null(target_path)
	
	if not target_ref:
		# Fallback: try to find a node in the "player" or "boss" group if target_path isn't set
		_find_target_automatically()

	if target_ref:
		_setup_connections()
	else:
		# Wait one frame in case the target is spawned dynamically during initialization
		await get_tree().process_frame
		_find_target_automatically()
		if target_ref:
			_setup_connections()
		else:
			hide()


func _setup_connections() -> void:
	show()
	max_value = target_ref.max_health
	value = target_ref.current_health
	
	if target_ref.has_signal("health_changed"):
		if not target_ref.health_changed.is_connected(_on_health_changed):
			target_ref.health_changed.connect(_on_health_changed)
			
	if target_ref.has_signal("boss_defeated"):
		if not target_ref.boss_defeated.is_connected(_on_target_defeated):
			target_ref.boss_defeated.connect(_on_target_defeated)
	elif target_ref.has_signal("player_died"):
		if not target_ref.player_died.is_connected(_on_target_defeated):
			target_ref.player_died.connect(_on_target_defeated)


func _on_health_changed(current_hp: float, max_hp: float) -> void:
	max_value = max_hp
	
	if animate_hp_change:
		var tween := create_tween()
		tween.tween_property(self, "value", current_hp, tween_duration)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
	else:
		value = current_hp


func _on_target_defeated() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func _find_target_automatically() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_ref = players[0]
		return
		
	var bosses := get_tree().get_nodes_in_group("boss")
	if bosses.size() > 0:
		target_ref = bosses[0]
		return
