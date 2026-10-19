extends RefCounted
static var cached_rainbow: GradientTexture2D
static func rainbow_square() -> GradientTexture2D:
	if cached_rainbow == null:
		var gradient = Gradient.new()
		gradient.colors = PackedColorArray([Color("ff8fa3"), Color("ffc175"), Color("fff176"), Color("7cf2a3"), Color("72dafa"), Color("9a9aff"), Color("e3a0ff")])
		gradient.offsets = PackedFloat32Array([0, 0.1667, 0.3333, 0.5, 0.6667, 0.8333, 1])
		cached_rainbow = GradientTexture2D.new()
		cached_rainbow.gradient = gradient
		cached_rainbow.width = 128
		cached_rainbow.height = 128
		cached_rainbow.fill_from = Vector2.ZERO
		cached_rainbow.fill_to = Vector2.ONE
	return cached_rainbow
