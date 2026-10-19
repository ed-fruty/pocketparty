extends Node
## LAN-only, host-authoritative sessions. No backend or persistent peer IDs.
signal changed
signal notice(message: String)
const PORT = 47638
const DISCOVERY_PORT = 47639
const PROTOCOL = "pocketparty-netplay-1"
const STATE = {
	"common": ["scores", "time", "countdown", "duration", "paused", "ended", "feedback", "shown_steps", "signal_round", "signal_phase", "signal_clock", "lamp_pop"],
	"pairs": ["deck", "opened", "matched", "turn", "pairs_found"],
	"darkspots": ["positions", "targets", "target_indices", "range_lengths", "pulses", "messages", "message_times"],
	"obby": ["alive", "jump_starts", "duck_ends", "duck_blends", "death_times", "course", "finishing"],
	"snake": ["bodies", "previous_bodies", "headings", "wishes", "alive", "sticks", "foods", "eaten_at", "notices", "notice_times", "chase_leader", "chase_left", "hunt_active", "accumulator"],
	"dance": ["leader_id", "sequence", "phase", "phase_time", "watch_index", "progress", "failed", "poses", "pose_times", "feedback_text"],
	"burger": ["display_scores"]
}
var active = false
var hosting = false
var local_id = -1
var peers: Dictionary = {}
var skins: Array = []
var rooms: Dictionary = {}
var screen = "lobby"
var ui: Control
var arena: Control
var applying = false
var dispatching = false
var ticket = 0
var ready_peers: Array = []
var waiting = false
var wait_started = 0
var rate_times: Dictionary = {}
var remote_taps: Dictionary = {}
var saved_difficulty = 1
var saved_slots: Array = []
var saved_equipped: Array = []
var scan_socket: PacketPeerUDP
var beacon_socket: PacketPeerUDP
var beacon_clock = 0.0
var snapshot_clock = 0.0
var status = ""
var joined_at = 0
var last_state_at = 0
var last_render_time = 0.0
var addresses: String:
	get:
		var found = PackedStringArray()
		for address in IP.get_local_addresses():
			if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
				found.append(address)
		return " · ".join(found)

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_disconnected)
	multiplayer.connected_to_server.connect(func(): hello.rpc_id(1, PROTOCOL, Party.equipped[0]))
	multiplayer.connection_failed.connect(func(): fail("Could not connect. Check the address and Wi-Fi."))
	multiplayer.server_disconnected.connect(func(): fail("The host left the room."))

func prepare() -> void:
	saved_difficulty = Party.difficulty
	saved_slots = Party.slots.duplicate()
	saved_equipped = Party.equipped.duplicate()
	skins = Party.equipped.duplicate()
	active = true
	status = ""
	screen = "lobby"
	joined_at = Time.get_ticks_msec()

func host() -> Error:
	leave()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, 3)
	if error != OK:
		status = "Cannot create room. Another room may already be open on this device."
		return error
	prepare()
	hosting = true
	local_id = 0
	peers = {1: 0}
	Party.slots = ["Human", "Off", "Off", "Off"]
	multiplayer.multiplayer_peer = peer
	beacon_socket = PacketPeerUDP.new()
	beacon_socket.set_broadcast_enabled(true)
	changed.emit()
	return OK

func join(address: String) -> Error:
	if not address.is_valid_ip_address():
		status = "Enter the host's local IP address, for example 192.168.1.12."
		return ERR_INVALID_PARAMETER
	leave()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error != OK:
		status = "Could not connect to that address."
		return error
	prepare()
	hosting = false
	local_id = -1
	status = "Connecting…"
	multiplayer.multiplayer_peer = peer
	return OK

func leave() -> void:
	if active:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		Party.slots = saved_slots.duplicate()
		Party.equipped = saved_equipped.duplicate()
		Party.difficulty = saved_difficulty
	active = false
	hosting = false
	local_id = -1
	ticket = 0
	peers.clear()
	ready_peers.clear()
	rate_times.clear()
	remote_taps.clear()
	waiting = false
	arena = null
	if beacon_socket:
		beacon_socket.close()
	beacon_socket = null

func fail(message: String) -> void:
	leave()
	status = message
	if is_instance_valid(ui):
		ui.call_deferred("show_netplay")
	notice.emit(message)

