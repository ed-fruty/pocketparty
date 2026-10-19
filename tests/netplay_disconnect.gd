extends Node
const Main = preload("res://ui/main.gd")
var ui: Control
var role: String
var failures = 0
var checks = 0

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(role + ": " + title)

func wait_for(test: Callable, seconds: float = 8) -> bool:
	for i in range(int(seconds * 20)):
		if test.call():
			return true
		await get_tree().create_timer(0.05).timeout
	return false

func _ready() -> void:
	role = OS.get_cmdline_user_args()[0]
	Party.save_path = "res://builds/netplay_disconnect_%s.json" % role
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
	await get_tree().create_timer(0.1).timeout
	print("DISCONNECT %s: %d checks, %d failures" % [role, checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func host_test() -> void:
	check(NetPlay.host() == OK, "host created")
	ui.show_net_lobby()
	check(await wait_for(func(): return NetPlay.peers.size() == 2), "friend joined")
	NetPlay.set_seat(2, "Bot")
	check(Party.slots == ["Human", "Human", "Bot", "Off"], "mixed bot/empty seats")
	ui.show_library()
	Party.start_session("sprint", false)
	ui.launch_round()
	check(await wait_for(func(): return not NetPlay.waiting), "ready handshake")
	ui.arena.countdown = 0
	await get_tree().create_timer(0.8).timeout
	check(ui.arena.scores[0] == 0, "friend cannot control host")
	check(ui.arena.scores[1] > 0, "friend controls own seat")
	check(await wait_for(func(): return NetPlay.screen == "lobby"), "disconnect aborts unfinished round")
	check(Party.coins == 1000, "aborted round awards nothing")
	check(Party.slots[1] == "Off" and Party.slots[2] == "Bot", "departed seat empty; bot retained")
	check(await wait_for(func(): return NetPlay.peers.size() == 2), "friend can reconnect")
	Party.start_session("sprint", false)
	ui.launch_round()
	check(await wait_for(func(): return not NetPlay.waiting), "new match after reconnect")
	ui.arena.countdown = 0
	await get_tree().create_timer(0.4).timeout
	ui.toggle_pause()
	await get_tree().create_timer(0.25).timeout
	check(ui.arena.paused, "host can pause")
	ui.toggle_pause()
	await get_tree().create_timer(0.25).timeout
	NetPlay.leave()

func client_test() -> void:
	NetPlay.scan()
	check(await wait_for(func(): return not NetPlay.rooms.is_empty(), 4), "host discovered over UDP")
	NetPlay.stop_scan()
	check(NetPlay.join("127.0.0.1") == OK, "join")
	ui.show_net_lobby()
	check(await wait_for(func(): return NetPlay.screen == "game" and is_instance_valid(ui.arena) and ui.arena.countdown <= 0), "game received")
	ui.arena.activate(0)
	NetPlay.input_action.rpc_id(1, NetPlay.ticket + 99, "tap", null, {})
	for i in range(4):
		ui.arena.activate(NetPlay.local_id)
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(0.5).timeout
	NetPlay.leave()
	check(Party.coins == 1000, "leaving unfinished game awards nothing")
	await get_tree().create_timer(0.5).timeout
	check(NetPlay.join("127.0.0.1") == OK, "rejoin")
	ui.show_net_lobby()
	check(await wait_for(func(): return NetPlay.screen == "game" and is_instance_valid(ui.arena)), "new round after reconnect")
	check(await wait_for(func(): return is_instance_valid(ui.arena) and ui.arena.paused), "host pause reaches client")
	check(await wait_for(func(): return is_instance_valid(ui.arena) and not ui.arena.paused), "host resume reaches client")
	check(await wait_for(func(): return not NetPlay.active), "host loss ends room")
	check(Party.coins == 1000, "host loss awards nothing")
