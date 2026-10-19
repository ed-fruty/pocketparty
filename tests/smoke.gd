extends Node
const Main = preload("res://ui/main.gd")
const Arena = preload("res://games/arena.gd")
var failures: int = 0
var checks: int = 0
var main: Control
var capture: bool = false

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func find_button(node: Node, title: String, game_id: String = "") -> Button:
	if node is Button and ((game_id != "" and node.get_meta("game_id", "") == game_id) or (game_id == "" and node.text == title)):
		return node
	for child in node.get_children():
		var found = find_button(child, title, game_id)
		if found:
			return found
	return null

func frames() -> void:
	for i in range(4):
		await get_tree().process_frame

func photo(name: String) -> void:
	await frames()
	if capture:
		await get_tree().create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://builds/%s.png" % name)

func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--screenshots")
	Party.save_path = "res://builds/test_save.json"
	Party.sound = false
	Music.set_enabled(false)
	var valid: int = 0
	for combination in range(81):
		var code: int = combination
		for seat in range(4):
			Party.slots[seat] = ["Off", "Human", "Bot"][code % 3]
			code = code / 3
		var expected: bool = Party.slots.has("Human")
		check(Party.valid_setup() == expected, "Invalid seat combination")
		if expected:
			valid += 1
	check(valid == 65, "Expected all 65 combinations containing a human")
	Party.slots = ["Human", "Human", "Bot", "Off"]
	Party.coins = 0
	Party.owned = ["classic"]
	Party.start_session("sprint", true)
	check(Party.record_round({0: 10, 1: 10, 2: 4}) == [0, 1], "Tied round winners")
	check(Party.coins == 30 and Party.standings[0] == 30 and Party.standings[2] == 10, "Tie rewards and rankings")
	Party.round_index = 1
	Party.record_round({0: 5, 1: 4, 2: 9})
	check(Party.coins == 30, "Bots must not earn wallet gold")
	Party.round_index = 2
	Party.record_round({0: 9, 1: 6, 2: 4})
	check(Party.finish_cup() == [0] and Party.coins == 85, "Cup champion payout")
	Party.finish_cup()
	Party.record_round({0: 9, 1: 6, 2: 4})
	check(Party.coins == 85, "Rewards must be idempotent")
	check(Party.buy_skin("cat") and Party.coins == 25, "Skin purchase")
	check(not Party.buy_skin("cat") and not Party.buy_skin("royal"), "Duplicate/insufficient purchases")
	Party.equipped[0] = "cat"
	Party.save_progress()
	Party.coins = 999
	Party.load_progress()
	check(Party.coins == 25 and Party.equipped[0] == "cat", "Save roundtrip")
	var f = FileAccess.open(Party.save_path, FileAccess.WRITE)
	f.store_string("broken json")
	f.close()
	Party.load_progress()
	check(Party.coins == 25, "Malformed saves should not destroy in-memory progress")
	Party.slots = ["Human", "Human", "Bot", "Bot"]
	get_window().size = Vector2i(540, 900)
	main = Main.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	await frames()
	await photo("home_portrait")
	main.show_library()
	await photo("library_portrait")
	main.show_setup()
	await photo("setup_portrait")
	main.show_shop()
	await photo("skins_portrait")
	Party.start_session("sprint", false)
	main.launch_round()
	await frames()
	var sprint = main.arena
	sprint.set_process(false)
	sprint.countdown = 0
	sprint.time = 1.0
	sprint.activate(0)
	sprint.activate(0)
	check(sprint.scores[0] == 1, "Sprint debounces input")
	sprint.time = 1.2
	sprint.activate(0)
	check(sprint.scores[0] == 2, "Sprint accepts subsequent press")
	sprint.paused = true
	sprint.activate(0)
	check(sprint.scores[0] == 2, "Pause blocks scoring")
	sprint.paused = false
	sprint.queue_redraw()
	await photo("sprint_portrait")
	check(sprint.pads.size() == 4, "Four touch regions")
	check(sprint.pads[0].position.y > sprint.size.y * 0.5 and sprint.pads[2].position.y < sprint.size.y * 0.5, "P1 starts at bottom with four players")
	check(sprint.corner_at(sprint.pads[2].get_center()) == -1 and sprint.control_label(2, true).contains("BOT"), "Bot controls remain labelled and reject human taps")
	for id in sprint.pads:
		check(Rect2(Vector2.ZERO, sprint.size).encloses(sprint.pads[id]), "Portrait pads within arena")
	var full_roster: Array = sprint.roster.duplicate(true)
	sprint.roster = [full_roster[0]]
	sprint.queue_redraw()
	await photo("sprint_one_bottom_portrait")
	check(sprint.pads.size() == 1 and sprint.pads[0].position.y > sprint.size.y * 0.5, "Solo portrait finger is at bottom")
	check(absf(sprint.pads[0].get_center().x - sprint.size.x * 0.5) < 1, "Solo portrait finger is centered")
	var second_human: Dictionary = full_roster[3].duplicate(true)
	second_human.bot = false
	sprint.roster = [full_roster[0], second_human]
	sprint.queue_redraw()
	await photo("sprint_two_bottom_portrait")
	check(sprint.pads.size() == 2 and sprint.pads[0].position.y == sprint.pads[3].position.y and sprint.pads[3].position.y > sprint.size.y * 0.5, "Two portrait fingers occupy bottom corners even for nonadjacent seats")
	check(sprint.corner_at(sprint.pads[0].get_center()) == 0 and sprint.corner_at(sprint.pads[3].get_center()) == 3, "Bottom fingers retain their player touch mapping")
	sprint.roster = full_roster
	get_window().size = Vector2i(1200, 720)
	await frames()
	sprint.queue_redraw()
	await photo("sprint_landscape")
	check(sprint.pads[0].position.y > sprint.size.y * 0.5, "P1 remains at bottom in landscape")
	for id in sprint.pads:
		check(Rect2(Vector2.ZERO, sprint.size).encloses(sprint.pads[id]), "Landscape pads within arena")
	# Synthetic simultaneous touch events route to separate human seats.
	for id in [0, 1]:
		sprint.time += 0.2
		var event = InputEventScreenTouch.new()
		event.index = id
		event.pressed = true
		event.position = sprint.pads[id].get_center()
		sprint._gui_input(event)
	check(sprint.scores[0] == 3 and sprint.scores[1] == 1, "Multi-touch routing")
	sprint.time += 0.2
	var dispatched_touch = InputEventScreenTouch.new()
	dispatched_touch.index = 4
	dispatched_touch.pressed = true
	dispatched_touch.position = sprint.get_global_transform_with_canvas() * sprint.pads[0].get_center()
	get_viewport().push_input(dispatched_touch, true)
	await get_tree().process_frame
	check(sprint.scores[0] == 4, "Dispatched corner touch reaches scoring through full input pipeline")
	check(sprint.held_corner_touches.has(4), "Corner finger displays held press feedback")
	await get_tree().create_timer(0.13).timeout
	check(is_equal_approx(float(sprint.finger_amounts[0]), 1.0), "Finger eases into held pressed position")
	dispatched_touch.pressed = false
	get_viewport().push_input(dispatched_touch, true)
	await get_tree().process_frame
	check(not sprint.held_corner_touches.has(4), "Finger releases after touch ends")
	check(float(sprint.finger_amounts[0]) > 0.0, "Release animates instead of snapping instantly")
	await get_tree().create_timer(0.32).timeout
	check(absf(float(sprint.finger_amounts[0])) < 0.01, "Finger springs back to rest after release")

	sprint.scores[0] = 80
	sprint._process(0.01)
	check(sprint.ended, "Sprint finish line completes round")
	await frames()
	await photo("results_landscape")
	check(main.content.get_combined_minimum_size().y <= main.menu_scroll.size.y, "Landscape results fit without scrolling")
	check(find_button(main, "Play again   ↻").get_global_rect().end.y <= main.size.y and find_button(main, "More games").get_global_rect().end.y <= main.size.y, "Result actions are visible in landscape")
	Party.start_session("signal", false)
	main.launch_round()
	await frames()
	var snap = main.arena
	snap.set_process(false)
	snap.countdown = 0
	snap.scores[0] = 500
	snap.activate(0)
	check(snap.scores[0] == 400 and snap.reacted.has(0), "False start penalty")
	snap.signal_phase = "go"
	snap.signal_clock = 0.3
	snap.activate(0)
	check(snap.scores[0] == 400, "False start locks player for signal")
	snap.activate(1)
	check(snap.scores[1] == 820, "Reaction latency scoring")
	snap.activate(1)
	check(snap.scores[1] == 820, "One reaction per signal")
	snap.queue_redraw()
	await photo("signal_landscape")
	get_window().size = Vector2i(540, 900)
	await frames()
	snap.queue_redraw()
	await photo("signal_portrait")
	for id in snap.pads:
		check(Rect2(Vector2.ZERO, snap.size).encloses(snap.pads[id]), "Signal touch layout")
	# Advance all five signal phases with bots and no human input.
	snap.signal_round = 0
	snap.new_signal()
	for i in range(5):
		snap._process(4.0)
		snap._process(1.6)
		snap._process(1.3)
	check(snap.ended, "Five-signal game completes")
	await frames()
	main.show_home()
	get_window().size = Vector2i(1200, 720)
	await photo("home_landscape")
	main.show_library()
	await photo("library_landscape")
	main.show_setup()
	await photo("setup_landscape")
	main.show_shop()
	await photo("skins_landscape")
	main.show_settings()
	await photo("settings_landscape")
	# Pair Peek: only the current player may reveal, exactly two cards per turn.
	Party.slots = ["Human", "Human", "Off", "Off"]
	Party.start_session("pairs", true)
	check(Party.schedule.size() == 3 and Party.schedule.has("pairs"), "Four-game cup catalog")
	main.launch_round()
	await frames()
	var memory = main.arena
	memory.set_process(false)
	memory.countdown = 0
	memory.deck = [0, 1, 0, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7]
	memory.choose_card(0)
	memory.choose_card(1)
	memory.choose_card(2)
	check(memory.opened == [0, 1], "Memory allows only two reveals")
	memory.resolve_pair()
	check(memory.turn == 1 and memory.scores[0] == 0, "Mismatch passes turn")
	check(memory.control_is_highlighted(1) and not memory.control_is_highlighted(0), "Only current player is highlighted")
	check(memory.control_label(0, false).contains("WAIT") and memory.control_label(1, false).contains("TURN"), "Turn labels distinguish active and waiting players")
	check(memory.turn_instruction() == "Tap two cards", "Turn instruction names card input target")
	memory.choose_card(0)
	memory.choose_card(2)
	memory._process(0.3)
	memory.queue_redraw()
	await photo("pairs_landscape")
	memory.resolve_pair()
	check(memory.scores[1] == 1 and memory.matched.size() == 2 and memory.turn == 0, "Match earns pair and passes turn")
	memory.choose_card(0)
	check(memory.opened.is_empty(), "Matched cards cannot reopen")
	memory.choose_card(1, true)
	check(memory.opened.is_empty(), "Bot cannot act on human turn")
	get_window().size = Vector2i(540, 900)
	await frames()
	memory._process(0.3)
	memory.queue_redraw()
	await photo("pairs_portrait")
	for rect in memory.card_rects:
		check(Rect2(Vector2.ZERO, memory.size).encloses(rect), "Memory grid within viewport")
	memory.choose_card(1)
	memory.choose_card(3)
	memory.resolve_pair()
	for pair in range(2, 8):
		memory.choose_card(pair * 2)
		memory.choose_card(pair * 2 + 1)
		memory.resolve_pair()
	check(memory.ended and memory.pairs_found == 8, "All eight pairs complete game")
	await frames()
	# BurgerTower: real physics, support graph, rotation and pause.
	Party.slots = ["Human", "Bot", "Off", "Off"]
	Party.start_session("burger", false)
	main.launch_round()
	await frames()
	var burger = main.arena
	burger.countdown = 0
	burger.set_process(false)
	burger._process(0.01)
	var lane = burger.lanes[0]
	lane.preview_x = 180
	lane.preview_y = 80
	check(lane.drop(), "Burger drop accepted")
	check(not lane.drop(), "Burger cooldown prevents spam")
	check(burger.views[0].world_2d != burger.views[1].world_2d, "Independent lane physics")
	await get_tree().create_timer(1.5).timeout
	check(lane.pieces.size() == 1 and lane.measure() > 20, "Ingredient lands and counts supported height")
	var body = lane.pieces[0]
	var position_before: Vector2 = body.position
	burger.paused = true
	burger._process(0.01)
	await get_tree().create_timer(0.2).timeout
	check(body.freeze and body.position.distance_to(position_before) < 2, "Pause freezes physics")
	burger.paused = false
	burger._process(0.01)
	await get_tree().create_timer(0.1).timeout
	check(not body.freeze, "Resume restores physics")
	burger.queue_redraw()
	await photo("burger_portrait")
	get_window().size = Vector2i(1200, 720)
	await frames()
	burger.queue_redraw()
	await photo("burger_landscape")
	check(body.position.distance_to(position_before) < 5, "Rotation keeps physics coordinates stable")
	lane.cooldown = 0
	lane.preview_x = 335
	lane.preview_y = 80
	lane.drop()
	await get_tree().create_timer(1.8).timeout
	check(lane.measure() < 40, "Off-plate ingredient never scores airborne height")
	burger.time = burger.duration + burger.settle_duration
	burger._process(0.01)
	check(burger.ended and burger.scores[0] > 0, "Timed burger round completes")
	await frames()
	main.show_home()
	find_button(main, "Play on One Device   →").pressed.emit()
	check(main.page == "setup", "Home chooses roster before games")
	check(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch")), "Native menus require emulated mouse from touch")
	check(main.find_children("*", "OptionButton", true, false).is_empty(), "Seat states use buttons")
	check(main.seat_choice_buttons.size() == 12, "Three state buttons for each seat")
	main.seat_choice_buttons[1].pressed.emit()
	check(Party.slots[0] == "Bot" and main.seat_continue.disabled, "All-bot roster disables continue")
	main.seat_choice_buttons[0].pressed.emit()
	check(Party.slots[0] == "Human" and not main.seat_continue.disabled, "Human button enables continue")
	for choice in main.seat_choice_buttons:
		check(choice.button_pressed == (choice.get_meta("seat_mode") == Party.slots[choice.get_meta("seat_id")]), "Selected state matches roster")
	find_button(main, "Choose your games   →").pressed.emit()
	check(main.page == "library", "Roster leads to preview library")
	find_button(main, "", "pairs").pressed.emit()
	check(main.page == "game" and main.current_game == "pairs", "Quick preview tap launches game")
	main.show_library()
	find_button(main, "Build tournament").pressed.emit()
	for id in ["sprint", "pairs", "burger"]:
		find_button(main, "", id).pressed.emit()
	check(main.cup_selection == ["sprint", "pairs", "burger"], "Preview selection preserves cup order")
	await photo("tournament_landscape")
	var cup_coins: int = Party.coins
	find_button(main, "Start tournament   →").pressed.emit()
	check(Party.schedule == ["sprint", "pairs", "burger"], "User-built cup schedule")
	for round_number in range(3):
		main.round_finished({0: 10, 1: 5})
		await frames()
		main.next_round()
		await frames()
	check(main.cup_done and Party.coins == cup_coins + 85, "Selected cup completes with gold payout")
	get_window().size = Vector2i(540, 900)
	main.show_library()
	await photo("previews_portrait")
	Party.slots = ["Human", "Bot", "Human", "Bot"]
	Party.start_session("darkspots", false)
	main.launch_round()
	await frames()
	var dark = main.arena
	dark.set_process(false)
	dark.countdown = 0
	dark.time = 1.0
	var first_target: float = dark.targets[0]
	var first_length: float = dark.range_lengths[0]
	dark.positions[0] = first_target
	dark.activate(0)
	check(dark.range_lengths[0] != first_length, "Darkspots hit changes range length")
	check(dark.range_lengths[0] >= dark.MIN_RANGE_LENGTH and dark.range_lengths[0] <= dark.MAX_RANGE_LENGTH, "Darkspots range size bounds")
	check(dark.scores[0] == 5 and dark.targets[0] != first_target, "Darkspots hit earns five points and moves target")
	check(dark.orbit_distance(first_target, dark.targets[0]) >= 0.2, "New dark spot moves a meaningful distance")
	dark.activate(0)
	check(dark.scores[0] == 5, "Darkspots suppresses duplicate touch/mouse taps")
	dark.time = 1.3
	var next_target: float = dark.targets[0]
	dark.positions[0] = fposmod(next_target + 0.3, 1)
	dark.activate(0)
	check(dark.scores[0] == 5 and dark.targets[0] == next_target, "Darkspots miss gives no point and keeps target")
	check(is_equal_approx(dark.orbit_distance(0.99, 0.01), 0.02), "Darkspots hit window wraps at square origin")
	dark.paused = true
	var time_before: float = dark.time
	dark._process(2.0)
	dark.activate(0)
	check(dark.time == time_before and dark.scores[0] == 5, "Darkspots pause blocks orbit, clock and scoring")
	dark.paused = false
	dark.queue_redraw()
	await photo("darkspots_portrait")
	for rect in dark.pads.values():
		check(Rect2(Vector2.ZERO, dark.size).encloses(rect), "Darkspots portrait controls within arena")
	get_window().size = Vector2i(1200, 720)
	await frames()
	dark.queue_redraw()
	await photo("darkspots_landscape")
	for rect in dark.pads.values():
		check(Rect2(Vector2.ZERO, dark.size).encloses(rect), "Darkspots landscape controls within arena")
	dark.time = 2.0
	var range_length: float = dark.range_lengths[0]
	dark.positions[0] = fposmod(dark.targets[0] + range_length * 0.49, 1)
	var points_before: int = dark.scores[0]
	dark.activate(0)
	check(dark.scores[0] == points_before + 5, "Outer portion of dark range scores")
	dark.time = 2.3
	dark.positions[0] = fposmod(dark.targets[0] + dark.range_lengths[0] / 2 + dark.ring_overlap_allowance() + 0.01, 1)
	points_before = dark.scores[0]
	dark.activate(0)
	check(dark.scores[0] == points_before, "Outside visible range does not score")
	dark.time = 2.6
	dark.positions[0] = fposmod(dark.targets[0] + dark.range_lengths[0] / 2 + dark.ring_overlap_allowance() * 0.5, 1)
	points_before = dark.scores[0]
	dark.activate(0)
	check(dark.scores[0] == points_before + 5, "Visible ring overlapping target edge scores")
	check(dark.message_times[0] == dark.time and dark.messages[0].begins_with("+5"), "Hit feedback remains available after finger tap")
	var square = Rect2(0, 0, 100, 100)
	var wrapped_range = dark.perimeter_range(square, 0.99, 0.20)
	check(wrapped_range.size() == 3 and wrapped_range[1].is_equal_approx(Vector2.ZERO), "Dark range follows corner across loop origin")
	check(dark.visible_overlap(square, 0.29, 0.24, 0.02), "Gold overlap around square corner counts using visible geometry")
	check(not dark.visible_overlap(square, 0.45, 0.24, 0.02), "Separated ring and gold still miss")
	dark.time = 3.0
	dark.positions[0] = fposmod(dark.targets[0] + 0.3, 1)
	dark.displayed_states[0] = {"square": dark.board_square(0), "position": dark.targets[0], "target": dark.targets[0], "length": dark.range_lengths[0], "index": dark.target_indices[0], "time": 2.95, "ticks": Time.get_ticks_msec()}
	check(dark.tap_overlaps(0, false), "Tap can score ring position in most recently displayed frame")
	check(not dark.tap_overlaps(0, true), "Bots receive no display latency allowance")
	dark.displayed_states[0].index -= 1
	check(not dark.tap_overlaps(0, false), "Previous target frame cannot score twice")
	dark.displayed_states[0].index += 1
	dark.displayed_states[0].time = 2.8
	check(not dark.tap_overlaps(0, false), "Old displayed frames cannot score")
	dark.displayed_states.clear()
	points_before = dark.scores[0]
	dark.activate(0)
	check(dark.scores[0] == points_before, "Separated tap misses before retry")
	dark.time += 0.06
	dark.positions[0] = dark.targets[0]
	dark.activate(0)
	check(dark.scores[0] == points_before + 5, "Valid tap shortly after miss is not swallowed by long lockout")
	dark.rng.seed = 42
	for i in range(120):
		dark._process(0.1)
	check(not dark.ended and dark.duration == 20.0, "Darkspots keeps running after ten seconds")
	dark.time = 19.9
	dark._process(0.2)
	check(dark.ended and is_equal_approx(dark.time, 20.0), "Darkspots ends exactly at twenty seconds")
	check(dark.scores[1] > 0 or dark.scores[3] > 0, "Darkspots bots can score")
	var final_scores: Dictionary = dark.scores.duplicate()
	dark.activate(0)
	check(dark.scores == final_scores, "Darkspots cannot score after deadline")
	await frames()
	main.show_shop()
	await frames()
	var touch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = main.menu_scroll.get_global_rect().get_center()
	main._input(touch)
	var drag = InputEventScreenDrag.new()
	drag.index = 0
	drag.position = touch.position - Vector2(0, 180)
	drag.relative = Vector2(0, -180)
	drag.velocity = Vector2(0, -600)
	main._input(drag)
	check(main.menu_scroll.scroll_vertical > 0, "Swiping over skin cards scrolls menu")
	touch.pressed = false
	main._input(touch)
	check(main.swipe_index == -1 and main.swipe_block_until > Time.get_ticks_msec(), "Swipe release suppresses accidental skin button clicks")
	main.swipe_velocity = 0
	main.menu_scroll.scroll_vertical = 0
	var mouse_down = InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	mouse_down.position = main.menu_scroll.get_global_rect().get_center()
	main._input(mouse_down)
	var mouse_drag = InputEventMouseMotion.new()
	mouse_drag.position = mouse_down.position - Vector2(0, 160)
	mouse_drag.relative = Vector2(0, -160)
	mouse_drag.velocity = Vector2(0, -500)
	main._input(mouse_drag)
	check(main.menu_scroll.scroll_vertical > 0, "Mouse drag also scrolls skin shop")
	mouse_down.pressed = false
	mouse_down.position = Vector2(-100, -100)
	main._input(mouse_down)
	check(main.swipe_index == -1, "Dragging outside menu releases scroll pointer")
	var saved_offset: int = main.menu_scroll.scroll_vertical
	main.show_shop("Scroll position is preserved")
	await frames()
	check(main.menu_scroll.scroll_vertical == saved_offset, "Skin updates preserve scroll position")
	Party.coins = 1000
	var animal_ids: Array = ["rabbit", "koala", "panda", "capybara"]
	for i in range(4):
		check(Party.buy_skin(animal_ids[i]), "Animal skin can be unlocked")
		Party.equipped[i] = animal_ids[i]
	Party.save_progress()
	Party.equipped = ["classic", "classic", "classic", "classic"]
	Party.load_progress()
	check(Party.equipped == animal_ids and Party.coins == 790, "Animal equips and purchases persist")
	Music.set_enabled(true)
	await get_tree().create_timer(0.7).timeout
	check(Music.player.playing and Music.player.volume_db > -19, "Ambient music fades in independently of effects")
	Party.load_progress()
	check(Party.music_enabled and not Party.sound, "Music and effects preferences persist separately")
	Music._notification(NOTIFICATION_APPLICATION_PAUSED)
	check(Music.player.stream_paused, "Music pauses when application backgrounds")
	Music.player.stop()
	Music._notification(NOTIFICATION_APPLICATION_RESUMED)
	await get_tree().create_timer(0.7).timeout
	check(Music.player.playing and not Music.player.stream_paused, "Music restarts after interrupted Android playback on resume")
	Music.set_enabled(false)
	await get_tree().create_timer(0.5).timeout
	check(not Music.player.playing, "Disabling music fades and stops playback")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Party.save_path))
	print("SMOKE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
