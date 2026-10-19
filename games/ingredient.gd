extends RigidBody2D
var kind: int = 0
var width: float = 108.0
var height: float = 24.0
const FOOD_COLORS = [Color("f3b15e"), Color("9bd970"), Color("a05d42"), Color("ffce58"), Color("ee7666"), Color("f5c579")]
func _ready() -> void:
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	add_child(collision)
	mass = 0.8 if kind == 1 or kind == 3 else 1.3
	gravity_scale = 0.8
	linear_damp = 0.4
	angular_damp = 0.65
	contact_monitor = true
	max_contacts_reported = 8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.7
	physics_material_override.bounce = 0.08
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON

func _draw() -> void:
	draw_food(self, kind, width, height)

static func draw_food(canvas: CanvasItem, type: int, w: float, h: float) -> void:
	var rect = Rect2(-w / 2, -h / 2, w, h)
	var b = StyleBoxFlat.new()
	b.bg_color = FOOD_COLORS[type % 6]
	b.set_corner_radius_all(9 if type in [0, 5] else 5)
	canvas.draw_style_box(b, rect)
	canvas.draw_line(Vector2(-w * 0.4, h * 0.3), Vector2(w * 0.4, h * 0.3), FOOD_COLORS[type % 6].darkened(0.18), 3, true)
	if type in [0, 5]:
		for i in range(7):
			canvas.draw_line(Vector2(-w * 0.35 + i * w * 0.11, -h * 0.18 + (i % 2) * 5), Vector2(-w * 0.32 + i * w * 0.11, -h * 0.28 + (i % 2) * 5), Color("fff0c4"), 3, true)
	elif type == 1:
		for i in range(6):
			canvas.draw_circle(Vector2(-w * 0.42 + i * w * 0.16, h * 0.22), 6, FOOD_COLORS[1])
	elif type == 2:
		for i in range(4):
			canvas.draw_line(Vector2(-w * 0.32 + i * w * 0.21, -h * 0.2), Vector2(-w * 0.23 + i * w * 0.21, h * 0.1), Color("78432f"), 3, true)
	elif type == 3:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.2, 0), Vector2(w * 0.42, 0), Vector2(w * 0.36, h)]), FOOD_COLORS[3])
	elif type == 4:
		for i in range(4):
			canvas.draw_circle(Vector2(-w * 0.28 + i * w * 0.19, 0), 3, Color("ffdba2"))
