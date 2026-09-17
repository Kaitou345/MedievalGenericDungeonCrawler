extends TextureProgressBar
class_name BossHealthBar

@export_group("Boss Reference")
## NodePath to your FireBoss instance in the scene
@export var boss_path: NodePath

@export_group("Animation Settings")
@export var animate_hp_change: bool = true
@export var tween_duration: float = 0.25

var boss_ref: FireBoss = null


func _ready() -> void:
	# Locate boss via explicit NodePath or group search
	if boss_path and not boss_path.is_empty():
		boss_ref = get_node_or_null(boss_path) as FireBoss
	
	if not boss_ref:
		_find_boss_in_group()

	if boss_ref:
		_setup_boss_connections()
	else:
		# Defer one frame to handle dynamic boss spawning
		await get_tree().process_frame
		_find_boss_in_group()
		if boss_ref:
			_setup_boss_connections()
		else:
			hide()


func _setup_boss_connections() -> void:
	show()
	max_value = boss_ref.max_health
	value = boss_ref.current_health
	
	# Connect FireeBoss signals
	if not boss_ref.health_changed.is_connected(_on_boss_health_changed):
		boss_ref.health_changed.connect(_on_boss_health_changed)
	if not boss_ref.boss_defeated.is_connected(_on_boss_defeated):
		boss_ref.boss_defeated.connect(_on_boss_defeated)


func _on_boss_health_changed(current_hp: float, max_hp: float) -> void:
	max_value = max_hp
	
	if animate_hp_change:
		var tween := create_tween()
		tween.tween_property(self, "value", current_hp, tween_duration)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
	else:
		value = current_hp


func _on_boss_defeated() -> void:
	# Fade out UI bar smoothly upon boss death
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func _find_boss_in_group() -> void:
	var boss_nodes := get_tree().get_nodes_in_group("boss")
	if boss_nodes.size() > 0:
		boss_ref = boss_nodes[0] as FireBoss
