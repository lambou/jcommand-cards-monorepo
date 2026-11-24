shader_type canvas_item;
// Analytic anti-aliased disc with an optional border ring. Edges are exactly ~1 px wide at any
// scale/DPI (width comes from fwidth of the distance), unlike polygon discs whose edge quality
// depends on segment count and MSAA.

uniform vec4 fill_color : source_color = vec4(1.0);
uniform vec4 border_color : source_color = vec4(0.0);
uniform float radius = 30.0;   // outer radius, in pixels of the node's local space
uniform float border = 0.0;    // border width, pixels (inside the radius)
uniform vec2 node_size = vec2(64.0);

float cover(float d) {
	// 1 inside, 0 outside, one-pixel transition centred on d = 0.
	float w = max(fwidth(d), 0.0001);
	return clamp(0.5 - d / w, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV * node_size - node_size * 0.5;
	float r = length(p);
	float outer = cover(r - radius);
	float inner = border > 0.0 ? cover(r - (radius - border)) : 1.0;
	vec4 c = mix(border_color, fill_color, inner);
	COLOR = vec4(c.rgb, c.a * outer);
}
