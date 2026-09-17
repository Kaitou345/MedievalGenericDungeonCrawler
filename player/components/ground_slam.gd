extends Node

signal landed

@export var slam_speed: float = 900.0
@export var enabled: bool = true   # flip true once purchased in the shop

var is_slamming: bool = false


func try_start(player: CharacterBody2D) -> void:
	if not enabled or is_slamming:
		return
	if player.is_on_floor():
		return   # only usable in the air

	# Matches updated "slam" action in Input Map
	if Input.is_action_just_pressed("slam"):
		is_slamming = true


func apply(player: CharacterBody2D, _delta: float) -> void:
	player.velocity.x = 0.0
	player.velocity.y = slam_speed

	if player.is_on_floor():
		is_slamming = false
		landed.emit()