func scan() -> void:
	stop_scan()
	rooms.clear()
	scan_socket = PacketPeerUDP.new()
	var error = scan_socket.bind(DISCOVERY_PORT)
	if error != OK:
		status = "Room discovery is unavailable. Join using the host's address instead."

func stop_scan() -> void:
	if scan_socket:
		scan_socket.close()
	scan_socket = null

func room_data() -> Dictionary:
	return {"slots": Party.slots, "skins": skins, "peers": peers, "difficulty": Party.difficulty, "screen": screen}

func publish_lobby() -> void:
	if not active or not hosting:
		return
	lobby.rpc(room_data())
	changed.emit()

@rpc("any_peer", "call_remote", "reliable")
func hello(protocol: String, skin: String) -> void:
	if not hosting:
		return
	var sender = multiplayer.get_remote_sender_id()
	if peers.has(sender):
		return
	if protocol != PROTOCOL or screen != "lobby":
		reject.rpc_id(sender, "Room unavailable or game versions differ.")
		return
	var seat = -1
	for i in range(1, 4):
		if not peers.values().has(i):
			seat = i
			break
	if seat < 0:
		reject.rpc_id(sender, "This room is full.")
		return
	peers[sender] = seat
	Party.slots[seat] = "Human"
	skins[seat] = valid_skin(skin)
	publish_lobby()

func valid_skin(value: String) -> String:
	for item in Party.SKINS:
		if item.id == value:
			return value
	return "classic"

@rpc("authority", "call_remote", "reliable")
func reject(message: String) -> void:
	fail(message)

@rpc("authority", "call_remote", "reliable")
func lobby(data: Dictionary) -> void:
	Party.slots = data.slots.duplicate()
	skins = data.skins.duplicate()
	peers = data.peers.duplicate()
	local_id = int(peers.get(multiplayer.get_unique_id(), -1))
	Party.difficulty = int(data.difficulty)
	status = ""
	screen = data.screen
	changed.emit()

func set_seat(id: int, mode: String) -> void:
	if not hosting or screen != "lobby" or id < 1 or id > 3 or peers.values().has(id) or not mode in ["Bot", "Off"]:
		return
	Party.slots[id] = mode
	publish_lobby()

func _disconnected(peer_id: int) -> void:
	_handle_disconnected.call_deferred(peer_id)

func _handle_disconnected(peer_id: int) -> void:
	if not hosting or not peers.has(peer_id):
		return
	Party.slots[peers[peer_id]] = "Off"
	peers.erase(peer_id)
	if screen != "lobby":
		return_to_lobby("A friend disconnected. Choose seats and start again.")
	else:
		publish_lobby()

func return_to_lobby(message: String = "") -> void:
	if not hosting:
		return
	screen = "lobby"
	waiting = false
	arena = null
	status = message
	event.rpc("lobby", {"message": message})
	publish_lobby()
	if is_instance_valid(ui):
		ui.call_deferred("show_net_lobby")

func show_library() -> void:
	if not hosting:
		return
	screen = "library"
	event.rpc("library", {})

func launch() -> void:
	if not hosting:
		return
	ticket += 1
	screen = "game"
	waiting = true
	wait_started = Time.get_ticks_msec()
	ready_peers = [1]
	var data = {"ticket": ticket, "schedule": Party.schedule, "round": Party.round_index, "cup": Party.tournament, "standings": Party.standings, "room": room_data()}
	event.rpc("launch", data)
	applying = true
	ui.launch_round()
	applying = false

func attach(value: Control) -> void:
	arena = value
	last_state_at = Time.get_ticks_msec()
	if not hosting:
		ready.rpc_id(1, ticket)

@rpc("any_peer", "call_remote", "reliable")
func ready(round_ticket: int) -> void:
	var sender = multiplayer.get_remote_sender_id()
	if not hosting or not peers.has(sender) or round_ticket != ticket or ready_peers.has(sender):
		return
	ready_peers.append(sender)

func can_control(id: int) -> bool:
	return not active or id == local_id

func intercept(id: int, action: String, value: Variant = null) -> bool:
	if not active or dispatching:
		return false
	if id != local_id:
		# Host bot logic still runs locally.
		return not (hosting and Party.slots[id] == "Bot")
	if waiting or screen != "game":
		return true
	if hosting:
		return false
	if is_instance_valid(arena):
		var extra: Dictionary = {}
		if arena.game_id == "darkspots":
			extra = {"time": arena.time, "index": arena.target_indices[id], "position": arena.positions[id], "square": arena.board_square(id)}
		input_action.rpc_id(1, ticket, action, value, extra)
	return true

