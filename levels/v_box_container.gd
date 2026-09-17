extends VBoxContainer
class_name AbilityUI

@export var player_path: NodePath
var player_ref: Player = null

# Map your ability names to their corresponding Label nodes
@onready var labels: Dictionary = {
	"dash": $DashLabel,
	"ground_slam": $SlamLabel,
	"double_jump": $JumpLabel,
	"parry": $ParryLabel
}

func _ready() -> void:
	if player_path and not player_path.is_empty():
		player_ref = get_node_or_null(player_path) as Player
	else:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_ref = players[0] as Player

	if player_ref:
		player_ref.ability_lost.connect(_on_player_ability_lost)
		player_ref.ability_restored.connect(_on_player_ability_restored)

	# Hide all labels at the start of the game since no abilities are lost yet
	for label in labels.values():
		if label:
			label.visible = false

func _on_player_ability_lost(ability_name: String) -> void:
	if labels.has(ability_name):
		var label_node = labels[ability_name] as Label
		if label_node:
			# Show the label only when the ability is lost
			label_node.visible = true

func _on_player_ability_restored(ability_name: String) -> void:
	if labels.has(ability_name):
		var label_node = labels[ability_name] as Label
		if label_node:
			# Hide the label again once the player gets the ability back
			label_node.visible = false
