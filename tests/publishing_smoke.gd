extends Node
const Main = preload("res://ui/main.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func button(node: Node, title: String) -> Button:
	if node is Button and node.text == title:
		return node
	for child in node.get_children():
		var found = button(child, title)
		if found:
			return found
	return null

func _ready() -> void:
	Party.save_path = "res://builds/publishing_test_save.json"
	Music.set_enabled(false)
	var main = Main.new()
	add_child(main)
	main.show_settings()
	check(is_instance_valid(button(main, "Privacy policy")), "Privacy policy is accessible from Settings")
	button(main, "Privacy policy").pressed.emit()
	check(main.page == "privacy", "Policy page opens without internet access")
	check(FileAccess.get_file_as_string("res://PRIVACY_POLICY.md").contains("ed.fruty@gmail.com"), "Policy includes requested support contact")
	check(is_instance_valid(button(main, "Open policy online")) and is_instance_valid(button(main, "Contact support")), "Online policy and support actions exist")
	main.back()
	check(main.page == "settings", "Privacy Back returns to Settings")
	button(main, "Open source licenses").pressed.emit()
	check(main.page == "licenses" and FileAccess.get_file_as_string("res://publishing/google-play/GODOT_LICENSES.txt").length() > 50000, "License page includes actual engine and third-party notices")
	main.back()
	check(main.page == "settings", "Licenses Back returns to Settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Party.save_path))
	Music.player.stop()
	await get_tree().create_timer(0.1).timeout
	print("PUBLISHING: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
