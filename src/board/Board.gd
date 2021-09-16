extends Node2D
# This class represents the game board. It is basicaly a manager
# for prompts, items and players. The main tasks are:
#  - Procedurally generating all items
#  - Distributing items if this is the only client playing,
#    otherwise requesting the game state from the remote peer
#  - Adding/Removing players to the local game on join/leave
#  - Generating new prompts once enough people votes. Always the
#    oldest client has this responsibility. (This is kinda a hack,
#    but I don't care if some peer connections are failing. In the
#    worst case two clients think they are the oldest, so two
#    prompts would be generated. Most likely not at the exact same
#    time, so the one generated later will be set for all. One could
#    to this much better with more time to have peer voting or
#    something like that. I would really like to implement the Raft
#    algorithm at some point)
#  - Update HUD labels


const ITEM_COUNT := 150
const ITEM_AREA_EXTENTS := Vector2(500, 300)

const PlayerScene := preload("res://src/player/Player.tscn")
const Player := preload("res://src/player/Player.gd")
const ItemScene := preload("res://src/item/Item.tscn")
const Item := preload("res://src/item/Item.gd")
const SmoothCamera := preload("res://src/camera/SmoothCamera.gd")
const Options := preload("res://src/options/Options.gd")

# Used to indicate if we are waiting for initialisation. The problem is
# that when we join, it will take a few milliseconds before we can discover
# other players. And since there is no central server, we need other peers
# to get the current state of the game. Thankfully the signalling server
# sends us the current player count when connecting. So we will know if
# there are other players. If there aren't, then we simply set this to false
# immediately and create a whole new game. Otherwise we will ask the first
# peer to send us the current game state.
var _waiting_for_init := true

# I planned to support different color schemes, but I ran out of time so I
# just hardcoded one with colors I like.
var _colors := ColorScheme.new(
	Color('#201335'),
	Color('#FDF7FA'),
	Color('#D56AA0'),
	Color('#4F4789'),
	Color('#44BBA4')
)

# These are the prompts to choose from
var _prompts := PoolStringArray([
	'Godot Logo',
	'Sunset',
	'Console Controller',
	'The Letter "A"',
	'Heart',
	'Circle',
	'Triangle',
	'Computer',
	'Nothing',
	'Chaos'
])

var _own_player: Player

onready var _border: Polygon2D = $Border
onready var _items: Node2D = $Items
onready var _players: Node2D = $Players
onready var _camera: SmoothCamera = $SmoothCamera
onready var _options: Options = $Options
onready var _prompt: Label = $HUD/ColorRectPrompt/CenterContainer/VBox/Prompt
onready var _voting: Label = $HUD/ColorRectVotes/Voting
onready var _prompt_change: AudioStreamPlayer = $PromptChange


func _ready() -> void:
	
	_border.color = _colors.dark * 0.5
	_border.color.a = 1.0
	VisualServer.set_default_clear_color(_colors.dark)
	for idx in ITEM_COUNT:
		var item: Item = ItemScene.instance()
		item.modulate = _colors.get_accent(idx)
		item.generate_polygon(idx)
		_items.add_child(item)
	
	# warning-ignore:return_value_discarded
	_options.connect("toggled", self, "_on_options_toggled")
	
	# warning-ignore:return_value_discarded
	NetworkMesh.connect("own_connection_ready", self, "_on_own_connection_ready")
	# warning-ignore:return_value_discarded
	NetworkMesh.connect("player_joined", self, "_on_player_joined")
	# warning-ignore:return_value_discarded
	NetworkMesh.connect("player_left", self, "_on_player_left")


func _process(_delta: float) -> void:
	# Iterate players to count how many vote to finish the prompt
	var votes := 0
	var needed := int(ceil(_players.get_child_count() * 0.666666)) # 2/3 needed
	for child in _players.get_children():
		if child.voted:
			votes += 1
	_voting.text = "%s/%s Votes" % [votes, needed]
	if is_instance_valid(_own_player) and _own_player.voted:
		_voting.add_color_override("font_color", Color.greenyellow)
	else:
		_voting.add_color_override("font_color", _colors.bright)
	
	if votes >= needed and NetworkMesh.is_lowest_ranking():
		generate_next_prompt()


func generate_next_prompt(sound := true) -> void:
	var available := []
	for p in _prompts:
		if not p == _prompt.text:
			available.append(p)
	rpc("update_prompt", available[randi() % available.size()], sound)


remotesync func update_prompt(prompt: String, sound := true) -> void:
	_prompt.text = prompt
	_own_player.rset('voted', false)
	if sound:
		_prompt_change.play()


remote func publish_remote_prompt() -> void:
	var reply_id := get_tree().multiplayer.get_rpc_sender_id()
	rpc_id(reply_id, "update_prompt", _prompt.text, false)


func _on_options_toggled(active: bool) -> void:
	if is_instance_valid(_own_player):
		_own_player.input_paused = active


func _on_own_connection_ready(own_id: int, expected_peer_count: int) -> void:
	_add_player(own_id)
	if expected_peer_count == 0:
		# There are no other peers, we can generate a new game immediately
		# without waiting for a peer that sends us the current state.
		_waiting_for_init = false
		for item in _items.get_children():
			item.position.x = rand_range(-ITEM_AREA_EXTENTS.x, ITEM_AREA_EXTENTS.x)
			item.position.y = rand_range(-ITEM_AREA_EXTENTS.y, ITEM_AREA_EXTENTS.y)
			item.init_local_state()
		generate_next_prompt(false)
	else:
		_waiting_for_init = true


func _on_player_joined(peer_id: int) -> void:
	_add_player(peer_id)
	if _waiting_for_init:
		# We have a connection to an existing peer and need to sync the game state.
		# Therefore we request the other peer to publish all it's item positions as
		# well as the current prompt.
		_waiting_for_init = false
		for item in _items.get_children():
			item.rpc_id(peer_id, "publish_remote_state")
		rpc_id(peer_id, "publish_remote_prompt")


func _on_player_left(peer_id: int) -> void:
	if _players.has_node(str(peer_id)):
		_players.remove_child(_players.get_node(str(peer_id)))


func _add_player(peer_id: int) -> void:
	var player: Player = PlayerScene.instance()
	player.name = str(peer_id)
	player.set_network_master(peer_id)
	_players.add_child(player)
	if player.is_network_master():
		player.z_index = 1000
		player.modulate = _colors.bright
		player.input_paused = _options.is_active()
		_camera.set_target(player)
		_own_player = player
	else:
		player.modulate = _colors.bright * 0.85
		player.modulate.a = 1.0
