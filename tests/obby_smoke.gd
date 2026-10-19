extends Node
const Obby = preload("res://games/obby_run.gd")
const Main = preload("res://ui/main.gd")
var checks: int = 0
var failures: int = 0
var capture: bool = false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func make_game(slots: Array) -> Control:
	Party.slots = slots
	var game = Obby.new()
	game.roster = Party.players()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game)
	game.set_process(false)
	game.countdown = 0
	return game

func photo(game: Control, title: String) -> void:
	game.queue_redraw()
	for i in range(5):
		await get_tree().process_frame
	if capture:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://builds/%s.png" % title)

func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--screenshots")
	Party.save_path = "res://builds/obby_test_save.json"
	Party.sound = false
	Music.set_enabled(false)
	get_window().size = Vector2i(540, 900)
	var game = make_game(["Human", "Human", "Off", "Off"])
	game.course.resize(1)
	game.course[0].at = 1.0
	game.course[0].kind = "jump"
	game.time = 0.66
	game.do_action(0, "jump")
	game.do_action(1, "duck")
	game._process(0.34)
	check(game.alive[0] and not game.alive[1], "Jump clears low block; ducking hits it and eliminates player")
	check(game.finishing == 0 and game.scores[0] > game.scores[1], "Last survivor wins over eliminated runner")
	await photo(game, "obby_elimination_portrait")
	check(game.pads[0].position.y > game.size.y * 0.5, "Obby P1 controls start at bottom")
	check(game.corner_at(game.action_pads[1].jump.get_center()) == -1, "Eliminated player cannot tap")
	game._process(0.81)
	check(game.ended, "Elimination round completes after short outcome animation")
	var old_jump: float = game.jump_starts[0]
	game.do_action(0, "jump")
	check(game.jump_starts[0] == old_jump, "Ended round rejects actions")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Off", "Off", "Off"])
	game.course.resize(1)
	game.course[0].at = 1.0
	game.course[0].kind = "duck"
	game.time = 0.66
	game.do_action(0, "duck")
	game._process(0.34)
	check(game.alive[0] and game.finishing < 0, "Duck clears high bar and solo game continues")
	game.paused = true
	var old_time: float = game.time
	game._process(4)
	game.do_action(0, "jump")
	check(game.time == old_time and game.jump_starts[0] < 0, "Pause freezes course and blocks actions")
	game.paused = false
	game.time = 2
	game.do_action(0, "jump")
	game.do_action(0, "jump")
	check(game.jump_starts[0] == 2, "Repeated jump does not reset flight")
	game.do_action(0, "duck")
	check(game.duck_ends[0] < 2, "Cannot duck in mid-jump")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Off", "Off", "Off"])
	game.course[0].at = 1
	game._process(1.2)
	check(not game.alive[0] and game.living_ids().is_empty(), "Missed obstacle eliminates solo runner even during a long frame")
	Party.coins = 1000
	Party.start_session("obby", false)
	check(Party.record_round(game.scores, false).is_empty() and Party.coins == 1000, "Failed solo run awards no win gold")
	Party.record_round(game.scores, false)
	check(Party.coins == 1000, "Failed round remains reward-idempotent")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Bot", "Human", "Bot"])
	for obstacle in game.course:
		for id in obstacle.plans:
			obstacle.plans[id].correct = true
	for frame in range(2200):
		for obstacle in game.course:
			for id in [0, 2]:
				if game.time >= obstacle.at - 0.34 and game.time < obstacle.at - 0.30:
					game.do_action(id, obstacle.kind)
		game._process(1.0 / 60)
	check(game.living_ids().size() == 4 and game.ended, "Perfect human inputs and bots clear identical full course")
	check(game.scores[0] == game.scores[1] and game.scores[2] == game.scores[3], "Finishers tie fairly")
	game.ended = false
	game.finishing = -1
	game.time = 1.95
	game.jump_starts[0] = 1.8
	game.duck_ends[2] = 2.4
	game._process(0.01)
	await photo(game, "obby_four_portrait")
	check(game.action_pads.size() == 2 and game.pads.size() == 4, "Only humans have interactive jump and duck controls; bots remain visible")
	for id in game.pads:
		check(Rect2(Vector2.ZERO, game.size).encloses(game.pads[id]), "Portrait controls inside screen")
	var pos: Vector2 = game.action_pads[0].duck.get_center()
	check(game.corner_at(pos) == 0 and game.pending_actions[0] == "duck", "Duck button maps to correct player and action")
	get_window().size = Vector2i(1200, 720)
	await photo(game, "obby_four_landscape")
	for id in game.pads:
		check(Rect2(Vector2.ZERO, game.size).encloses(game.pads[id]), "Landscape controls inside screen")
	check(game.pads[0].position.y > game.size.y * 0.5, "Landscape P1 stays at bottom")
	game.time = 2.8
	game.jump_starts[0] = -10
	game.duck_ends[0] = -10
	game.jump_starts[2] = -10
	game.duck_ends[2] = -10
	for id in [0, 2]:
		var touch = InputEventScreenTouch.new()
		touch.index = id
		touch.pressed = true
		touch.position = game.get_global_transform_with_canvas() * game.action_pads[id]["duck" if id == 0 else "jump"].get_center()
		get_viewport().push_input(touch, true)
	await get_tree().process_frame
	check(is_equal_approx(float(game.duck_ends[0]), game.time + game.DUCK_SECONDS), "Native touch on P1 duck button starts duck")
	check(game.jump_starts[2] == game.time and game.duck_ends[2] < game.time, "Simultaneous P3 jump touch stays independent of P1 duck")
	for id in [0, 2]:
		var release = InputEventScreenTouch.new()
		release.index = id
		release.pressed = false
		get_viewport().push_input(release, true)
	await get_tree().create_timer(0.4).timeout
	game.queue_free()
	await get_tree().process_frame
	var main = Main.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	Party.slots = ["Human", "Off", "Off", "Off"]
	Party.start_session("obby", false)
	main.launch_round()
	main.arena.countdown = 0
	main.arena.alive[0] = false
	var balance: int = Party.coins
	main.round_finished({0: 10})
	await photo(main, "obby_solo_results_landscape")
	check(main.page == "results" and main.last_winners.is_empty() and Party.coins == balance, "Actual results show failed solo without paying winner gold")
	main.show_library()
	await photo(main, "obby_library_landscape")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Party.save_path))
	print("OBBY: %d checks, %d failures" % [checks, failures])
	Music.player.stop()
	await get_tree().create_timer(0.06).timeout
	get_tree().quit(0 if failures == 0 else 1)
