extends Node

@export var move_speed: float = 300.0

var facing: float = 1.0


func apply(player: CharacterBody2D, _delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	player.velocity.x = dir * move_speed
	
	if dir != 0.0:
		facing = dir
