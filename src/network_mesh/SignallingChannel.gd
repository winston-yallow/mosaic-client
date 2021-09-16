class_name SignallingChannel
extends WebSocketClient
# This class adds a few helpers to the usual websocket client to work
# more easily with my custom message format. It exposes signals to
# receive them and methods to send them.


# -------------------------------------------------- #
# Custom signalling message format
# -------------------------------------------------- #
#
# Different parts of the message are separated by
# spaces. There are always three parts. This allows
# the last part to contain additional spaces that
# won't separate it into any more parts.
#
# Sending messages format:
#   TO TYPE CONTENT
# Receiving messages format:
#   FROM TYPE CONTENT
#
# Values:
#   TO: int       peer ID
#   FROM: int     peer ID
#   TYPE: str     see TYPE enum below for all types
#   CONTENT: str  message content
#
# -------------------------------------------------- #


signal message_received(message)
signal message_error(error, raw_message)

enum TYPE { INIT, DISCOVER, ERROR, DISCONNECT, SDP, ICE }

var _type_mapping := {
	TYPE.INIT: "INIT",
	TYPE.DISCOVER: "DISCOVER",
	TYPE.ERROR: "ERROR",
	TYPE.DISCONNECT: "DISCONNECT",
	TYPE.SDP: "SDP",
	TYPE.ICE: "ICE",
}


func _init() -> void:
	# warning-ignore:return_value_discarded
	connect("data_received", self, "_on_data")


func send(to: int, type: int, content: String) -> void:
	if not type in _type_mapping:
		push_error("Action does not exist: %s" % type)
		return
	var message := "%s %s %s" % [to, _type_mapping[type], content]
	var err := get_peer(1).put_packet(message.to_utf8())
	if err != OK:
		push_error("Failed to send message (error code %s)" % err)


func send_sdp(type: String, sdp: String, to: int) -> void:
	# The type here refers to the SDP type, not to the message type.
	# Confusing naming, I know. But to my defense, I wrote this within a time constraint :P
	send(to, TYPE.SDP, '%s %s' % [type, sdp])


func send_ice(media: String, index: int, name: String, to: int) -> void:
	send(to, TYPE.ICE, '%s %s %s' % [media, index, name])


func _on_data() -> void:
	var raw_message := get_peer(1).get_packet().get_string_from_utf8()
	var parts := raw_message.split(" ", true, 2)
	
	if parts.size() != 3:
		emit_signal("message_error", "Malformed message", raw_message)
		return
	
	if not parts[0].is_valid_integer():
		emit_signal("message_error", "Invalid sender ID", raw_message)
		return
	
	if not parts[1] in TYPE:
		emit_signal("message_error", "Invalid message type", raw_message)
		return
	
	emit_signal("message_received", Message.new(int(parts[0]), TYPE[parts[1]], parts[2]))
