extends SceneTree
func _initialize() -> void:
	var content: String = Engine.get_license_text() + "\n\nTHIRD-PARTY COPYRIGHT NOTICES\n\n" + JSON.stringify(Engine.get_copyright_info(), "  ") + "\n\nLICENSE TEXTS\n\n" + JSON.stringify(Engine.get_license_info(), "  ")
	var out = FileAccess.open("res://publishing/google-play/GODOT_LICENSES.txt", FileAccess.WRITE)
	out.store_string(content)
	out.close()
	print("Exported Godot and third-party license notices")
	call_deferred("finish")

func finish() -> void:
	var music = root.get_node_or_null("Music")
	if music and is_instance_valid(music.player):
		music.player.stop()
	await create_timer(0.06).timeout
	quit()
