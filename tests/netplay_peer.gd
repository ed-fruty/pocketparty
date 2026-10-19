extends Node
const Main = preload("res://ui/main.gd")
var ui: Control
var role: String
var failures = 0
var checks = 0
var captured: Dictionary = {}

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(role + ": " + title)

func wait_seconds(value: float) -> void:
	await get_tree().create_timer(value).timeout

func _ready() -> void:
	role = OS.get_cmdline_user_args()[0]
	Party.save_path = "res://builds/netplay_test_%s.json" % role
	Party.coins = 1000
	Party.sound = false
	Music.set_enabled(false)
	Music.player.stop()
	ui = Main.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	if role == "host":
		await host_test()
	else:
		await client_test()
	NetPlay.leave()
	Music.player.stop()
	await wait_seconds(0.1)
	print("NETPLAY %s: %d checks, %d failures" % [role, checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func host_test() -> void:
	check(NetPlay.host() == OK, "host starts")
	ui.show_net_lobby()
	for i in range(100):
		if NetPlay.peers.size() == 4:
			break
		await wait_seconds(0.1)
	check(NetPlay.peers.size() == 4, "three devices join")
	check(Party.slots == ["Human", "Human", "Human", "Human"], "seats assigned")
	check(NetPlay.local_id == 0, "host owns P1")
	NetPlay.set_seat(1, "Bot")
	check(Party.slots[1] == "Human", "cannot replace connected friend")
	for game in ["sprint", "signal", "pairs", "burger", "darkspots", "obby", "snake", "dance"]:
		Party.start_session(game, false)
		ui.launch_round()
		await wait_seconds(0.7)
		check(not NetPlay.waiting, game + " ready handshake")
		var arena = ui.arena
		arena.countdown = 0
		if game == "signal":
			arena.signal_phase = "go"
		if game == "darkspots":
			for id in arena.targets:
				arena.targets[id] = fposmod(arena.time * arena.LAP_SPEED + 0.15, 1.0)
		if game == "pairs":
			arena.turn = 1
		if game == "dance":
			arena.leader_id = 1
		await wait_seconds(0.7)
		check(is_instance_valid(ui.arena), game + " remains running")
		if game == "sprint":
			check(arena.scores[1] > 0 and arena.scores[2] > 0 and arena.scores[3] > 0, "remote taps reach host")
		if game == "darkspots":
			check(arena.scores[1] > 0, "remote displayed gold hit")
		if game == "burger":
			check(arena.lanes[1].pieces.size() > 0, "remote burger drop")
		if game == "pairs":
			check(arena.opened.size() > 0, "remote card input")
		if game == "obby":
			check(arena.jump_starts[1] >= 0 or arena.duck_ends[1] > 0, "remote obstacle action")
		if game == "dance":
			check(not arena.sequence.is_empty(), "remote dance move")
		if game == "snake":
			check(arena.wishes[1].x > 0.5, "remote snake steering")
		# Force a tie to check each wallet awards exactly one human's winnings.
		arena.set_process(false)
		var before = Party.coins
		arena.scores = {0: 5, 1: 5, 2: 5, 3: 5}
		arena.complete()
		await wait_seconds(0.3)
		check(Party.coins == before + 15, game + " own wallet only")
		NetPlay.results({0: 5, 1: 5, 2: 5, 3: 5}, true)
		await wait_seconds(0.2)
	# Two-round cup, ties, ceremony and duplicate-safe bonus.
	Party.start_session("sprint", true)
	Party.schedule = ["sprint", "signal"]
	ui.launch_round()
	await wait_seconds(0.5)
	ui.arena.set_process(false)
	ui.arena.scores = {0: 9, 1: 9, 2: 0, 3: 0}
	ui.arena.complete()
	await wait_seconds(0.3)
	ui.next_round()
	await wait_seconds(0.5)
	ui.arena.set_process(false)
	ui.arena.scores = {0: 9, 1: 9, 2: 0, 3: 0}
	ui.arena.complete()
	await wait_seconds(0.3)
	var before = Party.coins
	ui.next_round()
	await wait_seconds(0.3)
	check(Party.round_history.size() == 2, "complete tournament round history")
	check(Party.cup_winners == [0, 1], "tied cup winners")
	check(Party.coins == before + 40, "own cup bonus")
	NetPlay.ceremony()
	await wait_seconds(0.3)
	check(Party.coins == before + 40, "cup bonus not duplicated")
	check(Party.coins == 1000 + 8 * 15 + 2 * 15 + 40, "total wallet")
	NetPlay.return_to_lobby()
	await wait_seconds(0.5)

func client_test() -> void:
	check(NetPlay.join("127.0.0.1") == OK, "connect starts")
	ui.show_net_lobby()
	for i in range(1200):
		await wait_seconds(0.025)
		if not NetPlay.active:
			break
		if NetPlay.screen == "game" and is_instance_valid(ui.arena) and ui.arena.countdown <= 0:
			var a = ui.arena
			var id = NetPlay.local_id
			check(id > 0 and id < 4, "own assigned seat") if not captured.has("seat") else null
			captured["seat"] = true
			captured[a.game_id] = true
			match a.game_id:
				"sprint", "signal", "darkspots", "burger": a.activate(id)
				"pairs": a.choose_card(0)
				"obby": a.do_action(id, "jump")
				"dance": a.choose_move(id, 0)
				"snake": NetPlay.intercept(id, "steer", Vector2.RIGHT)
		if NetPlay.screen == "results":
			check(ui.last_scores.size() == 4, "received authoritative scores") if not captured.has("results") else null
			captured["results"] = true
		if ui.cup_done:
			captured["cup"] = true
			check(Party.round_history.size() == 2, "complete synced tournament history") if not captured.has("history") else null
			captured["history"] = true
		if captured.has("cup") and NetPlay.screen == "lobby":
			break
	for game in ["sprint", "signal", "pairs", "burger", "darkspots", "obby", "snake", "dance"]:
		check(captured.has(game), "received " + game)
	check(captured.has("cup"), "received cup ceremony")
	var expected = 1000 + 8 * 15 + (2 * 15 + 40 if NetPlay.local_id == 1 else 0)
	check(Party.coins == expected, "local-only rewards, duplicate-safe: got %d expected %d" % [Party.coins, expected])
	await wait_seconds(1.0)
