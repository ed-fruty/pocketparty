extends Node
const Dance = preload("res://games/lets_dance.gd")
const Main = preload("res://ui/main.gd")
var failures: int = 0
var checks: int = 0
var capture: bool = false

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(title)

func make_game(slots: Array) -> Control:
	Party.slots = slots
	var game = Dance.new()
	game.roster = Party.players()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game)
	game.set_process(false)
	game.countdown = 0
	game.rng.seed = 42
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
	Party.save_path = "res://builds/dance_test_save.json"
	Party.sound = false
	Music.set_enabled(false)
	get_window().size = Vector2i(540, 900)
	var game = make_game(["Human", "Human", "Human", "Bot"])
	check(game.leader_id >= 0 and game.leader_id < 4, "Exactly one active player is chosen as dance leader")
	game.leader_id = 0
	game.choose_move(1, 2)
	check(game.sequence.is_empty(), "Followers cannot create or skip leader moves")
	game.choose_move(0, 0)
	game.choose_move(0, 1)
	await photo(game, "dance_create_portrait")
	check(game.sequence == [0, 1] and game.can_move(0) and not game.can_move(1), "Only chosen leader's move controls are enabled")
	for move in [2, 3, 0]:
		game.choose_move(0, move)
	check(game.sequence == [0, 1, 2, 3, 0] and game.phase == "watch", "Five leader moves become exact shared sequence")
	game.choose_move(0, 2)
	check(game.sequence.size() == 5, "Cannot append moves after dance is set")
	game._process(0.1)
	check(game.watch_index == 0 and game.poses[0] == 0, "Replay animates first leader move")
	game._process(1)
	check(game.watch_index == 1 and game.poses[0] == 1, "Replay follows original move order")
	game._process(3.2)
	check(game.phase == "repeat" and not game.can_move(0) and game.can_move(1), "Followers copy only after complete replay; leader waits")
	game.choose_move(1, 1)
	check(game.failed[1] and game.progress[1] == 0, "Skipping the first move fails the attempt")
	game.choose_move(1, 0)
	check(game.progress[1] == 0 and not game.can_move(1), "Failed player cannot continue or skip ahead")
	for move in game.sequence:
		game.choose_move(2, move)
	check(game.progress[2] == 5 and game.scores[2] == 5 and game.successful_ids() == [2], "Exact full sequence earns perfect dance")
	game.choose_move(2, 0)
	check(game.progress[2] == 5, "Extra taps cannot earn more moves")
	game.failed[3] = true
	game.finish_copy()
	check(game.scores[0] == 0 and game.scores[2] == 5, "Perfect followers beat the dance leader")
	await photo(game, "dance_finish_portrait")
	game._process(1.1)
	check(game.ended, "Dance result animation completes round")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Human", "Off", "Off"])
	game.leader_id = 0
	for move in [0, 1, 2, 3, 0]:
		game.choose_move(0, move)
	game.begin_repeat()
	game.choose_move(1, 3)
	game.finish_copy()
	check(game.scores[0] == 5 and game.scores[1] == 0 and game.has_winner(), "Leader wins when nobody repeats complete dance")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Bot", "Human", "Bot"])
	game.leader_id = 0
	await photo(game, "dance_four_portrait")
	check(game.pads[0].position.y > game.size.y * 0.5 and game.pads[2].position.y < game.size.y * 0.5, "Dance controls keep P1 at bottom")
	check(game.corner_at(game.pads[1].get_center()) == -1, "Bot controls reject human input")
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = game.get_global_transform_with_canvas() * game.move_pads[0][3].get_center()
	get_viewport().push_input(touch, true)
	await get_tree().process_frame
	check(game.sequence == [3], "Native touch selects exact leader move")
	touch.pressed = false
	get_viewport().push_input(touch, true)
	game.sequence = [0, 1, 2, 3, 0]
	game.begin_repeat()
	game.choose_move(2, 0)
	game._process(0.2)
	await photo(game, "dance_repeat_portrait")
	get_window().size = Vector2i(1200, 720)
	await photo(game, "dance_repeat_landscape")
	for rect in game.pads.values():
		check(Rect2(Vector2.ZERO, game.size).encloses(rect), "Landscape move controls fit inside screen")
	game.paused = true
	var old_time: float = game.time
	game._process(5)
	game.choose_move(2, 1)
	check(game.time == old_time and game.progress[2] == 1, "Pause freezes replay and blocks dance moves")
	game.paused = false
	game._process(13)
	check(game.phase == "finish" and game.failed[2], "Unfinished sequence fails at deadline")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Off", "Off", "Off"])
	check(game.leader_id == -1 and game.phase == "watch" and game.sequence.size() == 5, "Solo player watches virtual teacher")
	game.begin_repeat()
	game.choose_move(0, (game.sequence[0] + 1) % 4)
	game.finish_copy()
	check(not game.has_winner(), "Failed solo dance has no winner")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Bot", "Bot", "Off", "Off"])
	for i in range(500):
		game._process(0.1)
		if game.ended:
			break
	check(game.ended and game.sequence.size() == 5 and game.has_winner(), "Bots create and repeat a full round without stalling")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Human", "Off", "Off"])
	game._process(13)
	check(game.phase == "watch" and game.sequence.size() == 5, "Inactive creator cannot stall round forever")
	game.queue_free()
	await get_tree().process_frame
	var main = Main.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	Party.slots = ["Human", "Off", "Off", "Off"]
	Party.coins = 1000
	Party.start_session("dance", false)
	main.launch_round()
	main.arena.countdown = 0
	main.arena.begin_repeat()
	main.arena.failed[0] = true
	main.arena.finish_copy()
	main.round_finished({0: 0})
	await photo(main, "dance_solo_results_landscape")
	check(main.last_winners.is_empty() and Party.coins == 1000, "Failed solo dance awards no gold through real results screen")
	main.show_library()
	await photo(main, "dance_library_landscape")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Party.save_path))
	print("DANCE: %d checks, %d failures" % [checks, failures])
	Music.player.stop()
	await get_tree().create_timer(0.06).timeout
	get_tree().quit(0 if failures == 0 else 1)
