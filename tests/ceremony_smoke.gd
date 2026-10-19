extends Node
const Main = preload("res://ui/main.gd")
var checks: int = 0
var failures: int = 0
var capture: bool = false
var main: Control

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func photo(title: String) -> void:
	for i in range(6):
		await get_tree().process_frame
	if capture:
		await get_tree().create_timer(1.1).timeout
		RenderingServer.force_draw()
		get_viewport().get_texture().get_image().save_png("res://builds/%s.png" % title)

func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--screenshots")
	Party.save_path = "res://builds/ceremony_test_save.json"
	Party.sound = false
	Music.set_enabled(false)
	Party.slots = ["Human", "Human", "Human", "Bot"]
	Party.equipped = ["panda", "capybara", "koala", "rabbit"]
	Party.coins = 1000
	Party.start_session("sprint", true)
	Party.record_round({0: 9, 1: 5, 2: 3, 3: 1})
	check(Party.round_points == {0: 40, 1: 30, 2: 20, 3: 10}, "Round points follow finish order")
	check(Party.standings == Party.round_points, "First round initializes tournament totals")
	var balance: int = Party.coins
	Party.record_round({0: 9, 1: 5, 2: 3, 3: 1})
	check(Party.coins == balance and Party.standings[0] == 40, "Reopening results cannot award points or gold twice")
	Party.round_index = 1
	Party.record_round({0: 1, 1: 3, 2: 5, 3: 9})
	check(Party.round_points == {0: 10, 1: 20, 2: 30, 3: 40}, "Each new round has its own earned points")
	check(Party.standings == {0: 50, 1: 50, 2: 50, 3: 50}, "Round points accumulate across tournament")
	get_window().size = Vector2i(1200, 720)
	main = Main.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	main.current_game = "sprint"
	main.last_scores = {0: 1, 1: 3, 2: 5, 3: 9}
	main.last_winners = [3]
	main.show_results()
	await photo("tournament_points_landscape")
	check(main.content.get_combined_minimum_size().y <= main.menu_scroll.size.y, "Round standings fit landscape without scrolling")
	for winner_count in range(1, 5):
		Party.cup_awarded = false
		Party.standings = {}
		var expected: Array = []
		for id in range(4):
			Party.standings[id] = 100 if id < winner_count else 70 - id * 10
			if id < winner_count:
				expected.append(id)
		balance = Party.coins
		main.last_winners = Party.finish_cup()
		check(main.last_winners == expected, "All players tied for highest total win")
		check(Party.coins == balance + mini(winner_count, 3) * 40, "Only human tied champions receive bonus gold")
		Party.finish_cup()
		check(Party.coins == balance + mini(winner_count, 3) * 40, "Ceremony bonus is idempotent")
		main.cup_done = true
		main.show_results()
		await photo("cup_%d_winners_landscape" % winner_count)
		var ceremony: Control = main.find_child("TournamentCeremony", true, false)
		check(is_instance_valid(ceremony) and ceremony.winners == expected, "Ceremony gives a cup to every tied winner")
		check(ceremony.dancers.size() == 4 and ceremony.podium_order.size() == 4, "Every non-winner remains on the stage")
		for id in ceremony.dancers:
			check(not ceremony.dancers[id].animate, "Skin avatars stay still; ceremony alone moves winners")
		check(ceremony.confetti.size() > 50, "Ceremony has animated confetti")
		check(main.content.get_combined_minimum_size().y <= main.menu_scroll.size.y, "Champion results fit landscape without scrolling")
		if winner_count in [1, 2, 4]:
			get_window().size = Vector2i(540, 900)
			await photo("cup_%d_winners_portrait" % winner_count)
			check(main.content.get_combined_minimum_size().y <= main.menu_scroll.size.y, "Champion results fit portrait")
			get_window().size = Vector2i(1200, 720)
	Party.start_session("sprint", true)
	check(Party.round_points.is_empty() and Party.standings[0] == 0, "New tournament starts with zero totals and round points")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Party.save_path))
	print("CEREMONY: %d checks, %d failures" % [checks, failures])
	Music.player.stop()
	await get_tree().create_timer(0.06).timeout
	get_tree().quit(0 if failures == 0 else 1)
