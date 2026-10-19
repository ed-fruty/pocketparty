extends Node
var player: AudioStreamPlayer
var fade: Tween
var suspended: bool = false

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var stream = load("res://assets/audio/party_ambient.wav") as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	player.stream = stream
	player.volume_db = -80
	add_child(player)
	apply_enabled()

func set_enabled(enabled: bool) -> void:
	Party.music_enabled = enabled
	Party.save_progress()
	apply_enabled()

func apply_enabled() -> void:
	if not is_instance_valid(player):
		return
	if is_instance_valid(fade):
		fade.kill()
	fade = create_tween()
	if Party.music_enabled:
		if not player.playing:
			player.play()
		player.stream_paused = suspended
		fade.tween_property(player, "volume_db", -18.0, 0.6)
	else:
		fade.tween_property(player, "volume_db", -80.0, 0.4)
		fade.tween_callback(player.stop)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		suspended = true
		if is_instance_valid(player):
			player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		suspended = false
		if is_instance_valid(player) and Party.music_enabled:
			apply_enabled()
