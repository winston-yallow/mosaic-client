extends Node
# This class implements all the network magic. It creates a connection to the
# signalling server. It exchanges WebRTC SDP offers and ICE candidates. Additionally
# it listens to messages from the signalling server to discover new peers. This
# class is used as an autoload in order to make it easy to access. This is probably
# not the best approach, but it was an approach that allowed me to develop this
# within the time limitation of the jam. This can be used as a non-autoload too.

# Most of the magic happens in _signalling_on_message()
# To get more debug prints set _verbose = true


signal own_connection_ready(own_peer_id, expected_peer_count)
signal player_joined(peer_id)
signal player_left(peer_id)


var _verbose := false
var _websocket_url := "ws://127.0.0.1:8765"  # NOTE: Change this to point to your server
var _ice_servers = [
	{
		"urls": [
			# NOTE: You should replace this with your own STUN/TURN servers
			# The supported options can be found in the godot docs at
			# https://docs.godotengine.org/en/stable/classes/class_webrtcpeerconnection.html
			"stun:stun.example.com:3478"
		]
	}
]

var _signalling := SignallingChannel.new()
var _peers := {}  # TODO: We don't need this
var _own_peer_id := -1
var _webrtc_multiplayer = WebRTCMultiplayer.new()


func _ready() -> void:
	randomize()
	_init_multiplayer()
	_init_signalling()


func get_peer_count() -> int:
	return _webrtc_multiplayer.get_peers().size()


func is_lowest_ranking() -> bool:
	# We can be sure that this won't change except if *we* disconnect.
	# Other clients will *always* have a higher ID after this returned
	# true for the first time.
	var peers: Array = _webrtc_multiplayer.get_peers().keys() + [_own_peer_id]
	peers.sort()
	return _own_peer_id == peers[0]


func is_peer_valid(peer_id: int) -> bool:
	return _webrtc_multiplayer.has_peer(peer_id) or peer_id == _own_peer_id


func _info(message: String) -> void:
	if _verbose:
		print(message)


func _init_multiplayer() -> void:
	_webrtc_multiplayer.connect("peer_connected", self, "_on_peer_connected")
	_webrtc_multiplayer.connect("peer_disconnected", self, "_on_peer_disconnected")


func _init_signalling() -> void:
	# warning-ignore:return_value_discarded
	_signalling.connect("connection_closed", self, "_signalling_closed")
	# warning-ignore:return_value_discarded
	_signalling.connect("connection_error", self, "_signalling_closed")
	# warning-ignore:return_value_discarded
	_signalling.connect("connection_established", self, "_signalling_connected")
	# warning-ignore:return_value_discarded
	_signalling.connect("message_received", self, "_signalling_on_message")
	# warning-ignore:return_value_discarded
	_signalling.connect("message_error", self, "_signalling_on_message_error")
	var err := _signalling.connect_to_url(_websocket_url)
	if err != OK:
		print("[WS] Unable to connect, error ", err)
		set_process(false)


func _on_peer_connected(peer_id: int):
	print("[WebRTC] Connected to ", peer_id)
	emit_signal("player_joined", peer_id)


func _on_peer_disconnected(peer_id: int):
	print("[WebRTC] Disconnected from ", peer_id)
	emit_signal("player_left", peer_id)
	if peer_id in _peers:
		# warning-ignore:return_value_discarded
		_peers.erase(peer_id)


func _signalling_closed(was_clean := false) -> void:
	print("[WS] Closed (clean: %s)" % was_clean)
	set_process(false)


func _signalling_connected(_proto := "") -> void:
	print("[WS] Connected")


func _signalling_on_message(message: Message) -> void:
	# TODO: Check sender ID for security
	match message.type:
		
		SignallingChannel.TYPE.INIT:
			var parts := message.content.split(',')
			_own_peer_id = int(parts[0])
			_webrtc_multiplayer.initialize(_own_peer_id)
			_info('[SIGNALLING] own client ID: %s' % _own_peer_id)
			print("[WebRTC] Initialized with client ID ", _own_peer_id)
			get_tree().set_network_peer(_webrtc_multiplayer)
			emit_signal("own_connection_ready", _own_peer_id, int(parts[1]))
		
		SignallingChannel.TYPE.DISCOVER:
			for raw_peer_id in message.content.split(',', false):
				var peer_id := int(raw_peer_id)
				_info('[SIGNALLING] discovering %s' % peer_id)
				_ensure_peer_exists(peer_id)
				if peer_id > _own_peer_id:
					_info('[SIGNALLING] creating offer for %s' % peer_id)
					_peers[peer_id].create_offer()
		
		SignallingChannel.TYPE.DISCONNECT:
			var peer_id := int(message.content)
			if _webrtc_multiplayer.has_peer(peer_id):
				_webrtc_multiplayer.remove_peer(peer_id)
			if peer_id in _peers:
				# warning-ignore:return_value_discarded
				_peers.erase(peer_id)
		
		SignallingChannel.TYPE.SDP:
			# TODO: Do we need to ensure this even at this stage?
			_ensure_peer_exists(message.from)
			_info('[SIGNALLING] received SDP from %s' % message.from)
			var parts := message.content.split(' ', true, 1)
			_peers[message.from].set_remote_description(parts[0], parts[1])
		
		SignallingChannel.TYPE.ICE:
			# TODO: Do we need to ensure this even at this stage?
			_ensure_peer_exists(message.from)
			_info('[SIGNALLING] received ICE candidate from %s' % message.from)
			var parts := message.content.split(' ', true, 2)
			if parts[2].length() > 0:  # Filters invalid candidates
				_peers[message.from].add_ice_candidate(parts[0], int(parts[1]), parts[2])
		
		_:
			prints("[WS] Unrecognised message:", message.from, message.type, message.content)


func _signalling_on_message_error(error: String, raw_message: String) -> void:
	print("[WS] Error: %s (%s)" % [error, raw_message])


func _ensure_peer_exists(peer_id: int) -> void:
	if not peer_id in _peers:
		var peer := WebRTCPeerConnection.new()
		peer.initialize({"iceServers": _ice_servers})
		# warning-ignore:return_value_discarded
		peer.connect("session_description_created", peer, 'set_local_description')
		# warning-ignore:return_value_discarded
		peer.connect("session_description_created", _signalling, 'send_sdp', [peer_id])
		# warning-ignore:return_value_discarded
		peer.connect("ice_candidate_created", _signalling, 'send_ice', [peer_id])
		_webrtc_multiplayer.add_peer(peer, peer_id)
		_peers[peer_id] = peer


func _process(_delta: float) -> void:
	_signalling.poll()
