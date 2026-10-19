extends "res://games/arena.gd"
const Lane = preload("res://games/burger_lane.gd")
var lanes: Dictionary = {}
var views: Dictionary = {}
var display_scores: Dictionary = {}
var bot_targets: Dictionary = {}
var lane_rects: Dictionary = {}
var settle_duration: float = 2.0

func _ready() -> void:
	duration = 30.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	rng.randomize()
	audio = Audio.new()
	add_child(audio)
	for p in roster:
		scores[p.id] = 0
		display_scores[p.id] = 0.0
		bot_targets[p.id] = rng.randf_range(-30, 30)
		var view = SubViewport.new()
		view.size = Vector2i(360, 560)
		view.world_2d = World2D.new()
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.physics_object_picking = false
		view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		add_child(view)
		var lane = Lane.new()
		lane.phase = 0.0 # Identical wave and ingredient sequence for every seat.
		view.add_child(lane)
		lanes[p.id] = lane
		views[p.id] = view

func _process(delta: float) -> void:
	if NetPlay.client_frame(self, delta):
		return
	for p in roster:
		lanes[p.id].active = not paused and not ended and countdown <= 0
		lanes[p.id].accepting = time < duration
	if paused or ended:
		return
	if countdown > 0:
		countdown -= delta
		queue_redraw()
		return
	time += delta
	for p in roster:
		var lane = lanes[p.id]
		scores[p.id] = roundi(lane.settled_height / 4)
		display_scores[p.id] = lerpf(display_scores[p.id], scores[p.id], 1.0 - exp(-delta * 9))
		if p.bot and time < duration and lane.cooldown <= 0:
			var tolerance: float = [40.0, 22.0, 10.0][Party.difficulty]
			if absf(lane.preview_x - 180 - bot_targets[p.id]) < tolerance:
				activate(p.id)
				bot_targets[p.id] = rng.randf_range(-tolerance, tolerance)
	if time >= duration + settle_duration:
		for p in roster:
			scores[p.id] = roundi(lanes[p.id].measure() / 4)
			lanes[p.id].active = false
		complete()
	queue_redraw()

func activate(id: int) -> void:
	if NetPlay.intercept(id, "tap"):
		return
	if ended or paused or countdown > 0 or time >= duration or not lanes.has(id):
		return
	if lanes[id].drop():
		audio.tone(340 + id * 90)

func _draw() -> void:
	var portrait: bool = size.y > size.x
	var cols: int = mini(2, roster.size()) if portrait else roster.size()
	var rows: int = ceili(float(roster.size()) / cols)
	var top: float = 110
	round_clock("Settling…" if time >= duration else "%02d seconds" % maxi(0, ceili(duration - time)))
	var cell: Vector2 = Vector2((size.x - (cols - 1) * 12) / cols, (size.y - top - 110 - (rows - 1) * 12) / rows)
	pads.clear()
	for i in range(roster.size()):
		var p = roster[i]
		var rect = Rect2(Vector2((i % cols) * (cell.x + 12), top + floorf(float(i) / cols) * (cell.y + 12)), cell)
		lane_rects[p.id] = rect
		draw_style_box(style(p.color.darkened(0.9), 20), rect)
		text_at("P%d%s · %d cm" % [p.id + 1, " BOT" if p.bot else "", roundi(display_scores[p.id])], rect.position + Vector2(cell.x / 2, 27), 20, p.color)
		var picture_area = Rect2(rect.position + Vector2(6, 34), Vector2(cell.x - 12, cell.y - 44))
		var factor: float = minf(picture_area.size.x / 360, picture_area.size.y / 560)
		var picture_size = Vector2(360, 560) * factor
		draw_texture_rect(views[p.id].get_texture(), Rect2(picture_area.get_center() - picture_size / 2, picture_size), false)
	corner_controls()
	if countdown > 0:
		draw_style_box(style(Color(0.035, 0.047, 0.09, 0.94)), Rect2(Vector2.ZERO, size))
		text_at(str(ceili(countdown)), size / 2, 90, Color("ffd577"))
		text_at("Steady hands. Tall burgers.", size / 2 + Vector2(0, 65), 22)
