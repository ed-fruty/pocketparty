extends Control
const Avatar = preload("res://ui/avatar.gd")
const Catalog = preload("res://core/catalog.gd")
var roster: Array = []
var history: Array = []
var schedule: Array = []
var totals: Dictionary = {}
var animate_latest = true
var progress = 0.0
var avatars: Dictionary = {}
var ordered: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ordered = roster.duplicate(true)
	ordered.sort_custom(func(a, b):
		var difference: int = int(totals.get(a.id, 0)) - int(totals.get(b.id, 0))
		return difference > 0 if difference != 0 else a.id < b.id)
	custom_minimum_size.y = 64 + roster.size() * 58 + ceili(schedule.size() / 2.0) * 22 + 16
	for p in roster:
		var avatar = Avatar.new()
		avatar.skin = p.skin
		avatar.tint = p.color
		avatar.animate = false
		add_child(avatar)
		avatars[p.id] = avatar
	progress = 0 if animate_latest else 1
	if animate_latest:
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(self, "progress", 1.0, 1.0)

func _process(_delta: float) -> void:
	queue_redraw()

func word(value: String, point: Vector2, font_size: int, color: Color, centered: bool = true) -> void:
	var font = ThemeDB.fallback_font
	var offset: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2 if centered else 0
	draw_string(font, point - Vector2(offset, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func panel(rect: Rect2, fill: Color, border: Color = Color.TRANSPARENT) -> void:
	var box = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(12)
	box.set_border_width_all(2)
	box.border_color = border
	draw_style_box(box, rect)

func points_for(round_id: int, player_id: int) -> int:
	for result in history:
		if int(result.round) == round_id:
			return int(result.points.get(player_id, 0))
	return 0

func completed(round_id: int) -> bool:
	for result in history:
		if int(result.round) == round_id:
			return true
	return false

func shown_total(player_id: int) -> int:
	var total: int = int(totals.get(player_id, 0))
	var latest: int = int(history.back().points.get(player_id, 0)) if not history.is_empty() else 0
	return total - latest + roundi(latest * progress) if animate_latest else total

func _draw() -> void:
	if ordered.is_empty() or schedule.is_empty():
		return
	panel(Rect2(Vector2.ZERO, size), Color("151e34"))
	var compact: bool = size.x < 850
	var name_width: float = 126 if compact else 194
	var total_width: float = 76 if compact else 118
	var round_width: float = (size.x - name_width - total_width - 24) / schedule.size()
	var latest: int = int(history.back().round) if not history.is_empty() else -1
	word("PLAYER", Vector2(16, 29), 15, Color("a4afc8"), false)
	word("TOTAL", Vector2(size.x - total_width / 2 - 8, 29), 16, Color("ffd577"))
	for index in range(schedule.size()):
		var x: float = name_width + (index + 0.5) * round_width
		word("R%d" % (index + 1), Vector2(x, 29), 16, Color("ffd577") if index == latest else Color("a4afc8"))
	var best: int = int(totals.get(ordered[0].id, 0))
	for row in range(ordered.size()):
		var p: Dictionary = ordered[row]
		var y: float = 43 + row * 58
		var leader: bool = int(totals.get(p.id, 0)) == best
		panel(Rect2(10, y, size.x - 20, 52), Color("302942") if leader else Color("202b43"), p.color)
		avatars[p.id].position = Vector2(18, y + 8)
		avatars[p.id].size = Vector2(34, 34)
		word("P%d%s" % [p.id + 1, " BOT" if p.bot else " YOU" if NetPlay.active and NetPlay.local_id == p.id else ""], Vector2(58, y + 22), 15, p.color, false)
		word("LEADER" if leader else "", Vector2(58, y + 41), 11, Color("ffd577"), false)
		for index in range(schedule.size()):
			var x: float = name_width + (index + 0.5) * round_width
			var value: String = "+%d" % points_for(index, p.id) if completed(index) else "—"
			word(value, Vector2(x, y + 33), 15 if compact else 20, Color("ffd577") if index == latest else Color("dce6f0"))
		word(str(shown_total(p.id)), Vector2(size.x - total_width / 2 - 8, y + 35), 28, Color("ffd577"))
	var legend_y: float = 43 + ordered.size() * 58 + 25
	for index in range(schedule.size()):
		var x: float = 18 if index % 2 == 0 else size.x / 2
		word("R%d · %s" % [index + 1, Catalog.entry(schedule[index]).title], Vector2(x, legend_y + floori(index / 2.0) * 22), 14, Color("a4afc8"), false)
	word("Points by place · ties receive the same points", Vector2(size.x / 2, size.y - 14), 14, Color("a4afc8"))
