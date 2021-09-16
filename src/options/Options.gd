extends CanvasLayer
# Handles opening/closing options (and switching to/back from credits)


signal toggled(active)

onready var _overlay: Control = $Overlay
onready var _explanations: VBoxContainer = $Overlay/Explanations
onready var _credits: VBoxContainer = $Overlay/Credits


func _ready() -> void:
	pause()


func _input(event: InputEvent) -> void:
	if not is_active() and event.is_action_pressed("pause"):
		get_tree().set_input_as_handled()
		explanations()
		pause()
	elif is_active() and (event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		get_tree().set_input_as_handled()
		if _explanations.visible:
			resume()
		else:
			explanations()


func is_active() -> bool:
	return _overlay.visible


func credits() -> void:
	_explanations.visible = false
	_credits.visible = true


func explanations() -> void:
	_explanations.visible = true
	_credits.visible = false


func pause() -> void:
	_overlay.visible = true
	emit_signal("toggled", true)


func resume() -> void:
	_overlay.visible = false
	emit_signal("toggled", false)


func _on_resume_pressed() -> void:
	resume()


func _on_back_pressed() -> void:
	explanations()
