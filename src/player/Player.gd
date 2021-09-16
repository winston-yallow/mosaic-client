extends Node2D
# This is the general purpose player class.
# It is used for both (local and remote) types of players.  We simply set
# the peer that controls a certain player as the network master. That way
# only one client has controll. Only if this is the network master we
# will add a Detector as a child node. No need to check for available items
# locally for remote players as they do this themselves.
# Players also have a property to indicate that they voted to finish the
# current prompt.


const SPEED := 250.0
const INTERPOLATION := 20.0
const ALLOWED_AREA_EXTENTS := Vector2(600, 400)

const DetectorScene := preload("res://src/player/Detector.tscn")
const Detector := preload("res://src/player/Detector.gd")
const Item := preload("res://src/item/Item.gd")

export var input_paused := true

enum STATE { INIT, MOVE, WAIT_LOCK }
var _current_state: int = STATE.INIT
var _current_item: Item
var _detector: Detector

remotesync var target_position := Vector2.ZERO
remotesync var voted := false

onready var _polygon: Polygon2D = $Polygon2D


func _ready() -> void:
	if is_network_master():
		_current_state = STATE.MOVE
		_detector = DetectorScene.instance()
		add_child(_detector)
	else:
		rpc_id(get_network_master(), "reply_state")
		set_process_input(false)


remote func reply_state() -> void:
	var reply_id := get_tree().multiplayer.get_rpc_sender_id()
	rpc_id(reply_id, "init_state", position, target_position)


remote func init_state(current: Vector2, target: Vector2) -> void:
	position = current
	target_position = target
	_current_state = STATE.MOVE


func _unhandled_input(event: InputEvent) -> void:
	if input_paused:
		return
	
	if event.is_action_pressed("interact") and _current_state == STATE.MOVE:
		if not is_instance_valid(_current_item):
			_current_item = _detector.get_closest_available_item()
			if not is_instance_valid(_current_item):
				return  # No items available
			_current_state = STATE.WAIT_LOCK
			# warning-ignore:return_value_discarded
			_current_item.connect("lock_decided", self, "_on_lock_decided", [], CONNECT_ONESHOT)
			_current_item.request_lock(get_network_master())
		else:
			_current_item.unlock()
			_current_item = null
	
	elif event.is_action_pressed("vote"):
		rset('voted', not voted)


func _on_lock_decided(decision_ok: bool):
	if not decision_ok:
		_current_item = null
	_current_state = STATE.MOVE


func _process(delta: float) -> void:
	if is_network_master() and _current_state == STATE.MOVE and not input_paused:
		var direction := Vector2.ZERO
		direction.x += Input.get_action_strength("move_right")
		direction.x -= Input.get_action_strength("move_left")
		direction.y += Input.get_action_strength("move_down")
		direction.y -= Input.get_action_strength("move_up")
		var change := direction.clamped(1.0) * SPEED * delta
		var new_position := target_position + change
		new_position.x = clamp(new_position.x, -ALLOWED_AREA_EXTENTS.x, ALLOWED_AREA_EXTENTS.x)
		new_position.y = clamp(new_position.y, -ALLOWED_AREA_EXTENTS.y, ALLOWED_AREA_EXTENTS.y)
		rset_unreliable('target_position', new_position)
		if is_instance_valid(_current_item):
			_current_item.rset_unreliable('target_position', new_position)
	
	# Smoothed out movement, so unreliably set target positions won't be noticable that much
	var look_dir := target_position - position
	position = position.linear_interpolate(target_position, delta * INTERPOLATION)
	if look_dir.length_squared() > 1:
		_polygon.rotation = lerp_angle(_polygon.rotation, look_dir.angle() + (TAU / 4.0), delta * INTERPOLATION)
