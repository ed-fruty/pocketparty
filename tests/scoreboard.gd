extends Node
const Main = preload("res://ui/main.gd")
var checks = 0
var failures = 0
var ui: Control
var screen: SubViewport
var capture = false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames() -> void:
	for i in range(6):
		await get_tree().process_frame

func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--screenshots")
	Party.save_path = "res://builds/scoreboard_test_save.json"
	Party.sound = false
	Music.set_enabled(false)
	Music.player.stop()
	Party.slots = ["Human", "Human", "Bot", "Human"]
	screen = SubViewport.new()
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(screen)
	ui = Main.new()
	screen.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Party.start_session("sprint", true)
	Party.schedule = ["sprint", "signal", "pairs", "burger", "darkspots", "obby", "snake", "dance"]
	for round_id in range(8):
		Party.round_index = round_id
		Party.record_round({0: 9, 1: 9, 2: 5, 3: 0})
	check(Party.round_history.size() == 8, "Every completed round is recorded")
	var coins: int = Party.coins
	Party.record_round({0: 9, 1: 9, 2: 5, 3: 0})
	check(Party.round_history.size() == 8 and coins == Party.coins, "Duplicate result does not duplicate history or gold")
	for id in Party.standings:
		var sum: int = 0
		for round_result in Party.round_history:
			sum += round_result.points[id]
		check(sum == Party.standings[id], "Round columns add up to total")
	for dimensions in [Vector2i(1280, 720), Vector2i(720, 1280)]:
		screen.size = dimensions
		ui.show_results()
		await frames()
		var board = ui.find_child("TournamentScoreboard", true, false)
		check(is_instance_valid(board), "Tournament results open the scoreboard automatically")
		check(ui.content.get_combined_minimum_size().y <= ui.menu_scroll.size.y, "Eight-round table fits without scrolling")
		check(board.points_for(0, 0) == 40 and board.points_for(0, 1) == 40 and board.points_for(0, 2) == 20, "Tied placement points shown correctly")
		board.progress = 0
		check(board.shown_total(0) == 280, "Counting starts from previous total")
		board.progress = 1
		check(board.shown_total(0) == 320, "Counting finishes at exact total")
		check(board.ordered[0].id == 0 and board.ordered[1].id == 1, "Tied leaders have stable player order")
		if capture:
			await get_tree().create_timer(1.1).timeout
			RenderingServer.force_draw()
			screen.get_texture().get_image().save_png("res://builds/scoreboard-%s.png" % ("landscape" if dimensions.x > dimensions.y else "portrait"))
	ui.last_winners = Party.finish_cup()
	ui.cup_done = true
	var balance: int = Party.coins
	ui.show_cup_ceremony()
	ui.show_scoreboard(true)
	await frames()
	check(ui.page == "scoreboard", "Complete table can open after cup ceremony")
	ui.back()
	check(ui.cup_done and Party.coins == balance, "Returning to ceremony cannot award gold twice")
	Party.start_session("sprint", false)
	check(Party.round_history.is_empty(), "New session clears old table")
	Music.player.stop()
	await get_tree().create_timer(0.1).timeout
	print("SCOREBOARD: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