@rpc("any_peer", "call_remote", "reliable", 1)
func input_action(round_ticket: int, action: String, value: Variant, extra: Dictionary) -> void:
	var sender = multiplayer.get_remote_sender_id()
	if not hosting or screen != "game" or waiting or round_ticket != ticket or not peers.has(sender) or not is_instance_valid(arena) or arena.ended or arena.paused:
		return
	var id: int = peers[sender]
	var now = Time.get_ticks_msec()
	if now - int(rate_times.get(sender, 0)) < 15:
		return
	rate_times[sender] = now
	dispatching = true
	match action:
		"tap":
			if arena.game_id in ["sprint", "signal", "burger", "darkspots"]:
				if arena.game_id == "darkspots":
					remote_taps[id] = extra
				arena.press_corner(id)
				remote_taps.erase(id)
		"card":
			if arena.game_id == "pairs" and arena.roster[arena.turn].id == id and value is int:
				arena.choose_card(value)
		"move":
			if arena.game_id == "dance" and value is int:
				arena.animate_finger(id, true)
				arena.choose_move(id, value)
		"obstacle":
			if arena.game_id == "obby" and value in ["jump", "duck"]:
				arena.pending_actions[id] = value
				arena.animate_finger(id, true)
				arena.do_action(id, value)
		"steer":
			if arena.game_id == "snake" and value is Vector2 and value.is_finite() and not value.is_zero_approx():
				arena.wishes[id] = value.normalized()
	dispatching = false

func client_frame(value: Control, _delta: float) -> bool:
	if not active:
		return false
	if waiting or not hosting:
		if not hosting and not value.paused and not value.ended:
			# Interpolate presentation between authoritative 30Hz updates.
			if value.countdown <= 0:
				value.time = minf(value.time + _delta, last_render_time + 0.05)
				if value.game_id == "darkspots":
					for id in value.positions:
						value.positions[id] = fposmod(value.time * value.LAP_SPEED, 1.0)
				elif value.game_id == "snake":
					value.accumulator = minf(value.STEP, value.accumulator + _delta)
			if value.game_id == "pairs":
				for i in range(16):
					value.flips[i] = move_toward(value.flips[i], 1.0 if value.opened.has(i) or value.matched.has(i) else 0.0, _delta * 4)
		value.queue_redraw()
		return true
	return false

func snapshot() -> Dictionary:
	var data: Dictionary = {}
	var fields: Array = STATE.common + STATE.get(arena.game_id, [])
	for field in fields:
		data[field] = arena.get(field)
	if arena.game_id == "pairs":
		var visible_deck: Array = []
		for i in range(16):
			visible_deck.append(arena.deck[i] if arena.opened.has(i) or arena.matched.has(i) else -1)
		data.deck = visible_deck
	if arena.game_id == "burger":
		var lanes: Dictionary = {}
		for id in arena.lanes:
			var lane = arena.lanes[id]
			var pieces: Array = []
			for piece in lane.pieces:
				pieces.append([piece.kind, piece.width, piece.height, piece.position, piece.rotation])
			lanes[id] = {"clock": lane.clock, "preview_x": lane.preview_x, "preview_y": lane.preview_y, "next_kind": lane.next_kind, "cooldown": lane.cooldown, "accepting": lane.accepting, "camera": lane.camera.position, "pieces": pieces}
		data["lanes"] = lanes
	return data

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func state(round_ticket: int, packed: PackedByteArray) -> void:
	if packed.size() > 65536:
		return
	var decoded = bytes_to_var(packed.decompress_dynamic(262144, FileAccess.COMPRESSION_DEFLATE))
	if not decoded is Dictionary:
		return
	var data: Dictionary = decoded
	if hosting or screen != "game" or round_ticket != ticket or not is_instance_valid(arena):
		return
	last_state_at = Time.get_ticks_msec()
	last_render_time = float(data.get("time", 0))
	var old_scores: Dictionary = arena.scores.duplicate()
	var old_opened: Array = arena.opened.duplicate() if arena.game_id == "pairs" else []
	var old_watch: int = arena.watch_index if arena.game_id == "dance" else -1
	var fields: Array = STATE.common + STATE.get(arena.game_id, [])
	for field in fields:
		if data.has(field):
			# Preserve a previously revealed card during its closing animation.
			if field == "deck":
				for i in range(16):
					if data.deck[i] >= 0:
						arena.deck[i] = data.deck[i]
			else:
				arena.set(field, data[field])
	if arena.game_id == "burger" and data.has("lanes"):
		for id in data.lanes:
			arena.lanes[id].apply_network(data.lanes[id])
	if arena.game_id == "dance" and old_watch != arena.watch_index and arena.watch_index >= 0:
		arena.audio.tone([520, 660, 780, 900][arena.sequence[arena.watch_index]])
	elif old_scores != arena.scores or (arena.game_id == "pairs" and old_opened != arena.opened):
		arena.audio.tone(660)
	arena.queue_redraw()

