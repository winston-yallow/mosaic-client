extends Camera2D
# Smoothly moves to a target node


const INTERPOLATION := 10.0

var _target: Node2D


func set_target(target: Node2D) -> void:
	_target = target


func _process(delta: float) -> void:
	if is_instance_valid(_target):
		position = position.linear_interpolate(_target.position, delta * INTERPOLATION)
