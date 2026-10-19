extends Node
const Snake = preload("res://games/snake_clash.gd")
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
	var game = Snake.new()
	game.roster = Party.players()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game)
	game.set_process(false)
	game.countdown = 0
	game.rng.seed = 42
	return game

func body(head: Vector2, length: int) -> Array:
	var points: Array = []
	for i in range(length):
		points.append(head - Vector2(i * 7, 0))
	return points

func photo(game: Control, title: String) -> void:
	game.queue_redraw()
	for i in range(5):
		await get_tree().process_frame
	if capture:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://builds/%s.png" % title)

func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--screenshots")
	Party.save_path = "res://builds/snake_test_save.json"
	Party.sound = false
	Music.set_enabled(false)
	get_window().size = Vector2i(540, 900)
	var game = make_game(["Human", "Bot", "Human", "Bot"])
	check(game.duration == 10 and game.foods.size() == 18, "Ten-second hunt is ready; field starts with pizza")
	check(game.bodies.size() == 4 and game.bodies[0].size() == 8, "Four snakes start equal in size")
	check(game.bodies[0][0].y > 500 and game.bodies[2][0].y < 500, "P1 snake starts on bottom side like its control")
	game.foods = [game.bodies[0][0] + Vector2.UP * 7]
	game.simulate_step(game.STEP)
	check(game.bodies[0].size() == 11 and game.scores[0] == 11, "Pizza adds three body segments and updates score")
	check(game.foods.size() == 1 and game.foods[0].distance_to(game.bodies[0][0]) > 28, "Eaten pizza respawns away from snake")
	game.bodies[0] = body(Vector2(500, 500), 14)
	game.bodies[1] = body(Vector2(520, 500), 8)
	game.bodies[2] = body(Vector2(800, 800), 8)
	game.bodies[3] = body(Vector2(100, 100), 8)
	game.resolve_clashes()
	check(game.alive[0] and not game.alive[1] and game.scores[1] == 0, "Bigger snake consumes smaller snake; eaten snake cannot win")
	check(game.bodies[0].size() == 18, "Eating snake grows by absorbed prey")
	var length_after: int = game.bodies[0].size()
	game.resolve_clashes()
	check(game.bodies[0].size() == length_after, "Cannot consume same snake twice")
	game.bodies[2] = body(Vector2(520, 520), 8)
	game.bodies[3] = body(Vector2(525, 520), 8)
	game.bodies[0] = body(Vector2(100, 900), 18)
	game.resolve_clashes()
	check(game.alive[2] and game.alive[3], "Equal-size snakes survive contact")
	check(game.headings[2].dot(game.headings[3]) < -0.99, "Equal-size snakes bump in opposite directions")
	game.paused = true
	var old_time: float = game.time
	var old_head: Vector2 = game.bodies[0][0]
	game._process(2)
	check(game.time == old_time and game.bodies[0][0] == old_head, "Pause freezes clock and snakes")
	game.paused = false
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Bot", "Human", "Bot"])
	await photo(game, "snake_four_portrait")
	check(game.pads[0].position.y > game.size.y * 0.5 and game.pads[2].position.y < game.size.y * 0.5, "Snake controls retain bottom-first player ordering")
	check(game.corner_at(game.pads[1].get_center()) == -1, "Bot control cannot be steered by human")
	for id in [0, 2]:
		var press = InputEventScreenTouch.new()
		press.index = id
		press.pressed = true
		press.position = game.get_global_transform_with_canvas() * (game.pads[id].get_center() - Vector2(0, 12))
		get_viewport().push_input(press, true)
		var drag = InputEventScreenDrag.new()
		drag.index = id
		drag.position = press.position + Vector2(100 if id == 0 else -100, 0)
		get_viewport().push_input(drag, true)
	await get_tree().process_frame
	check(game.wishes[0].x > 0.99 and game.wishes[2].x < -0.99, "Simultaneous native drags independently steer two humans")
	for id in [0, 2]:
		var release = InputEventScreenTouch.new()
		release.index = id
		release.pressed = false
		get_viewport().push_input(release, true)
	check(game.held_corner_touches.is_empty(), "Touch release frees both steering controls")
	game.alive[2] = false
	check(game.corner_at(game.pads[2].get_center()) == -1, "Eaten snake control is disabled")
	game.alive[2] = true
	game.grow(0, 10)
	game.previous_bodies = game.bodies.duplicate(true)
	await photo(game, "snake_grown_portrait")
	get_window().size = Vector2i(1200, 720)
	await photo(game, "snake_four_landscape")
	for rect in game.pads.values():
		check(Rect2(Vector2.ZERO, game.size).encloses(rect), "Landscape control fits inside screen")
	check(game.field_rect().size.x > game.field_rect().size.y, "Landscape field fills available width")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Off", "Off", "Off"])
	game.foods.clear()
	game.bodies[0] = body(Vector2(978, 500), 8)
	game.headings[0] = Vector2.RIGHT
	game.wishes[0] = Vector2.RIGHT
	game.simulate_step(game.STEP)
	check(game.headings[0].x < 0 and game.alive[0], "Walls bounce snake safely rather than eliminate it")
	game.time = 0
	for i in range(599):
		game._process(1.0 / 60)
	check(not game.ended and game.chase_leader == -1, "Round has no ten-second limit before a biggest snake exists")
	game.grow(0, 3)
	game.update_hunt(0)
	game.accumulator = 0
	check(game.hunt_active and game.chase_left == 10, "Becoming biggest starts a full ten-second hunt")
	for i in range(599):
		game._process(1.0 / 60)
	check(not game.ended, "Hunt remains active until full ten seconds have elapsed")
	game._process(0.1)
	check(game.ended and game.chase_left == 0 and game.time > 10, "Ten-second hunt ends independently from total round time")
	old_head = game.bodies[0][0]
	game._process(2)
	check(game.bodies[0][0] == old_head, "No movement after round ends")
	game.queue_free()
	await get_tree().process_frame
	var fast = make_game(["Human", "Off", "Off", "Off"])
	var slow = make_game(["Human", "Off", "Off", "Off"])
	fast.foods.clear()
	slow.foods.clear()
	for i in range(120):
		fast._process(1.0 / 120)
	for i in range(30):
		slow._process(1.0 / 30)
	check(fast.bodies[0][0].distance_to(slow.bodies[0][0]) < 0.01, "Snake speed is identical at 30 and 120 FPS")
	fast.queue_free()
	slow.queue_free()
	await get_tree().process_frame
	game = make_game(["Bot", "Bot", "Bot", "Bot"])
	for i in range(3000):
		game.simulate_step(game.STEP)
		if game.ended:
			break
	var grew: bool = false
	for id in game.living_ids():
		grew = grew or game.bodies[id].size() > 8
	check(grew and game.ended and not game.living_ids().is_empty(), "Bots collect pizza and survive complete round")
	game.queue_free()
	await get_tree().process_frame
	game = make_game(["Human", "Human", "Off", "Off"])
	game.grow(0, 3)
	game.update_hunt(0)
	game.update_hunt(3)
	check(game.chase_leader == 0 and game.chase_left == 7, "Current biggest snake's hunt counts down")
	game.grow(1, 6)
	game.update_hunt(0.5)
	check(game.chase_leader == 1 and game.chase_left == 10, "Different biggest snake restarts a full hunt")
	game.grow(0, 3)
	game.update_hunt(4)
	check(not game.hunt_active and game.chase_left == 10, "Equal biggest snakes pause hunt")
	game.grow(1, 1)
	game.update_hunt(2)
	check(game.hunt_active and game.chase_leader == 1 and game.chase_left == 8, "Same leader resumes hunt after tie")
	game.queue_free()
	await get_tree().process_frame
	var main = Main.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	Party.slots = ["Human", "Bot", "Off", "Off"]
	Party.coins = 1000
	Party.start_session("snake", false)
	main.launch_round()
	check(main.current_game == "snake" and main.arena.duration == 10, "Snake Clash launches through shared catalog")
	main.round_finished({0: 20, 1: 0})
	await photo(main, "snake_results_landscape")
	check(Party.coins == 1015 and main.last_winners == [0], "Snake winner receives ordinary win gold")
	check(main.content.get_combined_minimum_size().y <= main.menu_scroll.size.y, "Snake results stay compact in landscape")
	main.show_library()
	await photo(main, "snake_library_landscape")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Party.save_path))
	print("SNAKE: %d checks, %d failures" % [checks, failures])
	Music.player.stop()
	await get_tree().create_timer(0.06).timeout
	get_tree().quit(0 if failures == 0 else 1)