func results(scores: Dictionary, award: bool) -> void:
	screen = "results"
	event.rpc("results", {"ticket": ticket, "scores": scores, "award": award})

func ceremony() -> void:
	event.rpc("ceremony", {"ticket": ticket})

func pause_game(paused: bool) -> void:
	if hosting:
		event.rpc("pause", {"paused": paused})

@rpc("authority", "call_remote", "reliable")
func event(kind: String, data: Dictionary) -> void:
	if not active or hosting or not is_instance_valid(ui):
		return
	match kind:
		"lobby":
			screen = "lobby"
			waiting = false
			arena = null
			status = data.message
			ui.call_deferred("show_net_lobby")
		"library":
			screen = "library"
			ui.call_deferred("show_net_waiting")
		"launch":
			if int(data.ticket) <= ticket:
				return
			ticket = int(data.ticket)
			lobby(data.room)
			screen = "game"
			Party.start_session(data.schedule[0], data.cup)
			Party.schedule = data.schedule.duplicate()
			Party.round_index = int(data.round)
			Party.standings = data.standings.duplicate()
			ui.launch_round()
		"results":
			if int(data.ticket) != ticket or screen != "game":
				return
			screen = "results"
			ui.last_scores = data.scores
			ui.last_winners = Party.record_round(data.scores, data.award)
			ui.cup_done = false
			ui.call_deferred("show_results")
		"ceremony":
			if int(data.ticket) == ticket and screen == "results":
				ui.last_winners = Party.finish_cup()
				ui.cup_done = true
				ui.call_deferred("show_results")
		"pause":
			if is_instance_valid(arena):
				arena.paused = data.paused

func _process(delta: float) -> void:
	if scan_socket:
		while scan_socket.get_available_packet_count() > 0:
			var packet = scan_socket.get_packet()
			var address = scan_socket.get_packet_ip()
			if packet.size() > 512:
				continue
			var data = JSON.parse_string(packet.get_string_from_utf8())
			if data is Dictionary and data.get("protocol") == PROTOCOL:
				rooms[address] = {"address": address, "seen": Time.get_ticks_msec(), "seats": clampi(int(data.get("seats", 1)), 1, 4)}
				changed.emit()
		for address in rooms.keys():
			if Time.get_ticks_msec() - int(rooms[address].seen) > 4000:
				rooms.erase(address)
				changed.emit()
	if not active:
		return
	if not hosting:
		if local_id < 0 and Time.get_ticks_msec() - joined_at > 12000:
			fail("Joining timed out. Check both devices are on the same Wi-Fi.")
		elif screen == "game" and Time.get_ticks_msec() - last_state_at > 12000:
			fail("The host stopped responding. No unfinished-round reward was awarded.")
		return
	beacon_clock += delta
	if screen == "lobby" and beacon_clock >= 0.8 and beacon_socket:
		beacon_clock = 0
		beacon_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
		beacon_socket.put_packet(JSON.stringify({"protocol": PROTOCOL, "seats": peers.size()}).to_utf8_buffer())
	if screen == "game" and is_instance_valid(arena):
		if waiting:
			waiting = ready_peers.size() < peers.size()
			if waiting and Time.get_ticks_msec() - wait_started > 12000:
				return_to_lobby("A device did not become ready. Please try again.")
		snapshot_clock += delta
		if snapshot_clock >= 1.0 / 30:
			snapshot_clock = 0
			state.rpc(ticket, var_to_bytes(snapshot()).compress(FileAccess.COMPRESSION_DEFLATE))
