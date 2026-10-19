extends Node
var player: AudioStreamPlayer
func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
func tone(frequency: float = 660.0) -> void:
	if not Party.sound:
		return
	var data = PackedByteArray()
	var length: int = 2400
	for i in range(length):
		var value: int = int(sin(TAU * frequency * i / 24000.0) * 8500 * (1.0 - float(i) / length))
		data.append(value & 255)
		data.append((value >> 8) & 255)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 24000
	stream.data = data
	player.stream = stream
	player.play()
