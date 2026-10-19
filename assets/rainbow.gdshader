shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// Soft diagonal rainbow, drifting slowly without abrupt color changes.
	float hue = UV.x * 0.68 + UV.y * 0.42 + sin(TIME * 0.12) * 0.035;
	vec3 rainbow = 0.5 + 0.5 * cos(6.2831853 * (hue + vec3(0.0, 0.6666667, 0.3333333)));
	vec3 pastel = mix(rainbow, vec3(1.0), 0.48);
	COLOR = vec4(pastel, 1.0);
}
