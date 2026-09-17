extends Node

signal axis_unlocked(axis_name: String)

var has_x: bool = true   # you start with this
var has_y: bool = true
var has_time: bool = true

func unlock(axis_name: String) -> void:
	match axis_name:
		"y":
			has_y = true
		"time":
			has_time = true
	axis_unlocked.emit(axis_name)
