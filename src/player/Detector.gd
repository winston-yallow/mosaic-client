extends Area2D
# Handles detection of items. Exposes helper method to get the closest
# available (meaning: not locked by another peer) item.


const Item := preload("res://src/item/Item.gd")

var closest_item: Item
var items := []


func _ready() -> void:
	# warning-ignore:return_value_discarded
	connect("area_entered", self, "_on_area_entered")
	# warning-ignore:return_value_discarded
	connect("area_exited", self, "_on_area_exited")


func get_closest_available_item() -> Item:
	var closest: Item
	var closest_distance := 0.0
	for item in items:
		if item.is_locked():
			continue
		var current_distance := global_transform.origin.distance_to(item.global_transform.origin)
		if not is_instance_valid(closest) or current_distance < closest_distance:
			closest = item
			closest_distance = current_distance
	return closest


func _on_area_entered(other: Area2D) -> void:
	if other is Item:
		items.append(other)


func _on_area_exited(other: Area2D) -> void:
	if other in items:
		items.erase(other)
