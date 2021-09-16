extends Area2D
# Represents an item that can be picked up by players. Implements voting so
# peers can request an item to be locked to them. We use a peer-to-peer
# network, and items could be used by anyone. Without a central server it
# would not make sense to have a fixed network master for items as that
# master would need to change when peers leave. Instead we have a dynamic
# locking mechanism. A peer that wants to controll the item asks all other
# peers if that is ok. Only once more than 50% have agreed (and therefore
# no other peer can successfully request the item anymore) it informs all
# other peers that the item is now locked to this peer.
# The implementation is definitely flawed and there are ways to achive
# invalid states. I would love to use paxos or raft at some point when I
# have more time than in a game jam :D


signal lock_decided(decision)

const VOTE_TIMEOUT := 500
const INTERPOLATION := 20.0
const POLYGON_BASE_SIZE := 10.0
const POLYGON_RANDOM_SIZE := 5.0

remotesync var target_position := Vector2.ZERO

var _initialised = false
var _vote_local_active := false
var _vote_time := -1000
var _vote_for := -1
var _votes_needed := 0
var _votes_yes := 0
var _votes_no := 0

var _locked_by := -1


func _ready() -> void:
	# Only show once initialised
	visible = false


func generate_polygon(base: int) -> void:
	# We generate a pseudo random polygon based on a number. This way all clients
	# will have the same "random" shape for the same polygon.
	var _polygon: Polygon2D = $Polygon2D
	var vertex_count := 3 + (base % 7)
	var step_angle := TAU / float(vertex_count)
	var vertex_array := PoolVector2Array()
	for idx in vertex_count:
		var pseudo_random := fmod(sin(Vector2(base * 2.0, idx * 5.0).dot(Vector2(12.9898, 78.233))), 1.0)
		var angle: float = (step_angle * idx) + (step_angle * pseudo_random * 0.2)
		var length := POLYGON_BASE_SIZE + (pseudo_random * POLYGON_RANDOM_SIZE)
		var vertex := Vector2.UP.rotated(angle) * length
		vertex_array.append(vertex)
	_polygon.set_polygon(vertex_array)


func init_local_state() -> void:
	visible = true
	target_position = position
	_initialised = true


remote func init_remote_state(current: Vector2, target: Vector2) -> void:
	visible = true
	position = current
	target_position = target
	_initialised = true


remote func publish_remote_state() -> void:
	var reply_id := get_tree().multiplayer.get_rpc_sender_id()
	rpc_id(reply_id, "init_remote_state", position, target_position)


func get_locking_peer() -> int:
	return _locked_by


func is_locked() -> bool:
	return NetworkMesh.is_peer_valid(_locked_by) or not _initialised


func request_lock(peer_id: int) -> void:
	_vote_local_active = true
	_vote_time = OS.get_ticks_msec()
	_vote_for = peer_id
	_votes_needed = int(ceil(NetworkMesh.get_peer_count() / 2.0))
	_votes_yes = 0
	if _votes_needed == 0:
		vote_result(true)
		return
	_votes_no = 0
	rpc('vote', peer_id)


remote func vote(peer_id: int) -> void:
	if (OS.get_ticks_msec() - _vote_time) < VOTE_TIMEOUT or is_locked() or _vote_local_active:
		# We are still within the last votes timeout, so we can't vote again now
		rpc_id(peer_id, 'vote_result', false)
	else:
		# No recent votes, we can agree on this peer
		_vote_time = OS.get_ticks_msec()
		_vote_local_active = false
		rpc_id(peer_id, 'vote_result', true)


remote func vote_result(ok: bool) -> void:
	if (OS.get_ticks_msec() - _vote_time) > VOTE_TIMEOUT or not _vote_local_active:
		# No recent votings
		return
	
	if ok:
		_votes_yes += 1
	else:
		_votes_no += 1
	
	if _votes_yes >= _votes_needed:
		_vote_local_active = false
		_vote_time = -1000
		rpc('lock', _vote_for)
		emit_signal('lock_decided', true)
	elif _votes_no >= _votes_needed:
		_vote_local_active = false
		_vote_time = -1000
		emit_signal('lock_decided', false)


remotesync func lock(peer_id: int) -> void:
	_locked_by = peer_id


func unlock() -> void:
	rpc('_unlock')


remotesync func _unlock() -> void:
	_locked_by = -1


func _process(delta: float) -> void:
	if (OS.get_ticks_msec() - _vote_time) > VOTE_TIMEOUT and _vote_local_active:
		_vote_local_active = false
		_vote_time = -1000
		emit_signal('lock_decided', false)
	
	position = position.linear_interpolate(target_position, delta * INTERPOLATION)
