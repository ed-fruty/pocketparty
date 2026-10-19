extends Node
const Main = preload("res://ui/main.gd")
var viewport: SubViewport
var ui: Control

func _ready() -> void:
	Party.save_path = "res://builds/player_fields_capture_save.json"
	Party.sound = false
	Music.set_enabled(false)
	Music.player.stop()
	Party.slots = ["Human", "Human", "Human", "Human"]
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	ui = Main.new()
	viewport.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for dimensions in [Vector2i(720, 1280), Vector2i(1280, 720)]:
		viewport.size = dimensions
		for game in ["darkspots", "burger", "sprint", "obby", "dance"]:
			Party.start_session(game, false)
			ui.launch_round()
			ui.arena.countdown = 0
			ui.arena.set_process(false)
			for i in range(8):
				await get_tree().process_frame
			await get_tree().create_timer(0.32).timeout
			RenderingServer.force_draw()
			viewport.get_texture().get_image().save_png("res://builds/player-fields-%s-%s.png" % [game, "portrait" if dimensions.y > dimensions.x else "landscape"])
	Music.player.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
