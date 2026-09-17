extends Node

@export_group("Jump")
@export var jump_distance: float = 120.0
@export var jump_time: float = 0.35
@export var fall_time: float = 0.25
@export var max_jumps: int = 2

@export_group("Jump Buffer / Coyote")
@export var jump_buffer_duration: float = 0.12
@export var coyote_time_duration: float = 0.12

var _jump_velocity: float
var _rise_gravity: float
var _fall_gravity: float

var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var _jumps_remaining: int = 0


func _ready() -> void:
	_recalculate()
	_jumps_remaining = max_jumps


func _recalculate() -> void:
	_jump_velocity = (2.0 * jump_distance) / jump_time
	_rise_gravity = (2.0 * jump_distance) / (jump_time * jump_time)
	_fall_gravity = (2.0 * jump_distance) / (fall_time * fall_time)


func grant_double_jump() -> void:
	max_jumps = max(max_jumps, 2)
	_jumps_remaining = max_jumps


func set_max_jumps(value: int) -> void:
	max_jumps = value


func apply(player: CharacterBody2D, delta: float, _facing: float, _stamina: Stamina = null) -> void:
	if player.is_on_floor():
		_coyote_timer = coyote_time_duration
		_jumps_remaining = max_jumps

	_handle_timers(player, delta)
	_handle_gravity(player, delta)
	_handle_jump(player)


func _handle_timers(player: CharacterBody2D, delta: float) -> void:
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta
	if not player.is_on_floor() and _coyote_timer > 0.0:
		_coyote_timer -= delta


func _handle_gravity(player: CharacterBody2D, delta: float) -> void:
	if player.is_on_floor():
		player.velocity.y = 0.0
		return
	if player.velocity.y < 0.0:
		player.velocity.y += _rise_gravity * delta
	else:
		player.velocity.y += _fall_gravity * delta


func _handle_jump(player: CharacterBody2D) -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_duration

	var used_first_jump := _jumps_remaining < max_jumps
	var can_jump := _jump_buffer_timer > 0.0 and _jumps_remaining > 0 and (_coyote_timer > 0.0 or used_first_jump)

	if can_jump:
		player.velocity.y = -_jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_jumps_remaining -= 1

	if Input.is_action_just_released("jump") and player.velocity.y < 0.0:
		player.velocity.y *= 0.5
