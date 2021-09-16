class_name Message
extends Reference
# Only a small data holder class for our signalling messages. Makes passing
# them around more convenient and provides type hints.


var from: int
var type: int
var content: String


func _init(from_id: int, message_type: int, message_content: String) -> void:
	from = from_id
	type = message_type
	content = message_content
