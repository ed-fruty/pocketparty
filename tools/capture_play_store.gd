extends Node
const Main = preload("res://ui/main.gd")
const Feature = preload("res://tools/play_feature.gd")
var screen: SubViewport
var main: Control
var directory: String

func frames() -> void:
	for i in range(6):
		await get_tree().process_frame

func set_size(pixels: Vector2i) -> void:
	screen.size = pixels
	screen.size_2d_override = Vector2i(720, 1280) if pixels.y > pixels.x else Vector2i(1280, 720)
	screen.size_2d_override_stretch = true
	await frames()

func photo(name: String) -> void:
	await frames()
	await get_tree().create_timer(0.35).timeout
	RenderingServer.force_draw()
	var image = screen.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	var result: int = image.save_png(directory.path_join(name + ".png"))
	if result != OK:
		push_error("Screenshot failed: " + name)
		get_tree().quit(1)
	print(name, " ", image.get_size())

func game(id: String) -> Control:
	Party.start_session(id, false)
	main.current_game = id
	main.launch_round()
	await frames()
	main.arena.countdown = 0
	main.arena.set_process(false)
	return main.arena

func snake(name: String) -> void:
	var arena = await game("snake")
	arena.rng.seed = 24
	for step in range(65):
		for p in arena.roster:
			arena.think_bot(p.id)
		arena.simulate_step(arena.STEP)
	arena.queue_redraw()
	await photo(name)

func dance(name: String) -> void:
	var arena = await game("dance")
	arena.leader_id = 0
	for move in [0, 1, 2, 3, 0]:
		arena.choose_move(0, move)
	arena.begin_repeat()
	arena.choose_move(1, 0)
	arena.choose_move(1, 1)
	arena._process(0.22)
	arena.queue_redraw()
	await photo(name)

func burger(name: String) -> void:
	var arena = await game("burger")
	arena.set_process(true)
	for drop in range(4):
		for id in [0, 1]:
			arena.lanes[id].drop()
		await get_tree().create_timer(0.75).timeout
	arena.set_process(false)
	await photo(name)

func ceremony(name: String) -> void:
	Party.start_session("sprint", true)
	for round_number in range(3):
		Party.round_index = round_number
		Party.record_round({0: 10, 1: 10, 2: 3, 3: 1} if round_number != 1 else {0: 3, 1: 3, 2: 10, 3: 1})
	main.last_winners = Party.finish_cup()
	main.cup_done = true
	main.show_results()
	await frames()
	var stage = main.find_child("TournamentCeremony", true, false)
	stage.age = 1.4
	await photo(name)
	main.cup_done = false

func _ready() -> void:
	Party.save_path = "res://builds/store_capture_save.json"
	Party.slots = ["Human", "Human", "Bot", "Bot"]
	Party.equipped = ["panda", "capybara", "koala", "rabbit"]
	Party.coins = 320
	Party.sound = false
	Music.set_enabled(false)
	get_window().size = Vector2i(360, 220)
	screen = SubViewport.new()
	screen.disable_3d = true
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(screen)
	main = Main.new()
	screen.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for device in ["phone", "tablet-7-inch", "tablet-10-inch"]:
		directory = "res://builds/google-play/screenshots/" + device
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if device == "phone":
			await set_size(Vector2i(1080, 1920))
			main.show_library()
			await photo("01-game-library")
			await snake("02-snake-clash")
			var memory = await game("pairs")
			memory.choose_card(0)
			memory.choose_card(1)
			memory._process(0.30)
			memory.queue_redraw()
			await photo("03-pair-peek")
			await dance("04-lets-dance")
			await set_size(Vector2i(1920, 1080))
			await burger("05-burger-tower")
			var obby = await game("obby")
			obby.time = obby.course[0].at - 0.34
			obby.do_action(0, obby.course[0].kind)
			obby.do_action(1, "duck" if obby.course[0].kind == "jump" else "jump")
			obby._process(0.15)
			await photo("06-obby-run")
			var dark = await game("darkspots")
			dark.time = 2.0
			dark.positions[0] = dark.targets[0]
			dark.activate(0)
			dark._process(0.12)
			await photo("07-darkspots")
			await ceremony("08-tournament-cups")
		else:
			await set_size(Vector2i(1920, 1080) if device == "tablet-7-inch" else Vector2i(2560, 1440))
			await snake("01-snake-clash")
			await dance("02-lets-dance")
			await burger("03-burger-tower")
			await ceremony("04-tournament-cups")
	main.queue_free()
	await frames()
	screen.size_2d_override = Vector2i(1024, 500)
	screen.size = Vector2i(1024, 500)
	var feature = Feature.new()
	feature.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(feature)
	directory = "res://builds/google-play/graphics"
	await photo("feature-graphic-1024x500")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Party.save_path))
	Music.player.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
