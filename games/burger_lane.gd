extends Node2D
const Ingredient = preload("res://games/ingredient.gd")
const FLOOR_Y: float = 510.0
var clock: float = 0.0
var phase: float = 0.0
var active: bool = false
var accepting: bool = true
var cooldown: float = 0.0
var next_kind: int = 0
var pieces: Array = []
var ground: StaticBody2D
var camera: Camera2D
var settled_height: float = 0.0
var preview_x: float = 180.0
var preview_y: float = 80.0
var count: int = 0
var freeze_state: bool = true
var stored_motion: Dictionary = {}

func _ready() -> void:
	ground = StaticBody2D.new()
	ground.position = Vector2(180, FLOOR_Y + 10)
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(145, 20)
	collision.shape = shape
	ground.add_child(collision)
	add_child(ground)
	camera = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position = Vector2(180, 380)
	add_child(camera)

func supported_pieces() -> Array:
	var supported: Array = [ground]
	# Traverse real contact links, so floating/falling ingredients never count as tower height.
	for pass_index in range(pieces.size() + 1):
		var changed: bool = false
		for piece in pieces:
			if not is_instance_valid(piece) or supported.has(piece):
				continue
			for contact in piece.get_colliding_bodies():
				if supported.has(contact):
					supported.append(piece)
					changed = true
					break
		if not changed:
			break
	supported.erase(ground)
	return supported

func measure() -> float:
	var highest: float = FLOOR_Y
	for piece in supported_pieces():
		if piece.linear_velocity.length() < 38 and absf(piece.angular_velocity) < 1.4:
			var extent: float = absf(sin(piece.rotation)) * piece.width / 2 + absf(cos(piece.rotation)) * piece.height / 2
			highest = minf(highest, piece.position.y - extent)
	return maxf(0, FLOOR_Y - highest)

func _process(delta: float) -> void:
	if active:
		clock += delta
		cooldown = maxf(0, cooldown - delta)
		settled_height = measure()
		preview_x = 180 + sin(clock * 1.65 + phase) * 116
		preview_y = FLOOR_Y - settled_height - 165

	queue_redraw()

func _physics_process(_delta: float) -> void:
	if active:
		camera.position.y = lerpf(camera.position.y, minf(380, preview_y + 180), 1.0 - exp(-_delta * 4))
	if freeze_state != not active:
		freeze_state = not active
		for piece in pieces:
			if is_instance_valid(piece):
				if freeze_state:
					stored_motion[piece] = [piece.linear_velocity, piece.angular_velocity]
				piece.freeze = freeze_state
				if not freeze_state and stored_motion.has(piece):
					piece.linear_velocity = stored_motion[piece][0]
					piece.angular_velocity = stored_motion[piece][1]
					stored_motion.erase(piece)
	for i in range(pieces.size() - 1, -1, -1):
		var piece = pieces[i]
		if is_instance_valid(piece) and piece.position.y > FLOOR_Y + 250:
			pieces.remove_at(i)
			stored_motion.erase(piece)
			piece.queue_free()

func drop() -> bool:
	if not active or not accepting or cooldown > 0:
		return false
	var piece = Ingredient.new()
	piece.kind = next_kind
	piece.height = [28.0, 18.0, 24.0, 17.0, 20.0, 30.0][next_kind]
	piece.width = [108.0, 116.0, 100.0, 110.0, 96.0, 112.0][next_kind]
	piece.position = Vector2(preview_x, preview_y)
	add_child(piece)
	piece.reset_physics_interpolation()
	pieces.append(piece)
	count += 1
	next_kind = count % 6
	cooldown = 0.75
	return true

func _draw() -> void:
	for i in range(1, 15):
		var y: float = FLOOR_Y - i * 40
		draw_line(Vector2(25, y), Vector2(335, y), Color(0.5, 0.6, 0.8, 0.1), 1, true)
		draw_string(ThemeDB.fallback_font, Vector2(12, y - 4), str(i * 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("6b7a97"))
	draw_circle(Vector2(180, FLOOR_Y + 60), 65, Color(0, 0, 0, 0.18))
	var plate = StyleBoxFlat.new()
	plate.bg_color = Color("dce6f0")
	plate.set_corner_radius_all(9)
	draw_style_box(plate, Rect2(101, FLOOR_Y, 158, 20))
	draw_line(Vector2(118, FLOOR_Y + 5), Vector2(242, FLOOR_Y + 5), Color.WHITE, 3, true)
	if accepting and cooldown <= 0:
		draw_dashed_line(Vector2(preview_x, preview_y + 24), Vector2(preview_x, FLOOR_Y - settled_height), Color(1, 1, 1, 0.2), 2, 8, true)
		draw_set_transform(Vector2(preview_x, preview_y), sin(clock * 3) * 0.025)
		Ingredient.draw_food(self, next_kind, [108,116,100,110,96,112][next_kind], [28,18,24,17,20,30][next_kind])
		draw_set_transform(Vector2.ZERO)
