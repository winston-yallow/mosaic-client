class_name ColorScheme
extends Reference
# This is basically just a data holder with an added utility method.
# I initially planned that players can choose between different color
# schemes but I didn't have enough time. So I actually only instance
# this once with a fixed color scheme.


var dark: Color
var bright: Color
var accent_a: Color
var accent_b: Color
var accent_c: Color


func _init(bg: Color, fg: Color, a: Color, b: Color, c: Color) -> void:
	dark = bg
	bright = fg
	accent_a = a
	accent_b = b
	accent_c = c


func get_accent(id: int) -> Color:
	return [accent_a, accent_b, accent_c][id % 3]
