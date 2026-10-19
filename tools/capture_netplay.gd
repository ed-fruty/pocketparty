extends Node
const Main = preload("res://ui/main.gd")
var screen: SubViewport
var ui: Control

func photo(file: String, landscape: bool) -> void:
	screen.size = Vector2i(1280, 720) if landscape else Vector2i(720, 1280)
	for i in range(8):
		await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	RenderingServer.force_draw()
	screen.get_texture().get_image().save_png("res://builds/" + file + ".png")

func _ready() -> void:
	Party.save_path = "res://builds/netplay_capture_save.json"
	Party.sound = false
	Music.set_enabled(false)
	Music.player.stop()
	screen = SubViewport.new()
	screen.disable_3d = true
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(screen)
	ui = Main.new()
	screen.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.show_home()
	await photo("netplay-home", false)
	ui.show_netplay()
	await photo("netplay-join", false)
	NetPlay.stop_scan()
	if NetPlay.host() != OK:
		get_tree().quit(1)
		return
	NetPlay.set_seat(1, "Bot")
	ui.show_net_lobby()
	await photo("netplay-lobby-portrait", false)
	await photo("netplay-lobby-landscape", true)
	ui.show_library()
	await photo("netplay-library", true)
	Party.start_session("darkspots", false)
	ui.launch_round()
	await get_tree().create_timer(3.5).timeout
	await photo("netplay-darkspots", true)
	NetPlay.leave()
	Music.player.stop()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()
